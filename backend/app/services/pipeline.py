"""The story pipeline, one job at a time (AGENTS.md, *Staying up to date*):

    fetch-source  → new or changed items, saved first
    process-item  → rule 3 and noise, language, names
    index-item    → BGE-M3 vectors into Milvus Lite, then the clustering decision
    claims-item   → facts with quotes (claims agent), checked by the verifier
    write-story   → the story's title and cited summary (writer agent)

Every step can run again safely. Without model keys the agents are unavailable: stories
still form from clear matches, there are no facts, and nothing pretends otherwise."""

from collections.abc import Callable
from dataclasses import dataclass, field
from datetime import UTC, datetime, timedelta

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.agent.kit import AgentKit
from app.db.milvus import VectorIndex
from app.db.models import Claim, Item, Source, Story
from app.services import claims as claims_agent
from app.services import jobs
from app.services import judge as judge_agent
from app.services import verifier as verifier_agent
from app.services import writer as writer_agent
from app.services.clustering import Candidate, Thresholds, decide
from app.services.embeddings import Embedder, item_text
from app.services.ingestion import scheduler
from app.services.ingestion.adapters.feed import UnsafeFeed, parse_feed
from app.services.ingestion.fetcher import Fetcher, FetchError
from app.services.ingestion.safety import UnsafeUrl
from app.services.language import detect
from app.services.names import names as find_names
from app.services.triage import prefilter

#: Kinds that join stories. Papers wait for paper labels in the eval; photos and comics
#: are timeline-only (AGENTS.md, *Source types*).
CLUSTER_KINDS = frozenset({"article", "episode", "post", "video"})
#: A first fetch doesn't drag in a source's distant past.
MAX_AGE = timedelta(days=14)
MAX_ENTRIES = 200


class AgentUnavailable(RuntimeError):
    """A configured agent failed; the job retries later."""


def _aware(moment: datetime) -> datetime:
    return moment.replace(tzinfo=UTC) if moment.tzinfo is None else moment


@dataclass
class Pipeline:
    fetcher: Fetcher
    embedder_factory: Callable[[], Embedder]
    index_factory: Callable[[int], VectorIndex]
    kit: AgentKit
    thresholds: Thresholds = field(default_factory=Thresholds)
    clock: Callable[[], datetime] = lambda: datetime.now(UTC)
    _embedder: Embedder | None = None
    _index: VectorIndex | None = None

    @property
    def embedder(self) -> Embedder:
        if self._embedder is None:
            self._embedder = self.embedder_factory()
        return self._embedder

    @property
    def index(self) -> VectorIndex:
        if self._index is None:
            self._index = self.index_factory(self.embedder.dim)
        return self._index

    def handle(self, db: Session, kind: str, ref: str) -> None:
        handler = {
            "fetch-source": self.fetch_source,
            "process-item": self.process_item,
            "index-item": self.index_item,
            "claims-item": self.claims_item,
            "write-story": self.write_story,
        }[kind]
        handler(db, int(ref))

    # ── 1. Coming in ──────────────────────────────────────────────────────────

    def fetch_source(self, db: Session, source_id: int) -> None:
        source = db.get(Source, source_id)
        if source is None:
            return
        now = self.clock()
        try:
            result = self.fetcher.fetch(source.feed_url, etag=source.etag, last_modified=source.last_modified)
            if result.status == 304:
                scheduler.after_success(source, now)
                db.commit()
                return
            meta, entries = parse_feed(result.body, source_type=source.type)
        except (FetchError, UnsafeUrl, UnsafeFeed) as error:
            scheduler.after_error(source, now, str(error), retry_after_s=getattr(error, "retry_after_s", None))
            db.commit()
            return
        source.etag, source.last_modified = result.etag, result.last_modified
        hint = meta.language or source.language
        published = []
        for entry in entries[:MAX_ENTRIES]:
            when = min(_aware(entry.published_at), now) if entry.published_at else now
            published.append(when)
            item = db.scalar(select(Item).where(Item.source_id == source.id, Item.guid == entry.guid))
            if item is None:
                if now - when > MAX_AGE:
                    continue
                item = Item(
                    source_id=source.id,
                    guid=entry.guid,
                    link=entry.link,
                    title=entry.title,
                    text=entry.text,
                    language=detect(f"{entry.title}\n{entry.text}", hint),
                    kind=entry.kind,
                    published_at=when,
                    fetched_at=now,
                    updated_at=now,
                    content_hash=entry.content_hash,
                )
                db.add(item)
                db.flush()
                jobs.enqueue(db, "process-item", item.id)
            elif item.content_hash != entry.content_hash:
                # The source changed it, usually a correction: re-read it, keep its history.
                item.title, item.text, item.link = entry.title, entry.text, entry.link or item.link
                item.content_hash, item.updated_at = entry.content_hash, now
                jobs.enqueue(db, "process-item", item.id)
        scheduler.after_success(source, now, published=published, ttl_minutes=meta.ttl_minutes)
        db.commit()

    # ── 2. Processing ─────────────────────────────────────────────────────────

    def process_item(self, db: Session, item_id: int) -> None:
        item = db.get(Item, item_id)
        if item is None:
            return
        if reason := prefilter(item.title, item.text):
            item.status, item.drop_reason = "dropped", reason
            db.commit()
            return
        item.names = find_names(item.title, item.text)
        if item.kind in CLUSTER_KINDS:
            item.vector_status = "pending"
            jobs.enqueue(db, "index-item", item.id)
        else:
            item.vector_status, item.status = "skipped", "ready"
        db.commit()

    def index_item(self, db: Session, item_id: int) -> None:
        item = db.get(Item, item_id)
        if item is None or item.status == "dropped":
            return
        embedding = self.embedder.embed([item_text(item.title, item.text)])[0]
        published = _aware(item.published_at)
        self.index.upsert(item.id, embedding, int(published.timestamp()))
        item.vector_status = "indexed"
        if item.story_id is None:
            self._assign(db, item, embedding, published)
        db.commit()
        if item.story_id is not None and item.kind in claims_agent.FACT_KINDS:
            jobs.enqueue(db, "claims-item", item.id)
            db.commit()

    def _assign(self, db: Session, item: Item, embedding, published: datetime) -> None:
        window = int(self.thresholds.window.total_seconds())
        stamp = int(published.timestamp())
        neighbours = self.index.neighbours(embedding, since_ts=stamp - window, until_ts=stamp + window, exclude=item.id)
        known = {
            i.id: i
            for i in db.scalars(select(Item).where(Item.id.in_([n.item_id for n in neighbours]), Item.status != "dropped"))
        }
        candidates = [
            Candidate(n.item_id, known[n.item_id].story_id, n.similarity, _aware(known[n.item_id].published_at), tuple(known[n.item_id].names))
            for n in neighbours
            if n.item_id in known
        ]
        decision = decide(published, tuple(item.names), candidates, self.thresholds)
        story_id = decision.story_id if decision.action == "join" else None
        if decision.action == "judge":
            for candidate in decision.ask:
                if judge_agent.same_event(self.kit, item, known[candidate.item_id]):
                    story_id = candidate.story_id
                    break
        now = self.clock()
        if story_id is None:
            story = Story(created_at=now, updated_at=now)
            db.add(story)
            db.flush()
            story_id = story.id
        else:
            story = db.get(Story, story_id)
            story.updated_at = now
        item.story_id = story_id
        item.status = "ready"

    # ── 3. Facts ──────────────────────────────────────────────────────────────

    def claims_item(self, db: Session, item_id: int) -> None:
        item = db.get(Item, item_id)
        if item is None or item.story_id is None or item.status == "dropped":
            return
        proposed = list(db.scalars(select(Claim).where(Claim.item_id == item.id, Claim.status == "proposed")))
        stale = [c for c in proposed if c.created_at and _aware(c.created_at) < _aware(item.updated_at)]
        for claim in stale:  # Extracted from text the source has since changed.
            claim.status, claim.verifier_reason = "dropped", "the source changed the item"
        proposed = [c for c in proposed if c not in stale]
        if not proposed:
            extracted = claims_agent.extract(db, self.kit, item)
            if extracted is None:
                db.commit()
                if self.kit.can("claims"):
                    raise AgentUnavailable("claims agent failed")
                return  # No key: nothing to do until one is configured.
            proposed = extracted
        if not verifier_agent.verify(db, self.kit, item, proposed):
            db.commit()
            if self.kit.can("verifier"):
                raise AgentUnavailable("verifier failed")
            return
        story = db.get(Story, item.story_id)
        if any(c.status == "kept" for c in proposed):
            story.updated_at = self.clock()
            jobs.enqueue(db, "write-story", story.id)
        db.commit()

    def write_story(self, db: Session, story_id: int) -> None:
        story = db.get(Story, story_id)
        if story is None:
            return
        writer_agent.write(db, self.kit, story)
        db.commit()
