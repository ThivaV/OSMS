"""The morning briefing: the editor picks, the writer scripts from kept facts (uncited
sentences dropped), every chapter is voiced and transcribed back before anyone hears it
(remade once, then left out), and only its reader can play it (rule 7)."""

from datetime import UTC, datetime, timedelta

import numpy as np
import pytest
from sqlalchemy import select

from app.agent.decision_log import DecisionLog
from app.agent.kit import AgentKit
from app.agent.runtime import ModelRoute, ModelStep, ModelUsage, Runner
from app.db.models import Briefing, Claim, Item, Job, Source, Story, Subscription, Topic, TopicSource, User
from app.services import briefing
from app.services.speech import RATE, similarity
from app.worker import schedule_briefings

NOW = datetime.now(UTC)
ROUTES = {a: ModelRoute(model="muse-spark-1.3", endpoint="https://api.meta.ai/v1") for a in ("editor", "writer")}


class Script:
    def __init__(self, answers: dict[str, list[dict]]) -> None:
        self.answers = answers
        self.seen: list[tuple[str, str]] = []

    def step(self, *, system, messages, tools, agent, schema=None, effort=None) -> ModelStep:
        self.seen.append((agent, messages[-1]["content"]))
        return ModelStep(final=self.answers[agent].pop(0), reason="scripted", usage=ModelUsage(60, 30))


class Voice:
    """Audio whose length follows the text; the listener 'hears' what was said."""

    def __init__(self) -> None:
        self.said: list[tuple[str, str, int]] = []

    def speak(self, text: str, language: str, *, attempt: int = 0) -> np.ndarray:
        self.said.append((text, language, attempt))
        return np.full(RATE // 10 * max(1, len(text) // 20), 0.1, dtype=np.float32)


class Listener:
    by = "muse-voice-transcribe-1.0"

    def __init__(self, voice: Voice, garble: set[tuple[str, int]] = frozenset()) -> None:
        self.voice, self.garble = voice, garble

    def handles(self, language: str) -> bool:
        return language in {"en", "ta"}

    def transcribe(self, wav: bytes, language: str) -> str:
        text, _, attempt = self.voice.said[-1]
        return "mumble mumble" if any(word in text and attempt <= n for word, n in self.garble) else text


def seed(db) -> dict:
    db.add(Topic(id="test-product", name="Startups and product"))
    source = Source(type="feed", title="Bytebladet", feed_url="https://bytebladet.example/rss", language="da")
    other = Source(type="feed", title="Niche Notes", feed_url="https://niche.example/rss", language="en")
    db.add_all([source, other])
    db.flush()
    db.add(TopicSource(topic_id="test-product", source_id=source.id))
    ids: dict = {"source": source.id, "other": other.id}
    for name, title, facts in (
        ("fold", "Lumen Fold kommer til Danmark", ["The Lumen Fold costs 7,999 kroner.", "It ships on 12 November."]),
        ("kestrel", "Kestrel opens in Aarhus", ["Kestrel opened an office in Aarhus."]),
        ("quiet", "A story with no checked facts", []),
    ):
        story = Story(created_at=NOW, updated_at=NOW)
        db.add(story)
        db.flush()
        item = Item(
            source_id=source.id,
            guid=name,
            link=f"https://bytebladet.example/{name}",
            title=title,
            text=title,
            language="da",
            published_at=NOW - timedelta(hours=2),
            content_hash=name,
            story_id=story.id,
            status="ready",
        )
        db.add(item)
        db.flush()
        claims = [
            Claim(
                story_id=story.id,
                item_id=item.id,
                statement=f,
                subject="fact",
                quote=title,
                quote_language="da",
                status="kept",
                relation="new",
                kept_at=NOW - timedelta(hours=1),
            )
            for f in facts
        ]
        db.add_all(claims)
        db.flush()
        ids[name] = (story.id, [c.id for c in claims])
    db.commit()
    return ids


def kit(db, answers: dict[str, list[dict]]) -> AgentKit:
    return AgentKit(runner=Runner(Script(answers), DecisionLog(db)), routes=ROUTES, available={a: True for a in ROUTES})


def script_for(ids: dict) -> dict:
    (fold, (price, ships)), (kestrel, (office,)) = ids["fold"], ids["kestrel"]
    return {
        "editor": [{"picks": [{"story_id": fold, "reason": "new facts"}, {"story_id": kestrel, "reason": "local"}]}],
        "writer": [
            {
                "chapters": [
                    {
                        "story_id": fold,
                        "title": "The Lumen Fold arrives",
                        "sentences": [
                            {
                                "text": "Bytebladet reports a price of seven thousand nine hundred and ninety-nine kroner.",
                                "claim_ids": [price],
                            },
                            {
                                "text": "It will also come in gold.",
                                "claim_ids": [9999],
                            },  # cites nothing it has: dropped
                            {"text": "It ships on the twelfth of November.", "claim_ids": [ships]},
                        ],
                    },
                    {
                        "story_id": kestrel,
                        "title": "Kestrel comes to Aarhus",
                        "sentences": [
                            {
                                "text": "Bytebladet reports that Kestrel opened an office in Aarhus.",
                                "claim_ids": [office],
                            },
                        ],
                    },
                ]
            }
        ],
    }


def test_the_demo_briefing_is_scripted_from_kept_facts_and_checked(memory_db, tmp_path) -> None:
    ids = seed(memory_db)
    voice = Voice()
    made = briefing.make(
        memory_db, kit(memory_db, script_for(ids)), voice, [Listener(voice)], user=None, out_dir=tmp_path
    )
    assert made is not None and made.user_id is None and made.language == "en"
    fold, kestrel = made.chapters
    assert [s["text"] for s in fold["sentences"]] == [
        "Bytebladet reports a price of seven thousand nine hundred and ninety-nine kroner.",
        "It ships on the twelfth of November.",
    ]
    assert fold["check"] == {"by": "muse-voice-transcribe-1.0", "similarity": 1.0, "attempts": 1}
    assert 0 < fold["start_ms"] < kestrel["start_ms"] and made.duration_ms > kestrel["start_ms"]
    assert (tmp_path / made.audio_path).read_bytes()[:4] == b"RIFF"
    assert made.intro == "Good morning. Here is your OSMS briefing: 2 stories."


def test_a_chapter_that_drifts_is_remade_once_then_left_out(memory_db, tmp_path) -> None:
    ids = seed(memory_db)
    voice = Voice()
    # The Fold chapter is misheard on its first try only; Kestrel's every time.
    listener = Listener(voice, garble={("Lumen Fold", 0), ("Kestrel", 1)})
    made = briefing.make(memory_db, kit(memory_db, script_for(ids)), voice, [listener], user=None, out_dir=tmp_path)
    assert [c["title"] for c in made.chapters] == ["The Lumen Fold arrives"]
    assert made.chapters[0]["check"]["attempts"] == 2
    assert made.intro == "Good morning. Here is your OSMS briefing: 1 story."


def test_no_way_to_check_the_language_means_no_briefing(memory_db, tmp_path) -> None:
    ids = seed(memory_db)
    reader = User(id="ada", email="ada@reader.example", language="da", onboarded_at=NOW)
    memory_db.add_all([reader, Subscription(user_id="ada", source_id=ids["source"])])
    memory_db.commit()
    voice = Voice()
    script = kit(memory_db, script_for(ids))
    assert briefing.make(memory_db, script, voice, [Listener(voice)], user=reader, out_dir=tmp_path) is None
    assert script.runner.client.seen == []  # Nothing is written that can't be checked.


def test_similarity_reads_letters_so_tamil_and_mishearings_score_fairly() -> None:
    assert similarity("Three sources report it.", "Resources report it") > 0.8
    assert similarity("காலை வணக்கம். லூமென் ஃபோல்ட்", "காலை வணக்கம் லுமன் போல்") > 0.6
    assert similarity("The Lumen Fold costs 7,999 kroner.", "mumble mumble") < 0.3


@pytest.fixture
def made(client, settings):
    with client.app.state.sessions() as db:
        ids = seed(db)
        voice = Voice()
        result = briefing.make(
            db, kit(db, script_for(ids)), voice, [Listener(voice)], user=None, out_dir=settings.briefings_dir
        )
        return result.id


def test_the_demo_briefing_plays_from_a_signed_url(client, made) -> None:
    body = client.get("/demo/briefing").json()
    assert [c["title"] for c in body["chapters"]] == ["The Lumen Fold arrives", "Kestrel comes to Aarhus"]
    assert body["chapters"][0]["sentences"][0]["sources"][0]["name"] == "Bytebladet"
    audio = client.get(body["audio_url"])
    assert audio.status_code == 200 and audio.headers["content-type"] == "audio/wav"
    assert client.get(body["audio_url"], headers={"Range": "bytes=0-99"}).status_code == 206
    tampered = body["audio_url"].replace("signature=", "signature=0")
    assert client.get(tampered).status_code == 404


def test_a_reader_only_ever_gets_their_own_briefing(client, auth, made) -> None:
    client.get("/me", headers=auth("ada"))
    assert client.get("/briefings/latest", headers=auth("ada")).status_code == 404  # The demo's isn't hers.
    with client.app.state.sessions() as db:
        mine = db.get(Briefing, made)
        db.add(
            Briefing(user_id="ada", language="en", chapters=mine.chapters, audio_path=mine.audio_path, duration_ms=1)
        )
        db.commit()
    client.get("/me", headers=auth("grace"))
    assert client.get("/briefings/latest", headers=auth("ada")).status_code == 200
    assert client.get("/briefings/latest", headers=auth("grace")).status_code == 404


def test_briefings_are_scheduled_once_each_morning(memory_db) -> None:
    memory_db.add_all(
        [User(id="ada", email="a@reader.example", onboarded_at=NOW), User(id="new", email="n@reader.example")]
    )
    memory_db.commit()
    morning = NOW.replace(hour=7, minute=0)
    assert schedule_briefings(memory_db, morning.replace(hour=5)) == 0
    assert schedule_briefings(memory_db, morning) == 2  # The demo and Ada; not someone mid-onboarding.
    memory_db.commit()
    assert schedule_briefings(memory_db, morning + timedelta(hours=1)) == 0
    assert sorted(memory_db.scalars(select(Job.ref).where(Job.kind == "make-briefing"))) == ["ada", "demo"]


def test_deleting_an_account_deletes_its_briefings_audio(client, auth, settings, made) -> None:
    client.get("/me", headers=auth("ada"))
    with client.app.state.sessions() as db:
        demo = db.get(Briefing, made)
        settings.briefings_dir.mkdir(parents=True, exist_ok=True)
        (settings.briefings_dir / "ada.wav").write_bytes(b"RIFF")
        db.add(Briefing(user_id="ada", language="en", chapters=demo.chapters, audio_path="ada.wav", duration_ms=1))
        db.commit()
    assert client.delete("/me", headers=auth("ada")).status_code == 204
    assert not (settings.briefings_dir / "ada.wav").exists()
    assert (settings.briefings_dir / demo.audio_path).exists()  # the demo's stays
    with client.app.state.sessions() as db:
        assert db.scalar(select(Briefing).where(Briefing.user_id == "ada")) is None
