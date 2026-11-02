"""The videos API: a reader watches their own followed sources' videos, newest
first, each linking to the publisher's page and to its story when it joined
one; signed-out visitors get the demo's; one reader never sees another
reader's sources (rule 7)."""

from datetime import UTC, datetime, timedelta

from app.db.models import Item, Source, Story, StorySummary, Subscription, Topic, TopicSource, User

NOW = datetime.now(UTC)


def _seed(client) -> dict[str, int]:
    """A demo channel, Ada's private channel, one video each, one clustered."""
    with client.app.state.sessions() as db:
        db.add(Topic(id="demo-space", name="Space"))
        demo = Source(type="youtube", title="Launchpad Lens", feed_url="https://launchpad.example/feed", language="en")
        private = Source(type="youtube", title="Ada's Bench", feed_url="https://adabench.example/feed", language="en")
        db.add_all([demo, private])
        db.flush()
        db.add(TopicSource(topic_id="demo-space", source_id=demo.id))
        story = Story(created_at=NOW, updated_at=NOW)
        db.add(story)
        db.flush()
        db.add(StorySummary(story_id=story.id, title="Selene lands"))
        db.add_all([
            Item(source_id=demo.id, guid="v1", link="https://launchpad.example/v1", title="Selene lands",
                 text="The landing, live.", published_at=NOW - timedelta(hours=2), content_hash="v1",
                 kind="video", status="ready", story_id=story.id, duration_s=620),
            Item(source_id=demo.id, guid="v0", link="https://launchpad.example/v0", title="Pad tour",
                 text="A walk around the pad.", published_at=NOW - timedelta(days=1), content_hash="v0",
                 kind="video", status="ready"),
            Item(source_id=demo.id, guid="n1", link=None, title="Unlinked clip",
                 text="No page to open.", published_at=NOW - timedelta(hours=1), content_hash="n1",
                 kind="video", status="ready"),
            Item(source_id=demo.id, guid="d1", link="https://launchpad.example/d1", title="Dropped clip",
                 text="Out of scope.", published_at=NOW - timedelta(hours=1), content_hash="d1",
                 kind="video", status="dropped"),
            Item(source_id=demo.id, guid="a1", link="https://launchpad.example/a1", title="Shownotes",
                 text="Just links.", published_at=NOW - timedelta(hours=1), content_hash="a1",
                 kind="article", status="ready"),
            Item(source_id=private.id, guid="p1", link="https://adabench.example/p1", title="Bench build",
                 text="Only Ada watches this.", published_at=NOW - timedelta(hours=1), content_hash="p1",
                 kind="video", status="ready"),
        ])
        db.commit()
        return {"demo": demo.id, "private": private.id, "story": story.id}


def _follow(client, user: str, *source_ids: int) -> None:
    with client.app.state.sessions() as db:
        if db.get(User, user) is None:
            db.add(User(id=user, email=f"{user}@users.example", created_at=datetime.now(UTC)))
            db.flush()
        for source_id in source_ids:
            db.add(Subscription(user_id=user, source_id=source_id))
        db.commit()


def test_the_demo_is_public_and_newest_first(client) -> None:
    ids = _seed(client)
    videos = client.get("/demo/videos").json()["videos"]
    assert [v["title"] for v in videos] == ["Selene lands", "Pad tour"]
    first = videos[0]
    assert (first["link"], first["duration_s"]) == ("https://launchpad.example/v1", 620)
    assert (first["source"]["name"], first["source"]["type"]) == ("Launchpad Lens", "youtube")
    assert (first["story_id"], first["story_title"]) == (str(ids["story"]), "Selene lands")
    assert videos[1]["story_id"] is None, "in no story: the row says so, Watch still opens"


def test_a_reader_watches_only_their_own_sources(client, auth) -> None:
    ids = _seed(client)
    _follow(client, "ada", ids["demo"], ids["private"])
    assert client.get("/videos").status_code == 401
    watched = client.get("/videos", headers=auth("ada")).json()["videos"]
    assert {v["title"] for v in watched} == {"Selene lands", "Pad tour", "Bench build"}
    assert client.get("/videos", headers=auth("bo")).json()["videos"] == []
    limited = client.get("/videos?limit=1", headers=auth("ada")).json()["videos"]
    assert [v["title"] for v in limited] == ["Bench build"]
