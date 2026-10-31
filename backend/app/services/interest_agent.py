"""The interest agent (Muse Spark, no backup): a reader's research keywords → related
terms papers use, likely arXiv categories, and keywords outside rule 3. Its prompt holds
only the keywords being edited, never who typed them; the decision log records the run
with the keywords redacted (frozen guardrail: research keywords count as topics)."""

from pydantic import BaseModel, ConfigDict, Field

from app.agent.kit import AgentKit
from app.agent.prompts import load
from app.services.triage import prefilter

#: The categories OSMS offers, inside rule 3 (the app's list: frontend/lib/core/models/research.dart).
CATEGORIES = (
    "cs.AI", "cs.CL", "cs.LG", "cs.CV", "cs.IR", "cs.RO", "cs.SE", "cs.PL", "cs.HC",
    "stat.ML", "eess.AS", "q-bio.BM", "cond-mat.mtrl-sci", "astro-ph.EP", "astro-ph.IM",
)


class Suggestions(BaseModel):
    model_config = ConfigDict(extra="ignore", title="interest_suggestions")

    related_terms: list[str] = Field(default_factory=list, max_length=12)
    categories: list[str] = Field(default_factory=list, max_length=6)
    flagged: list[str] = Field(default_factory=list, max_length=20)


class InterestAgentUnavailable(RuntimeError):
    pass


def suggest(kit: AgentKit, keywords: list[str]) -> Suggestions:
    if not kit.can("interest"):
        raise InterestAgentUnavailable("no interest agent")
    prompt = load("interest")
    quoted = "\n".join(f"<keyword>{k}</keyword>" for k in keywords)
    result = kit.runner.call_once(
        kit.spec("interest", prompt_version=prompt.version, max_steps=2, token_budget=4_000, sensitive=tuple(keywords)),
        system=prompt.text,
        user=f"<keywords>\n{quoted}\n</keywords>\n\nCategories to choose from: {', '.join(CATEGORIES)}",
        schema=Suggestions,
    )
    if result.status != "ok" or result.value is None:
        raise InterestAgentUnavailable("the interest agent failed")
    out = Suggestions.model_validate(result.value)
    given = {k.casefold() for k in keywords}
    seen: set[str] = set()
    related = []
    for term in out.related_terms:
        key = term.strip().casefold()
        # The rule-3 word list catches what the model suggests despite its prompt.
        if key and key not in given and key not in seen and len(term) <= 100 and prefilter(term, "") is None:
            seen.add(key)
            related.append(term.strip())
    return Suggestions(
        related_terms=related[:8],
        categories=[c for c in dict.fromkeys(out.categories) if c in CATEGORIES][:4],
        flagged=[k for k in keywords if k in out.flagged],
    )
