"""The judge agent (Muse Spark Open; Muse Spark as backup): are two similar items the
same event? Asked only for pairs the clustering rule can't settle on its own."""

from pydantic import BaseModel, ConfigDict, Field

from app.agent.kit import AgentKit, quoted_item
from app.agent.prompts import load
from app.db.models import Item


class JudgeVerdict(BaseModel):
    model_config = ConfigDict(extra="ignore", title="judge_verdict")

    same_event: bool
    reason: str = Field(max_length=400)


def _quoted(label: str, item: Item) -> str:
    return quoted_item(
        label,
        source=item.source.title,
        language=item.language,
        published=item.published_at,
        title=item.title,
        text=item.text,
        limit=900,
    )


def same_event(kit: AgentKit, a: Item, b: Item) -> bool | None:
    """True or False from the judge; None when it couldn't answer (unavailable or failed).
    The caller treats None as "not sure": they stay apart."""
    if not kit.can("judge"):
        return None
    prompt = load("judge")
    result = kit.runner.call_once(
        kit.spec("judge", prompt_version=prompt.version, max_steps=2, token_budget=6_000),
        system=prompt.text,
        user=f"{_quoted('A', a)}\n\n{_quoted('B', b)}",
        schema=JudgeVerdict,
    )
    if result.status != "ok" or result.value is None:
        return None
    return bool(result.value["same_event"])
