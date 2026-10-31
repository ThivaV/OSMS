"""When each source is checked (AGENTS.md, *Staying up to date*).

A source is fetched while someone follows it, or the demo does (every seed source).
Each has its own rhythm: about half its usual gap between items, between 5 minutes and
6 hours, with ±10% jitter so sources don't all fire together. arXiv runs once a day,
just after its feeds update. Errors back off, doubling up to a day, and are never a
reason to drop a source silently."""

import itertools
import random
import statistics
from collections.abc import Sequence
from datetime import UTC, datetime, time, timedelta

from sqlalchemy import or_, select
from sqlalchemy.orm import Session

from app.db.models import Interest, Source, Subscription, TopicSource

MIN_INTERVAL = timedelta(minutes=5)
MAX_INTERVAL = timedelta(hours=6)
MAX_BACKOFF = timedelta(days=1)
#: arXiv's feeds update at midnight US Eastern, about 05:00 UTC.
ARXIV_DAILY_AT = time(5, 15, tzinfo=UTC)


def _aware(moment: datetime | None) -> datetime | None:
    # SQLite hands back naive datetimes; everything OSMS stores is UTC.
    return moment.replace(tzinfo=UTC) if moment is not None and moment.tzinfo is None else moment


def followed_sources(db: Session) -> list[Source]:
    """Sources someone follows, the demo's (every seed source), and the arXiv searches
    of everyone's research interests."""
    followed = select(Subscription.source_id)
    seeded = select(TopicSource.source_id)
    searches = select(Interest.query_url).where(Interest.query_url.is_not(None))
    return list(
        db.scalars(select(Source).where(or_(Source.id.in_(followed), Source.id.in_(seeded), Source.feed_url.in_(searches))))
    )


def due_sources(db: Session, now: datetime) -> list[Source]:
    due = [s for s in followed_sources(db) if s.next_fetch_at is None or _aware(s.next_fetch_at) <= now]
    return sorted(due, key=lambda s: _aware(s.next_fetch_at) or datetime.min.replace(tzinfo=UTC))


def _jitter(interval: timedelta, rng: random.Random) -> timedelta:
    return interval * rng.uniform(0.9, 1.1)


def next_arxiv_run(now: datetime) -> datetime:
    today = datetime.combine(now.date(), ARXIV_DAILY_AT)
    return today if now < today else today + timedelta(days=1)


def interval_from(published: Sequence[datetime], ttl_minutes: int | None) -> timedelta:
    """Half the source's median gap between recent items, clamped; never under its TTL."""
    times = sorted(_aware(t) for t in published if t is not None)[-20:]
    gaps = [(later - earlier).total_seconds() for earlier, later in itertools.pairwise(times) if later > earlier]
    interval = timedelta(seconds=statistics.median(gaps) / 2) if gaps else timedelta(hours=1)
    if ttl_minutes:
        interval = max(interval, timedelta(minutes=ttl_minutes))
    return min(max(interval, MIN_INTERVAL), MAX_INTERVAL)


def after_success(
    source: Source,
    now: datetime,
    *,
    published: Sequence[datetime] = (),
    ttl_minutes: int | None = None,
    rng: random.Random | None = None,
) -> None:
    rng = rng or random.Random()
    source.last_fetched_at, source.error_count, source.last_error = now, 0, None
    if source.type.startswith("arxiv"):  # category feeds and interest searches alike
        source.next_fetch_at = next_arxiv_run(now)
        return
    if published:
        source.fetch_interval_s = int(interval_from(published, ttl_minutes).total_seconds())
    source.next_fetch_at = now + _jitter(timedelta(seconds=source.fetch_interval_s), rng)


def after_error(source: Source, now: datetime, error: str, *, retry_after_s: float | None = None) -> None:
    source.error_count += 1
    source.last_error = error[:500]
    backoff = min(timedelta(seconds=source.fetch_interval_s) * 2**source.error_count, MAX_BACKOFF)
    if retry_after_s:
        backoff = max(backoff, timedelta(seconds=retry_after_s))
    source.next_fetch_at = now + backoff
