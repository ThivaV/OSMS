# Spec: Ask this story (Oct 30)

**Goal:** a reader types a question on a story page and gets an answer drawn
only from that story's verified claims, each sentence cited — or "Not reported
yet". Secondary (rule 4): it never replaces reading the story. AGENTS.md §1
and §10 item 20, architecture.md (*Ask this story*) define the contract; this
spec makes it buildable.

## Inputs

- **From the reader:** one typed question (1–280 characters), per story.
- **From the story:** its verified claims with quotes and source links —
  and nothing else. Never other stories, never the web, never the reader's
  other data.

## Outputs

- `AskResult`: the question, answer segments (`text` + `sources`, reusing
  `SummaryPoint`), and whether anything was reported.
- In the app: `AskStoryBox` at the end of the story page (after Every source),
  reached from the story toolbar. Five states: **idle** (suggestions included),
  **thinking**, **answered** (every sentence cited), **not reported** ("Not
  reported yet" + what the story does cover), **unavailable** (the answer
  service failed; ask again).
- Backend (when it lands): `POST /stories/{id}/ask` with `AskRequest`, answered
  by the ask agent on Muse Spark with no backup (the question is reader data).
  Until then the app shows thinking, then unavailable — a spec'd state, never a
  faked answer.

## Rules

- **Every answer sentence cites its sources** (publisher-first chips, never
  bare numbers). Code drops any sentence that doesn't cite one.
- **"Not reported yet"** instead of guessing. No hedging paragraph, no
  related-knowledge fill.
- **Nothing is stored or logged:** not the question, not the answer (rule 7,
  architecture.md). The decision log records that a question was answered
  (model id, prompt version, latency) without either text.
- **No search grounding**, no contributor variants (reader data), frozen.
- Suggested questions come from the story (its disagreements, its timeline),
  never from the reader's history.
- Rate-limited per reader; over the limit reads as unavailable.

## Steps

1. `core/models/ask.dart`: `AskResult` (question, segments, reported).
2. `shared/widgets/ask_story_box.dart`: the five states; suggestions when
   idle; retry when unavailable.
3. Story page: the box after Every source, toolbar jump button (speech icon).
4. `schemas/ask.py`: `AskRequest`/`AskResponse` with the cite-every-sentence
   invariant validated; tests on fakes.
5. `agent/ask.py` + prompt (Day 8, with the backend): claims-only context,
   structured output, citation check before responding.

## How to test

- `flutter analyze` + `flutter test` in both projects; new use cases render at
  every width and theme.
- Backend: over-long/empty questions refused; a response with an uncited
  sentence fails validation; a second reader's question never touches the
  first reader's data (nothing is stored at all).
- By hand in Widgetbook: each of the five states, then the toolbar jump.
