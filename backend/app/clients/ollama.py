"""Muse Glimmer on a local Ollama, for the triage agent.

Ollama 0.40 renders the GGUF's own chat template, which opens every answer on Glimmer's
reasoning channel (`<|start|>assistant to=self<|message|>`) with `<|message|>` as a stop,
so through `/v1/chat/completions` every answer comes back empty, and a Modelfile
TEMPLATE doesn't replace it (Oct 31). So this client writes Glimmer's turns itself and
calls the raw generate API, opening the answer channel (`to=user`) directly: the JSON
schema then constrains the answer itself. Triage needs no reasoning channel; tested on
our own items, answering directly was as right and twice as fast."""

import json
from typing import Any

import httpx

from app.agent.guardrails import assert_no_search
from app.agent.runtime import ModelError, ModelStep, ModelUsage

TIMEOUT_S = 300.0  # the first call loads 18 GB
_STOPS = ["<|eot|>", "<|eom|>", "<|start|>"]


def render(system: str, messages: list[dict[str, Any]], effort: str | None) -> str:
    """Glimmer's turn format, ending on an open answer channel."""
    parts = [
        (
            f"<|start|>system<|message|>{system}\n\nReasoning strength: {effort or 'low'}.\n\n"
            '# Valid recipients: "self", "user".<|eot|>'
        )
    ]
    for message in messages:
        if message["role"] == "user":
            parts.append(f"<|start|>user<|message|>{message['content']}<|eot|>")
        elif message["role"] == "assistant":
            parts.append(f"<|start|>assistant to=user<|message|>{message.get('content') or ''}<|eot|>")
    parts.append("<|start|>assistant to=user<|message|>")
    return "".join(parts)


class OllamaEndpoint:
    def __init__(self, base_url: str, *, http: httpx.Client | None = None) -> None:
        # Settings hold the OpenAI-compatible URL (…/v1); the raw API lives at the root.
        self.root = base_url.rstrip("/").removesuffix("/v1")
        self.http = http or httpx.Client(timeout=TIMEOUT_S)

    def complete(
        self,
        *,
        model: str,
        system: str,
        messages: list[dict[str, Any]],
        tools: list[dict[str, Any]],
        schema: dict[str, Any] | None = None,
        effort: str | None = None,
    ) -> ModelStep:
        if tools:
            raise ModelError(f"{model}: no tools on Ollama's raw API")
        body: dict[str, Any] = {
            "model": model,
            "raw": True,
            "prompt": render(system, messages, effort),
            "stream": False,
            "options": {"temperature": 0.2, "num_predict": 800, "stop": _STOPS},
        }
        if schema is not None:
            body["format"] = schema
        assert_no_search(body)
        try:
            response = self.http.post(f"{self.root}/api/generate", json=body)
        except httpx.HTTPError as error:
            raise ModelError(f"{model} unreachable: {type(error).__name__}") from None
        if not response.is_success:
            raise ModelError(f"{response.status_code} from {model}")  # never the body
        out = response.json()
        text = str(out.get("response") or "")
        try:
            final = json.loads(text) if schema is not None else {"text": text}
        except ValueError:
            final = None
        return ModelStep(
            final=final if isinstance(final, dict) else None,
            reason=str(final.get("reason", "")) if isinstance(final, dict) else "",
            usage=ModelUsage(int(out.get("prompt_eval_count") or 0), int(out.get("eval_count") or 0)),
            model=model,
        )
