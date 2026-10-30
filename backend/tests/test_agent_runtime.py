"""The agent loop: bounded runs, one retry on bad output, exact decision log."""

from pydantic import BaseModel

from app.agent.decision_log import DecisionLog
from app.agent.runtime import AgentSpec, ModelRoute, ModelStep, ModelUsage, Runner, ToolCall
from app.clients.fake import FakeModelClient
from app.db.models import AgentRun, AgentStep


class Verdict(BaseModel):
    same_event: bool
    reason: str


def _spec(**changes) -> AgentSpec:
    route = ModelRoute(model="muse-spark-open-1026", endpoint="https://baseten.example", backup="muse-spark-1.3")
    return AgentSpec(name="judge", route=route, **changes)


def _ok(payload: dict | None = None) -> ModelStep:
    return ModelStep(
        final=payload if payload is not None else {"same_event": True, "reason": "same launch"},
        reason="clear match",
        usage=ModelUsage(100, 20),
    )


def test_structured_call_succeeds_and_logs(memory_db) -> None:
    runner = Runner(FakeModelClient([_ok()]), DecisionLog(memory_db))
    result = runner.call_once(_spec(), system="judge", user="a vs b", schema=Verdict)
    assert result.status == "ok" and result.value == {"same_event": True, "reason": "same launch"}
    assert result.usage == ModelUsage(100, 20)
    run = memory_db.get(AgentRun, result.run_id)
    assert (run.agent, run.model, run.status) == ("judge", "muse-spark-open-1026", "ok")
    assert run.input_tokens == 100 and run.output_tokens == 20
    steps = memory_db.query(AgentStep).filter_by(run_id=result.run_id).all()
    assert len(steps) == 1 and steps[0].tool is None


def test_bad_output_retries_once_with_the_error_then_gives_up(memory_db) -> None:
    bad = ModelStep(final={"same_event": "maybe"}, reason="unsure", usage=ModelUsage(10, 5))
    client = FakeModelClient([bad, bad])
    runner = Runner(client, DecisionLog(memory_db))
    result = runner.call_once(_spec(), system="judge", user="a vs b", schema=Verdict)
    assert (result.status, result.stop_reason) == ("failed", "invalid-output")
    assert result.usage == ModelUsage(20, 10)
    assert len(client.calls) == 2
    run = memory_db.get(AgentRun, result.run_id)
    assert run.status == "failed" and "same_event" in (run.error or "")


def test_retry_can_recover(memory_db) -> None:
    bad = ModelStep(final={"nope": 1}, reason="slip", usage=ModelUsage(10, 5))
    runner = Runner(FakeModelClient([bad, _ok()]), DecisionLog(memory_db))
    result = runner.call_once(_spec(), system="judge", user="a vs b", schema=Verdict)
    assert result.status == "ok" and result.value is not None


def test_model_outage_fails_without_retry(memory_db) -> None:
    runner = Runner(FakeModelClient([RuntimeError("baseten is down")]), DecisionLog(memory_db))
    result = runner.call_once(_spec(), system="judge", user="a vs b", schema=Verdict)
    assert (result.status, result.stop_reason) == ("failed", "error")
    assert memory_db.get(AgentRun, result.run_id).status == "failed"


def test_keywords_never_reach_the_log(memory_db) -> None:
    phrase = "retrieval-augmented generation"
    first = ModelStep(
        tool_calls=[ToolCall(name="search", arguments={"keywords": [phrase]})],
        reason=f"planning for {phrase}",
        usage=ModelUsage(10, 5),
    )
    done = ModelStep(final={"same_event": True, "reason": f"about {phrase}"}, reason="done")
    spec = AgentSpec(
        name="interest",
        route=ModelRoute(model="muse-spark-1.3", endpoint="https://api.meta.ai/v1"),
        sensitive=(phrase,),
    )
    runner = Runner(FakeModelClient([first, done]), DecisionLog(memory_db))
    result = runner.run_tool_loop(spec, system="plan", user="go", tools={"search": _Echo()})
    assert result.status == "ok"
    blob = ""
    for row in memory_db.query(AgentRun).all() + memory_db.query(AgentStep).all():
        blob += " ".join(
            str(value)
            for value in (
                getattr(row, "error", None),
                getattr(row, "reason", None),
                getattr(row, "result_summary", None),
                getattr(row, "commentary", None),
                getattr(row, "arguments", None),
            )
            if value
        )
    assert phrase not in blob
    assert "[redacted]" in blob


class _Echo:
    name = "echo"

    def definition(self) -> dict:
        return {"name": "echo", "parameters": {}}

    def call(self, args: dict) -> dict:
        return {"echo": args}


def test_tool_loop_calls_tools_then_finishes(memory_db) -> None:
    calls = ModelStep(
        tool_calls=[ToolCall(name="echo", arguments={"text": "hi"})],
        reason="need a lookup",
        usage=ModelUsage(50, 10),
    )
    done = ModelStep(final={"answer": "hi"}, reason="done", usage=ModelUsage(60, 10))
    runner = Runner(FakeModelClient([calls, done]), DecisionLog(memory_db))
    spec = _spec(max_steps=5)
    result = runner.run_tool_loop(spec, system="editor", user="brief me", tools={"echo": _Echo()})
    assert (result.status, result.value) == ("ok", {"answer": "hi"})
    tools = [s.tool for s in memory_db.query(AgentStep).filter_by(run_id=result.run_id).order_by(AgentStep.position)]
    assert tools == [None, "echo", None]


def test_unknown_tool_fails_the_run(memory_db) -> None:
    step = ModelStep(tool_calls=[ToolCall(name="rm_rf", arguments={})], reason="mischief")
    runner = Runner(FakeModelClient([step]), DecisionLog(memory_db))
    result = runner.run_tool_loop(_spec(), system="editor", user="go", tools={"echo": _Echo()})
    assert (result.status, result.stop_reason) == ("failed", "unknown-tool")


def test_step_budget_stops(memory_db) -> None:
    endless = ModelStep(
        tool_calls=[ToolCall(name="echo", arguments={"text": "again"})], reason="loop", usage=ModelUsage(10, 10)
    )
    runner = Runner(FakeModelClient([endless] * 10), DecisionLog(memory_db))
    result = runner.run_tool_loop(_spec(max_steps=3), system="editor", user="go", tools={"echo": _Echo()})
    assert (result.status, result.stop_reason) == ("stopped", "max-steps")


def test_token_budget_stops(memory_db) -> None:
    pricey = ModelStep(
        tool_calls=[ToolCall(name="echo", arguments={"text": "x"})], reason="spend", usage=ModelUsage(9000, 1000)
    )
    runner = Runner(FakeModelClient([pricey] * 5), DecisionLog(memory_db))
    result = runner.run_tool_loop(_spec(max_steps=50, token_budget=20_000), system="e", user="go", tools={"echo": _Echo()})
    assert (result.status, result.stop_reason) == ("stopped", "token-budget")


def test_time_budget_stops_before_the_first_call(memory_db) -> None:
    runner = Runner(FakeModelClient([_ok()]), DecisionLog(memory_db))
    result = runner.run_tool_loop(_spec(time_limit_s=0), system="e", user="go", tools={"echo": _Echo()})
    assert (result.status, result.stop_reason) == ("stopped", "time-limit")
