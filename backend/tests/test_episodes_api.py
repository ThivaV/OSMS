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


def _history(client, source_id: int, count: int, tag: str = "") -> None:
    """A deep history on one show: one episode an hour apart."""
    with client.app.state.sessions() as db:
        db.add_all([
            Item(source_id=source_id, guid=f"{tag}h{i}", link=f"https://gradienthour.example/{tag}h{i}",
                 title=f"{tag}Hour {i}", text=f"Show notes {i}.", published_at=NOW - timedelta(hours=i),
                 content_hash=f"{tag}h{i}", kind="episode", status="ready",
                 audio_url=f"https://cdn.gradienthour.example/h{i}.mp3")
            for i in range(count)
        ])
        db.commit()


def _walk(client, headers, **params) -> list[str]:
    """Every page to the end: titles in order, one request per page."""
    titles, cursor, guard = [], None, 0
    while guard < 10:
        guard += 1
        query = {"limit": 2, **params}
        if cursor is not None:
            query["cursor"] = cursor
        body = client.get("/demo/episodes", params=query, headers=headers).json()
        titles += [e["title"] for e in body["episodes"]]
        cursor = body["next_cursor"]
        if cursor is None:
            return titles
    raise AssertionError("history never ended")


def test_history_pages_oldest_last_without_dupes_or_gaps(client) -> None:
    ids = _seed(client)
    _history(client, ids["demo"], 5)
    # Hour 2 ties "Diffusion normals" to the hour; the id tie-break puts the
    # later insert first, deterministically.
    assert _walk(client, {}) == [
        "Hour 0", "Hour 1", "Hour 2", "Diffusion normals", "Hour 3", "Hour 4", "Trailer",
    ]


def test_new_episodes_mid_browse_neither_dupe_nor_skip(client) -> None:
    ids = _seed(client)
    _history(client, ids["demo"], 3)
    first = client.get("/demo/episodes", params={"limit": 2}).json()
    assert [e["title"] for e in first["episodes"]] == ["Hour 0", "Hour 1"]
    _history(client, ids["demo"], 1, tag="fresh")  # a fresh episode lands while browsing
    second = client.get("/demo/episodes", params={"limit": 2, "cursor": first["next_cursor"]}).json()
    # The fresh episode is newer than the cursor: it waits for a refresh, and
    # nothing already seen repeats, nothing unseen is skipped.
    assert [e["title"] for e in second["episodes"]] == ["Hour 2", "Diffusion normals"]
    assert second["next_cursor"] is not None


def test_one_shows_history_and_stable_show_list(client, auth) -> None:
    ids = _seed(client)
    _follow(client, "ada", ids["demo"], ids["private"])
    headers = auth("ada")
    only = client.get("/episodes", params={"source_id": ids["private"]}, headers=headers).json()
    assert [e["title"] for e in only["episodes"]] == ["A niche episode"]
    assert only["next_cursor"] is None
    shows = [s["title"] for s in only["shows"]]
    assert shows == ["Ada's Cast", "Gradient Hour"], "every show, alphabetical, filter or none"
    assert client.get("/episodes", params={"source_id": 999999}, headers=headers).json()["episodes"] == []


def test_a_forged_cursor_is_422(client) -> None:
    assert client.get("/demo/episodes", params={"cursor": "not-a-cursor"}).status_code == 422
    assert client.get("/demo/episodes", params={"cursor": "bm90LWpzb24="}).status_code == 422
