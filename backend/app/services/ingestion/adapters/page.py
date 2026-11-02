"""An article page's preview image: the picture a site names for link previews (Open
Graph's og:image, Twitter's card image), read from its <head>. Only the link is kept;
the page is read in memory and dropped (rule 5: OSMS never stores article text)."""

import re
from html.parser import HTMLParser
from urllib.parse import urljoin

from app.services.ingestion.adapters.feed import safe_image

#: Most specific first.
_KEYS = ("og:image:secure_url", "og:image:url", "og:image", "twitter:image", "twitter:image:src")
#: A site's own picture standing in for an article's: its logo or a placeholder.
_GENERIC = re.compile(r"logo|placeholder|fallback|default[-_.]", re.IGNORECASE)


class _Head(HTMLParser):
    def __init__(self) -> None:
        super().__init__(convert_charrefs=True)
        self.meta: dict[str, str] = {}
        self.image_src: str | None = None
        self.done = False

    def handle_starttag(self, tag: str, attrs) -> None:
        if self.done:
            return
        a = {key.lower(): value or "" for key, value in attrs}
        if tag == "body":
            self.done = True
        elif tag == "meta":
            key = (a.get("property") or a.get("name") or "").lower()
            if key in _KEYS and a.get("content"):
                self.meta.setdefault(key, a["content"].strip())
        elif tag == "link" and "image_src" in a.get("rel", "").lower().split() and a.get("href"):
            self.image_src = self.image_src or a["href"].strip()

    def handle_endtag(self, tag: str) -> None:
        self.done = self.done or tag == "head"


def preview_image(body: bytes, page_url: str) -> str | None:
    """The page's preview image as an https link, or None (no tag, plain http, a logo)."""
    head = _Head()
    try:
        head.feed(body.decode("utf-8", errors="replace"))
    except (ValueError, AssertionError):
        pass
    for candidate in [head.meta.get(key) for key in _KEYS] + [head.image_src]:
        if candidate and (url := safe_image(urljoin(page_url, candidate))) and not _GENERIC.search(url.split("?", 1)[0]):
            return url
    return None
