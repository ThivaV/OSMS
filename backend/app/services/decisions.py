"""How OSMS decided: the agent runs behind one story, oldest first, each with the model
that decided (and any backup), what it said, and what it changed, read from the story's
own history. Only runs about the story and its items: runs about a reader (ask, editor,
briefing) carry no subject and never show here."""

from collections import Counter
from datetime import UTC, datetime, timedelta

from sqlalchemy import or_, select
from sqlalchemy.orm import Session

from app.db.models import AgentRun, AgentStep, Claim, Item, Story, StorySummary
from app.schemas.decisions import DecisionOut

MAX_RUNS = 200


def _aware(moment: datetime) -> datetime:
    return moment.replace(tzinfo=UTC) if moment.tzinfo is None else moment


def _facts_outcome(claims: list[Claim]) -> str:
    if not claims:
        return "No facts"
    counts = Counter("corrects" if c.relation == "corrects" and c.status == "kept" else c.status for c in claims)
    words = {"kept": "kept", "corrects": "a correction", "repeat": "repeated", "dropped": "dropped", "proposed": "waiting"}
    return ", ".join(f"{n} {words.get(k, k)}" for k, n in counts.items())


def story_decisions(db: Session, story_id: int) -> list[DecisionOut]:
    items = {i.id: i for i in db.scalars(select(Item).where(Item.story_id == story_id))}
    subjects = [f"story:{story_id}", *(f"item:{i}" for i in items)]
    runs = list(
        db.scalars(
            select(AgentRun)
            .where(AgentRun.subject.in_(subjects), AgentRun.status != "running")
            .order_by(AgentRun.started_at, AgentRun.id)
            .limit(MAX_RUNS)
        )
    )
    reasons = {}
    for step in db.scalars(select(AgentStep).where(AgentStep.run_id.in_([r.id for r in runs])).order_by(AgentStep.position)):
        reasons[step.run_id] = step.reason or reasons.get(step.run_id)
    claims_by_item: dict[int, list[Claim]] = {}
    for claim in db.scalars(select(Claim).where(or_(Claim.story_id == story_id, Claim.item_id.in_(items)))):
        claims_by_item.setdefault(claim.item_id, []).append(claim)
    summaries = list(db.scalars(select(StorySummary).where(StorySummary.story_id == story_id).order_by(StorySummary.id)))

    out = []
    for run in runs:
        kind, _, ref = (run.subject or "").partition(":")
        item = items.get(int(ref)) if kind == "item" and ref.isdigit() else None
        outcome = None
        if run.status != "ok":
            outcome = "Didn't decide: " + (run.stop_reason or "failed")
        elif run.agent == "triage" and item is not None:
            outcome = "Dropped: " + item.drop_reason if item.status == "dropped" and item.drop_reason else "Kept"
        elif run.agent == "claims" and item is not None:
            found = len(claims_by_item.get(item.id, []))
            outcome = f"{found} fact{'s' if found != 1 else ''} found"
        elif run.agent == "verifier" and item is not None:
            outcome = _facts_outcome(claims_by_item.get(item.id, []))
        elif run.agent == "illustration":
            record = db.get(Story, story_id).illustration or {}
            outcome = "Illustrated" if record.get("status") == "ready" else "Kept the drawn art"
        elif run.agent == "writer":
            started, ended = _aware(run.started_at), _aware(run.ended_at or run.started_at) + timedelta(seconds=5)
            written = next((s for s in summaries if started <= _aware(s.created_at) <= ended), None)
            outcome = f"Wrote “{written.title}”" if written else "Nothing new to write"
        ended = _aware(run.ended_at) if run.ended_at else None
        out.append(
            DecisionOut(
                id=str(run.id),
                agent=run.agent,
                model=run.model,
                fallback=run.fallback,
                prompt_version=run.prompt_version,
                at=_aware(run.started_at),
                latency_ms=int((ended - _aware(run.started_at)).total_seconds() * 1000) if ended else None,
                input_tokens=run.input_tokens,
                output_tokens=run.output_tokens,
                about=(item.title or item.text[:120]) if item else None,
                source=item.source.title if item else None,
                reason=reasons.get(run.id) or None,
                outcome=outcome,
            )
        )
    return out
