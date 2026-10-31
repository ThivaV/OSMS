"""One client for every text model: Meta Model API, Baseten (Muse Spark Open) and the
Muse Glimmer server all speak OpenAI-compatible Chat Completions (AGENTS.md §4,
*Runtime*). Plain httpx, so the decision log sees exactly what was asked.

Every request passes `assert_no_search` first: search grounding stays off for every
model (frozen guardrail). The routing table decides which endpoint an agent uses, and
`RoutedModels` fails over to the backup only for agents allowed one."""

import json
from collections.abc import Mapping
from typing import Any

import httpx

from app.agent.guardrails import assert_no_search, backup_allowed
from app.agent.runtime import ModelError, ModelRoute, ModelStep, ModelUsage, ToolCall

# The verifier at high or maximum effort can think for over two minutes (seen Oct 31);
# a timeout there wastes a paid call and retries the whole job.
TIMEOUT_S = 300.0


class ChatEndpoint:
    """One OpenAI-compatible base URL and its key."""

    def __init__(self, base_url: str, api_key: str, *, http: httpx.Client | None = None) -> None:
        self.base_url = base_url.rstrip("/")
        self.api_key = api_key
        self.http = http or httpx.Client(timeout=TIMEOUT_S)

    def complete(
        self,
        *,
        model: str,
        system: str,
        messages: list[dict[str, Any]],
        tools: list[dict[str, Any]],
        schema: dict[str, Any] | None,
        effort: str | None,
    ) -> ModelStep:
        request: dict[str, Any] = {"model": model, "messages": [{"role": "system", "content": system}, *messages]}
        if tools:
            request["tools"] = tools
        if schema is not None:
            request["response_format"] = {
                "type": "json_schema",
                "json_schema": {"name": str(schema.get("title") or "answer"), "schema": schema},
            }
        if effort:
            request["reasoning_effort"] = effort
        assert_no_search(request)
        headers = {"Authorization": f"Bearer {self.api_key}"} if self.api_key else {}
        try:
            response = self.http.post(f"{self.base_url}/chat/completions", json=request, headers=headers)
        except httpx.HTTPError as error:
            raise ModelError(f"{type(error).__name__} calling {model}") from error
        if response.status_code >= 400:
            # The body can echo the prompt; keep the status and the provider's error type only.
            kind = ""
            try:
                kind = str(response.json().get("error", {}).get("type", ""))
            except (ValueError, AttributeError):
                pass
            raise ModelError(f"{response.status_code} from {model}{f' ({kind})' if kind else ''}")
        return parse_completion(response.json(), model=model)


def parse_completion(body: Mapping[str, Any], *, model: str) -> ModelStep:
    try:
        message = body["choices"][0]["message"]
    except (KeyError, IndexError, TypeError) as error:
        raise ModelError(f"{model} answered without a message") from error
    usage = body.get("usage") or {}
    calls = [
        ToolCall(
            id=str(call.get("id", "")),
            name=call["function"]["name"],
            arguments=json.loads(call["function"].get("arguments") or "{}"),
        )
        for call in message.get("tool_calls") or []
    ]
    final = None
    content = message.get("content")
    if not calls and isinstance(content, str) and content.strip():
        text = content.strip()
        if text.startswith("```"):
            text = text.strip("`").removeprefix("json").strip()
        try:
            parsed = json.loads(text)
            final = parsed if isinstance(parsed, dict) else {"value": parsed}
        except json.JSONDecodeError:
            final = {"text": content}
    reason = str(final.get("reason", "")) if isinstance(final, dict) else ""
    return ModelStep(
        tool_calls=calls,
        final=final,
        reason=reason,
        usage=ModelUsage(int(usage.get("prompt_tokens", 0)), int(usage.get("completion_tokens", 0))),
        # Muse Spark Open states its intent on a separate commentary channel.
        commentary=message.get("commentary") if isinstance(message.get("commentary"), str) else None,
        model=str(body.get("model") or model),
    )


class RoutedModels:
    """The `ModelClient` agents run on: the routing table, with backups both ways for
    the agents that see only public source text (judge, claims, verifier)."""

    def __init__(self, routes: Mapping[str, ModelRoute], endpoints: Mapping[str, ChatEndpoint], backup_endpoints: Mapping[str, str]) -> None:
        self.routes = routes
        self.endpoints = endpoints
        #: backup model id → the endpoint it runs on.
        self.backup_endpoints = backup_endpoints

    def available(self, agent: str) -> bool:
        route = self.routes.get(agent)
        if route is None:
            return False
        if route.endpoint in self.endpoints:
            return True
        return bool(route.backup and backup_allowed(agent) and self.backup_endpoints.get(route.backup) in self.endpoints)

    def step(
        self,
        *,
        system: str,
        messages: list[dict[str, Any]],
        tools: list[dict[str, Any]],
        agent: str,
        schema: dict[str, Any] | None = None,
        effort: str | None = None,
    ) -> ModelStep:
        route = self.routes[agent]
        effort = effort or route.effort
        primary = self.endpoints.get(route.endpoint)
        try:
            if primary is None:
                raise ModelError(f"{route.model} isn't configured")
            return primary.complete(model=route.model, system=system, messages=messages, tools=tools, schema=schema, effort=effort)
        except ModelError:
            backup_endpoint = self.endpoints.get(self.backup_endpoints.get(route.backup or "", ""))
            if not (route.backup and backup_allowed(agent) and backup_endpoint):
                raise
            step = backup_endpoint.complete(
                model=route.backup, system=system, messages=messages, tools=tools, schema=schema, effort=effort
            )
            return ModelStep(
                tool_calls=step.tool_calls,
                final=step.final,
                reason=step.reason,
                usage=step.usage,
                commentary=step.commentary,
                model=route.backup,
                fallback=True,
            )


def triage_escalation(settings, models: RoutedModels) -> RoutedModels:
    """The triage agent on Muse Spark, for the items it is unsure about. Its own small
    table: the main one has exactly one route per agent (guardrails)."""
    return RoutedModels({"triage": settings.triage_escalation_route()}, models.endpoints, {})


def local_model_ready(base_url: str, model: str, *, http: httpx.Client | None = None) -> bool:
    """Whether a local server (Ollama) is up and has the model, so a stopped server or a
    model not pulled yet reads as unavailable instead of failing on every item."""
    try:
        response = (http or httpx.Client(timeout=3.0)).get(f"{base_url.rstrip('/')}/models")
        ids = {str(m.get("id", "")) for m in response.json().get("data", [])}
    except (httpx.HTTPError, ValueError, AttributeError):
        return False
    return model in ids or f"{model}:latest" in ids


def models_from_settings(settings) -> RoutedModels:
    """Build the routing table's clients. An endpoint without a key (or a URL) is left
    out, so its agents report unavailable instead of failing on every call."""
    from app.clients.ollama import OllamaEndpoint
    from app.config import GLIMMER_MODEL, check_routes

    routes = settings.model_routes()
    check_routes(routes)
    endpoints: dict[str, ChatEndpoint] = {}
    for route in routes.values():
        for model, url in ((route.model, route.endpoint), (route.backup, settings.endpoint_for(route.backup or ""))):
            if not model or not url or url in endpoints:
                continue
            key = settings.key_for(url)
            local = url.startswith(("http://127.0.0.1", "http://localhost"))
            if local and model == GLIMMER_MODEL:
                endpoints[url] = OllamaEndpoint(url)  # Glimmer's own turn format; see clients/ollama.py
            elif key or local:
                endpoints[url] = ChatEndpoint(url, key)
    backups = {r.backup: settings.endpoint_for(r.backup) for r in routes.values() if r.backup}
    return RoutedModels(routes, endpoints, backups)
