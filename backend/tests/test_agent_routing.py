"""The routing table upholds the frozen backup rules for every agent."""

import pytest

from app.agent.guardrails import ALL_AGENTS
from app.config import (
    FIREWORKS_GLIMMER_ID,
    FIREWORKS_SPARK_OPEN_ID,
    FIREWORKS_URL,
    GLIMMER_MODEL,
    META_API_URL,
    SPARK_ID,
    SPARK_OPEN_ID,
    Settings,
    check_routes,
)


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


def test_without_baseten_fireworks_runs_the_open_weight_models() -> None:
    settings = Settings(_env_file=None, FIREWORKS_API_KEY="fw", GLIMMER_BASE_URL=FIREWORKS_URL)
    routes = settings.model_routes()
    assert (routes["judge"].model, routes["judge"].endpoint, routes["judge"].backup) == (
        FIREWORKS_SPARK_OPEN_ID, FIREWORKS_URL, SPARK_ID
    )
    assert routes["claims"].backup == routes["verifier"].backup == FIREWORKS_SPARK_OPEN_ID
    assert settings.endpoint_for(FIREWORKS_SPARK_OPEN_ID) == FIREWORKS_URL
    assert (routes["triage"].model, routes["triage"].effort) == (FIREWORKS_GLIMMER_ID, None)
    assert settings.key_for(FIREWORKS_URL) == "fw"
    check_routes(routes)


def test_baseten_stays_first_and_ollama_stays_local() -> None:
    settings = Settings(_env_file=None, FIREWORKS_API_KEY="fw", BASETEN_BASE_URL="https://baseten.example")
    routes = settings.model_routes()
    assert (routes["judge"].model, routes["judge"].endpoint) == (SPARK_OPEN_ID, "https://baseten.example")
    assert (routes["triage"].model, routes["triage"].effort) == (GLIMMER_MODEL, "low")
