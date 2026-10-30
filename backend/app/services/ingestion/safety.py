"""Link safety and untrusted OPML parsing (AGENTS.md §13).

`check_url` never touches the network: scheme, credentials, literal IPs and
special-use names are all decided from the string. DNS time-of-check — and the
recheck after every redirect — stays the fetcher's job (Day 4), because only
the fetcher reaches the web.
"""

import ipaddress
import xml.etree.ElementTree as ET
from urllib.parse import urlparse

#: A reader's OPML file is parsed, then discarded. Caps keep a hostile file cheap.
MAX_OPML_BYTES = 1_000_000
MAX_OPML_OUTLINES = 5_000

#: Hosts that are never fetched, however they are spelled.
_BLOCKED_HOSTS = frozenset({"localhost", "metadata.google.internal"})
#: Suffixes that never leave the local network (plus cloud metadata names).
_BLOCKED_SUFFIXES = (".local", ".internal", ".invalid", ".localhost")


class UnsafeUrl(ValueError):
    """The URL fails closed. Callers never get a maybe-URL."""


class UnsafeOpml(ValueError):
    """The OPML file is refused as a whole: oversize, entities, too many
    outlines, or one bad URL. Fix the file, never the parser."""


def check_url(candidate: str) -> str:
    """Return the normalized URL, or raise `UnsafeUrl`."""
    url = candidate.strip()
    try:
        parts = urlparse(url)
    except ValueError as error:
        raise UnsafeUrl(f"not a URL: {candidate!r}") from error
    if parts.scheme not in ("http", "https"):
        raise UnsafeUrl(f"http(s) only: {candidate!r}")
    if parts.username or parts.password:
        raise UnsafeUrl(f"no credentials in URLs: {candidate!r}")
    host = (parts.hostname or "").lower().rstrip(".")
    if not host:
        raise UnsafeUrl(f"no host: {candidate!r}")
    _check_host(host, candidate)
    return url


def _check_host(host: str, candidate: str) -> None:
    if host in _BLOCKED_HOSTS or host.endswith(_BLOCKED_SUFFIXES) or "." not in host:
        raise UnsafeUrl(f"not a public host: {candidate!r}")
    try:
        address = ipaddress.ip_address(host)
    except ValueError:
        return  # A public-looking name; the fetcher checks what it resolves to.
    if not address.is_global:
        raise UnsafeUrl(f"not a public address: {candidate!r}")


def read_user_opml(data: bytes) -> list[tuple[str, str, str | None]]:
    """Parse a reader's OPML file into `(title, feed_url, html_url)` triples.

    Untrusted input: entity declarations (billion-laughs needs them),
    oversize files and outline floods are refused before parsing does any
    real work, and every URL goes through `check_url`.
    """
    if len(data) > MAX_OPML_BYTES:
        raise UnsafeOpml(f"OPML over {MAX_OPML_BYTES} bytes")
    if b"<!ENTITY" in data:
        raise UnsafeOpml("OPML with entity declarations")
    try:
        root = ET.fromstring(data)
    except ET.ParseError as error:
        raise UnsafeOpml(f"OPML does not parse: {error}") from error
    body = root.find("body")
    outlines = list(body.iter("outline")) if body is not None else []
    if len(outlines) > MAX_OPML_OUTLINES:
        raise UnsafeOpml(f"OPML with more than {MAX_OPML_OUTLINES} outlines")
    found: list[tuple[str, str, str | None]] = []
    for outline in outlines:
        feed_url = outline.get("xmlUrl")
        if not feed_url:
            continue  # Folders and bare links subscribe to nothing.
        try:
            safe_feed = check_url(feed_url)
        except UnsafeUrl as error:
            raise UnsafeOpml(f"OPML with an unsafe feed URL: {error}") from error
        html_url = outline.get("htmlUrl")
        if html_url:
            try:
                html_url = check_url(html_url)
            except UnsafeUrl as error:
                raise UnsafeOpml(f"OPML with an unsafe page URL: {error}") from error
        else:
            html_url = None
        found.append((outline.get("title") or outline.get("text") or safe_feed, safe_feed, html_url))
    return found
