"""The worker: scheduled checks, the jobs queue, embeddings, clustering and the agents
that run as items arrive. One process, one job at a time, so SQLite has one writer for
the pipeline and Milvus Lite has the only process it allows.

    uv run python -m app.worker run            # keep going (make worker, Tilt's worker)
    uv run python -m app.worker once           # fetch what's due, drain the queue, stop
    uv run python -m app.worker fetch-now [ID] # every followed source now, or one
    uv run python -m app.worker claims-backlog # facts for clustered items without any (after adding a key)
    uv run python -m app.worker status         # what's queued, stored and clustered
    uv run python -m app.worker export-predictions FILE  # {item_id: story_id} for the eval
"""

import argparse
import json
import sys
import time
import traceback
from datetime import UTC, datetime
from pathlib import Path

from sqlalchemy import func, select
from sqlalchemy.orm import Session, sessionmaker

from app.agent.decision_log import DecisionLog
from app.agent.kit import AgentKit
from app.agent.runtime import Runner
from app.clients.openai_compat import models_from_settings
from app.config import SEED_OPML, Settings
from app.db.milvus import VectorIndex
from app.db.models import Claim, Item, Job, Source, Story
from app.db.sqlite import make_engine, migrate, session_factory
from app.services import jobs
from app.services.claims import FACT_KINDS
from app.services.embeddings import BgeM3Embedder
from app.services.ingestion import scheduler
from app.services.ingestion.fetcher import Fetcher
from app.services.ingestion.opml import load_seed
from app.services.pipeline import Pipeline

IDLE_SLEEP_S = 5.0


def build(settings: Settings) -> tuple[sessionmaker[Session], Pipeline]:
    migrate(settings.database_url)
    sessions = session_factory(make_engine(settings.database_url))
    with sessions() as db:
        load_seed(db, SEED_OPML)
    models = models_from_settings(settings)
    # The decision log commits on its own session, so a failed job never half-commits.
    runner = Runner(models, DecisionLog(sessions()))
    kit = AgentKit(runner=runner, routes=dict(models.routes), available={a: models.available(a) for a in models.routes})
    pipeline = Pipeline(
        fetcher=Fetcher(),
        embedder_factory=BgeM3Embedder,
        index_factory=lambda dim: VectorIndex(settings.milvus_uri, dim=dim),
        kit=kit,
    )
    return sessions, pipeline


def schedule_due(db: Session, now: datetime) -> int:
    queued = sum(jobs.enqueue(db, "fetch-source", s.id) for s in scheduler.due_sources(db, now))
    db.commit()
    return queued


def drain(sessions: sessionmaker[Session], pipeline: Pipeline, *, limit: int | None = None, log=print) -> int:
    """Run due jobs until none are left (or `limit`). Returns how many ran."""
    ran = 0
    while limit is None or ran < limit:
        with sessions() as db:
            job = jobs.claim_next(db, datetime.now(UTC))
            if job is None:
                return ran
            kind, ref, job_id = job.kind, job.ref, job.id
        started = time.monotonic()
        try:
            with sessions() as db:
                pipeline.handle(db, kind, ref)
            with sessions() as db:
                jobs.finish(db, db.get(Job, job_id))
            log(f"{kind} {ref}: done in {time.monotonic() - started:.1f}s")
        except Exception as error:  # noqa: BLE001 — a failed job is retried, never fatal
            with sessions() as db:
                jobs.fail(db, db.get(Job, job_id), f"{type(error).__name__}: {error}", datetime.now(UTC))
            log(f"{kind} {ref}: failed: {type(error).__name__}: {error}")
            if not isinstance(error, (OSError, RuntimeError)):
                traceback.print_exc()
        ran += 1
    return ran


def status(db: Session) -> dict[str, object]:
    def count(*where):
        return db.scalar(select(func.count()).select_from(Item).where(*where)) or 0

    return {
        "sources": db.scalar(select(func.count()).select_from(Source)),
        "failing_sources": db.scalar(select(func.count()).select_from(Source).where(Source.error_count > 0)),
        "items": count(),
        "dropped": count(Item.status == "dropped"),
        "indexed": count(Item.vector_status == "indexed"),
        "in_stories": count(Item.story_id.is_not(None)),
        "stories": db.scalar(select(func.count()).select_from(Story)),
        "stories_with_2_plus_items": db.scalar(
            select(func.count()).select_from(
                select(Item.story_id).where(Item.story_id.is_not(None)).group_by(Item.story_id).having(func.count() > 1).subquery()
            )
        ),
        "kept_facts": db.scalar(select(func.count()).select_from(Claim).where(Claim.status == "kept")),
        "jobs": dict(db.execute(select(Job.status, func.count()).group_by(Job.status)).all()),
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(prog="python -m app.worker", description=__doc__.splitlines()[0])
    sub = parser.add_subparsers(dest="command", required=True)
    sub.add_parser("run")
    sub.add_parser("once")
    fetch = sub.add_parser("fetch-now")
    fetch.add_argument("source_id", nargs="?", type=int)
    sub.add_parser("claims-backlog")
    sub.add_parser("status")
    export = sub.add_parser("export-predictions")
    export.add_argument("path", type=Path)
    args = parser.parse_args(argv)

    settings = Settings()
    sessions, pipeline = build(settings)
    if args.command == "status":
        with sessions() as db:
            print(json.dumps(status(db), indent=2, default=str))
        return 0
    if args.command == "export-predictions":
        with sessions() as db:
            rows = db.execute(select(Item.id, Item.story_id).where(Item.story_id.is_not(None))).all()
        args.path.write_text(json.dumps({str(i): str(s) for i, s in rows}, indent=1))
        print(f"wrote {len(rows)} predictions to {args.path}")
        return 0
    if args.command == "fetch-now":
        with sessions() as db:
            sources = [db.get(Source, args.source_id)] if args.source_id else scheduler.followed_sources(db)
            queued = sum(jobs.enqueue(db, "fetch-source", s.id) for s in sources if s is not None)
            db.commit()
        print(f"queued {queued} fetches; the worker runs them")
        return 0
    if args.command == "claims-backlog":
        with sessions() as db:
            have = select(Claim.item_id)
            ids = db.scalars(
                select(Item.id).where(Item.story_id.is_not(None), Item.kind.in_(FACT_KINDS), Item.id.not_in(have))
            ).all()
            queued = sum(jobs.enqueue(db, "claims-item", i) for i in ids)
            db.commit()
        print(f"queued {queued} items for facts")
        return 0
    with sessions() as db:
        jobs.requeue_running(db)
    if args.command == "once":
        with sessions() as db:
            schedule_due(db, datetime.now(UTC))
        ran = drain(sessions, pipeline)
        with sessions() as db:
            print(json.dumps(status(db), indent=2, default=str))
        print(f"ran {ran} jobs")
        return 0
    print("worker running; Ctrl+C to stop")
    while True:
        with sessions() as db:
            schedule_due(db, datetime.now(UTC))
        if drain(sessions, pipeline, limit=50) == 0:
            time.sleep(IDLE_SLEEP_S)


if __name__ == "__main__":
    sys.exit(main())
