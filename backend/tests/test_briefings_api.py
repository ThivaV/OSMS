"""The briefings history: a reader replays their own earlier briefings, newest
first, each with a freshly signed audio URL; signed-out visitors get the
demo's; and one reader never sees another reader's (rule 7)."""

from datetime import UTC, datetime

from app.db.models import Briefing, Source, Topic, TopicSource, User


def _chapters(title: str) -> list[dict]:
    return [{
        "story_id": 1,
        "title": title,
        "sentences": [],
        "new_fact_count": 0,
        "start_ms": 0,
        "duration_ms": 1000,
        "check": {"by": "test", "similarity": 1.0, "attempts": 1},
    }]


def _seed(client) -> None:
    """Two demo briefings (one without audio), Ada's own, Bo's own."""
    with client.app.state.sessions() as db:
        for user in ("ada", "bo"):
            db.add(User(id=user, email=f"{user}@users.example", created_at=datetime.now(UTC)))
        db.add(Topic(id="demo-space", name="Space"))
        demo = Source(type="feed", title="Seed Feed", feed_url="https://seed.example/rss", language="en")
        db.add(demo)
        db.flush()
        db.add(TopicSource(topic_id="demo-space", source_id=demo.id))
        db.add_all([
            Briefing(user_id=None, language="en", chapters=_chapters("Seed one"),
                     audio_path="seed1.wav", duration_ms=1000, created_at=datetime(2026, 9, 1, tzinfo=UTC)),
            Briefing(user_id=None, language="en", chapters=_chapters("Seed two"),
                     audio_path="seed2.wav", duration_ms=2000, created_at=datetime(2026, 9, 2, tzinfo=UTC)),
            Briefing(user_id=None, language="en", chapters=_chapters("Seed silent"),
                     audio_path=None, duration_ms=500, created_at=datetime(2026, 9, 3, tzinfo=UTC)),
            Briefing(user_id="ada", language="en", chapters=_chapters("Ada one"),
                     audio_path="ada1.wav", duration_ms=1000, created_at=datetime(2026, 9, 1, tzinfo=UTC)),
            Briefing(user_id="bo", language="en", chapters=_chapters("Bo one"),
                     audio_path="bo1.wav", duration_ms=1000, created_at=datetime(2026, 9, 1, tzinfo=UTC)),
        ])
        db.commit()


def _follow(client, user: str) -> None:
    with client.app.state.sessions() as db:
        if db.get(User, user) is None:
            db.add(User(id=user, email=f"{user}@users.example", created_at=datetime.now(UTC)))
        db.commit()


def test_the_demo_history_is_public_newest_first_and_audio_only(client) -> None:
    _seed(client)
    history = client.get("/demo/briefings").json()["briefings"]
    assert [b["chapters"][0]["title"] for b in history] == ["Seed two", "Seed one"]
    assert all("/briefings/" in b["audio_url"] and "signature=" in b["audio_url"] for b in history)
    assert all(isinstance(b["id"], str) for b in history)


def test_a_reader_replays_only_their_own_briefings(client, auth) -> None:
    _seed(client)
    _follow(client, "ada")
    _follow(client, "bo")
    assert client.get("/briefings").status_code == 401
    heard = client.get("/briefings", headers=auth("ada")).json()["briefings"]
    assert [b["chapters"][0]["title"] for b in heard] == ["Ada one"]
    assert [b["chapters"][0]["title"] for b in client.get("/briefings", headers=auth("bo")).json()["briefings"]] == [
        "Bo one"
    ]
    assert client.get("/briefings?limit=1", headers=auth("ada")).json()["briefings"][0]["duration_ms"] == 1000
