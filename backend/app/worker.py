"""The worker: scheduled checks, the jobs queue, embeddings, clustering and the agents
that run as items arrive. One process, one job at a time, so SQLite has one writer for
the pipeline and Milvus Lite has the only process it allows.

    uv run python -m app.worker run            # keep going (make worker, Tilt's worker)
    uv run python -m app.worker once           # fetch what's due, drain the queue, stop
    uv run python -m app.worker fetch-now [ID] # every followed source now, or one
    uv run python -m app.worker claims-backlog [--min-sources 2]  # facts for items without any (after adding a key)
    uv run python -m app.worker briefing [--reader ID]  # the demo's briefing now, or a reader's
    uv run python -m app.worker illustrations-backlog [--limit 10]  # stories that earned one
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
from app.clients.meta_media import MetaMedia
from app.clients.meta_voice import Transcriber
from app.clients.openai_compat import local_model_ready, models_from_settings, triage_escalation
from app.config import GLIMMER_MODEL, SEED_OPML, Settings
from app.db.milvus import VectorIndex
from app.db.models import Briefing, Claim, Item, Job, Source, Story, StorySummary, User
from app.db.sqlite import make_engine, migrate, session_factory
from app.services import interests as research
from app.services import jobs, visuals
from app.services.claims import FACT_KINDS
from app.services.embeddings import BgeM3Embedder
from app.services.ingestion import scheduler
from app.services.ingestion.fetcher import Fetcher
from app.services.ingestion.opml import load_seed
from app.services.pipeline import Pipeline
from app.services.speech import MetaSpeech, SeamlessListener

IDLE_SLEEP_S = 5.0
#: The morning briefing is made from 06:00 UTC: 07:00 in Denmark in winter. Per reader
#: time zones come later.
BRIEFING_HOUR_UTC = 6


def build(settings: Settings) -> tuple[sessionmaker[Session], Pipeline]:
    migrate(settings.database_url)
    sessions = session_factory(make_engine(settings.database_url))
    with sessions() as db:
        load_seed(db, SEED_OPML)
        research.sync_all(db)
    models = models_from_settings(settings)
    # The decision log commits on its own session, so a failed job never half-commits.
    log = DecisionLog(sessions())
    available = {a: models.available(a) for a in models.routes}
    if available.get("triage") and settings.glimmer_base_url.startswith(("http://127.0.0.1", "http://localhost")):
        # Ollama stopped, or Muse Glimmer not pulled yet: the word list stands in.
        available["triage"] = local_model_ready(settings.glimmer_base_url, GLIMMER_MODEL)
    kit = AgentKit(runner=Runner(models, log), routes=dict(models.routes), available=available)
    unsure = triage_escalation(settings, models)
    escalation = AgentKit(runner=Runner(unsure, log), routes=dict(unsure.routes), available={"triage": unsure.available("triage")})
    print(f"triage: {'Muse Glimmer' if available.get('triage') else 'the word list'}"
          f"{', unsure items to Muse Spark' if escalation.can('triage') else ''}")
    pipeline = Pipeline(
        fetcher=Fetcher(),
        embedder_factory=BgeM3Embedder,
        index_factory=lambda dim: VectorIndex(settings.milvus_uri, dim=dim),
        kit=kit,
        escalation=escalation,
        voice_factory=MetaSpeech,
        checkers_factory=lambda voice: [
            *([Transcriber(settings.meta_api_key)] if settings.meta_api_key else []),
            SeamlessListener(voice),
        ],
        briefings_dir=settings.briefings_dir,
        media=MetaMedia(settings.meta_api_key) if settings.meta_api_key else None,
        visuals_dir=settings.visuals_dir,
    )
    return sessions, pipeline


def schedule_due(db: Session, now: datetime) -> int:
    queued = sum(jobs.enqueue(db, "fetch-source", s.id) for s in scheduler.due_sources(db, now))
    queued += schedule_briefings(db, now)
    db.commit()
    return queued


def schedule_briefings(db: Session, now: datetime) -> int:
    """Once a day from BRIEFING_HOUR_UTC: the demo's briefing and each onboarded reader's."""
    morning = now.replace(hour=BRIEFING_HOUR_UTC, minute=0, second=0, microsecond=0)
    if now < morning:
        return 0
    made = set(db.scalars(select(func.coalesce(Briefing.user_id, "demo")).where(Briefing.created_at >= morning)))
    tried = set(db.scalars(select(Job.ref).where(Job.kind == "make-briefing", Job.created_at >= morning)))
    readers = db.scalars(select(User.id).where(User.onboarded_at.is_not(None)))
    return sum(jobs.enqueue(db, "make-briefing", ref) for ref in ("demo", *readers) if ref not in made | tried)


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


def illustration_backlog(db: Session, limit: int) -> list[int]:
    """Stories with a summary and enough sources but no illustration tried yet, most
    sources first."""
    sources = func.count(func.distinct(Item.source_id))
    rows = db.execute(
        select(Story.id, sources)
        .join(Item, Item.story_id == Story.id)
        .where(Item.status != "dropped", Story.illustration.is_(None), Story.id.in_(select(StorySummary.story_id)))
        .group_by(Story.id)
        .having(sources >= visuals.ILLUSTRATE_AT_SOURCES)
        .order_by(sources.desc(), Story.id.desc())
        .limit(limit)
    ).all()
    return [story_id for story_id, _ in rows]


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
        "briefings": db.scalar(select(func.count()).select_from(Briefing)),
        "illustrated": db.scalar(select(func.count()).select_from(Story).where(Story.illustration.is_not(None))),
        "jobs": dict(db.execute(select(Job.status, func.count()).group_by(Job.status)).all()),
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(prog="python -m app.worker", description=__doc__.splitlines()[0])
    sub = parser.add_subparsers(dest="command", required=True)
    sub.add_parser("run")
    sub.add_parser("once")
    fetch = sub.add_parser("fetch-now")
    fetch.add_argument("source_id", nargs="?", type=int)
    backlog = sub.add_parser("claims-backlog")
    backlog.add_argument("--min-sources", type=int, default=1, help="only stories with at least this many items")
    drawings = sub.add_parser("illustrations-backlog")
    drawings.add_argument("--limit", type=int, default=10, help="at most this many (each is a few paid calls)")
    brief = sub.add_parser("briefing")
    brief.add_argument("--reader", help="a reader's id; the demo's briefing without it")
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
    if args.command == "illustrations-backlog":
        with sessions() as db:
            ids = illustration_backlog(db, args.limit)
            queued = sum(jobs.enqueue(db, "illustrate-story", i) for i in ids)
            db.commit()
        print(f"queued {queued} stories for illustrations")
        return 0
    if args.command == "briefing":
        with sessions() as db:
            queued = jobs.enqueue(db, "make-briefing", args.reader or "demo")
            db.commit()
        print("queued the briefing; the worker makes it" if queued else "a briefing is already queued")
        return 0
    if args.command == "claims-backlog":
        with sessions() as db:
            have = select(Claim.item_id)
            busy = (
                select(Item.story_id)
                .where(Item.story_id.is_not(None), Item.status != "dropped")
                .group_by(Item.story_id)
                .having(func.count() >= args.min_sources)
            )
            ids = db.scalars(
                select(Item.id).where(
                    Item.story_id.in_(busy), Item.kind.in_(FACT_KINDS), Item.id.not_in(have), Item.status != "dropped"
                )
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
