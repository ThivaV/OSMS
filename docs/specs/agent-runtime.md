# Spec: Agent runtime, guardrails, routing, decision log (Oct 30)

**Goal:** the specified agent machinery as boilerplate, before the Day 4–6
agents use it: one small loop, frozen guardrails as code, a routing table, and
a decision log. No prompts, no thresholds, no model calls to real providers —
those land with their agents. AGENTS.md §4 (*Techniques*, *Runtime*,
*Guardrails*) and `docs/specs/meta-models.md` are the contract.

## Inputs

- An `AgentSpec`: agent name, route, step limit, token budget, time limit,
  prompt version (run bounds, tunable; not clustering thresholds).
- A `ModelClient`: one method returning a normalized step (tool calls or a
  final payload, usage, optional commentary). The network clients: httpx with no
  SDK (`app/clients/openai_compat.py`, since Oct 30) and, for local Muse Glimmer,
  Ollama's raw API (`app/clients/ollama.py`, Oct 31); tests use fakes.
- Typed tools: name, OpenAI-style definition, a `call(args)` that validates
  with Pydantic. Plain code over SQLite and Milvus Lite; only the fetcher
  reaches the web, write tools touch only OSMS's own tables.

## Outputs

- `agent/runtime.py`: `call_once` (structured output; on a validation error
  retry once with the error, then give up and log it) and `run_tool_loop`
  (bounded steps; unknown tool, exhausted steps/tokens/time all stop the run
  and say so in the log). No framework, one file.
- `agent/decision_log.py`: `agent_runs`/`agent_steps` rows (tool, arguments,
  result summary, reason, model id, prompt version, tokens, latency, plus
  escalation/fallback and commentary). Personal data never reaches them:
  interests, questions and answers are scrubbed, and the log stores summaries,
  never source text.
- `agent/guardrails.py`: the frozen rules as code — which agents may fail over
  (judge, claims, verifier only), `assert_no_search` on outbound requests, and
  the scrubber. Changing these needs the author.
- `config.py` routing table: every agent → model id (pinned), endpoint,
  backup, effort. Switching the editor to Muse Wonder is config, not code.
  Contributor variants never appear in a reader path.
- Migration `0002`: the two decision-log tables.

## Rules

- **Author owns the core.** No thresholds, no prompts, no eval scoring here.
- **Backups never move personal data.** Only public-source-text agents fail
  over; interest, ask, editor and writer have no backup. Every fallback is
  logged. Tests enforce the matrix.
- **Bounded runs.** Step, token and time limits; hitting one stops the run
  with its reason in the log.
- **Fake models in tests.** No network calls from agent tests, ever.

## How to test

- `cd backend && uv run ruff check . && uv run pytest -q`.
- Runtime: success, retry-then-success, double-failure gives up and logs;
  unknown tool stops; step/token/time budgets each stop with their reason.
- Decision log: runs and steps persist with all specified fields; keywords and
  questions passed through args appear nowhere in the tables.
- Routing: all eight agents resolve; backups only where allowed; no
  `-contributor` id anywhere in a reader path.
