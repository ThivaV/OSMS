# Spec: Meta models, routing, backups and checks

**Goal:** one model layer that every agent and service uses. Each agent runs on the Meta
model that suits it, fails over safely, and every generated output is checked by a
different model before a reader sees it. AGENTS.md (*Meta models*, *Agents*) has the why.

## Inputs

- Keys from the environment (names in `.env.example`): `META_API_KEY`,
  `BASETEN_API_KEY`, `GLIMMER_BASE_URL`, `GLIMMER_API_KEY`.
- Model ids pinned in `backend/app/config.py`, never in the environment.
- Endpoints for Muse Image, SAM 3.1 and Muse Voice Transcribe from dev.meta.ai/docs,
  confirmed against the live API on Oct 31 (below).

## Outputs

- **A routing table** in `config.py`: for each agent (triage, interest, judge, claims,
  verifier, editor, writer, ask), its model id, endpoint, reasoning effort and backup.
- **One text client** over httpx, no SDK (`clients/openai_compat.py`), for Meta Model
  API, Baseten and a hosted Muse Glimmer, all OpenAI-compatible. **Local Muse Glimmer**
  through Ollama's raw generate API in Glimmer's own turn format (`clients/ollama.py`):
  through Ollama's `/v1/chat/completions` its answers come back empty.
- **Media clients** in `backend/app/clients/`: Muse Image and SAM 3.1
  (`meta_media.py`: draw a WebP; noun-phrase prompts → boxes with confidence), Muse
  Voice Transcribe (`meta_voice.py`: a WAV back to text, biased to its language).
- **Checks:** SAM 3.1 on every illustration; Muse Voice Transcribe on every briefing.
- **Decision-log fields:** model id, escalation, fallback, Muse Spark Open's commentary.

## Rules

- **Escalation:** triage (Muse Glimmer) hands unsure items to Muse Spark; the verifier
  re-runs unsure cases at maximum reasoning effort.
- **Backups:** judge → Muse Spark; claims and verifier → Muse Spark Open. No backup for
  agents that see reader data (interest, ask, editor, writer). Every fallback is logged.
- **Illustrations:** prompt from OSMS's own summary title in a house-style prompt
  (reference images from `backend/seed/visual-style/`: not yet), no web references. SAM 3.1 prompts: "a person", "a face",
  "a logo", "text". Flagged → redraw once → drawn art. Labelled "Illustration".
- **Briefing check:** transcribe each chapter back, compare with its script, remake a
  chapter that drifts (the threshold is the author's call). Muse Voice Transcribe
  supports English and Tamil, not Danish: Danish chapters are checked by SeamlessM4T's
  own speech recognition until the author decides.
- **Never:** search grounding; contributor variants on anything per reader; third-party
  images, arXiv PDFs or YouTube video to any model.
- **The author picks the model** per agent from the agent task set's results.
- **Frozen:** the illustration, no-web-search and backup rules are guardrails in
  AGENTS.md; change them only with the author. Tests below enforce them.

## Steps

1. Routing table and the text client; fake models for tests. **Done Oct 30.**
2. Backups and the decision-log fields. **Done Oct 30.**
3. Triage on Muse Glimmer (Ollama locally: Q4_K_M, 18 GB, fine on the author's 48 GB
   Mac). **Done Oct 31.**
4. Model comparison in `eval/agents/`: editor on Muse Spark vs Muse Wonder, judge on
   Muse Spark Open vs Muse Spark (quality, cost, latency). Not yet.
5. Muse Image + SAM 3.1 check and crops. **Done Oct 31.**
6. Muse Voice Transcribe: the briefing check (**done Oct 31**); podcasts with keyword
   biasing (not yet).

## How to test

- Routing: each agent resolves to its configured model; switching one is a config change.
- Backups: a fake outage on each provider moves only the allowed agents, logs it, and
  never sends an interest, ask, editor or writer prompt to the backup.
- Escalation: an unsure fake triage verdict reaches the fake Muse Spark.
- Illustration check (`tests/test_visuals.py`): fake SAM results that flag a face → one
  redraw → drawn art; a clean result → stored with its focus; real SAM records parsed.
- Briefing check (`tests/test_briefing.py`): a fake transcript that drifts remakes that
  chapter only, then leaves it out.
- Glimmer on Ollama (`tests/test_triage.py`): the raw request in Glimmer's turn format,
  no `reasoning_effort`, no body in errors.
- Schemas (`tests/test_agent_schemas.py`): every list a model must fill is required.
- No request ever enables search grounding or uses a `-contributor` id for reader data
  (asserted on the fake client).

## Confirmed against the live API (Oct 31)

- **Muse Image** (`POST /v1/images/generations`): `model`, `prompt`, `n`, `size`,
  `response_format: "b64_json"`, `output_format: "png" | "webp"`. It refuses
  `enable_image_search` as an unknown parameter: there is no image search to turn off.
  Asked for `1024x1024`, it returned 1600×1600 (PNG about 3 MB, WebP about 0.5 MB, in
  12–19 s). The response is `{"data": [{"b64_json"}], "output_format", "usage", ...}`.
- **SAM 3.1** (`POST /v1/responses`, model `sam-3.1`): one noun phrase and one image (a
  PNG or WebP data URL) per request; the answer is in `output[0].content[0].text`, one
  record per match, `<|box;x1;y1;x2;y2;w;h;c|><|mask;...|>`, empty when nothing matches.
  `metadata.include_confidence: "true"` adds `c`. 3–4 s per call.
- **Muse Voice Transcribe** (`POST /v1/asr/transcribe`): multipart `request` (JSON) and
  `audio` (16 kHz mono 16-bit WAV); `languageBias` takes names (`["English"]`,
  `["Tamil"]`); answers `transcript`, `audioDurationMs`. English and Tamil worked on our
  own generated speech; Danish isn't supported.
