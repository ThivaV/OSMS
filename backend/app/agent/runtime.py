"""Our small agent loop, not a framework: one file, exact decision log, few
dependencies. Single structured calls (`call_once`) for the judge/claims style
agents, a bounded tool loop (`run_tool_loop`) for the editor style ones. The
network client lands Day 5; tests drive this through the fake in
`app/clients/fake.py`."""

import time
from collections.abc import Callable, Mapping
from dataclasses import dataclass, field
from typing import Any, Literal, Protocol

from pydantic import BaseModel, ValidationError


@dataclass(frozen=True)
class ToolCall:
    name: str
    arguments: dict[str, Any]


@dataclass(frozen=True)
class ModelUsage:
    input_tokens: int = 0
    output_tokens: int = 0

    def __add__(self, other: "ModelUsage") -> "ModelUsage":
        return ModelUsage(self.input_tokens + other.input_tokens, self.output_tokens + other.output_tokens)

    @property
    def total(self) -> int:
        return self.input_tokens + self.output_tokens


@dataclass(frozen=True)
class ModelStep:
    """One model turn, already normalized from the provider's shape."""

    tool_calls: list[ToolCall] = field(default_factory=list)
    final: dict[str, Any] | None = None
    reason: str = ""
    usage: ModelUsage = field(default_factory=ModelUsage)
    commentary: str | None = None


class ModelClient(Protocol):
    """One method every text model speaks through. The Day 5 client adapts
    Meta Model API / Baseten / Ollama responses into `ModelStep`."""

    def step(
        self,
        *,
        system: str,
        messages: list[dict[str, str]],
        tools: list[dict[str, Any]],
        agent: str,
    ) -> ModelStep: ...


class Tool(Protocol):
    @property
    def name(self) -> str: ...

    def definition(self) -> dict[str, Any]: ...

    def call(self, args: dict[str, Any]) -> dict[str, Any]: ...


@dataclass(frozen=True)
class ModelRoute:
    """One line of the routing table: which model an agent runs on, where it
    lives, what covers for it, and how hard it may think."""

    model: str
    endpoint: str
    backup: str | None = None
    effort: str = "medium"


@dataclass(frozen=True)
class AgentSpec:
    """Run bounds, tunable in one place. These cap spend, not quality: they
    are not clustering thresholds and never stand in for them."""

    name: str
    route: ModelRoute
    prompt_version: str = "v1"
    max_steps: int = 10
    token_budget: int = 20_000
    time_limit_s: float = 120.0
    # Values that must never reach the decision log (the keywords being
    # worked on, the question being answered): redacted even from free text.
    sensitive: tuple[str, ...] = ()


@dataclass(frozen=True)
class RunResult:
    status: Literal["ok", "failed", "stopped"]
    stop_reason: str | None
    value: dict[str, Any] | None
    usage: ModelUsage
    run_id: int


class Runner:
    def __init__(self, client: ModelClient, log, clock: Callable[[], float] = time.monotonic) -> None:
        self.client = client
        self.log = log
        self.clock = clock

    def _call_model(
        self, spec: AgentSpec, *, system: str, messages: list[dict[str, str]], tools: list[dict[str, Any]]
    ) -> tuple[ModelStep, int]:
        start = self.clock()
        try:
            step = self.client.step(system=system, messages=messages, tools=tools, agent=spec.name)
        except Exception as error:
            raise ModelError(str(error)) from error
        latency_ms = max(0, int((self.clock() - start) * 1000))
        return step, latency_ms

    def call_once(
        self,
        spec: AgentSpec,
        *,
        system: str,
        user: str,
        schema: type[BaseModel],
    ) -> RunResult:
        """One structured call; on a validation error retry once with the
        error, then give up and log it."""
        from app.agent.decision_log import DecisionLog

        log: DecisionLog = self.log
        run_id = log.start_run(agent=spec.name, model=spec.route.model, prompt_version=spec.prompt_version)
        messages = [{"role": "user", "content": user}]
        usage = ModelUsage()
        attempts = 0
        while True:
            attempts += 1
            try:
                step, latency_ms = self._call_model(spec, system=system, messages=messages, tools=[])
            except ModelError as error:
                log.end_run(run_id=run_id, status="failed", stop_reason="error", error=error.detail,
                        sensitive=spec.sensitive)
                return RunResult("failed", "error", None, usage, run_id)
            usage += step.usage
            log.log_step(
                run_id=run_id,
                position=attempts - 1,
                reason=step.reason,
                model=spec.route.model,
                prompt_version=spec.prompt_version,
                input_tokens=step.usage.input_tokens,
                output_tokens=step.usage.output_tokens,
                latency_ms=latency_ms,
                commentary=step.commentary,
                sensitive=spec.sensitive,
            )
            if step.final is None:
                log.end_run(run_id=run_id, status="failed", stop_reason="no-final", error="model returned no payload",
                        sensitive=spec.sensitive)
                return RunResult("failed", "no-final", None, usage, run_id)
            try:
                value = schema.model_validate(step.final)
            except ValidationError as error:
                if attempts > 1:
                    log.end_run(run_id=run_id, status="failed", stop_reason="invalid-output", error=str(error),
                        sensitive=spec.sensitive)
                    return RunResult("failed", "invalid-output", None, usage, run_id)
                messages.append({"role": "assistant", "content": "Invalid output, retry as JSON matching the schema."})
                messages.append({"role": "user", "content": f"Validation failed: {error}. Return only the fixed JSON."})
                continue
            log.end_run(run_id=run_id, status="ok")
            return RunResult("ok", None, value.model_dump(), usage, run_id)

    def run_tool_loop(
        self,
        spec: AgentSpec,
        *,
        system: str,
        user: str,
        tools: Mapping[str, Tool],
    ) -> RunResult:
        """Bounded tool loop for orchestrator-style agents. Budgets stop the
        run with their reason; an unknown tool fails it."""
        from app.agent.decision_log import DecisionLog

        log: DecisionLog = self.log
        run_id = log.start_run(agent=spec.name, model=spec.route.model, prompt_version=spec.prompt_version)
        started = self.clock()
        messages = [{"role": "user", "content": user}]
        definitions = [tool.definition() for tool in tools.values()]
        usage = ModelUsage()
        position = 0
        while True:
            if position >= spec.max_steps:
                return self._stop(log, run_id, usage, "max-steps", spec)
            if usage.total >= spec.token_budget:
                return self._stop(log, run_id, usage, "token-budget", spec)
            if self.clock() - started >= spec.time_limit_s:
                return self._stop(log, run_id, usage, "time-limit", spec)
            try:
                step, latency_ms = self._call_model(spec, system=system, messages=messages, tools=definitions)
            except ModelError as error:
                log.end_run(run_id=run_id, status="failed", stop_reason="error", error=error.detail,
                        sensitive=spec.sensitive)
                return RunResult("failed", "error", None, usage, run_id)
            usage += step.usage
            log.log_step(
                run_id=run_id,
                position=position,
                reason=step.reason,
                model=spec.route.model,
                prompt_version=spec.prompt_version,
                input_tokens=step.usage.input_tokens,
                output_tokens=step.usage.output_tokens,
                latency_ms=latency_ms,
                commentary=step.commentary,
                sensitive=spec.sensitive,
            )
            position += 1
            if not step.tool_calls:
                if step.final is None:
                    log.end_run(run_id=run_id, status="failed", stop_reason="no-final", error="model returned no payload",
                        sensitive=spec.sensitive)
                    return RunResult("failed", "no-final", None, usage, run_id)
                log.end_run(run_id=run_id, status="ok")
                return RunResult("ok", None, step.final, usage, run_id)
            for call in step.tool_calls:
                tool = tools.get(call.name)
                if tool is None:
                    log.end_run(
                        run_id=run_id, status="failed", stop_reason="unknown-tool", error=f"no such tool: {call.name}",
                        sensitive=spec.sensitive,
                    )
                    return RunResult("failed", "unknown-tool", None, usage, run_id)
                try:
                    outcome = tool.call(call.arguments)
                except Exception as error:  # noqa: BLE001 — a failing tool is a logged outcome, never a crashed run
                    outcome = {"error": f"{type(error).__name__}: {error}"}
                log.log_step(
                    run_id=run_id,
                    position=position,
                    tool=tool.name,
                    arguments=call.arguments,
                    result_summary=str(outcome),
                    model=spec.route.model,
                    prompt_version=spec.prompt_version,
                    sensitive=spec.sensitive,
                )
                position += 1
                messages.append({"role": "tool", "content": f"{tool.name}: {outcome}"})

    def _stop(self, log, run_id: int, usage: ModelUsage, reason: str, spec: AgentSpec) -> RunResult:
        log.end_run(run_id=run_id, status="stopped", stop_reason=reason, sensitive=spec.sensitive)
        return RunResult("stopped", reason, None, usage, run_id)


class ModelError(Exception):
    """The model call itself failed (network, auth, outage). Distinct from a
    bad payload, which is `invalid-output` after its one retry."""

    def __init__(self, detail: str) -> None:
        super().__init__(detail)
        self.detail = detail
