"""The routing table upholds the frozen backup rules for every agent."""

import pytest

from app.agent.guardrails import ALL_AGENTS
from app.config import META_API_URL, SPARK_ID, SPARK_OPEN_ID, Settings, check_routes


def _routes(**env) -> dict:
    return Settings(**env).model_routes()


def test_every_agent_resolves_with_pinned_models() -> None:
    routes = _routes(baseten_base_url="https://baseten.example")
    assert set(routes) == ALL_AGENTS
    assert routes["claims"].model == SPARK_ID == routes["verifier"].model
    assert routes["judge"].model == SPARK_OPEN_ID
    assert routes["judge"].endpoint == "https://baseten.example"
    assert routes["triage"].endpoint == "http://127.0.0.1:11434/v1"  # Ollama's OpenAI-compatible API
    assert routes["claims"].endpoint == META_API_URL
    check_routes(routes)


def test_backups_only_where_public_text_allows() -> None:
    routes = _routes(baseten_base_url="https://baseten.example")
    assert routes["judge"].backup == SPARK_ID
    assert routes["claims"].backup == routes["verifier"].backup == SPARK_OPEN_ID
    for agent in ("triage", "interest", "ask", "editor", "writer"):
        assert routes[agent].backup is None, agent


def test_contributor_variants_never_appear() -> None:
    routes = _routes(baseten_base_url="https://baseten.example")
    for agent, route in routes.items():
        assert "-contributor" not in route.model, agent
        assert route.backup is None or "-contributor" not in route.backup, agent


def test_broken_tables_fail_before_deciding() -> None:
    routes = _routes(baseten_base_url="https://baseten.example")
    del routes["ask"]
    with pytest.raises(ValueError, match="without a route"):
        check_routes(routes)
    routes = _routes(baseten_base_url="https://baseten.example")
    routes["ask"] = routes["ask"].__class__(model=routes["ask"].model, endpoint="x", backup="other")
    with pytest.raises(ValueError, match="never move personal data"):
        check_routes(routes)
