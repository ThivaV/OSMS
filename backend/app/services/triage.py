"""Triage: is an item inside rule 3, and is it noise? Which language, which names?

The triage agent (Muse Glimmer, local) checks every new item. What it is unsure about,
Muse Spark decides. The word list below is the fallback when neither can answer, and a
tripwire when they can: an item the agent keeps but the list calls political goes to
Muse Spark too. It errs on the side of dropping: a missed tech story costs less than a
political one shown.

Dropped items keep their reason and never reach clustering, claims or a reader."""

import re
from dataclasses import dataclass
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field

from app.agent.kit import AgentKit, quoted_item
from app.agent.prompts import load
from app.db.models import Item
from app.services.names import from_listed
from app.services.names import names as find_names

# Rule 3: nothing political, nothing involving war (English and Danish). Whole words…
_POLITICAL = (  # noqa: SIM905  (a word list reads better as words)
    "election elections electoral parliament parliamentary politician politicians "
    "political politics war wars warfare military troops missile missiles invasion "
    "ceasefire senator senators referendum folketinget folketingsvalg kommunalvalg valget "
    "valgkamp politiker politikere politisk politiske politik krig krigen krige militær "
    "militære militæret soldater missil missiler"
).split()
# …and stems that take endings: names ("Trumps", "Bidens"), ministers and governments.
_POLITICAL_STEMS = (  # noqa: SIM905  (a word list reads better as words)
    "trump biden putin netanyahu zelensk nato ukrain gaza hamas israel minist regering "
    "statsminist"
).split()
# Noise: adverts, giveaways and deal posts.
_NOISE = (  # noqa: SIM905  (a word list reads better as words)
    "sponsored giveaway giveaways deal deals coupon coupons annonce sponsoreret "
    "konkurrence tilbud rabatkode"
).split()

_POLITICAL_RE = re.compile(
    r"\b(" + "|".join(map(re.escape, _POLITICAL)) + r")\b|\b((?:" + "|".join(map(re.escape, _POLITICAL_STEMS)) + r")\w*)",
    re.IGNORECASE,
)
_NOISE_RE = re.compile(r"\b(" + "|".join(map(re.escape, _NOISE)) + r")\b", re.IGNORECASE)


def prefilter(title: str, text: str) -> str | None:
    """The reason to drop the item, or None to keep it."""
    words = f"{title}\n{text}"
    if match := _POLITICAL_RE.search(words):
        return f"rule 3: political ({(match.group(1) or match.group(2)).lower()!r})"
    if match := _NOISE_RE.search(title):
        return f"noise: {match.group(1).lower()!r} in the headline"
    return None


class TriageVerdict(BaseModel):
    model_config = ConfigDict(extra="ignore", title="triage_verdict")

    in_scope: bool
    noise: bool
    language: Literal["da", "en", "ta", "other"]
    names: list[str] = Field(default_factory=list, max_length=12)
    sure: bool
    reason: str = Field(max_length=400)


@dataclass(frozen=True)
class Triaged:
    drop_reason: str | None  # None keeps the item
    names: list[str]
    language: str | None  # None leaves the detected language
    decided_by: str  # the model, or "word list"


def _ask(kit: AgentKit | None, item: Item) -> TriageVerdict | None:
    if kit is None or not kit.can("triage"):
        return None
    prompt = load("triage")
    quoted = quoted_item(
        "ITEM",
        source=item.source.title,
        language=item.language,
        published=item.published_at,
        title=item.title,
        text=item.text,
        limit=1200,
    )
    result = kit.runner.call_once(
        kit.spec("triage", prompt_version=prompt.version, max_steps=2, token_budget=4_000, subject=f"item:{item.id}"),
        system=prompt.text,
        user=quoted,
        schema=TriageVerdict,
    )
    if result.status != "ok" or result.value is None:
        return None
    return TriageVerdict.model_validate(result.value)


def _from(verdict: TriageVerdict, item: Item, model: str) -> Triaged:
    drop = None
    if verdict.noise:  # An advert is noise first, whatever else it is.
        drop = f"noise ({model}): {verdict.reason}"
    elif not verdict.in_scope:
        drop = f"rule 3 ({model}): {verdict.reason}"
    listed = from_listed(verdict.names)
    return Triaged(
        drop_reason=drop,
        names=listed or find_names(item.title, item.text),
        language=verdict.language if verdict.language in ("da", "en", "ta") else None,
        decided_by=model,
    )


def triage(kit: AgentKit, escalation: AgentKit | None, item: Item) -> Triaged:
    """Glimmer first; Muse Spark for what it is unsure about, or keeps against the list's
    rule-3 tripwire; the word list when neither answers."""
    listed = prefilter(item.title, item.text)
    tripped = bool(listed and listed.startswith("rule 3"))
    first = _ask(kit, item)
    if first is not None and first.sure and not (tripped and first.in_scope):
        return _from(first, item, kit.routes["triage"].model)
    if (second := _ask(escalation, item)) is not None:
        return _from(second, item, escalation.routes["triage"].model)
    if listed:
        return Triaged(drop_reason=listed, names=find_names(item.title, item.text), language=None, decided_by="word list")
    if first is not None:  # Unsure, and nobody to ask: its leaning stands.
        return _from(first, item, kit.routes["triage"].model)
    return Triaged(drop_reason=None, names=find_names(item.title, item.text), language=None, decided_by="word list")
