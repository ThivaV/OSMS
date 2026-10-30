"""The jobs queue in SQLite: what the worker does next. A restart loses nothing (running
jobs go back to the queue), failures retry with backoff, and the same work is never
queued twice."""

from datetime import UTC, datetime, timedelta

from sqlalchemy import select, update
from sqlalchemy.orm import Session

from app.db.models import Job

MAX_ATTEMPTS = 5
BASE_BACKOFF = timedelta(seconds=30)


def enqueue(db: Session, kind: str, ref: object, *, run_after: datetime | None = None) -> bool:
    """Queue `kind` for `ref` unless it is already queued or running. True if queued."""
    ref = str(ref)
    exists = db.scalar(
        select(Job.id).where(Job.kind == kind, Job.ref == ref, Job.status.in_(("queued", "running"))).limit(1)
    )
    if exists:
        return False
    now = datetime.now(UTC)
    db.add(Job(kind=kind, ref=ref, run_after=run_after or now, created_at=now, updated_at=now))
    return True


def claim_next(db: Session, now: datetime) -> Job | None:
    """The oldest due job, marked running."""
    job = db.scalar(
        select(Job).where(Job.status == "queued", Job.run_after <= now).order_by(Job.run_after, Job.id).limit(1)
    )
    if job is None:
        return None
    job.status, job.attempts, job.updated_at = "running", job.attempts + 1, now
    db.commit()
    return job


def finish(db: Session, job: Job) -> None:
    job.status, job.updated_at, job.last_error = "done", datetime.now(UTC), None
    db.commit()


def fail(db: Session, job: Job, error: str, now: datetime) -> None:
    """Retry later with doubling backoff; after MAX_ATTEMPTS the job stays failed."""
    job.last_error = error[:2000]
    job.updated_at = now
    if job.attempts >= MAX_ATTEMPTS:
        job.status = "failed"
    else:
        job.status = "queued"
        job.run_after = now + BASE_BACKOFF * 2 ** (job.attempts - 1)
    db.commit()


def requeue_running(db: Session) -> int:
    """After a crash or restart: what was running goes back to the queue."""
    result = db.execute(update(Job).where(Job.status == "running").values(status="queued"))
    db.commit()
    return result.rowcount or 0


def prune_done(db: Session, older_than: timedelta = timedelta(days=2)) -> None:
    db.query(Job).filter(Job.status == "done", Job.updated_at < datetime.now(UTC) - older_than).delete()
    db.commit()
