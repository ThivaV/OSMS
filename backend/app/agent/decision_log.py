"""Decision log writer: every run and step goes to `agent_runs` and
`agent_steps`, scrubbed of personal data before it touches the database."""

from datetime import UTC, datetime
from typing import Any

from sqlalchemy.orm import Session

from app.agent.guardrails import scrub_payload
from app.db.models import AgentRun

#: Long model reasons are kept readable; source text never belongs here anyway.
MAX_LOG_STR = 2000


class DecisionLog:
    def __init__(self, db: Session) -> None:
        self.db = db

    def _commit(self) -> None:
        try:
            self.db.commit()
        except Exception:
            self.db.rollback()  # One failed write must not poison every run after it.
            raise

    def start_run(self, *, agent: str, model: str, prompt_version: str = "v1", subject: str | None = None) -> int:
        run = AgentRun(agent=agent, model=model, prompt_version=prompt_version, subject=subject, status="running")
        self.db.add(run)
        self._commit()
        return run.id

    def log_step(
        self,
        *,
        run_id: int,
        position: int,
        tool: str | None = None,
        arguments: dict[str, Any] | None = None,
        result_summary: str | None = None,
        reason: str | None = None,
        model: str = "",
        prompt_version: str = "v1",
        input_tokens: int = 0,
        output_tokens: int = 0,
        latency_ms: int = 0,
        commentary: str | None = None,
        sensitive: tuple[str, ...] = (),
    ) -> int:
        from app.db.models import AgentStep

        run = self.db.get(AgentRun, run_id)
        if run is None:
            raise ValueError(f"unknown agent run: {run_id}")
        step = AgentStep(
            run_id=run_id,
            position=position,
            tool=tool,
            arguments=scrub_payload(arguments, sensitive=sensitive) if arguments is not None else None,
            result_summary=scrub_payload(result_summary, sensitive=sensitive, max_str=MAX_LOG_STR)
            if result_summary
            else None,
            reason=scrub_payload(reason, sensitive=sensitive, max_str=MAX_LOG_STR) if reason else None,
            model=model,
            prompt_version=prompt_version,
            input_tokens=input_tokens,
            output_tokens=output_tokens,
            latency_ms=latency_ms,
            commentary=scrub_payload(commentary, sensitive=sensitive, max_str=MAX_LOG_STR) if commentary else None,
        )
        self.db.add(step)
        run.input_tokens += input_tokens
        run.output_tokens += output_tokens
        self._commit()
        return step.id

    def end_run(
        self,
        *,
        run_id: int,
        status: str,
        stop_reason: str | None = None,
        fallback: str | None = None,
        error: str | None = None,
        sensitive: tuple[str, ...] = (),
    ) -> None:
        run = self.db.get(AgentRun, run_id)
        if run is None:
            raise ValueError(f"unknown agent run: {run_id}")
        run.status = status
        run.stop_reason = stop_reason
        run.fallback = fallback
        run.error = scrub_payload(error, sensitive=sensitive, max_str=MAX_LOG_STR) if error else None
        run.ended_at = datetime.now(UTC)
        self._commit()
