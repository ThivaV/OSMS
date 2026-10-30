"""The generic feed adapter: RSS, Atom and JSON Feed into one entry shape.

A feed is untrusted input. Entity declarations are refused before parsing (no entity
expansion, no billion laughs), HTML becomes plain text, links go through `check_url`,
and only the feed's own excerpt is kept, never the full article (rule 5)."""

import calendar
import hashlib
import html
import json
import re
from dataclasses import dataclass
from datetime import UTC, datetime
from html.parser import HTMLParser

import feedparser

from app.services.ingestion.safety import UnsafeUrl, check_url
from app.services.language import normalise

#: The excerpt OSMS keeps per item: enough for claims, never a whole article.
MAX_TEXT = 4000
MAX_TITLE = 500


class UnsafeFeed(ValueError):
    """The feed is refused as a whole."""


@dataclass(frozen=True)
class FeedMeta:
    title: str
    language: str | None
    ttl_minutes: int | None


@dataclass(frozen=True)
class Entry:
    guid: str
    link: str | None
    title: str
    text: str
    published_at: datetime | None
    kind: str

    @property
    def content_hash(self) -> str:
        return hashlib.sha256(f"{self.title}\n{self.text}".encode()).hexdigest()


class _Text(HTMLParser):
    """HTML → plain text: scripts and styles dropped, block tags become line breaks."""

    _SKIP = frozenset({"script", "style", "noscript", "iframe", "svg"})
    _BLOCK = frozenset({"p", "br", "div", "li", "h1", "h2", "h3", "h4", "tr", "blockquote", "figcaption"})

    def __init__(self) -> None:
        super().__init__(convert_charrefs=True)
        self.parts: list[str] = []
        self._skipping = 0

    def handle_starttag(self, tag: str, attrs) -> None:
        if tag in self._SKIP:
            self._skipping += 1
        elif tag in self._BLOCK:
            self.parts.append("\n")

    def handle_endtag(self, tag: str) -> None:
        if tag in self._SKIP and self._skipping:
            self._skipping -= 1
        elif tag in self._BLOCK:
            self.parts.append("\n")

    def handle_data(self, data: str) -> None:
        if not self._skipping:
            self.parts.append(data)


def plain_text(markup: str, limit: int = MAX_TEXT) -> str:
    parser = _Text()
    parser.feed(markup or "")
    parser.close()
    text = html.unescape("".join(parser.parts))
    lines = [re.sub(r"[ \t ]+", " ", line).strip() for line in text.splitlines()]
    text = "\n".join(line for line in lines if line)
    return text[:limit].rstrip()


_ARXIV_PREFIX = re.compile(r"^arXiv:\S+\s+Announce Type:\s*\S+\s*Abstract:\s*", re.IGNORECASE)


def _published(entry) -> datetime | None:
    for key in ("published_parsed", "updated_parsed", "created_parsed"):
        if parsed := entry.get(key):
            return datetime.fromtimestamp(calendar.timegm(parsed), UTC)
    return None


def _safe_link(link: str | None) -> str | None:
    if not link:
        return None
    try:
        return check_url(link)
    except UnsafeUrl:
        return None


def _json_feed(body: bytes, source_type: str) -> tuple[FeedMeta, list[Entry]]:
    try:
        feed = json.loads(body)
    except (UnicodeDecodeError, json.JSONDecodeError) as error:
        raise UnsafeFeed("not a feed: invalid JSON") from error
    if not isinstance(feed, dict) or not str(feed.get("version", "")).startswith("https://jsonfeed.org/"):
        raise UnsafeFeed("not a feed: JSON without a JSON Feed version")
    entries = []
    for raw in feed.get("items") or []:
        if not isinstance(raw, dict):
            continue
        title = plain_text(str(raw.get("title") or ""), MAX_TITLE)
        text = plain_text(str(raw.get("content_html") or raw.get("content_text") or raw.get("summary") or ""))
        if not title and not text:
            continue
        link = _safe_link(raw.get("url"))
        published = None
        if stamp := raw.get("date_published") or raw.get("date_modified"):
            try:
                published = datetime.fromisoformat(str(stamp)).astimezone(UTC)
            except ValueError:
                published = None
        guid = str(raw.get("id") or link or hashlib.sha256(f"{title}\n{text}".encode()).hexdigest())[:1000]
        kind = "paper" if source_type == "arxiv" else ("post" if not title else "article")
        entries.append(Entry(guid=guid, link=link, title=title, text=text, published_at=published, kind=kind))
    meta = FeedMeta(title=plain_text(str(feed.get("title") or ""), MAX_TITLE), language=normalise(feed.get("language")), ttl_minutes=None)
    return meta, entries


def parse_feed(body: bytes, *, source_type: str = "feed") -> tuple[FeedMeta, list[Entry]]:
    if body.lstrip()[:1] == b"{":
        return _json_feed(body, source_type)
    if b"<!ENTITY" in body[:20_000].upper():
        raise UnsafeFeed("feed with entity declarations")
    parsed = feedparser.parse(body)
    if parsed.bozo and not parsed.entries:
        raise UnsafeFeed(f"not a feed: {type(parsed.get('bozo_exception')).__name__}")
    feed = parsed.feed
    ttl = feed.get("ttl")
    meta = FeedMeta(
        title=plain_text(feed.get("title", ""), MAX_TITLE),
        language=normalise(feed.get("language")),
        ttl_minutes=int(ttl) if isinstance(ttl, str) and ttl.isdigit() else None,
    )
    entries = []
    for raw in parsed.entries:
        title = plain_text(raw.get("title", ""), MAX_TITLE)
        content = raw.get("content") or []
        body_html = (content[0].get("value") if content else None) or raw.get("summary", "")
        text = plain_text(body_html)
        if source_type == "arxiv":
            text = _ARXIV_PREFIX.sub("", text)
        link = _safe_link(raw.get("link"))
        guid = (raw.get("id") or link or hashlib.sha256(f"{title}\n{text}".encode()).hexdigest())[:1000]
        if not title and not text:
            continue
        kind = "paper" if source_type == "arxiv" else ("post" if not title else "article")
        entries.append(Entry(guid=guid, link=link, title=title, text=text, published_at=_published(raw), kind=kind))
    return meta, entries
