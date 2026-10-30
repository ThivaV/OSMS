"""The story pipeline end to end, on fakes (feeds, models, embeddings) and a real Milvus
Lite: a Danish and an English item about one launch become one story; its facts are
checked, a disagreement and a correction keep their history, and the writer cites
every sentence. Without model keys, stories still form and nothing pretends to know."""

from datetime import UTC, datetime, timedelta

import httpx
import pytest
from sqlalchemy import select

from app.agent.decision_log import DecisionLog
from app.agent.kit import AgentKit
from app.agent.runtime import ModelRoute, ModelStep, ModelUsage, Runner
from app.db.milvus import VectorIndex
from app.db.models import AgentRun, Claim, Disagreement, Item, Source, Story, StorySummary, Topic, TopicSource
from app.services import jobs, stories
from app.services.embeddings import Embedding
from app.services.ingestion.fetcher import Fetcher
from app.services.pipeline import Pipeline

NOW = datetime.now(UTC).replace(microsecond=0)


def rss(items: list[tuple[str, str, str, datetime]], language: str) -> bytes:
    body = "".join(
        f"<item><guid>{guid}</guid><title>{title}</title><link>https://{guid}.example/a</link>"
        f"<description>{text}</description><pubDate>{when:%a, %d %b %Y %H:%M:%S} GMT</pubDate></item>"
        for guid, title, text, when in items
    )
    return f'<?xml version="1.0"?><rss version="2.0"><channel><title>x</title><language>{language}</language>{body}</channel></rss>'.encode()


FEEDS = {
    "bytebladet.example": rss(
        [
            ("da-fold", "Lumen Fold kommer til Danmark", "Lumen Fold koster 7.999 kr. og har et batteri på 4.500 mAh.", NOW - timedelta(hours=3)),
            ("da-politics", "Ministeren vil regulere telefoner", "Regeringen foreslår nye regler.", NOW - timedelta(hours=2)),
        ],
        "da",
    ),
    "launchdesk.example": rss(
        [
            ("en-fold", "Lumen Fold launches at $999", "The Lumen Fold costs $999 and has a 4,700 mAh battery.", NOW - timedelta(hours=1)),
            ("en-kestrel", "Kestrel rocket lands at sea", "The Kestrel booster landed for the third time.", NOW - timedelta(hours=1)),
        ],
        "en",
    ),
}


class TopicEmbedder:
    """Same launch, same direction, whatever the language; anything else far away."""

    dim = 4

    def embed(self, texts: list[str]) -> list[Embedding]:
        out = []
        for text in texts:
            if "Lumen" in text:
                out.append(Embedding([0.99, 0.1, 0.0, 0.0], {1: 1.0}))
            elif "Kestrel" in text:
                out.append(Embedding([0.0, 0.0, 1.0, 0.0], {2: 1.0}))
            else:
                out.append(Embedding([0.0, 0.0, 0.0, 1.0], {3: 1.0}))
        return out


class AgentScript:
    """A fake model that answers per agent, in order."""

    def __init__(self, answers: dict[str, list[dict]]) -> None:
        self.answers = {agent: list(steps) for agent, steps in answers.items()}
        self.seen: list[tuple[str, str]] = []

    def step(self, *, system, messages, tools, agent, schema=None, effort=None) -> ModelStep:
        self.seen.append((agent, messages[-1]["content"]))
        return ModelStep(final=self.answers[agent].pop(0), reason="scripted", usage=ModelUsage(50, 10))


ROUTES = {
    name: ModelRoute(model="muse-spark-1.3", endpoint="https://api.meta.ai/v1")
    for name in ("triage", "interest", "judge", "claims", "verifier", "editor", "writer", "ask")
}


def _pipeline(db, tmp_path, client, *, available: bool) -> Pipeline:
    def handler(request: httpx.Request) -> httpx.Response:
        return httpx.Response(200, content=FEEDS[request.url.host])

    fetcher = Fetcher(httpx.Client(transport=httpx.MockTransport(handler)), resolver=lambda h, p: ["93.184.216.34"], sleep=lambda s: None)
    kit = AgentKit(runner=Runner(client, DecisionLog(db)), routes=ROUTES, available={a: available for a in ROUTES})
    return Pipeline(
        fetcher=fetcher,
        embedder_factory=TopicEmbedder,
        index_factory=lambda dim: VectorIndex(str(tmp_path / "milvus.db"), dim=dim),
        kit=kit,
    )


@pytest.fixture
def seeded(memory_db):
    db = memory_db
    db.add(Topic(id="product", name="Startups and product"))
    da = Source(type="feed", title="Bytebladet", feed_url="https://bytebladet.example/rss", language="da")
    en = Source(type="feed", title="The Launch Desk", feed_url="https://launchdesk.example/rss", language="en")
    db.add_all([da, en])
    db.flush()
    db.add_all([TopicSource(topic_id="product", source_id=da.id), TopicSource(topic_id="product", source_id=en.id)])
    db.commit()
    return db, da, en


def _drain(db, pipeline: Pipeline) -> list[str]:
    ran = []
    while job := jobs.claim_next(db, datetime.now(UTC) + timedelta(seconds=1)):
        pipeline.handle(db, job.kind, job.ref)
        jobs.finish(db, job)
        ran.append(job.kind)
    return ran


def test_two_languages_one_story_with_checked_facts(seeded, tmp_path) -> None:
    db, da, en = seeded
    client = AgentScript(
        {
            "claims": [
                {"claims": [
                    {"statement": "The Lumen Fold costs 7,999 kroner in Denmark.", "subject": "Danish price", "value": "7.999 kr.",
                     "quote": "Lumen Fold koster 7.999 kr.", "translation": "The Lumen Fold costs 7,999 kroner."},
                    {"statement": "It has a 4,500 mAh battery.", "subject": "Battery", "value": "4,500 mAh",
                     "quote": "et batteri på 4.500 mAh", "translation": "a 4,500 mAh battery"},
                    {"statement": "It flies.", "subject": "x", "value": None, "quote": "words the item never said", "translation": None},
                ]},
                {"claims": [
                    {"statement": "The Lumen Fold costs $999.", "subject": "US price", "value": "$999", "quote": "The Lumen Fold costs $999", "translation": "ignored"},
                    {"statement": "It has a 4,700 mAh battery.", "subject": "Battery", "value": "4,700 mAh", "quote": "a 4,700 mAh battery", "translation": None},
                ]},
                {"claims": []},  # the Kestrel landing: nothing scripted, nothing kept
            ],
            "verifier": [
                {"verdicts": [{"candidate": 0, "keep": True, "relation": "new"}, {"candidate": 1, "keep": True, "relation": "new"}]},
                {"verdicts": [
                    {"candidate": 0, "keep": True, "relation": "new", "reason": "a US price, not a conflict"},
                    {"candidate": 1, "keep": True, "relation": "conflicts", "related": 2, "reason": "4,500 vs 4,700 mAh"},
                ]},
            ],
            "writer": [
                {"title": "Lumen Fold arrives in Denmark and the US", "points": [
                    {"text": "The Lumen Fold costs 7,999 kroner in Denmark and $999 in the US.", "claim_ids": [1, 3]},
                    {"text": "Sources differ on its battery.", "claim_ids": [2, 4, 999]},
                    {"text": "It flies.", "claim_ids": [999]},
                ]},
                {"title": "unused", "points": [{"text": "x", "claim_ids": [1]}]},
            ],
        }
    )
    pipeline = _pipeline(db, tmp_path, client, available=True)
    for source in (da, en):
        jobs.enqueue(db, "fetch-source", source.id)
    db.commit()
    _drain(db, pipeline)

    political = db.scalar(select(Item).where(Item.guid == "da-politics"))
    assert political.status == "dropped" and political.drop_reason.startswith("rule 3") and political.story_id is None
    fold = {i.guid: i for i in db.scalars(select(Item).where(Item.guid.in_(["da-fold", "en-fold"])))}
    kestrel = db.scalar(select(Item).where(Item.guid == "en-kestrel"))
    assert fold["da-fold"].story_id == fold["en-fold"].story_id != kestrel.story_id
    assert fold["da-fold"].language == "da" and "lumen" in fold["da-fold"].names

    claims = list(db.scalars(select(Claim).order_by(Claim.id)))
    assert [c.status for c in claims] == ["kept", "kept", "kept", "kept"]  # the unquotable one never got in
    assert claims[0].translation == "The Lumen Fold costs 7,999 kroner." and claims[2].translation is None
    assert db.scalar(select(Disagreement)).subject == "Battery"

    summary = db.scalar(select(StorySummary))
    assert summary.title == "Lumen Fold arrives in Denmark and the US"
    assert [p["claim_ids"] for p in summary.points] == [[1, 3], [2, 4]]  # unknown ids dropped, uncited sentence gone

    out = stories.demo_stories(db)
    story = next(s for s in out if s.id == str(fold["da-fold"].story_id))
    assert story.title == summary.title and story.languages == ["da", "en"]
    assert story.why[0] == "2 sources" and story.why[-1] == "Startups and product"
    assert {c.quote_language for c in story.whats_new} == {"da", "en"} and story.whats_new[0].source_count == 1
    assert story.disagreements[0].sides[0].value == "4,500 mAh" and story.disagreements[0].sides[1].value == "4,700 mAh"
    assert story.summary_points[0].sources[0].name == "Bytebladet"
    assert all(e.url for e in story.timeline)
    # Every agent call is in the decision log, none of it with the reader's data.
    assert {r.agent for r in db.scalars(select(AgentRun))} == {"claims", "verifier", "writer"}

    # Bytebladet corrects its battery figure: the old fact stays, struck through.
    FEEDS["bytebladet.example"] = rss(
        [("da-fold", "Lumen Fold kommer til Danmark", "Lumen Fold koster 7.999 kr. og har et batteri på 4.700 mAh.", NOW - timedelta(hours=3))], "da"
    )
    client.answers["claims"] = [{"claims": [
        {"statement": "It has a 4,700 mAh battery.", "subject": "Battery", "value": "4,700 mAh", "quote": "et batteri på 4.700 mAh", "translation": "a 4,700 mAh battery"}
    ]}]
    client.answers["verifier"] = [{"verdicts": [{"candidate": 0, "keep": True, "relation": "corrects", "related": 2, "reason": "Bytebladet updated it"}]}]
    client.answers["writer"] = [{"title": "Lumen Fold arrives in Denmark and the US", "points": [{"text": "Both now give 4,700 mAh.", "claim_ids": [5, 4]}]}]
    jobs.enqueue(db, "fetch-source", da.id)
    db.commit()
    _drain(db, pipeline)
    old = db.get(Claim, 2)
    assert old.superseded_by == 5 and old.status == "kept"
    story = next(s for s in stories.demo_stories(db) if s.id == story.id)
    correction = [e for e in story.timeline if e.corrected_from]
    assert correction and correction[0].corrected_from == "4,500 mAh"
    assert "2" not in {c.id for c in story.whats_new}  # superseded facts aren't new any more
    assert len(list(db.scalars(select(StorySummary)))) == 2  # never overwritten


def test_without_model_keys_stories_form_and_say_only_what_is_known(seeded, tmp_path) -> None:
    db, da, en = seeded
    pipeline = _pipeline(db, tmp_path, AgentScript({}), available=False)
    for source in (da, en):
        jobs.enqueue(db, "fetch-source", source.id)
    db.commit()
    _drain(db, pipeline)
    assert db.scalar(select(Claim)) is None and db.scalar(select(AgentRun)) is None
    out = stories.demo_stories(db)
    fold = out[0]
    assert fold.title == "Lumen Fold kommer til Danmark"  # its first headline until the writer can run
    assert fold.summary == "Reported by 2 sources in Danish and English."
    assert fold.whats_new == [] and fold.summary_points == []
    assert len(db.scalars(select(Story)).all()) == 2
