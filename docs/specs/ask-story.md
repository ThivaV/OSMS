# Spec: Ask this story (Oct 30; built Oct 31)

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
- Backend (built Oct 31): `POST /stories/{id}/ask` (signed in, only stories from
  the reader's sources: anything else is a 404) and `POST /demo/stories/{id}/ask`
  (signed out, the demo's stories), answered by the ask agent on Muse Spark with
  no backup (the question is reader data). No key: 503, which the app shows as
  unavailable. The invented samples can't be asked: the box says so.

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
- Rate-limited: 12 questions per reader per 10 minutes, 6 per address for the
  demo (`api/stories.py`); over the limit (429) reads as unavailable.

## Steps

1. `core/models/ask.dart`: `AskResult` (question, segments, reported).
2. `shared/widgets/ask_story_box.dart`: the five states; suggestions when
   idle; retry when unavailable.
3. Story page: the box after Every source, toolbar jump button (speech icon).
4. `schemas/ask.py`: `AskRequest`/`AskResponse` with the cite-every-sentence
   invariant validated; tests on fakes.
5. `services/ask.py` + `prompts/ask.md` (built Oct 31): kept, current claims only,
   structured output, sentences citing no known claim dropped; the question
   redacted from the decision log; the routes in `api/stories.py`.
6. App (built Oct 31): `ApiClient.ask`, wired in the home screen; an answer to a
   story the reader has since left is ignored.

## How to test

- `flutter analyze` + `flutter test` in both projects; new use cases render at
  every width and theme.
- Backend (`tests/test_ask.py`, `tests/test_ask_api.py`): over-long/empty
  questions refused; uncited sentences dropped; "Not reported yet"; the question
  never reaches the decision log; a reader can't ask a story outside their
  sources; the rate limit; no agent → 503.
- App (`test/stories_test.dart`): a reader's and the demo's questions reach the
  right route; a failure offers to ask again.
- By hand in Widgetbook: each of the five states, then the toolbar jump.
