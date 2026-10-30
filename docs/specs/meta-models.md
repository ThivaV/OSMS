# Spec: Meta models, routing, backups and checks

**Goal:** one model layer that every agent and service uses. Each agent runs on the Meta
model that suits it, fails over safely, and every generated output is checked by a
different model before a reader sees it. AGENTS.md (*Meta models*, *Agents*) has the why.

## Inputs

- Keys from the environment (names in `.env.example`): `META_API_KEY`,
  `BASETEN_API_KEY`, `GLIMMER_BASE_URL`, `GLIMMER_API_KEY`.
- Model ids pinned in `backend/app/config.py`, never in the environment.
- Endpoints for Muse Image, SAM 3.1 and Muse Voice Transcribe, taken from dev.meta.ai/docs
  when their clients are written (the product pages don't give them).

## Outputs

- **A routing table** in `config.py`: for each agent (triage, interest, judge, claims,
  verifier, editor, writer, ask), its model id, endpoint, reasoning effort and backup.
- **One text client** (OpenAI Python SDK; ask before adding it) for Meta Model API,
  Baseten and the Muse Glimmer server, all OpenAI-compatible.
- **Media clients** in `backend/app/clients/`: Muse Image (generate with reference
  images), SAM 3.1 (noun-phrase prompts → boxes and masks), Muse Voice Transcribe
  (keyword biasing).
- **Checks:** SAM 3.1 on every illustration; Muse Voice Transcribe on every briefing.
- **Decision-log fields:** model id, escalation, fallback, Muse Spark Open's commentary.

## Rules

- **Escalation:** triage (Muse Glimmer) hands unsure items to Muse Spark; the verifier
  re-runs unsure cases at maximum reasoning effort.
- **Backups:** judge → Muse Spark; claims and verifier → Muse Spark Open. No backup for
  agents that see reader data (interest, ask, editor, writer). Every fallback is logged.
- **Illustrations:** prompt from OSMS's own summary, house-style references from
  `backend/seed/visual-style/`, no web references. SAM 3.1 prompts: "a person", "a face",
  "a logo", "text". Flagged → redraw once → drawn art. Labelled "Illustration".
- **Briefing check:** transcribe each chapter back, compare with its script, remake a
  chapter that drifts (the threshold is the author's call). Only for languages Muse
  Voice Transcribe supports; check Danish and Tamil first.
- **Never:** search grounding; contributor variants on anything per reader; third-party
  images, arXiv PDFs or YouTube video to any model.
- **The author picks the model** per agent from the agent task set's results.
- **Frozen:** the illustration, no-web-search and backup rules are guardrails in
  AGENTS.md; change them only with the author. Tests below enforce them.

## Steps

1. Routing table and the text client; fake models for tests.
2. Backups and the decision-log fields.
3. Triage on Muse Glimmer (Ollama locally; check memory on the author's Mac first).
4. Model comparison in `eval/agents/`: editor on Muse Spark vs Muse Wonder, judge on
   Muse Spark Open vs Muse Spark (quality, cost, latency).
5. Muse Image + SAM 3.1 check and crops.
6. Muse Voice Transcribe: podcasts with keyword biasing; the briefing check.

## How to test

- Routing: each agent resolves to its configured model; switching one is a config change.
- Backups: a fake outage on each provider moves only the allowed agents, logs it, and
  never sends an interest, ask, editor or writer prompt to the backup.
- Escalation: an unsure fake triage verdict reaches the fake Muse Spark.
- Illustration check: fake SAM results that flag a face → one redraw → drawn art; a clean
  result → crops for every card shape.
- Briefing check: a fake transcript that drifts from the script remakes that chapter only.
- No request ever enables search grounding or uses a `-contributor` id for reader data
  (asserted on the fake client).
