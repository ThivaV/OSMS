# Spec: arXiv as a main source, followed by keywords

**Goal:** a reader types their area of research in their own words, and OSMS pulls every
new arXiv paper related to it: papers that mention the keywords, and papers related to
them by meaning. Each paper says why it is there. arXiv category feeds work like any
other source.

## Inputs

- **From the reader:** keywords and phrases ("retrieval-augmented generation"), the
  related terms they accept, and optional arXiv categories. Edited in onboarding (when
  a research topic is picked), settings, the sidebar, the add-source sheet or ⌘K.
- **From the interest agent** (Muse Spark, structured output): suggested related terms,
  likely categories, and keywords flagged as outside rule 3. Its prompt holds only the
  keywords being edited.
- **From arXiv:** category feeds (`https://rss.arxiv.org/rss/<category>`) and the search
  API (`https://export.arxiv.org/api/query`).

## Outputs

- `interests` rows per reader: keywords, accepted related terms, categories, flagged
  keywords.
- One shared arXiv query per distinct plan, stored as a source; papers stored once as
  items of kind `paper` (title, authors, abstract, categories, arXiv id, version, links).
- `interest_matches` rows per reader: interest, paper, reason (matched terms, or related
  by meaning with its score), time.
- In the app: Today's "New research for you", the paper card, and "N new" per interest in
  the sidebar.

## Rules

- **arXiv's limits:** one request every three seconds and one connection, across all of
  OSMS (API, RSS and OAI-PMH together). Cache API results for the day. `max_results` at
  most 2000 per call; never page past 30,000 results.
- **Never store, cache or serve PDFs or full text.** Metadata is CC0. Link to the
  abstract page and the PDF on arXiv. Never imply arXiv endorses OSMS; no arXiv logo.
- **Rule 3:** the category list leaves out political and social categories; flagged
  keywords are shown struck through and never searched.
- **Rule 7:** interests and matches are personal. Queries sent to arXiv carry search text
  only. A shared query never tells one reader that another follows the same keywords.
- **The author decides:** the related-by-meaning threshold, the daily cap on borderline
  papers sent to the agent, and when papers start feeding clustering (only once the eval
  has labelled paper examples).
- **Prompts:** research keywords count as topics under the frozen prompt guardrail in
  AGENTS.md (the author's decision). The interest agent sees the keywords it is working
  on, never who typed them, and the decision log records its steps without them.

## Built Oct 31 (v1)

- Saving interests (onboarding or `PUT /me/interests`) points each at its arXiv search
  (`services/interests.py`): quoted phrases in `ti:`/`abs:`, its categories, newest first,
  100 results. The same words, in any order or case, give the same URL, stored once as a
  shared source titled "arXiv search" (never the words). Fetched daily after 05:15 UTC
  like the category feeds, through the one rate-limited client (3 s per arXiv host).
- The first fetch is the backfill: papers up to 30 days old (other items: 14).
- Every kept paper, from a search or a category feed, is matched against interests by
  the words it uses (keywords and accepted related terms, whole words); an interest with
  categories only takes papers from its own search or those categories' feeds. Each
  match records the words, per reader (`interest_matches`, migration `0006`).
- `GET /me/research`: the reader's papers from the last two weeks, each with its words;
  the app's "New research for you" shows them signed in.
- The interest agent (Muse Spark, no backup, keywords redacted from the decision log):
  related terms, categories and rule-3 flags as the reader types
  (`POST /me/interests/suggest`, rate-limited); suggestions also pass the rule-3 word
  list; flags accumulate on screen and are never searched or stored.
- Interests saved before searches existed get theirs when the worker starts.
- **Not yet:** related by meaning (needs your threshold), the borderline yes/no and its
  daily cap, the paper count before saving, the sidebar's "N new",
  authors and categories on the card, and one connection across processes (the API
  never calls arXiv today, so the worker's client is the only one).

## Steps

1. Parse category feeds and API results into `Item`s of kind `paper` (done: the generic
   `adapters/feed.py` handles both); one rate-limited arXiv client in the fetcher (done:
   3 s per arXiv host).
2. `services/interests.py`: build the query from a plan (quoted phrases in `ti:` and
   `abs:`, joined with `OR`, `AND cat:` when categories are picked, sorted by
   `submittedDate`), share identical queries, run the daily update and the 30-day
   backfill, record matches with reasons. (Done Oct 31, without plans: an interest's own
   words and accepted terms are its search.)
3. Related by meaning: embed papers and interests with BGE-M3, hybrid search per
   interest, apply the threshold, send borderline papers (capped) to the interest agent.
4. The interest agent and its prompt (`services/interest_agent.py`,
   `prompts/interest.md`): keywords → suggestions (done Oct 31); yes or no on borderline
   papers (not yet).
5. API routes for interests; wire the app's `InterestsEditor` (done), Today section
   (done) and the sidebar's "N new" (not yet).

## How to test

- Adapter tests on hand-written fake feeds and API responses (`arxiv.example`), never
  saved copies of real ones.
- Query builder: phrases quoted, categories applied, flagged keywords left out, identical
  plans give identical queries.
- The rate-limited client never sends two requests less than three seconds apart, and
  never two at once (fake clock).
- A second reader sees none of the first reader's interests or matches (rule 7 test).
- No PDF URL is ever fetched: the fetcher refuses `arxiv.org/pdf/` paths.
- The interest agent runs against a fake model; its output validates against the schema.
  Its prompt holds no user id, name or email, and its decision-log steps hold no
  keywords.
- The eval: labelled examples of papers with their news coverage before papers feed
  clustering.
- Widgetbook: `InterestsEditor`, the paper `ItemCard` and `TodayOverview` with research
  render at every width and theme (`flutter test` in `frontend/widgetbook/`).
