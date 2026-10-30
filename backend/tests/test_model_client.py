"""The one text-model client: OpenAI-compatible requests, no web search ever, errors that
never echo the prompt, and backups only for agents that see public source text."""

import json

import httpx
import pytest

from app.agent.guardrails import GuardrailViolation
from app.agent.runtime import ModelError, ModelRoute
from app.clients.openai_compat import ChatEndpoint, RoutedModels, models_from_settings, parse_completion
from app.config import META_API_URL, SPARK_ID, SPARK_OPEN_ID, Settings

ANSWER = {"choices": [{"message": {"content": '{"same_event": true, "reason": "same launch"}'}}], "usage": {"prompt_tokens": 40, "completion_tokens": 9}}


def _endpoint(handler) -> ChatEndpoint:
    return ChatEndpoint("https://models.example/v1", "test-key", http=httpx.Client(transport=httpx.MockTransport(handler)))


def test_request_shape_structured_output_and_effort() -> None:
    sent = {}

    def handler(request: httpx.Request) -> httpx.Response:
        sent["url"], sent["auth"], sent["body"] = str(request.url), request.headers["authorization"], json.loads(request.content)
        return httpx.Response(200, json=ANSWER)

    step = _endpoint(handler).complete(
        model=SPARK_ID, system="judge", messages=[{"role": "user", "content": "a vs b"}], tools=[], schema={"title": "verdict", "type": "object"}, effort="high"
    )
    body = sent["body"]
    assert sent["url"] == "https://models.example/v1/chat/completions" and sent["auth"] == "Bearer test-key"
    assert body["messages"][0] == {"role": "system", "content": "judge"}
    assert body["response_format"]["type"] == "json_schema" and body["reasoning_effort"] == "high"
    assert "tools" not in body
    assert step.final == {"same_event": True, "reason": "same launch"} and step.reason == "same launch"
    assert (step.usage.input_tokens, step.usage.output_tokens) == (40, 9)


def test_web_search_is_refused_before_anything_is_sent() -> None:
    calls = []
    endpoint = _endpoint(lambda r: calls.append(r) or httpx.Response(200, json=ANSWER))
    with pytest.raises(GuardrailViolation):
        endpoint.complete(model=SPARK_ID, system="s", messages=[], tools=[{"type": "web_search"}], schema=None, effort=None)
    assert calls == []


def test_errors_never_carry_the_providers_body() -> None:
    endpoint = _endpoint(lambda r: httpx.Response(500, json={"error": {"type": "server_error", "message": "prompt was: SECRET"}}))
    with pytest.raises(ModelError) as caught:
        endpoint.complete(model=SPARK_ID, system="s", messages=[], tools=[], schema=None, effort=None)
    assert "SECRET" not in str(caught.value) and "server_error" in str(caught.value)


def test_tool_calls_are_parsed_with_their_ids() -> None:
    body = {"choices": [{"message": {"tool_calls": [{"id": "call_1", "function": {"name": "stories_changed", "arguments": '{"since": "x"}'}}]}}]}
    step = parse_completion(body, model=SPARK_ID)
    assert step.tool_calls[0].id == "call_1" and step.tool_calls[0].arguments == {"since": "x"} and step.final is None


def _routed(fail: set[str]) -> tuple[RoutedModels, list[str]]:
    used: list[str] = []

    def endpoint(url: str) -> ChatEndpoint:
        def handler(request: httpx.Request) -> httpx.Response:
            used.append(url)
            return httpx.Response(503 if url in fail else 200, json=ANSWER)

        return ChatEndpoint(url, "k", http=httpx.Client(transport=httpx.MockTransport(handler)))

    baseten = "https://baseten.example/v1"
    routes = {
        "judge": ModelRoute(model=SPARK_OPEN_ID, endpoint=baseten, backup=SPARK_ID),
        "interest": ModelRoute(model=SPARK_ID, endpoint=META_API_URL),
    }
    endpoints = {baseten: endpoint(baseten), META_API_URL: endpoint(META_API_URL)}
    return RoutedModels(routes, endpoints, {SPARK_ID: META_API_URL}), used


def test_the_judge_falls_back_and_says_so() -> None:
    models, used = _routed(fail={"https://baseten.example/v1"})
    step = models.step(system="s", messages=[], tools=[], agent="judge")
    assert step.fallback and step.model == SPARK_ID and used == ["https://baseten.example/v1", META_API_URL]


def test_reader_data_agents_never_fail_over() -> None:
    models, used = _routed(fail={META_API_URL})
    with pytest.raises(ModelError):
        models.step(system="s", messages=[], tools=[], agent="interest")
    assert used == [META_API_URL]


def test_without_keys_no_hosted_agent_is_available(tmp_path) -> None:
    models = models_from_settings(Settings(_env_file=None, database_url=f"sqlite:///{tmp_path / 'x.db'}"))
    assert not any(models.available(a) for a in ("claims", "verifier", "writer", "judge", "interest", "ask", "editor"))
    with_meta = models_from_settings(Settings(_env_file=None, META_API_KEY="k"))
    assert all(with_meta.available(a) for a in ("claims", "verifier", "writer", "interest", "ask", "editor"))
    # No Baseten deployment yet: the judge runs on its backup, Muse Spark.
    assert with_meta.available("judge")
