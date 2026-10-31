# Spec: the story pipeline, one real story end to end (Days 4–6, built Oct 30)

**Goal:** Danish and English sources come in on their own schedules; items that report the
same event become one story; each story gets checked facts with the quotes they rest on,
where sources disagree, corrections that keep their history, and our own cited title and
summary; the app shows it all. Order decided Oct 30: this first, then papers, the briefing
and illustrations.

## Inputs

- `backend/seed/sources.opml`: 16 Danish and English feeds (tech, science, business, each
  with `language="da"`/`"en"`) next to the arXiv categories; plus every source a reader
  follows.
- `.env`: `META_API_KEY` (Muse Spark: claims, verifier, writer, and the judge's backup),
  `BASETEN_API_KEY` + `BASETEN_BASE_URL` (Muse Spark Open: the judge). All optional.
- The BGE-M3 weights (`uv sync --extra models`, downloaded on first use).

## Outputs

- **Worker** (`python -m app.worker run`, `make worker`, Tilt's `worker`): one process,
  one job at a time; Milvus Lite (`data/milvus.db`) in a child process it starts on
  `127.0.0.1` (faiss and torch can't share a process on macOS). A job never holds
  SQLite's write lock across a model call: the decision log writes on its own connection.
  - `fetch-source`: conditional GET (ETag/Last-Modified), per-host gaps (3 s for arXiv),
    every redirect and resolved address re-checked, 5 MB cap; RSS, Atom and JSON Feed to
    plain-text excerpts (never full articles); new or changed items saved first. The
    source is rescheduled: half its usual gap (5 min–6 h, ±10%), arXiv daily after
    05:15 UTC, errors doubling up to a day.
  - `process-item`: the triage agent (Muse Glimmer; unsure items to Muse Spark; the word
    list without them, and as a rule-3 tripwire): rule 3, noise, language, names. Dropped
    items keep their reason.
  - `index-item`: BGE-M3 dense + sparse into Milvus Lite, then the clustering decision.
  - `claims-item`: the claims agent, quotes checked against the item, then the verifier.
  - `write-story`: the writer agent, a new summary row when facts changed; a story with
    three sources then gets an `illustrate-story` job (Muse Image, checked by SAM 3.1).
  - Since Oct 31 also `make-briefing` (`docs/specs/morning-briefing.md`).
- **Tables** (migration `0003`): `items`, `jobs`, `stories`, `story_summaries`, `claims`
  (dated history: corrections supersede, nothing is overwritten), `disagreements`,
  `read_state`; fetch state on `sources`. Later: `0004` briefings, `0005` each agent
  run's subject, `0006` interest searches and matches, `0007` story illustrations.
- **API:** `GET /stories`, `GET /stories/{id}`, `POST /stories/{id}/read` (signed in);
  `GET /demo/stories`, `GET /demo/stories/{id}` (public, the seed sources). Since Oct 31:
  `.../ask` (`docs/specs/ask-story.md`), `.../decisions` (How OSMS decided), and
  `GET /visuals/{name}` for illustrations.
- **App:** Today reads the API (refreshing every minute and when the app comes back to
  the front); signed out, real demo stories replace the samples once they exist. The story
  page shows each fact's quote in its language with "Translated by OSMS", "One source so
  far", corrections struck through, links to the original articles, and why the story is
  in the list.

## Rules

- **Clustering (the author's rule, Oct 30):** join with no model only when close in
  meaning, close in time and naming the same things; any other similar pair goes to the
  judge; unsure stays apart. Thresholds (`services/clustering.py`) are provisional: the
  author sets them with the eval. Papers don't cluster until the eval has paper labels.
- **Critic before publish:** nothing is new or a disagreement until the verifier keeps it.
  A correction must come from the same source; a disagreement needs two sources.
- **Content rights:** feeds' own excerpts and headlines only, links to the original, our
  own summaries; quotes are short and attributed.
- **No keys, no pretending:** stories still form from clear matches, titled by their first
  headline, with "Reported by N sources"; no facts are invented.
- Guardrails as in AGENTS.md §4: source text is quoted data, no web search, backups only
  for judge/claims/verifier, prompts carry no reader data.

## How to test

- `make check-backend`: feeds (RSS, Atom, JSON Feed, arXiv, hostile ones refused), the
  fetcher (304, redirect to a metadata address refused, private DNS refused, Retry-After,
  size cap, arXiv's 3 s), scheduler, queue, language, names, the rule-3 list, the
  clustering rule, the model client (request shape, no web search, no body in errors,
  backups only where allowed), the whole pipeline on fakes and a real Milvus Lite (two
  languages → one story, quotes checked, a disagreement, a correction that keeps the old
  fact, cited summaries, and the no-keys path), and the stories API (demo, read state,
  rule 7).
- `make check-flutter`: stories parsed from the wire, shown with their evidence, marked
  read when opened; the demo's real stories replace the samples.
- By hand: `make worker` (or `uv run python -m app.worker once`), then
  `make pipeline-status`; open the app signed out to see the demo's real stories.
- `make eval` once `eval/labels/` has your labels.

## Not yet

- The agent task set in `eval/agents/`; your labels and the first eval numbers.
- Baseten for the judge: until the account is approved, Muse Spark judges (its backup).
  Real Muse Spark calls run since Oct 31: facts, summaries, Ask, the briefing.
