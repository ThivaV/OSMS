"""The verifier agent (Muse Spark; Muse Spark Open as backup), the critic before publish:
nothing reaches a reader as new or as a disagreement until it keeps it. Unsure cases run
again at maximum reasoning effort.

Code enforces what the model may claim: a correction only replaces the same source's
earlier fact, a disagreement needs two different sources, and every relation must point
at a fact the story really has. The story's history is never overwritten: a correction
supersedes the old fact, which stays, struck through, in the timeline."""

from datetime import UTC, datetime
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.agent.kit import AgentKit, quoted_item
from app.agent.prompts import load
from app.db.models import Claim, Disagreement, Item

Relation = Literal["new", "repeat", "corrects", "conflicts"]


class VerdictOut(BaseModel):
    model_config = ConfigDict(extra="ignore")

    candidate: int
    keep: bool
    relation: Relation = "new"
    related: int | None = None
    sure: bool = True
    reason: str = Field(default="", max_length=400)


class VerifierOut(BaseModel):
    model_config = ConfigDict(extra="ignore", title="verdicts")

    verdicts: list[VerdictOut] = Field(default_factory=list, max_length=12)


def current_claims(db: Session, story_id: int) -> list[Claim]:
    """The story's kept facts, not superseded: what a candidate is compared with."""
    return list(
        db.scalars(
            select(Claim)
            .where(Claim.story_id == story_id, Claim.status.in_(("kept", "repeat")), Claim.superseded_at.is_(None))
            .order_by(Claim.id)
        )
    )


def _user_message(item: Item, candidates: list[Claim], existing: list[Claim]) -> str:
    lines = [
        quoted_item(
            "item",
            source=item.source.title,
            language=item.language,
            published=item.published_at,
            title=item.title,
            text=item.text,
        ),
        "",
        "<candidates>",
    ]
    for n, c in enumerate(candidates):
        lines.append(f"{n}. {c.statement} | subject: {c.subject} | value: {c.value or '-'} | quote: {c.quote!r}")
    lines += ["</candidates>", "", "<existing_facts>"]
    for e in existing:
        lines.append(
            f"id {e.id}. {e.statement} | subject: {e.subject} | value: {e.value or '-'} | source: {e.item.source.title}"
        )
    lines.append("</existing_facts>")
    return "\n".join(lines)


def _ask(kit: AgentKit, item: Item, candidates: list[Claim], existing: list[Claim], *, effort: str | None) -> dict[int, VerdictOut] | None:
    prompt = load("verifier")
    result = kit.runner.call_once(
        kit.spec("verifier", effort=effort, prompt_version=prompt.version, max_steps=2, token_budget=16_000),
        system=prompt.text,
        user=_user_message(item, candidates, existing),
        schema=VerifierOut,
    )
    if result.status != "ok" or result.value is None:
        return None
    verdicts = VerifierOut.model_validate(result.value).verdicts
    return {v.candidate: v for v in verdicts if 0 <= v.candidate < len(candidates)}


def verify(db: Session, kit: AgentKit, item: Item, candidates: list[Claim]) -> bool:
    """Decide every candidate of one item. False when the verifier couldn't run (the
    candidates stay proposed and are tried again)."""
    if not candidates:
        return True
    if not kit.can("verifier"):
        return False
    existing = [e for e in current_claims(db, item.story_id) if e.item_id != item.id or e.status == "kept"]
    verdicts = _ask(kit, item, candidates, existing, effort=None)
    if verdicts is None:
        return False
    unsure = [n for n, v in verdicts.items() if not v.sure]
    if unsure:
        again = _ask(kit, item, [candidates[n] for n in unsure], existing, effort="max")
        for k, n in enumerate(unsure):
            if again and k in again:
                verdicts[n] = again[k].model_copy(update={"candidate": n})
    by_id = {e.id: e for e in existing}
    now = datetime.now(UTC)
    for n, claim in enumerate(candidates):
        verdict = verdicts.get(n)
        if verdict is None or not verdict.keep or (not verdict.sure and n in unsure):
            claim.status, claim.verifier_reason = "dropped", (verdict.reason if verdict else "no verdict")
            continue
        related = by_id.get(verdict.related) if verdict.related is not None else None
        relation: str = verdict.relation if related is not None or verdict.relation == "new" else "new"
        same_source = related is not None and related.item.source_id == item.source_id
        if relation == "corrects" and not same_source:
            relation = "conflicts"  # Another source can't correct this one; it disagrees.
        if relation == "conflicts" and same_source:
            relation = "corrects"  # A source that changes its own figure is correcting it.
        claim.relation, claim.related_claim_id, claim.verifier_reason = relation, related.id if related else None, verdict.reason
        claim.status = "repeat" if relation == "repeat" else "kept"
        claim.kept_at = now
        if relation == "corrects" and related is not None:
            related.superseded_at, related.superseded_by = now, claim.id
        elif relation == "conflicts" and related is not None:
            db.add(
                Disagreement(
                    story_id=item.story_id,
                    claim_a_id=related.id,
                    claim_b_id=claim.id,
                    subject=claim.subject or related.subject,
                    note=verdict.reason,
                    created_at=now,
                )
            )
    db.flush()
    return True
