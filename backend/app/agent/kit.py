"""What the pipeline's agents share: the runner, the routing table, whether an agent can
run right now, and how source text goes into a prompt (quoted data, never instructions)."""

import html
from dataclasses import dataclass, replace
from datetime import datetime

from app.agent.runtime import AgentSpec, ModelRoute, Runner, RunResult


@dataclass
class AgentKit:
    runner: Runner
    routes: dict[str, ModelRoute]
    #: agent → can it run now (configured, or its backup is)?
    available: dict[str, bool]

    def spec(self, agent: str, *, effort: str | None = None, **bounds) -> AgentSpec:
        route = self.routes[agent]
        if effort:
            route = replace(route, effort=effort)
        return AgentSpec(name=agent, route=route, **bounds)

    def can(self, agent: str) -> bool:
        return self.available.get(agent, False)

    def served_by(self, agent: str, result: RunResult) -> str:
        """The model that produced a result: the route's, or its backup after a fallback."""
        from app.db.models import AgentRun

        run = self.runner.log.db.get(AgentRun, result.run_id)
        return (run.fallback if run is not None and run.fallback else None) or self.routes[agent].model


def quoted_item(
    label: str, *, source: str, language: str, published: datetime | None, title: str, text: str, limit: int = 1500
) -> str:
    """An item as quoted data. Escaped, so nothing inside can close the tag or open a new one."""
    when = published.isoformat(timespec="minutes") if published else "unknown"
    return (
        f'<item id="{html.escape(label)}" source="{html.escape(source)}" language="{html.escape(language)}" '
        f'published="{when}">\n<title>{html.escape(title)}</title>\n<excerpt>{html.escape(text[:limit])}</excerpt>\n</item>'
    )
