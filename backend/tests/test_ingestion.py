"""Coming in: feeds parsed safely, fetched politely, scheduled on their own rhythm, and
queued so a restart loses nothing. All fake feeds, no network (AGENTS.md §12)."""

import random
from datetime import UTC, datetime, timedelta

import httpx
import pytest

from app.db.models import Job, Source, Subscription, Topic, TopicSource, User
from app.services import jobs
from app.services.ingestion import scheduler
from app.services.ingestion.adapters.feed import UnsafeFeed, parse_feed, plain_text
from app.services.ingestion.fetcher import Fetcher, FetchError
from app.services.ingestion.safety import UnsafeUrl
from app.services.language import detect
from app.services.names import names
from app.services.triage import prefilter

RSS = b"""<?xml version="1.0"?>
<rss version="2.0"><channel><title>Bytebladet</title><language>da-DK</language><ttl>30</ttl>
<item><guid>bb-1</guid><title>Lumen Fold koster 7.999 kr.</title><link>https://bytebladet.example/fold</link>
<description><![CDATA[<p>Lumen <b>Fold</b> kommer til Danmark.</p><img src="https://track.example/p.gif"><script>alert(1)</script>]]></description>
<pubDate>Fri, 30 Oct 2026 09:20:00 GMT</pubDate></item>
<item><title>Uden link</title><description>Kort tekst</description></item>
<item><guid>bb-3</guid><title>Farlig</title><link>javascript:alert(1)</link><description>x</description></item>
</channel></rss>"""

ATOM = b"""<?xml version="1.0" encoding="utf-8"?>
<feed xmlns="http://www.w3.org/2005/Atom"><title>The Launch Desk</title>
<entry><id>tag:launchdesk.example,2026:1</id><title>Lumen Fold launches at $999</title>
<link href="https://launchdesk.example/fold"/><updated>2026-10-30T10:05:00Z</updated>
<content type="html">&lt;p&gt;The Lumen Fold goes on sale in the US.&lt;/p&gt;</content></entry></feed>"""

JSON_FEED = b"""{"version": "https://jsonfeed.org/version/1.1", "title": "Orbit Notes",
"items": [{"id": "o1", "url": "https://orbit.example/1", "title": "Kestrel lands", "content_text": "The rocket landed.",
"date_published": "2026-10-29T08:00:00Z"}]}"""

ARXIV = b"""<?xml version="1.0"?><rss version="2.0"><channel><title>cs.CL updates</title>
<item><title>A Paper</title><link>https://arxiv.org/abs/2610.90001</link><guid>oai:arXiv.org:2610.90001v1</guid>
<description>arXiv:2610.90001v1 Announce Type: new Abstract: We study things.</description></item></channel></rss>"""


def test_rss_becomes_plain_text_entries_with_safe_links() -> None:
    meta, entries = parse_feed(RSS)
    assert (meta.language, meta.ttl_minutes) == ("da", 30)
    first = entries[0]
    assert (first.guid, first.link, first.title) == ("bb-1", "https://bytebladet.example/fold", "Lumen Fold koster 7.999 kr.")
    assert first.text == "Lumen Fold kommer til Danmark."  # no tags, no tracking pixel, no script
    assert first.published_at == datetime(2026, 10, 30, 9, 20, tzinfo=UTC)
    assert entries[1].guid and entries[1].link is None  # no link: a stable id from the text
    assert entries[2].link is None  # javascript: links never survive


def test_atom_json_feed_and_arxiv() -> None:
    _, atom = parse_feed(ATOM)
    assert atom[0].text == "The Lumen Fold goes on sale in the US." and atom[0].kind == "article"
    _, json_items = parse_feed(JSON_FEED)
    assert (json_items[0].title, json_items[0].link) == ("Kestrel lands", "https://orbit.example/1")
    _, papers = parse_feed(ARXIV, source_type="arxiv")
    assert papers[0].kind == "paper" and papers[0].text == "We study things."


def test_hostile_feeds_are_refused() -> None:
    with pytest.raises(UnsafeFeed):
        parse_feed(b'<?xml version="1.0"?><!DOCTYPE r [<!ENTITY a "aaaa">]><rss><channel><item><title>&a;</title></item></channel></rss>')
    with pytest.raises(UnsafeFeed):
        parse_feed(b"this is not a feed at all")


def test_plain_text_caps_and_collapses() -> None:
    assert plain_text("<p>a   b</p><p>c</p>") == "a b\nc"
    assert len(plain_text("x" * 10_000)) == 4000


# ── Fetcher ──────────────────────────────────────────────────────────────────


def _fetcher(handler, *, addresses=("93.184.216.34",)) -> tuple[Fetcher, list[float]]:
    slept: list[float] = []
    clock = iter(range(10_000)).__next__
    fetcher = Fetcher(
        httpx.Client(transport=httpx.MockTransport(handler)),
        resolver=lambda host, port: list(addresses),
        clock=lambda: float(clock()) * 0.1,
        sleep=slept.append,
    )
    return fetcher, slept


def test_fetch_sends_conditional_headers_and_reads_304() -> None:
    seen = {}

    def handler(request: httpx.Request) -> httpx.Response:
        seen.update(request.headers)
        return httpx.Response(304)

    fetcher, _ = _fetcher(handler)
    result = fetcher.fetch("https://feeds.example/rss", etag='"v1"', last_modified="Fri, 30 Oct 2026 09:00:00 GMT")
    assert result.status == 304
    assert seen["if-none-match"] == '"v1"' and "OSMS" in seen["user-agent"]


def test_redirects_are_rechecked_every_hop() -> None:
    def handler(request: httpx.Request) -> httpx.Response:
        if request.url.host == "feeds.example":
            return httpx.Response(301, headers={"location": "http://169.254.169.254/latest/meta-data"})
        return httpx.Response(200, content=b"secret")

    fetcher, _ = _fetcher(handler)
    with pytest.raises(UnsafeUrl):
        fetcher.fetch("https://feeds.example/rss")


def test_a_public_name_that_resolves_privately_is_refused() -> None:
    fetcher, _ = _fetcher(lambda r: httpx.Response(200, content=b"x"), addresses=("10.0.0.5",))
    with pytest.raises(UnsafeUrl):
        fetcher.fetch("https://intranet.example/rss")


def test_too_many_requests_carries_retry_after_and_big_bodies_stop() -> None:
    fetcher, _ = _fetcher(lambda r: httpx.Response(429, headers={"retry-after": "120"}))
    with pytest.raises(FetchError) as caught:
        fetcher.fetch("https://feeds.example/rss")
    assert caught.value.retry_after_s == 120
    fetcher, _ = _fetcher(lambda r: httpx.Response(200, content=b"x" * 6_000_000))
    with pytest.raises(FetchError, match="over"):
        fetcher.fetch("https://feeds.example/big")


def test_arxiv_gets_three_seconds_between_requests() -> None:
    fetcher, slept = _fetcher(lambda r: httpx.Response(200, content=ARXIV))
    fetcher.fetch("https://rss.arxiv.org/rss/cs.CL")
    fetcher.fetch("https://rss.arxiv.org/rss/cs.AI")
    assert slept and slept[0] == pytest.approx(2.9, abs=0.01)


# ── Scheduler and queue ──────────────────────────────────────────────────────


def test_interval_is_half_the_usual_gap_clamped() -> None:
    start = datetime(2026, 10, 30, tzinfo=UTC)
    hourly = [start + timedelta(hours=h) for h in range(6)]
    assert scheduler.interval_from(hourly, None) == timedelta(minutes=30)
    every_minute = [start + timedelta(minutes=m) for m in range(6)]
    assert scheduler.interval_from(every_minute, None) == scheduler.MIN_INTERVAL
    assert scheduler.interval_from(hourly, ttl_minutes=60) == timedelta(hours=1)


def test_arxiv_runs_once_a_day_after_its_update_and_errors_back_off() -> None:
    now = datetime(2026, 10, 30, 12, 0, tzinfo=UTC)
    arxiv = Source(type="arxiv", title="cs.CL", feed_url="https://rss.arxiv.org/rss/cs.CL", fetch_interval_s=3600, error_count=0)
    scheduler.after_success(arxiv, now)
    assert arxiv.next_fetch_at == datetime(2026, 10, 31, 5, 15, tzinfo=UTC)
    feed = Source(type="feed", title="x", feed_url="https://x.example/rss", fetch_interval_s=3600, error_count=0)
    scheduler.after_error(feed, now, "boom")
    scheduler.after_error(feed, now, "boom", retry_after_s=99_999)
    assert feed.error_count == 2 and feed.next_fetch_at == now + timedelta(seconds=99_999)
    scheduler.after_success(feed, now, rng=random.Random(1))
    assert feed.error_count == 0 and feed.last_error is None


def test_only_followed_or_demo_sources_are_due(memory_db) -> None:
    now = datetime(2026, 10, 30, tzinfo=UTC)
    db = memory_db
    followed = Source(type="feed", title="a", feed_url="https://a.example/rss")
    seeded = Source(type="feed", title="b", feed_url="https://b.example/rss")
    orphan = Source(type="feed", title="c", feed_url="https://c.example/rss")
    later = Source(type="feed", title="d", feed_url="https://d.example/rss", next_fetch_at=now + timedelta(hours=1))
    db.add_all([followed, seeded, orphan, later, User(id="u", email="u@users.example"), Topic(id="t", name="T")])
    db.flush()
    db.add_all([Subscription(user_id="u", source_id=followed.id), TopicSource(topic_id="t", source_id=seeded.id)])
    db.add(Subscription(user_id="u", source_id=later.id))
    db.commit()
    assert {s.title for s in scheduler.due_sources(db, now)} == {"a", "b"}


def test_queue_dedupes_retries_with_backoff_and_survives_restarts(memory_db) -> None:
    db = memory_db
    assert jobs.enqueue(db, "fetch-source", 1) and not jobs.enqueue(db, "fetch-source", 1)
    db.commit()
    now = datetime.now(UTC) + timedelta(seconds=1)
    job = jobs.claim_next(db, now)
    assert job.status == "running" and job.attempts == 1
    assert jobs.requeue_running(db) == 1
    job = jobs.claim_next(db, now)
    jobs.fail(db, job, "boom", now)
    assert job.status == "queued" and job.run_after.replace(tzinfo=UTC) > now
    for _ in range(jobs.MAX_ATTEMPTS):
        job.run_after = now
        db.commit()
        job = jobs.claim_next(db, now) or job
        jobs.fail(db, job, "boom", now)
    assert db.get(Job, job.id).status == "failed"


# ── Language, names, triage ──────────────────────────────────────────────────


def test_language_by_words_script_or_the_feed() -> None:
    assert detect("Prisen er 7.999 kr. og telefonen kommer til Danmark i næste uge") == "da"
    assert detect("The price is $999 and the phone comes to the US next week") == "en"
    assert detect("விலை 999 டாலர்") == "ta"
    assert detect("Lumen Fold", "da-DK") == "da"


def test_names_skip_ordinary_capitalised_words() -> None:
    found = names("Samsung præsenterer Galaxy S26 Ultra", "Telefonen fra Samsung har en ny chip fra Qualcomm.")
    assert {"samsung", "galaxy", "s26", "qualcomm"} <= set(found) and "telefonen" not in found
    title_case = names("Apple Unveils New iPhone With Bigger Battery", "Apple said the iPhone 18 ships in March.")
    assert {"apple", "iphone", "18"} & set(title_case) and "bigger" not in title_case and "battery" not in title_case


def test_rule_three_and_noise_are_dropped_with_a_reason() -> None:
    assert prefilter("Minister wants new rules for AI", "") .startswith("rule 3")
    assert prefilter("Folketinget vedtager lov", "").startswith("rule 3")
    assert prefilter("Deals: save on headphones", "").startswith("noise")
    assert prefilter("Lumen Fold launches at $999", "The phone ships in November.") is None
