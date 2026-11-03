"""Resolve a link or handle to a source type and feed URL, when a reader asks to add one.

One look on the reader's behalf, the way their browser would: what they pasted is
fetched once through the fetcher (public addresses only, every redirect re-checked,
size and time capped). A feed is read as a feed; an HTML page only for the feed it
names (`<link rel="alternate">`), which is then fetched too. Nothing found is stored
here: the preview is titles and links, never the articles (rule 5)."""

import re
from dataclasses import dataclass
from datetime import UTC, datetime
from html.parser import HTMLParser
from urllib.parse import urljoin, urlparse

from app.services.ingestion.adapters.feed import Entry, FeedMeta, UnsafeFeed, parse_feed
from app.services.ingestion.fetcher import Fetcher, FetchError
from app.services.ingestion.safety import UnsafeUrl, check_url
from app.services.language import detect

#: How many of the newest entries the preview shows.
LATEST = 3

_MASTODON = re.compile(r"^@([A-Za-z0-9_][A-Za-z0-9_.-]*)@([A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)+)$")
_BLUESKY = re.compile(r"^@([A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)+)$")
_REDDIT = re.compile(r"^/?r/([A-Za-z0-9_]{2,21})/?$", re.IGNORECASE)
_MASTODON_PATH = re.compile(r"^/@[^/]+\.rss$")
_FEED_TYPES = frozenset({"application/rss+xml", "application/atom+xml", "application/feed+json", "application/json"})
#: What the frequency counts, by what the source publishes.
_NOUNS = {"podcast": "episode", "youtube": "video", "arxiv": "paper"}


class NotFollowable(ValueError):
    """Nothing OSMS can follow at that address."""


@dataclass(frozen=True)
class Discovered:
    title: str
    type: str
    #: Where the feed was found, after redirects.
    feed_url: str
    #: The address the feed was asked for, before redirects: an existing source may use it.
    requested_url: str
    html_url: str | None
    language: str
    #: Newest first; only titles and links are shown.
    entries: list[Entry]
    frequency: str | None


def address(query: str) -> tuple[str, str | None]:
    """The feed or page to fetch for a link or handle, and the type a handle implies."""
    text = query.strip()
    if match := _MASTODON.match(text):
        return f"https://{match[2].lower()}/@{match[1]}.rss", "mastodon"
    if match := _BLUESKY.match(text):
        return f"https://bsky.app/profile/{match[1].lower()}/rss", "bluesky"
    if match := _REDDIT.match(text):
        return f"https://www.reddit.com/r/{match[1]}/.rss", "reddit"
    if "://" not in text:
        text = f"https://{text}"
    return check_url(text), None


def source_type(feed_url: str, handle_type: str | None, entries: list[Entry]) -> str:
    if handle_type:
        return handle_type
    parts = urlparse(feed_url)
    host = (parts.hostname or "").lower()
    if host == "rss.arxiv.org":
        return "arxiv"
    if host == "youtube.com" or host.endswith(".youtube.com"):
        return "youtube"
    if host == "reddit.com" or host.endswith(".reddit.com"):
        return "reddit"
    if host == "bsky.app":
        return "bluesky"
    if _MASTODON_PATH.match(parts.path):
        return "mastodon"
    if any(e.kind == "episode" for e in entries):
        return "podcast"
    return "feed"


def frequency(dates: list[datetime], *, type: str = "feed", now: datetime | None = None) -> str | None:
    """How often it publishes, in words, from its entries' dates; None with too few."""
    now = now or datetime.now(UTC)
    seen = sorted(d if d.tzinfo else d.replace(tzinfo=UTC) for d in dates)
    seen = [d for d in seen if d <= now]
    if len(seen) < 3 or (span := (seen[-1] - seen[0]).total_seconds()) <= 0:
        return None
    per_day = (len(seen) - 1) / (span / 86400)
    noun = _NOUNS.get(type, "post")
    # The largest period it publishes at least about once in: 0.7 a week reads as 3 a month.
    for count, period in ((per_day, "day"), (per_day * 7, "week"), (per_day * 30, "month")):
        if count >= 0.9:
            n = max(1, round(count))
            return f"about {n} {noun}{'s' if n != 1 else ''} a {period}"
    return f"under one {noun} a month"


class _Alternates(HTMLParser):
    """The feeds an HTML page names in its head, in order."""

    def __init__(self) -> None:
        super().__init__(convert_charrefs=True)
        self.hrefs: list[str] = []
        self.done = False

    def handle_starttag(self, tag: str, attrs) -> None:
        if self.done:
            return
        if tag == "body":
            self.done = True
            return
        if tag != "link":
            return
        values = {k.lower(): (v or "") for k, v in attrs}
        rel = values.get("rel", "").lower().split()
        kind = values.get("type", "").lower().split(";")[0].strip()
        if "alternate" in rel and kind in _FEED_TYPES and values.get("href"):
            self.hrefs.append(values["href"].strip())

    def handle_endtag(self, tag: str) -> None:
        if tag == "head":
            self.done = True


def _alternate(body: bytes, page_url: str) -> str | None:
    parser = _Alternates()
    try:
        parser.feed(body.decode("utf-8", errors="replace"))
    except AssertionError:  # html.parser gives up on some malformed markup
        pass
    for href in parser.hrefs:
        try:
            return check_url(urljoin(page_url, href))
        except UnsafeUrl:
            continue
    return None


def _looks_like_html(body: bytes) -> bool:
    start = body.lstrip(b"\xef\xbb\xbf \t\r\n")[:1000].lower()
    if start.startswith((b"<!doctype html", b"<html")):
        return True
    return b"<html" in start and not any(tag in start for tag in (b"<rss", b"<feed", b"<rdf"))


def _as_feed(body: bytes, type: str) -> tuple[FeedMeta, list[Entry]] | None:
    if _looks_like_html(body):
        return None
    try:
        meta, entries = parse_feed(body, source_type=type)
    except UnsafeFeed:
        return None
    return (meta, entries) if entries or meta.title else None


def _fetch(fetcher: Fetcher, url: str):
    # An unsafe address (or a redirect to one) stays `UnsafeUrl`: refused, not missing.
    try:
        return fetcher.fetch(url)
    except FetchError as error:
        raise NotFollowable(str(error)) from error


def discover(fetcher: Fetcher, query: str, *, now: datetime | None = None) -> Discovered:
    """What following `query` would follow. Raises `UnsafeUrl` for an address OSMS never
    fetches, `NotFollowable` when there is no feed to follow."""
    url, handle_type = address(query)
    # The type a feed's host implies decides how its entries read (papers, videos).
    guess = source_type(url, handle_type, [])
    page = _fetch(fetcher, url)
    requested, html_url = url, None
    found = _as_feed(page.body, guess)
    if found is None:
        feed_url = _alternate(page.body, page.url)
        if feed_url is None:
            raise NotFollowable("no feed at that address")
        guess = source_type(feed_url, handle_type, [])
        html_url, requested = page.url, feed_url
        page = _fetch(fetcher, feed_url)
        found = _as_feed(page.body, guess)
        if found is None:
            raise NotFollowable("the page names a feed that isn't one")
    meta, entries = found
    kind = source_type(page.url, handle_type, entries)
    if kind != guess:
        meta, entries = parse_feed(page.body, source_type=kind)
    entries = sorted(entries, key=lambda e: e.published_at or datetime.min.replace(tzinfo=UTC), reverse=True)
    sample = "\n".join(f"{e.title}\n{e.text[:500]}" for e in entries[:10])
    title = meta.title or urlparse(html_url or page.url).hostname or page.url
    return Discovered(
        title=title,
        type=kind,
        feed_url=page.url,
        requested_url=requested,
        html_url=html_url or meta.link,
        language=detect(sample, meta.language)[:8],
        entries=entries,
        frequency=frequency([e.published_at for e in entries if e.published_at], type=kind, now=now),
    )


def feed_urls(found: Discovered) -> set[str]:
    """Every address the feed answers to, for finding a source OSMS already has."""
    return {found.feed_url, found.requested_url}
