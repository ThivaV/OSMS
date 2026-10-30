"""The fetcher: the only part of OSMS that reaches the web (AGENTS.md §4, §13).

Polite: conditional requests (ETag / Last-Modified), one request at a time per host
with a gap between them (three seconds for arXiv), backs off on 429 and Retry-After,
and says who it is. Safe: http(s) only, every hop of a redirect re-checked, the host's
addresses must all be public, and the response size and time are capped."""

import ipaddress
import socket
import time
from collections.abc import Callable
from dataclasses import dataclass
from email.utils import parsedate_to_datetime
from urllib.parse import urljoin, urlparse

import httpx

from app.services.ingestion.safety import UnsafeUrl, check_url

USER_AGENT = "OSMS/0.1 (news reader; +https://github.com/ThivaV/OSMS)"
MAX_BYTES = 5_000_000
MAX_REDIRECTS = 5
TIMEOUT_S = 20.0
DEFAULT_GAP_S = 1.0
#: arXiv: one request every three seconds, one connection, across all of OSMS.
HOST_GAPS_S = {"rss.arxiv.org": 3.0, "export.arxiv.org": 3.0, "arxiv.org": 3.0}

Resolver = Callable[[str, int], list[str]]
_REDIRECTS = frozenset({301, 302, 303, 307, 308})


def resolve(host: str, port: int) -> list[str]:
    return sorted({info[4][0] for info in socket.getaddrinfo(host, port, type=socket.SOCK_STREAM)})


class FetchError(Exception):
    def __init__(self, message: str, *, status: int | None = None, retry_after_s: float | None = None) -> None:
        super().__init__(message)
        self.status = status
        self.retry_after_s = retry_after_s


@dataclass(frozen=True)
class FetchResult:
    status: int  # 200, or 304 when nothing changed
    body: bytes
    url: str
    etag: str | None
    last_modified: str | None


def _retry_after(value: str | None) -> float | None:
    if not value:
        return None
    if value.strip().isdigit():
        return float(value.strip())
    try:
        return max(0.0, parsedate_to_datetime(value).timestamp() - time.time())
    except (TypeError, ValueError):
        return None


class Fetcher:
    def __init__(
        self,
        client: httpx.Client | None = None,
        *,
        resolver: Resolver = resolve,
        clock: Callable[[], float] = time.monotonic,
        sleep: Callable[[float], None] = time.sleep,
    ) -> None:
        self.client = client or httpx.Client(timeout=TIMEOUT_S, headers={"User-Agent": USER_AGENT})
        self.resolver = resolver
        self.clock = clock
        self.sleep = sleep
        self._last_request: dict[str, float] = {}

    def _check_public(self, url: str) -> str:
        safe = check_url(url)
        parts = urlparse(safe)
        host = parts.hostname or ""
        try:
            ipaddress.ip_address(host)
            return safe  # A literal address, already checked by check_url.
        except ValueError:
            pass
        try:
            addresses = self.resolver(host, parts.port or (443 if parts.scheme == "https" else 80))
        except OSError as error:
            raise FetchError(f"can't resolve {host}: {error}") from error
        if not addresses or not all(ipaddress.ip_address(a).is_global for a in addresses):
            raise UnsafeUrl(f"not a public address: {url!r}")
        return safe

    def _polite_wait(self, host: str) -> None:
        gap = HOST_GAPS_S.get(host, DEFAULT_GAP_S)
        if (last := self._last_request.get(host)) is not None and (wait := gap - (self.clock() - last)) > 0:
            self.sleep(wait)
        self._last_request[host] = self.clock()

    def fetch(self, url: str, *, etag: str | None = None, last_modified: str | None = None) -> FetchResult:
        current = url
        for _ in range(MAX_REDIRECTS + 1):
            safe = self._check_public(current)
            self._polite_wait(urlparse(safe).hostname or "")
            headers = {
                "User-Agent": USER_AGENT,
                "Accept": "application/rss+xml, application/atom+xml, application/feed+json, application/xml;q=0.9, */*;q=0.5",
            }
            if etag:
                headers["If-None-Match"] = etag
            if last_modified:
                headers["If-Modified-Since"] = last_modified
            try:
                with self.client.stream("GET", safe, headers=headers, follow_redirects=False) as response:
                    if response.status_code in _REDIRECTS:
                        location = response.headers.get("location")
                        if not location:
                            raise FetchError("redirect without a location", status=response.status_code)
                        current = urljoin(safe, location)
                        continue
                    if response.status_code == 304:
                        return FetchResult(304, b"", safe, etag, last_modified)
                    if response.status_code in (429, 503):
                        raise FetchError(
                            f"{response.status_code} from {urlparse(safe).hostname}",
                            status=response.status_code,
                            retry_after_s=_retry_after(response.headers.get("retry-after")),
                        )
                    if response.status_code >= 400:
                        raise FetchError(f"{response.status_code} from {urlparse(safe).hostname}", status=response.status_code)
                    body = bytearray()
                    for chunk in response.iter_bytes():
                        body.extend(chunk)
                        if len(body) > MAX_BYTES:
                            raise FetchError(f"response over {MAX_BYTES} bytes")
                    return FetchResult(
                        200, bytes(body), safe, response.headers.get("etag"), response.headers.get("last-modified")
                    )
            except httpx.HTTPError as error:
                raise FetchError(f"{type(error).__name__}: {error}") from error
        raise FetchError(f"more than {MAX_REDIRECTS} redirects")
