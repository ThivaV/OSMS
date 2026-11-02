"""The episodes API: a reader hears their own podcasts, newest first, each with
its show and the story it joined; signed-out visitors get the demo's; and one
reader never hears another reader's episodes (rule 7)."""

from datetime import UTC, datetime, timedelta

from app.db.models import Item, Source, Story, StorySummary, Subscription, Topic, TopicSource, User

NOW = datetime.now(UTC)


def _seed(client) -> dict[str, int]:
    """A demo podcast, Ada's private podcast, one episode each, one clustered."""
    with client.app.state.sessions() as db:
        db.add(Topic(id="demo-space", name="Space"))
        demo = Source(type="podcast", title="Gradient Hour", feed_url="https://gradienthour.example/rss", language="en")
        private = Source(type="podcast", title="Ada's Cast", feed_url="https://adascast.example/rss", language="en")
        db.add_all([demo, private])
        db.flush()
        db.add(TopicSource(topic_id="demo-space", source_id=demo.id))
        story = Story(created_at=NOW, updated_at=NOW)
        db.add(story)
        db.flush()
        db.add(StorySummary(story_id=story.id, title="Diffusion story"))
        db.add_all([
            Item(source_id=demo.id, guid="g1", link="https://gradienthour.example/1", title="Diffusion normals",
                 text="Normals for breakfast.", published_at=NOW - timedelta(hours=2), content_hash="e1",
                 kind="episode", status="ready", story_id=story.id,
                 audio_url="https://cdn.gradienthour.example/1.mp3", duration_s=2530),
            Item(source_id=demo.id, guid="g0", link="https://gradienthour.example/0", title="Trailer",
                 text="Coming soon.", published_at=NOW - timedelta(days=1), content_hash="e0",
                 kind="episode", status="ready", audio_url=None, duration_s=300),
            Item(source_id=demo.id, guid="a1", link="https://gradienthour.example/a1", title="Shownotes",
                 text="Just links.", published_at=NOW - timedelta(hours=1), content_hash="a1",
                 kind="article", status="ready"),
            Item(source_id=private.id, guid="n1", link="https://adascast.example/1", title="A niche episode",
                 text="Only Ada hears this.", published_at=NOW - timedelta(hours=1), content_hash="n1",
                 kind="episode", status="ready", audio_url="https://cdn.adascast.example/1.mp3"),
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
    episodes = client.get("/demo/episodes").json()["episodes"]
    assert [e["title"] for e in episodes] == ["Diffusion normals", "Trailer"]
    first = episodes[0]
    assert (first["audio_url"], first["duration_s"]) == ("https://cdn.gradienthour.example/1.mp3", 2530)
    assert (first["show"]["title"], first["show"]["type"]) == ("Gradient Hour", "podcast")
    assert (first["story_id"], first["story_title"]) == (str(ids["story"]), "Diffusion story")
    assert episodes[0]["excerpt"] == "Normals for breakfast."
    assert episodes[1]["audio_url"] is None, "no audio: the row says so, the button stays off"


def test_a_reader_hears_only_their_own_podcasts(client, auth) -> None:
    ids = _seed(client)
    _follow(client, "ada", ids["demo"], ids["private"])
    assert client.get("/episodes").status_code == 401
    heard = client.get("/episodes", headers=auth("ada")).json()["episodes"]
    assert {e["title"] for e in heard} == {"Diffusion normals", "Trailer", "A niche episode"}
    assert client.get("/episodes", headers=auth("bo")).json()["episodes"] == []
    limited = client.get("/episodes?limit=1", headers=auth("ada")).json()["episodes"]
    assert [e["title"] for e in limited] == ["A niche episode"]
