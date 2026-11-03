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
    #: The site the feed belongs to, when it says.
    link: str | None = None


@dataclass(frozen=True)
class Entry:
    guid: str
    link: str | None
    title: str
    text: str
    published_at: datetime | None
    kind: str
    #: The entry's own picture, as a link (AGENTS.md: media stays where it is).
    image: str | None = None
    #: A podcast episode's audio, as a link. Never the file: playback streams
    #: from the publisher, and a bad enclosure fails closed to None.
    audio: str | None = None
    #: The episode's length in seconds, when the feed states one.
    duration_s: int | None = None

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


def _enclosure(raw) -> str | None:
    """The entry's audio enclosure address, first `audio/*` one wins, still
    unvalidated: presence decides the kind, validation decides the link."""
    for enclosure in raw.get("enclosures") or []:
        if str(enclosure.get("type", "")).startswith("audio/"):
            href = enclosure.get("href")
            return href if isinstance(href, str) else None
    return None


#: Longer than this, a stated duration is a typo, not an episode.
MAX_DURATION_S = 24 * 3600


def _duration(value) -> int | None:
    """`itunes:duration` shapes: seconds, `MM:SS`, `H:MM:SS`. Anything else —
    including nothing — is None, never a guess."""
    seconds: int | None = None
    if isinstance(value, bool):
        return None
    if isinstance(value, (int, float)):
        seconds = int(value)
    elif isinstance(value, str):
        try:
            parts = [int(part) for part in value.strip().split(":")]
        except ValueError:
            return None
        if len(parts) == 1:
            seconds = parts[0]
        elif len(parts) == 2:
            seconds = parts[0] * 60 + parts[1]
        elif len(parts) == 3:
            seconds = parts[0] * 3600 + parts[1] * 60 + parts[2]
    if seconds is None or not 0 < seconds <= MAX_DURATION_S:
        return None
    return seconds


#: Media URLs that name an image file.
_IMAGE_FILE = re.compile(r"\.(?:jpe?g|png|webp|gif|avif)(?:$|[?#])", re.IGNORECASE)
_IMG_TAG = re.compile(r"<img\b[^>]*>", re.IGNORECASE)
_ATTR = re.compile(r"([\w-]+)\s*=\s*[\"']([^\"']*)[\"']")
#: Trackers dressed as images: pixels, beacons, feed statistics, and GIFs.
_PIXEL = re.compile(r"pixel|beacon|track|feedburner\.com/~r/|//stats\.|\.gif(?:$|[?#])", re.IGNORECASE)


#: Sizes publishers write into a picture's address: WordPress's `name-300x188.jpg`,
#: GSMArena's `/-184x111/`; Phys.org keeps its thumbnails under `/tmb/`.
_STATED_WIDTH = re.compile(r"[-/](\d{2,4})x\d{2,4}(?:[./]|$)")
#: Narrower than this, a picture blurs on a large card: it stays a list thumbnail.
SMALL_IMAGE_WIDTH = 600


def is_thumbnail(url: str) -> bool:
    """Known to be small, by what its address says (OSMS never downloads it to look)."""
    path = url.split("?", 1)[0]
    widths = [int(w) for w in _STATED_WIDTH.findall(path)]
    return "/tmb/" in path or bool(widths and widths[-1] < SMALL_IMAGE_WIDTH)


def safe_image(url: str | None) -> str | None:
    """An image the reader's app can show from the publisher: https only (the macOS app's
    sandbox and the web app's HTTPS page refuse plain http), checked like any link."""
    url = html.unescape((url or "").strip())
    if not url.startswith("https://") or len(url) > 2000:
        return None
    return _safe_link(url)


def _image(raw) -> str | None:
    """The entry's own image, as its feed gives it: media:content, an image enclosure, the
    first real <img> in its HTML (never a tracking pixel), and media:thumbnail last, as
    thumbnails are small. Only the link is kept: OSMS never downloads, re-hosts or shows it
    to a model."""
    candidates = [
        m.get("url")
        for m in raw.get("media_content") or []
        if m.get("medium") == "image" or str(m.get("type", "")).startswith("image/") or _IMAGE_FILE.search(m.get("url", ""))
    ]
    candidates += [e.get("href") for e in raw.get("enclosures") or [] if str(e.get("type", "")).startswith("image/")]
    for markup in [c.get("value", "") for c in raw.get("content") or []] + [raw.get("summary", "")]:
        for tag in _IMG_TAG.findall(markup or ""):
            attrs = {key.lower(): value for key, value in _ATTR.findall(tag)}
            if attrs.get("width") in {"0", "1"} or attrs.get("height") in {"0", "1"} or _PIXEL.search(attrs.get("src", "")):
                continue
            candidates.append(attrs.get("src"))
    candidates += [m.get("url") for m in raw.get("media_thumbnail") or []]
    return next((safe for url in candidates if (safe := safe_image(url))), None)


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
        enclosure, duration = None, None
        if not source_type.startswith("arxiv"):
            for attachment in raw.get("attachments") or []:
                if isinstance(attachment, dict) and str(attachment.get("mime_type", "")).startswith("audio/"):
                    url = attachment.get("url")
                    enclosure = url if isinstance(url, str) else None
                    duration = _duration(attachment.get("duration_in_seconds"))
                    break
        audio = _safe_link(enclosure)
        if source_type.startswith("arxiv"):
            kind = "paper"
        elif enclosure:
            kind = "episode"
        elif source_type == "youtube":
            kind = "video"
        else:
            kind = "post" if not title else "article"
        image = safe_image(str(raw.get("image") or raw.get("banner_image") or ""))
        entries.append(Entry(guid=guid, link=link, title=title, text=text, published_at=published, kind=kind,
                             image=image, audio=audio, duration_s=duration))
    meta = FeedMeta(
        title=plain_text(str(feed.get("title") or ""), MAX_TITLE),
        language=normalise(feed.get("language")),
        ttl_minutes=None,
        link=_safe_link(feed.get("home_page_url") if isinstance(feed.get("home_page_url"), str) else None),
    )
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
        link=_safe_link(feed.get("link")),
    )
    entries = []
    for raw in parsed.entries:
        title = plain_text(raw.get("title", ""), MAX_TITLE)
        content = raw.get("content") or []
        body_html = (content[0].get("value") if content else None) or raw.get("summary", "")
        text = plain_text(body_html)
        if source_type.startswith("arxiv"):
            text = _ARXIV_PREFIX.sub("", text)
        link = _safe_link(raw.get("link"))
        guid = (raw.get("id") or link or hashlib.sha256(f"{title}\n{text}".encode()).hexdigest())[:1000]
        if not title and not text:
            continue
        enclosure = None if source_type.startswith("arxiv") else _enclosure(raw)
        audio = _safe_link(enclosure)
        duration = _duration(raw.get("itunes_duration")) if enclosure else None
        if source_type.startswith("arxiv"):
            kind = "paper"
        elif enclosure:
            kind = "episode"
        elif source_type == "youtube":
            kind = "video"
        else:
            kind = "post" if not title else "article"
        image = None if kind == "paper" else _image(raw)
        entries.append(Entry(guid=guid, link=link, title=title, text=text, published_at=_published(raw), kind=kind,
                             image=image, audio=audio, duration_s=duration))
    return meta, entries
