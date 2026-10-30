"""The stories API: a reader sees the stories their sources pick, with what's new since
they last read each; signed-out visitors get the demo's; and one reader never sees a
story only another reader's sources brought in (rule 7)."""

from datetime import UTC, datetime, timedelta

from sqlalchemy import select

from app.db.models import Claim, Item, Source, Story, Subscription, Topic, TopicSource

NOW = datetime.now(UTC)


def _seed(client) -> dict[str, int]:
    """A demo source, a source only Ada follows, one story each, one kept fact."""
    with client.app.state.sessions() as db:
        db.add(Topic(id="test-space", name="Space"))
        demo = Source(type="feed", title="Orbit Notes", feed_url="https://orbit.example/rss", language="en")
        private_pick = Source(type="feed", title="Ada's Niche Feed", feed_url="https://niche.example/rss", language="en")
        db.add_all([demo, private_pick])
        db.flush()
        db.add(TopicSource(topic_id="test-space", source_id=demo.id))
        launch, niche = Story(created_at=NOW, updated_at=NOW), Story(created_at=NOW, updated_at=NOW)
        db.add_all([launch, niche])
        db.flush()
        a = Item(source_id=demo.id, guid="k1", link="https://orbit.example/k1", title="Kestrel lands at sea", text="The booster landed.",
                 published_at=NOW - timedelta(hours=2), content_hash="h1", story_id=launch.id, status="ready")
        b = Item(source_id=private_pick.id, guid="n1", link="https://niche.example/n1", title="A niche story", text="Only Ada reads this.",
                 published_at=NOW - timedelta(hours=1), content_hash="h2", story_id=niche.id, status="ready")
        db.add_all([a, b])
        db.flush()
        db.add(Claim(story_id=launch.id, item_id=a.id, statement="The booster landed for the third time.", subject="Landing",
                     quote="The booster landed.", quote_language="en", status="kept", relation="new", kept_at=NOW - timedelta(hours=1)))
        db.commit()
        return {"demo": demo.id, "private": private_pick.id, "launch": launch.id, "niche": niche.id}


def _follow(client, user: str, *source_ids: int) -> None:
    with client.app.state.sessions() as db:
        for source_id in source_ids:
            db.add(Subscription(user_id=user, source_id=source_id))
        db.commit()


def test_the_demo_is_public_and_shows_only_seed_sources(client) -> None:
    ids = _seed(client)
    response = client.get("/demo/stories")
    assert response.status_code == 200
    stories = response.json()["stories"]
    assert [s["id"] for s in stories] == [str(ids["launch"])]
    assert stories[0]["whats_new"][0]["quote"] == "The booster landed." and stories[0]["whats_new"][0]["source_count"] == 1
    assert stories[0]["timeline"][0]["url"] == "https://orbit.example/k1"
    assert client.get(f"/demo/stories/{ids['niche']}").status_code == 404


def test_a_reader_sees_their_sources_stories_and_whats_new_since_reading(client, auth) -> None:
    ids = _seed(client)
    client.get("/me", headers=auth("ada"))
    _follow(client, "ada", ids["demo"], ids["private"])
    stories = client.get("/stories", headers=auth("ada")).json()["stories"]
    assert {s["id"] for s in stories} == {str(ids["launch"]), str(ids["niche"])}
    launch = next(s for s in stories if s["id"] == str(ids["launch"]))
    assert len(launch["whats_new"]) == 1 and launch["sources"][0]["followed"] is True
    assert client.post(f"/stories/{ids['launch']}/read", headers=auth("ada")).status_code == 204
    after = client.get(f"/stories/{ids['launch']}", headers=auth("ada")).json()
    assert after["whats_new"] == [] and after["last_read_at"] is not None


def test_one_reader_never_sees_another_readers_stories_or_read_state(client, auth) -> None:
    ids = _seed(client)
    for user in ("ada", "bo"):
        client.get("/me", headers=auth(user))
    _follow(client, "ada", ids["demo"], ids["private"])
    _follow(client, "bo", ids["demo"])
    client.post(f"/stories/{ids['launch']}/read", headers=auth("ada"))
    bo = client.get("/stories", headers=auth("bo")).json()["stories"]
    assert [s["id"] for s in bo] == [str(ids["launch"])]
    assert bo[0]["last_read_at"] is None and len(bo[0]["whats_new"]) == 1  # Ada's reading isn't Bo's
    assert client.get(f"/stories/{ids['niche']}", headers=auth("bo")).status_code == 404
    assert client.post(f"/stories/{ids['niche']}/read", headers=auth("bo")).status_code == 404


def test_stories_need_sign_in_and_deleting_the_reader_deletes_read_state(client, auth) -> None:
    ids = _seed(client)
    assert client.get("/stories").status_code == 401
    client.get("/me", headers=auth("ada"))
    _follow(client, "ada", ids["demo"])
    client.post(f"/stories/{ids['launch']}/read", headers=auth("ada"))
    assert client.delete("/me", headers=auth("ada")).status_code == 204
    with client.app.state.sessions() as db:
        from app.db.models import ReadState

        assert db.scalars(select(ReadState)).all() == []
        assert db.get(Story, ids["launch"]) is not None  # shared stories stay


def test_one_article_in_two_feeds_counts_once(client) -> None:
    with client.app.state.sessions() as db:
        db.add(Topic(id="test-science", name="Science"))
        main = Source(type="feed", title="Phys Example", feed_url="https://phys.example/rss", language="en")
        space = Source(type="feed", title="Phys Example: Space", feed_url="https://phys.example/space/rss", language="en")
        db.add_all([main, space])
        db.flush()
        db.add_all([TopicSource(topic_id="test-science", source_id=main.id), TopicSource(topic_id="test-science", source_id=space.id)])
        story = Story(created_at=NOW, updated_at=NOW)
        db.add(story)
        db.flush()
        for source in (main, space):
            db.add(Item(source_id=source.id, guid=f"g{source.id}", link="https://phys.example/a/telescope", title="Telescope launches",
                        text="x", published_at=NOW, content_hash="h", story_id=story.id, status="ready"))
        db.commit()
    out = client.get("/demo/stories").json()["stories"][0]
    assert out["why"][0] == "1 source" and len(out["timeline"]) == 1
