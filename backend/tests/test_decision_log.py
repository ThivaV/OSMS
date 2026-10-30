"""The decision log persists runs and steps with every specified field."""

from app.agent.decision_log import DecisionLog
from app.db.models import AgentRun, AgentStep


def test_run_lifecycle_persists(memory_db) -> None:
    log = DecisionLog(memory_db)
    run_id = log.start_run(agent="judge", model="muse-spark-open-1026", prompt_version="v3")
    log.log_step(
        run_id=run_id,
        position=0,
        reason="borderline pair",
        model="muse-spark-open-1026",
        prompt_version="v3",
        input_tokens=120,
        output_tokens=30,
        latency_ms=900,
        commentary="both name Halcyon-2, dates differ",
    )
    log.end_run(run_id=run_id, status="ok", fallback="muse-spark-1.3")
    run = memory_db.get(AgentRun, run_id)
    assert (run.agent, run.status, run.fallback, run.prompt_version) == ("judge", "ok", "muse-spark-1.3", "v3")
    assert (run.input_tokens, run.output_tokens) == (120, 30)
    assert run.started_at is not None and run.ended_at is not None and run.ended_at >= run.started_at
    (step,) = memory_db.query(AgentStep).filter_by(run_id=run_id).all()
    assert (step.position, step.tool, step.reason) == (0, None, "borderline pair")
    assert (step.input_tokens, step.output_tokens, step.latency_ms) == (120, 30, 900)
    assert step.commentary == "both name Halcyon-2, dates differ"


def test_tool_steps_keep_scrubbed_arguments(memory_db) -> None:
    log = DecisionLog(memory_db)
    run_id = log.start_run(agent="editor", model="muse-spark-1.3")
    log.log_step(
        run_id=run_id,
        position=0,
        tool="read_claims",
        arguments={"story_id": 7, "keywords": ["should not persist"]},
        result_summary="3 claims",
    )
    (step,) = memory_db.query(AgentStep).filter_by(run_id=run_id).all()
    assert step.tool == "read_claims"
    assert step.arguments == {"story_id": 7}
    assert step.result_summary == "3 claims"


def test_unknown_run_is_an_error(memory_db) -> None:
    log = DecisionLog(memory_db)
    try:
        log.log_step(run_id=999, position=0)
    except ValueError as error:
        assert "999" in str(error)
    else:
        raise AssertionError("logging to a missing run must fail")
