"""Adding a source by link or handle: discovery finds the feed (a feed link, a page that
names its feed, or a handle), previews titles and links only, and following reuses the
source OSMS already has before making a new one. One reader's follows are theirs alone."""

from datetime import UTC, datetime, timedelta

import httpx
import pytest
from sqlalchemy import func, select

from app.api import stories as stories_api
from app.db.models import Job, Source, Subscription
from app.services.ingestion import discovery
from app.services.ingestion.fetcher import Fetcher
from app.services.ingestion.safety import UnsafeUrl

NOW = datetime.now(UTC).replace(microsecond=0)


def rss(title: str, items: list[tuple[str, datetime]], *, link: str = "https://news.example/", language: str = "en",
        audio: bool = False) -> bytes:
    enclosure = '<enclosure url="https://cdn.example/{guid}.mp3" type="audio/mpeg" length="1"/>'
    body = "".join(
        f"<item><guid>{guid}</guid><title>{guid.title()} happened</title><link>https://news.example/{guid}</link>"
        f"<description>The full story of {guid}.</description><pubDate>{when:%a, %d %b %Y %H:%M:%S} GMT</pubDate>"
        f"{enclosure.format(guid=guid) if audio else ''}</item>"
        for guid, when in items
    )
    return (f'<?xml version="1.0"?><rss version="2.0"><channel><title>{title}</title><link>{link}</link>'
            f"<language>{language}</language>{body}</channel></rss>").encode()


def atom(title: str, entries: list[tuple[str, datetime]]) -> bytes:
    body = "".join(
        f"<entry><id>{guid}</id><title>{guid} uploaded</title><link href='https://www.youtube.com/watch?v={guid}'/>"
        f"<updated>{when:%Y-%m-%dT%H:%M:%SZ}</updated></entry>"
        for guid, when in entries
    )
    return f'<?xml version="1.0"?><feed xmlns="http://www.w3.org/2005/Atom"><title>{title}</title>{body}</feed>'.encode()


DAILY = [(f"day{n}", NOW - timedelta(days=n)) for n in range(5)]
PAGES = {
    "https://news.example/rss": rss("News Example", DAILY),
    "https://blog.example/": (
        b"<!doctype html><html><head><title>A blog</title>"
        b'<link rel="stylesheet" href="/style.css">'
        b'<link rel="alternate" type="application/atom+xml" title="Posts" href="/feed.atom">'
        b'<link rel="alternate" type="application/rss+xml" title="Comments" href="/comments.rss">'
        b"</head><body>Hello</body></html>"
    ),
    "https://blog.example/feed.atom": atom("A Blog", [("post1", NOW - timedelta(days=1)), ("post2", NOW - timedelta(days=3))]),
    "https://pods.example/feed": rss("A Podcast", [(f"ep{n}", NOW - timedelta(days=7 * n)) for n in range(4)], audio=True),
    "https://www.youtube.com/@makers": (
        b'<html><head><link rel="alternate" type="application/rss+xml" title="RSS" '
        b'href="https://www.youtube.com/feeds/videos.xml?channel_id=UC123"></head><body></body></html>'
    ),
    "https://www.youtube.com/feeds/videos.xml?channel_id=UC123": atom("Makers", [("v1", NOW - timedelta(hours=5))]),
    "https://plain.example/": b"<!doctype html><html><head><title>No feeds here</title></head><body></body></html>",
    "https://liar.example/": b'<html><head><link rel="alternate" type="application/rss+xml" href="/rss"></head></html>',
    "https://liar.example/rss": b"<!doctype html><html><head></head><body>Not a feed</body></html>",
    "https://www.theverge.com/rss/ai-artificial-intelligence/index.xml": rss("The Verge AI", DAILY),
}


def fetcher(pages: dict[str, bytes] = PAGES, *, addresses=("93.184.216.34",), redirects: dict[str, str] | None = None,
            seen: list[str] | None = None) -> Fetcher:
    def handler(request: httpx.Request) -> httpx.Response:
        url = str(request.url)
        if seen is not None:
            seen.append(url)
        if redirects and url in redirects:
            return httpx.Response(301, headers={"location": redirects[url]})
        return httpx.Response(200, content=pages[url]) if url in pages else httpx.Response(404)

    return Fetcher(httpx.Client(transport=httpx.MockTransport(handler)), resolver=lambda h, p: list(addresses),
                   sleep=lambda s: None)


@pytest.fixture(autouse=True)
def _fresh_limits():
    stories_api._asked.clear()
    yield
    stories_api._asked.clear()


# ── Discovery ─────────────────────────────────────────────────────────────────


def test_a_feed_link_is_read_as_a_feed() -> None:
    found = discovery.discover(fetcher(), "news.example/rss")
    assert (found.title, found.type, found.feed_url, found.html_url) == (
        "News Example", "feed", "https://news.example/rss", "https://news.example/")
    assert found.language == "en"
    assert [e.guid for e in found.entries][:3] == ["day0", "day1", "day2"], "newest first"
    assert found.frequency == "about 1 post a day"


def test_a_page_names_its_feed_and_the_first_one_wins() -> None:
    seen: list[str] = []
    found = discovery.discover(fetcher(seen=seen), "https://blog.example/")
    assert seen == ["https://blog.example/", "https://blog.example/feed.atom"], "relative href, resolved; comments skipped"
    assert (found.title, found.type, found.feed_url, found.html_url) == (
        "A Blog", "feed", "https://blog.example/feed.atom", "https://blog.example/")


def test_handles_name_their_feeds() -> None:
    assert discovery.address("@ada@Social.example") == ("https://social.example/@ada.rss", "mastodon")
    assert discovery.address("@ada.bsky.social") == ("https://bsky.app/profile/ada.bsky.social/rss", "bluesky")
    assert discovery.address("r/Python") == ("https://www.reddit.com/r/Python/.rss", "reddit")
    assert discovery.address("/r/python/") == ("https://www.reddit.com/r/python/.rss", "reddit")
    assert discovery.address("  news.example/rss ") == ("https://news.example/rss", None)
    for bad in ("ada@social.example", "localhost:8000", "ftp://files.example/feed", "http://10.0.0.1/rss", "verge"):
        with pytest.raises(UnsafeUrl):
            discovery.address(bad)


def test_a_mastodon_handle_is_typed_by_the_handle() -> None:
    pages = {"https://social.example/@ada.rss": rss("Ada", DAILY, link="https://social.example/@ada")}
    found = discovery.discover(fetcher(pages), "@ada@social.example")
    assert (found.type, found.html_url) == ("mastodon", "https://social.example/@ada")


def test_audio_makes_a_podcast_and_youtube_entries_are_videos() -> None:
    podcast = discovery.discover(fetcher(), "https://pods.example/feed")
    assert podcast.type == "podcast" and {e.kind for e in podcast.entries} == {"episode"}
    assert podcast.frequency == "about 1 episode a week"
    channel = discovery.discover(fetcher(), "https://www.youtube.com/@makers")
    assert (channel.type, channel.title) == ("youtube", "Makers")
    assert channel.feed_url == "https://www.youtube.com/feeds/videos.xml?channel_id=UC123"
    assert [e.kind for e in channel.entries] == ["video"]
    assert channel.frequency is None, "one video says nothing about how often"


def test_nothing_to_follow_says_so() -> None:
    for query in ("https://plain.example/", "https://liar.example/", "https://gone.example/rss"):
        with pytest.raises(discovery.NotFollowable):
            discovery.discover(fetcher(), query)


def test_unsafe_addresses_are_refused_however_they_are_reached() -> None:
    with pytest.raises(UnsafeUrl):
        discovery.discover(fetcher(addresses=("10.0.0.7",)), "https://news.example/rss")
    with pytest.raises(UnsafeUrl):
        discovery.discover(fetcher(redirects={"https://news.example/rss": "http://169.254.169.254/latest"}),
                           "https://news.example/rss")


def test_frequency_in_words() -> None:
    def every(gap: timedelta, n: int = 6) -> list[datetime]:
        return [NOW - gap * i for i in range(n)]

    assert discovery.frequency(every(timedelta(hours=12))) == "about 2 posts a day"
    assert discovery.frequency(every(timedelta(days=2))) == "about 4 posts a week"
    assert discovery.frequency(every(timedelta(days=10)), type="arxiv") == "about 3 papers a month"
    assert discovery.frequency(every(timedelta(days=90))) == "under one post a month"
    assert discovery.frequency(every(timedelta(days=1), n=2)) is None
    assert discovery.frequency([NOW] * 4) is None


# ── The API ───────────────────────────────────────────────────────────────────


def test_discover_previews_titles_and_links_and_stores_nothing(client, auth) -> None:
    client.app.state.fetcher = fetcher()
    before = _sources(client)
    response = client.post("/me/sources/discover", headers=auth("ada"), json={"query": "https://news.example/rss"})
    assert response.status_code == 200, response.text
    body = response.json()
    assert body["source"] == {"id": "", "name": "News Example", "type": "feed", "language": "en",
                              "url": "https://news.example/"}
    assert [e["title"] for e in body["latest"]] == ["Day0 happened", "Day1 happened", "Day2 happened"]
    assert set(body["latest"][0]) == {"title", "url", "published_at", "kind"}, "titles and links, never the text"
    assert body["latest"][0]["kind"] == "article" and body["frequency"] == "about 1 post a day"
    assert body["already_followed"] is False
    assert _sources(client) == before


def test_discover_needs_sign_in_and_explains_what_went_wrong(client, auth) -> None:
    client.app.state.fetcher = fetcher()
    assert client.post("/me/sources/discover", json={"query": "https://news.example/rss"}).status_code == 401
    ada = auth("ada")
    for bad in ({"query": ""}, {"query": "   "}, {"query": "x" * 501}, {"query": "a", "extra": 1}, {}):
        assert client.post("/me/sources/discover", headers=ada, json=bad).status_code == 422, bad
    assert client.post("/me/sources/discover", headers=ada, json={"query": "localhost"}).status_code == 422
    missing = client.post("/me/sources/discover", headers=ada, json={"query": "https://plain.example/"})
    assert (missing.status_code, missing.json()["detail"]) == (404, "No feed found at that address.")


def test_looking_up_sources_is_rate_limited(client, auth) -> None:
    client.app.state.fetcher = fetcher()
    codes = [
        client.post("/me/sources/discover", headers=auth("ada"), json={"query": "https://news.example/rss"}).status_code
        for _ in range(21)
    ]
    assert codes[:20] == [200] * 20 and codes[20] == 429
    assert client.post("/me/sources/discover", headers=auth("bo"), json={"query": "https://news.example/rss"}).status_code == 200


def test_following_makes_the_source_subscribes_and_fetches_it(client, auth) -> None:
    client.app.state.fetcher = fetcher()
    me = client.post("/me/sources", headers=auth("ada"), json={"query": "https://blog.example/"})
    assert me.status_code == 200, me.text
    assert [s["name"] for s in me.json()["subscriptions"]] == ["A Blog"]
    with client.app.state.sessions() as db:
        source = db.scalar(select(Source).where(Source.feed_url == "https://blog.example/feed.atom"))
        assert (source.type, source.html_url, source.language) == ("feed", "https://blog.example/", "en")
        assert db.scalar(select(Job).where(Job.kind == "fetch-source", Job.ref == str(source.id))) is not None
    again = client.post("/me/sources", headers=auth("ada"), json={"query": "https://blog.example/"})
    assert len(again.json()["subscriptions"]) == 1, "following twice follows once"
    preview = client.post("/me/sources/discover", headers=auth("ada"), json={"query": "https://blog.example/"}).json()
    assert preview["already_followed"] is True and preview["source"]["id"] == str(source.id)


def test_following_reuses_a_source_osms_already_has(client, auth) -> None:
    """The seed's Verge feed, and one reader's new feed for another: shared, never copied,
    and one reader's follows never show up as another's."""
    client.app.state.fetcher = fetcher()
    verge = "https://www.theverge.com/rss/ai-artificial-intelligence/index.xml"
    with client.app.state.sessions() as db:
        seeded = db.scalar(select(Source).where(Source.feed_url == verge))
    preview = client.post("/me/sources/discover", headers=auth("ada"), json={"query": verge}).json()
    assert preview["source"]["id"] == str(seeded.id) and preview["source"]["name"] == seeded.title
    client.post("/me/sources", headers=auth("ada"), json={"query": verge})
    client.post("/me/sources", headers=auth("ada"), json={"query": "https://pods.example/feed"})
    bo = client.post("/me/sources", headers=auth("bo"), json={"query": "https://pods.example/feed"}).json()
    assert [s["name"] for s in bo["subscriptions"]] == ["A Podcast"]
    with client.app.state.sessions() as db:
        assert db.scalar(select(func.count()).select_from(Source).where(Source.feed_url == verge)) == 1
        podcasts = db.scalars(select(Source).where(Source.feed_url == "https://pods.example/feed")).all()
        assert [p.type for p in podcasts] == ["podcast"]
        ada_follows = set(db.scalars(select(Subscription.source_id).where(Subscription.user_id == "ada")))
        assert ada_follows == {seeded.id, podcasts[0].id}


def test_following_a_redirected_feed_finds_the_source_at_either_address(client, auth) -> None:
    client.app.state.fetcher = fetcher(
        {"https://new.example/rss": rss("Moved", DAILY)}, redirects={"https://old.example/rss": "https://new.example/rss"}
    )
    client.post("/me/sources", headers=auth("ada"), json={"query": "https://old.example/rss"})
    client.post("/me/sources", headers=auth("bo"), json={"query": "https://new.example/rss"})
    with client.app.state.sessions() as db:
        assert db.scalars(select(Source.feed_url).where(Source.title == "Moved")).all() == ["https://new.example/rss"]


def test_unfollowing_keeps_the_source_for_everyone_else(client, auth) -> None:
    client.app.state.fetcher = fetcher()
    for user in ("ada", "bo"):
        client.post("/me/sources", headers=auth(user), json={"query": "https://news.example/rss"})
    source_id = client.get("/me", headers=auth("ada")).json()["subscriptions"][0]["id"]
    me = client.delete(f"/me/sources/{source_id}", headers=auth("ada"))
    assert me.status_code == 200 and me.json()["subscriptions"] == []
    assert client.delete(f"/me/sources/{source_id}", headers=auth("ada")).status_code == 404
    assert [s["id"] for s in client.get("/me", headers=auth("bo")).json()["subscriptions"]] == [source_id]
    assert client.delete(f"/me/sources/{source_id}").status_code == 401


def _sources(client) -> int:
    with client.app.state.sessions() as db:
        return db.scalar(select(func.count()).select_from(Source))
