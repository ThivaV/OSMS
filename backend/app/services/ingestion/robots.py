"""robots.txt, for article pages: OSMS reads a page's <head> for its preview image only
where the site allows a crawler like it (RFC 9309). Feeds are published to be read and
are fetched without it. One read per site a day."""

import time
from collections.abc import Callable
from urllib.parse import urlparse
from urllib.robotparser import RobotFileParser

from app.services.ingestion.fetcher import Fetcher, FetchError
from app.services.ingestion.safety import UnsafeUrl

#: The product token in OSMS's User-Agent, as robots.txt names crawlers.
AGENT = "OSMS"
TTL_S = 24 * 3600


def _rules(lines: list[str]) -> RobotFileParser:
    parser = RobotFileParser()
    parser.parse(lines)
    return parser


class Robots:
    def __init__(self, fetcher: Fetcher, *, clock: Callable[[], float] = time.monotonic) -> None:
        self.fetcher = fetcher
        self.clock = clock
        self._sites: dict[str, tuple[float, RobotFileParser]] = {}

    def allowed(self, url: str) -> bool:
        parts = urlparse(url)
        site = f"{parts.scheme}://{parts.netloc}"
        cached = self._sites.get(site)
        if cached is None or self.clock() - cached[0] > TTL_S:
            cached = (self.clock(), self._load(site))
            self._sites[site] = cached
        return cached[1].can_fetch(AGENT, url)

    def _load(self, site: str) -> RobotFileParser:
        try:
            body = self.fetcher.fetch(f"{site}/robots.txt").body
        except FetchError as error:
            # No robots.txt (4xx) allows everything; a server error or no answer, nothing.
            unavailable = error.status is not None and 400 <= error.status < 500
            return _rules([] if unavailable else ["User-agent: *", "Disallow: /"])
        except UnsafeUrl:
            return _rules(["User-agent: *", "Disallow: /"])
        return _rules(body.decode("utf-8", errors="replace").splitlines())
