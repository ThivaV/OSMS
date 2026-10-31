"""The claims agent (Muse Spark; Muse Spark Open as backup): the facts an article or
episode reports, each with the quote it rests on, in the source's own language, plus an
English translation when the source wrote in another language ("Translated by OSMS").

Code checks every quote against the item before keeping the claim as a candidate: a
quote the item doesn't contain is a claim the item doesn't make."""

import re
import unicodedata
from datetime import UTC, datetime

from pydantic import BaseModel, ConfigDict, Field
from sqlalchemy.orm import Session

from app.agent.kit import AgentKit, quoted_item
from app.agent.prompts import load
from app.db.models import Claim, Item

#: Kinds whose items carry facts. Posts and videos are reactions, never facts; papers
#: wait for paper labels in the eval (AGENTS.md, *Source types*).
FACT_KINDS = frozenset({"article", "episode"})


class ClaimOut(BaseModel):
    model_config = ConfigDict(extra="ignore")

    statement: str = Field(min_length=1, max_length=400)
    subject: str = Field(default="", max_length=120)
    value: str | None = Field(default=None, max_length=120)
    quote: str = Field(min_length=1, max_length=600)
    translation: str | None = Field(default=None, max_length=800)


class ClaimsOut(BaseModel):
    model_config = ConfigDict(extra="ignore", title="claims")

    claims: list[ClaimOut] = Field(default_factory=list, max_length=6)


def _normal(text: str) -> str:
    text = unicodedata.normalize("NFKC", text).casefold()
    text = re.sub(r"[‘’‚‛′]", "'", text)
    text = re.sub(r"[“”„‟″]", '"', text)
    return re.sub(r"\s+", " ", text).strip()


def quote_in_item(quote: str, item: Item) -> bool:
    return _normal(quote) in _normal(f"{item.title}\n{item.text}")


def extract(db: Session, kit: AgentKit, item: Item) -> list[Claim] | None:
    """Candidate claims for the item, stored as `proposed`. None when the agent couldn't run."""
    if item.kind not in FACT_KINDS or item.story_id is None:
        return []
    if not kit.can("claims"):
        return None
    prompt = load("claims")
    result = kit.runner.call_once(
        kit.spec("claims", prompt_version=prompt.version, max_steps=2, token_budget=12_000, subject=f"item:{item.id}"),
        system=prompt.text,
        user=quoted_item(
            "item",
            source=item.source.title,
            language=item.language,
            published=item.published_at,
            title=item.title,
            text=item.text,
        ),
        schema=ClaimsOut,
    )
    if result.status != "ok" or result.value is None:
        return None
    now = datetime.now(UTC)
    model = kit.served_by("claims", result)
    claims = []
    for out in ClaimsOut.model_validate(result.value).claims:
        if not quote_in_item(out.quote, item):
            continue  # Not in the item: the item doesn't say it.
        claim = Claim(
            story_id=item.story_id,
            item_id=item.id,
            statement=out.statement.strip(),
            subject=out.subject.strip(),
            value=(out.value or "").strip() or None,
            quote=out.quote.strip(),
            quote_language=item.language,
            translation=(out.translation or "").strip() or None if item.language != "en" else None,
            status="proposed",
            model=model,
            prompt_version=prompt.version,
            created_at=now,
        )
        db.add(claim)
        claims.append(claim)
    db.flush()
    return claims
