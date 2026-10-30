"""Frozen guardrails: backup matrix, no search grounding, log scrubbing."""

import pytest

from app.agent.guardrails import (
    ALL_AGENTS,
    BACKUP_AGENTS,
    NO_BACKUP_AGENTS,
    GuardrailViolation,
    assert_no_search,
    backup_allowed,
    scrub_payload,
)


def test_backup_matrix_covers_every_agent_exactly_once() -> None:
    assert BACKUP_AGENTS == {"judge", "claims", "verifier"}
    assert NO_BACKUP_AGENTS == {"interest", "ask", "editor", "writer"}
    assert ALL_AGENTS == BACKUP_AGENTS | NO_BACKUP_AGENTS | {"triage"}
    assert backup_allowed("judge") and backup_allowed("claims") and backup_allowed("verifier")
    assert not backup_allowed("ask") and not backup_allowed("editor") and not backup_allowed("triage")


def test_search_grounding_is_refused_in_every_shape() -> None:
    assert_no_search({"model": "muse-spark-1.3", "tools": [{"type": "function", "function": {"name": "f"}}]})
    with pytest.raises(GuardrailViolation):
        assert_no_search({"tools": [{"type": "web_search"}]})
    with pytest.raises(GuardrailViolation):
        assert_no_search({"tools": [{"type": "web_search_preview"}]})
    with pytest.raises(GuardrailViolation):
        assert_no_search({"tool_choice": {"type": "web_search"}})
    with pytest.raises(GuardrailViolation):
        assert_no_search({"search_grounding": True})


def test_scrub_drops_keys_and_redacts_values() -> None:
    payload = {
        "keywords": ["retrieval-augmented generation"],
        "counts": 3,
        "nested": {"question": "How big?", "reason": "planning for retrieval-augmented generation"},
        "list": [{"answer": "1.2T"}, "kept"],
    }
    scrubbed = scrub_payload(payload, sensitive=("retrieval-augmented generation", "How big?"))
    assert "keywords" not in scrubbed
    assert "question" not in scrubbed["nested"] and "answer" not in scrubbed["list"][0]
    assert scrubbed["nested"]["reason"] == "planning for [redacted]"
    assert scrubbed["counts"] == 3 and scrubbed["list"][1] == "kept"


def test_scrub_truncates_and_survives_depth() -> None:
    assert scrub_payload("x" * 600) == "x" * 500 + "…"
    deep: object = "bottom"
    for _ in range(12):
        deep = [deep]
    narrowed = scrub_payload(deep)
    assert "[truncated]" in str(narrowed)
    assert str(narrowed).count("[") <= 10
