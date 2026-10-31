"""Ask this story over HTTP: answered from the story's checked facts only, every sentence
cited, "Not reported yet" otherwise; rate-limited; nothing stored, and the question
never reaches the decision log."""

from datetime import UTC, datetime, timedelta

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import select

from app.agent.runtime import ModelRoute, ModelStep, ModelUsage
from app.api import stories as stories_api
from app.auth.tokens import TokenVerifier
from app.config import Settings
from app.db.models import AgentRun, AgentStep, Claim, Item, Source, Story, Subscription, Topic, TopicSource
from app.main import create_app
from tests.conftest import AUDIENCE, ISSUER, KEY, NoModels, StaticKeys

NOW = datetime.now(UTC)
QUESTION = "How much does the Lumen Fold cost in Denmark?"


class AskModels:
    """A fake ask agent: answers as scripted, records what it was sent."""

    def __init__(self, answers: list[dict]) -> None:
        self.routes = {"ask": ModelRoute(model="muse-spark-1.3", endpoint="https://api.meta.ai/v1")}
        self.answers = answers
        self.prompts: list[str] = []

    def available(self, agent: str) -> bool:
        return agent == "ask"

    def step(self, *, system, messages, tools, agent, schema=None, effort=None) -> ModelStep:
        self.prompts.append(messages[-1]["content"])
        return ModelStep(final=self.answers.pop(0), reason=f"answered {QUESTION}", usage=ModelUsage(80, 20))


@pytest.fixture
def models():
    return AskModels(
        [
            {
                "reported": True,
                "sentences": [
                    {"text": "Bytebladet reports a Danish price of 7,999 kroner.", "claim_ids": [1]},
                    {"text": "It is also waterproof.", "claim_ids": [99]},
                ],
            },
            {"reported": False, "sentences": []},
        ]
    )


@pytest.fixture(autouse=True)
def fresh_limits():
    stories_api._asked.clear()


def _seed(client) -> int:
    with client.app.state.sessions() as db:
        db.add(Topic(id="test-product", name="Startups and product"))
        source = Source(type="feed", title="Bytebladet", feed_url="https://bytebladet.example/rss", language="da")
        db.add(source)
        db.flush()
        db.add(TopicSource(topic_id="test-product", source_id=source.id))
        story = Story(created_at=NOW, updated_at=NOW)
        db.add(story)
        db.flush()
        item = Item(
            source_id=source.id,
            guid="f1",
            link="https://bytebladet.example/f1",
            title="Lumen Fold koster 7.999 kr.",
            text="Lumen Fold koster 7.999 kr.",
            language="da",
            published_at=NOW - timedelta(hours=1),
            content_hash="h",
            story_id=story.id,
            status="ready",
        )
        db.add(item)
        db.flush()
        db.add(
            Claim(
                story_id=story.id,
                item_id=item.id,
                statement="The Lumen Fold costs 7,999 kroner in Denmark.",
                subject="Danish price",
                value="7.999 kr.",
                quote="Lumen Fold koster 7.999 kr.",
                quote_language="da",
                status="kept",
                relation="new",
                kept_at=NOW,
            )
        )
        db.commit()
        return story.id


def test_answers_cite_the_storys_facts_and_drop_the_rest(client, models) -> None:
    story = _seed(client)
    body = client.post(f"/demo/stories/{story}/ask", json={"question": QUESTION}).json()
    assert body["reported"] is True and len(body["sentences"]) == 1  # the uncited claim is gone
    assert body["sentences"][0]["sources"][0]["name"] == "Bytebladet"
    assert "Lumen Fold costs 7,999 kroner" in models.prompts[0]
    not_reported = client.post(f"/demo/stories/{story}/ask", json={"question": "What does it weigh?"}).json()
    assert not_reported == {"question": "What does it weigh?", "reported": False, "sentences": []}


def test_the_question_never_reaches_the_decision_log(client) -> None:
    story = _seed(client)
    client.post(f"/demo/stories/{story}/ask", json={"question": QUESTION})
    with client.app.state.sessions() as db:
        run = db.scalar(select(AgentRun))
        step = db.scalar(select(AgentStep))
        assert run.agent == "ask" and QUESTION not in (step.reason or "") and "[redacted]" in (step.reason or "")


def test_readers_ask_only_stories_from_their_sources(client, auth) -> None:
    story = _seed(client)
    client.get("/me", headers=auth("ada"))
    client.get("/me", headers=auth("grace"))
    with client.app.state.sessions() as db:
        db.add(Subscription(user_id="ada", source_id=db.scalar(select(Item.source_id).where(Item.story_id == story))))
        db.commit()
    asked = client.post(f"/stories/{story}/ask", json={"question": QUESTION}, headers=auth("ada"))
    assert asked.status_code == 200 and asked.json()["reported"] is True
    assert client.post(f"/stories/{story}/ask", json={"question": QUESTION}, headers=auth("grace")).status_code == 404


def test_asking_is_rate_limited(client, monkeypatch) -> None:
    story = _seed(client)
    monkeypatch.setattr(stories_api, "DEMO_ASK_LIMIT", 1)
    assert client.post(f"/demo/stories/{story}/ask", json={"question": QUESTION}).status_code == 200
    assert client.post(f"/demo/stories/{story}/ask", json={"question": QUESTION}).status_code == 429


def test_without_the_ask_agent_it_is_unavailable(tmp_path) -> None:
    app = create_app(
        Settings(_env_file=None, database_url=f"sqlite:///{tmp_path / 'x.db'}"),
        TokenVerifier(issuer=ISSUER, audience=AUDIENCE, keys=StaticKeys(KEY.public_key())),
        models=NoModels(),
    )
    with TestClient(app) as client:
        story = _seed(client)
        assert client.post(f"/demo/stories/{story}/ask", json={"question": QUESTION}).status_code == 503
        assert client.post(f"/demo/stories/{story}/ask", json={"question": "  "}).status_code == 422


def test_how_osms_decided_shows_a_storys_runs_but_never_a_readers(client, auth) -> None:
    story = _seed(client)
    client.post(f"/demo/stories/{story}/ask", json={"question": QUESTION})  # The ask run is about a reader.
    with client.app.state.sessions() as db:
        item = db.scalar(select(Item).where(Item.story_id == story))
        db.add(
            AgentRun(
                agent="claims",
                model="muse-spark-1.3",
                subject=f"item:{item.id}",
                status="ok",
                input_tokens=900,
                output_tokens=120,
                started_at=NOW,
                ended_at=NOW + timedelta(seconds=2),
            )
        )
        db.commit()
    body = client.get(f"/demo/stories/{story}/decisions").json()
    assert [(d["agent"], d["outcome"], d["source"], d["latency_ms"]) for d in body["decisions"]] == [
        ("claims", "1 fact found", "Bytebladet", 2000)
    ]
    client.get("/me", headers=auth("grace"))
    assert client.get(f"/stories/{story}/decisions", headers=auth("grace")).status_code == 404
