"""Frozen agent guardrails as code (AGENTS.md §4, *Guardrails*).

Changing these needs the author. Tests enforce them.
"""

from collections.abc import Mapping
from typing import Any

# Agents that see public source text: the only ones that may fail over to a
# second provider, so personal data never reaches one.
BACKUP_AGENTS = frozenset({"judge", "claims", "verifier"})

# Agents that see reader data: no backup, never a second provider.
NO_BACKUP_AGENTS = frozenset({"interest", "ask", "editor", "writer"})

# Triage neither fails over nor sees reader data: unsure items escalate to
# Muse Spark inside the same provider.
TRIAGE_AGENT = "triage"

ALL_AGENTS = BACKUP_AGENTS | NO_BACKUP_AGENTS | {TRIAGE_AGENT}

# Keys that must never reach the decision log or a second provider. Research
# keywords count as topics, and a typed question counts the same way: the
# interest and ask agents see only the words being worked on, never whose.
SCRUB_KEYS = frozenset(
    {
        "keywords",
        "related_terms",
        "categories",
        "question",
        "answer",
        "email",
        "name",
        "display_name",
        "handle",
        "token",
        "interests",
    }
)


class GuardrailViolation(ValueError):
    """A frozen rule would have broken. The run stops; the log says why."""


def backup_allowed(agent: str) -> bool:
    """Whether the agent may fail over to its backup model."""
    return agent in BACKUP_AGENTS


def assert_no_search(request: Mapping[str, Any]) -> None:
    """Refuse any outbound model request with web search grounding on.

    Agents know only what the sources delivered; search grounding and web
    references stay off for every model.
    """
    if request.get("search_grounding") or request.get("web_search"):
        raise GuardrailViolation("search grounding is off for every model")
    tools = request.get("tools")
    if isinstance(tools, list):
        for tool in tools:
            tool_type = tool.get("type") if isinstance(tool, Mapping) else None
            if isinstance(tool_type, str) and tool_type.startswith("web_search"):
                raise GuardrailViolation("search grounding is off for every model")
    choice = request.get("tool_choice")
    if isinstance(choice, Mapping):
        choice_type = choice.get("type")
        if isinstance(choice_type, str) and choice_type.startswith("web_search"):
            raise GuardrailViolation("search grounding is off for every model")


def scrub_payload(
    value: Any, *, sensitive: tuple[str, ...] = (), max_str: int = 500, _depth: int = 0
) -> Any:
    """Copy a log payload minus personal data. Summaries stay, keywords,
    questions, answers and identities go — at any nesting level. Keyed entries
    are dropped outright; known sensitive *values* (the keywords being worked
    on, the question being answered) are redacted even from free text, because
    a model can echo them in a reason."""
    if _depth > 8:
        return "[truncated]"
    if isinstance(value, Mapping):
        return {
            key: scrub_payload(item, sensitive=sensitive, max_str=max_str, _depth=_depth + 1)
            for key, item in value.items()
            if key not in SCRUB_KEYS
        }
    if isinstance(value, (list, tuple)):
        return [scrub_payload(item, sensitive=sensitive, max_str=max_str, _depth=_depth + 1) for item in value]
    if isinstance(value, str):
        for secret in sensitive:
            if secret:
                value = value.replace(secret, "[redacted]")
        if len(value) > max_str:
            return value[:max_str] + "…"
    return value
