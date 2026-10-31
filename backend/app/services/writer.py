"""The writer agent (Muse Spark, no backup): a story's own title and cited summary,
rewritten when its kept facts change. Never overwritten: each version is a new row,
and the newest is the one readers see. Code drops any sentence that cites nothing the
story has kept."""

from datetime import UTC, datetime

from pydantic import BaseModel, ConfigDict, Field
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.agent.kit import AgentKit
from app.agent.prompts import load
from app.db.models import Claim, Story, StorySummary
from app.services.verifier import current_claims


class PointOut(BaseModel):
    model_config = ConfigDict(extra="ignore")

    text: str = Field(min_length=1, max_length=400)
    claim_ids: list[int] = Field(min_length=1, max_length=8)


class WriterOut(BaseModel):
    model_config = ConfigDict(extra="ignore", title="story_summary")

    title: str = Field(min_length=1, max_length=160)
    points: list[PointOut] = Field(default_factory=list, max_length=6)


def latest_summary(db: Session, story_id: int) -> StorySummary | None:
    return db.scalar(
        select(StorySummary).where(StorySummary.story_id == story_id).order_by(StorySummary.id.desc()).limit(1)
    )


def _facts(claims: list[Claim]) -> str:
    return "\n".join(
        f"id {c.id}. {c.statement} | source: {c.item.source.title} | reported {c.item.published_at:%Y-%m-%d %H:%M} UTC"
        for c in claims
    )


def write(db: Session, kit: AgentKit, story: Story) -> StorySummary | None:
    """A new summary for the story, or None when nothing changed or the writer couldn't run."""
    facts = [c for c in current_claims(db, story.id) if c.status == "kept"]
    if not facts or not kit.can("writer"):
        return None
    previous = latest_summary(db, story.id)
    cited = {i for p in (previous.points if previous else []) for i in p.get("claim_ids", [])}
    if previous and {c.id for c in facts} <= cited:
        return None  # Every fact is already told.
    prompt = load("writer")
    result = kit.runner.call_once(
        kit.spec("writer", prompt_version=prompt.version, max_steps=2, token_budget=12_000, subject=f"story:{story.id}"),
        system=prompt.text,
        user=f"<facts>\n{_facts(facts)}\n</facts>\n\nPrevious title: {previous.title if previous else '(none)'}",
        schema=WriterOut,
    )
    if result.status != "ok" or result.value is None:
        return None
    out = WriterOut.model_validate(result.value)
    known = {c.id for c in facts}
    points = [
        {"text": p.text.strip(), "claim_ids": ids}
        for p in out.points
        if (ids := [i for i in p.claim_ids if i in known])
    ]
    if not points:
        return None
    summary = StorySummary(
        story_id=story.id,
        title=out.title.strip(),
        points=points,
        model=kit.served_by("writer", result),
        prompt_version=prompt.version,
        created_at=datetime.now(UTC),
    )
    db.add(summary)
    db.flush()
    return summary
