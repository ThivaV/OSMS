"""The story pipeline, one job at a time (AGENTS.md, *Staying up to date*):

    fetch-source  → new or changed items, saved first
    preview-image → an article's link-preview picture, when its feed gives none
    process-item  → rule 3 and noise, language, names
    index-item    → BGE-M3 vectors into Milvus Lite, then the clustering decision
    claims-item   → facts with quotes (claims agent), checked by the verifier
    write-story   → the story's title and cited summary (writer agent)

Every step can run again safely. Without model keys the agents are unavailable: stories
still form from clear matches, there are no facts, and nothing pretends otherwise."""

from collections.abc import Callable
from dataclasses import dataclass, field
from datetime import UTC, datetime, timedelta
from pathlib import Path

from sqlalchemy import func, select, update
from sqlalchemy.orm import Session

from app.agent.kit import AgentKit
from app.db.milvus import VectorIndex
from app.db.models import Claim, Item, Source, Story, User
from app.services import briefing as briefing_service
from app.services import claims as claims_agent
from app.services import interests as research
from app.services import jobs, visuals
from app.services import judge as judge_agent
from app.services import verifier as verifier_agent
from app.services import writer as writer_agent
from app.services.clustering import Candidate, Thresholds, decide
from app.services.embeddings import Embedder, item_text
from app.services.ingestion import scheduler
from app.services.ingestion.adapters.feed import UnsafeFeed, is_thumbnail, parse_feed
from app.services.ingestion.adapters.page import preview_image
from app.services.ingestion.fetcher import Fetcher, FetchError
from app.services.ingestion.robots import Robots
from app.services.ingestion.safety import UnsafeUrl
from app.services.language import detect
from app.services.speech import Checker, Voice
from app.services.triage import triage

#: Kinds that join stories. Papers wait for paper labels in the eval; photos and comics
#: are timeline-only (AGENTS.md, *Source types*).
CLUSTER_KINDS = frozenset({"article", "episode", "post", "video"})
#: A first fetch doesn't drag in a source's distant past.
MAX_AGE = timedelta(days=14)
PAPER_MAX_AGE = timedelta(days=30)  # an interest's first search is its 30-day backfill
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
    #: The triage agent on Muse Spark, for what Glimmer is unsure about.
    escalation: AgentKit | None = None
    #: The briefing's voice and its checks, loaded on the first briefing.
    voice_factory: Callable[[], Voice] | None = None
    checkers_factory: Callable[[Voice], list[Checker]] = lambda voice: []
    briefings_dir: Path = Path("data/briefings")
    #: Muse Image and SAM 3.1; None without a key, and the cards keep their drawn art.
    media: visuals.Media | None = None
    visuals_dir: Path = Path("data/visuals")
    thresholds: Thresholds = field(default_factory=Thresholds)
    clock: Callable[[], datetime] = lambda: datetime.now(UTC)
    _embedder: Embedder | None = None
    _index: VectorIndex | None = None
    _voice: Voice | None = None
    _robots: Robots | None = None

    @property
    def robots(self) -> Robots:
        if self._robots is None:
            self._robots = Robots(self.fetcher)
        return self._robots

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
        if kind == "make-briefing":  # ref: a reader's id, or "demo"
            self.make_briefing(db, ref)
            return
        handler = {
            "fetch-source": self.fetch_source,
            "preview-image": self.preview_image,
            "process-item": self.process_item,
            "index-item": self.index_item,
            "claims-item": self.claims_item,
            "write-story": self.write_story,
            "illustrate-story": self.illustrate_story,
        }.get(kind)
        if handler is None:
            raise ValueError(f"unknown job kind {kind!r}")
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
                if now - when > (PAPER_MAX_AGE if entry.kind == "paper" else MAX_AGE):
                    continue
                item = Item(
                    source_id=source.id,
                    guid=entry.guid,
                    link=entry.link,
                    image_url=entry.image,
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
                if (item.image_url is None or is_thumbnail(item.image_url)) and item.link and item.kind != "paper":
                    jobs.enqueue(db, "preview-image", item.id)
            elif item.content_hash != entry.content_hash:
                # The source changed it, usually a correction: re-read it, keep its history.
                item.title, item.text, item.link = entry.title, entry.text, entry.link or item.link
                item.content_hash, item.updated_at = entry.content_hash, now
                jobs.enqueue(db, "process-item", item.id)
            if entry.image and item.image_url != entry.image and (
                item.image_url is None or is_thumbnail(item.image_url) or not is_thumbnail(entry.image)
            ):
                # A new or changed picture needs no re-reading; a feed's thumbnail never
                # replaces the full-size picture found on the article's page.
                item.image_url = entry.image
        scheduler.after_success(source, now, published=published, ttl_minutes=meta.ttl_minutes)
        db.commit()

    def preview_image(self, db: Session, item_id: int) -> None:
        """An article whose feed gives no picture, or only a thumbnail: the one its page names
        for link previews, read from the page's <head> where robots.txt allows. The page
        itself is never kept."""
        item = db.get(Item, item_id)
        if item is None or not item.link or item.kind == "paper":
            return
        if (item.image_url and not is_thumbnail(item.image_url)) or not self.robots.allowed(item.link):
            return
        try:
            page = self.fetcher.fetch(item.link, head_only=True)
        except FetchError as error:
            if error.status in (429, 503):
                raise  # Asked to slow down: the queue tries again later.
            return
        except UnsafeUrl:
            return
        image = preview_image(page.body, page.url)
        if image is None or is_thumbnail(image):
            return  # Nothing better than what the feed gave.
        same_source = (Item.source_id == item.source_id, Item.image_url == image)
        if db.scalar(select(Item.id).where(*same_source, Item.id != item.id).limit(1)) is not None:
            # One picture on several of a source's articles is the site's own, not theirs.
            db.execute(update(Item).where(*same_source).values(image_url=None))
        else:
            item.image_url = image
        db.commit()

    # ── 2. Processing ─────────────────────────────────────────────────────────

    def process_item(self, db: Session, item_id: int) -> None:
        item = db.get(Item, item_id)
        if item is None:
            return
        triaged = triage(self.kit, self.escalation, item)
        if triaged.drop_reason:
            item.status, item.drop_reason = "dropped", triaged.drop_reason
            db.commit()
            return
        item.names = triaged.names
        if triaged.language:
            item.language = triaged.language
        research.match_paper(db, item)
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
        db.commit()  # Before the judge: no write lock held across a model call.
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
        db.commit()  # No write lock held across a model call: the decision log needs it.
        if not proposed:
            extracted = claims_agent.extract(db, self.kit, item)
            if extracted is None:
                db.commit()
                if self.kit.can("claims"):
                    raise AgentUnavailable("claims agent failed")
                return  # No key: nothing to do until one is configured.
            proposed = extracted
            # Proposed facts are invisible until the verifier keeps them; a retry reuses them.
            db.commit()
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

    # ── 4. The morning briefing ───────────────────────────────────────────────

    def make_briefing(self, db: Session, ref: str) -> None:
        """`ref` is a reader's id, or "demo"."""
        user = None if ref == "demo" else db.get(User, ref)
        if (ref != "demo" and user is None) or self.voice_factory is None:
            return
        if self._voice is None:
            self._voice = self.voice_factory()
        briefing_service.make(
            db, self.kit, self._voice, self.checkers_factory(self._voice), user=user, out_dir=self.briefings_dir
        )

    def write_story(self, db: Session, story_id: int) -> None:
        story = db.get(Story, story_id)
        if story is None:
            return
        writer_agent.write(db, self.kit, story)
        sources = db.scalar(
            select(func.count(func.distinct(Item.source_id))).where(Item.story_id == story.id, Item.status != "dropped")
        )
        if self.media is not None and story.illustration is None and (sources or 0) >= visuals.ILLUSTRATE_AT_SOURCES:
            jobs.enqueue(db, "illustrate-story", story.id)
        db.commit()

    def illustrate_story(self, db: Session, story_id: int) -> None:
        story = db.get(Story, story_id)
        if story is None or story.illustration is not None or self.media is None:
            return
        visuals.illustrate(db, self.media, story, self.visuals_dir, log=self.kit.runner.log)
