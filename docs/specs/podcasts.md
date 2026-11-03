# Spec: Podcasts — browse, play, sources (Nov 2026)

**Goal:** a reader can see all their podcasts in one place, play any episode,
and see where it came from — the show, and the story it joined. Episodes were
a dead end: ingestion dropped enclosures, no endpoint served them, and every
Play button was unwired. Built: this spec closed the slice end to end
(migration `0009`, `backend/app/api/episodes.py`).

## Inputs

- **Followed podcast feeds** (RSS with audio enclosures, or JSON Feed with
  audio attachments), fetched like any feed. Rule 7 holds: a reader sees only
  their own sources' episodes; the demo sees the seed's.
- **The demo's samples**, clearly labelled, with openly-licensed sample audio
  so judges can press play.

## Outputs

- Ingestion: the feed adapter reads audio enclosures (`audio/*`, first one
  wins) and `itunes:duration` (seconds, `MM:SS` or `H:MM:SS`, capped at 24h);
  an entry with an audio enclosure becomes kind `episode`. JSON Feed
  attachments work the same way. Presence decides the kind, validation decides
  the link: bad enclosure URLs fail closed to null — the item stays, the audio
  doesn't.
- Storage: `items.audio_url` + `items.duration_s` (migration `0009`),
  persisted on create and refreshed when the feed changes them.
- API: `GET /episodes` and `GET /demo/episodes` (`limit`, default 50, max 100),
  newest first: id, title, excerpt, published date, duration, audio URL, the
  show (id, title, type, language), and the story it joined (id + title, when
  clustered). Rule 7 scoping like `/stories`.
- App: episodes live in the Listen hub (`_nav == 'listen'`, spec:
  `docs/specs/listen.md`), grouped by show: each row plays/pauses, shows
  duration and date, names its show, and links "Discussed in {story}" to the
  story when clustered. A now-playing card pins the current episode; one audio
  plays at a time (starting an episode pauses the briefing and vice versa).
  Entry points: the sidebar Listen row and a ⌘K action. Empty state points at
  adding a podcast; episodes without audio say so instead of a dead button.
- `Episode` model + wire parsing, `EpisodePlayback` (just_audio, fakes in
  tests), Widgetbook cases (Normal/Empty/Extreme + playing/failed, plus
  Filtered to one show and Loading older episodes).

## Rules

- **Media stays where it is.** OSMS stores enclosure links, never audio files;
  playback streams from the publisher.
- **No silent items.** An episode without playable audio is labelled, not a
  dead Play button.
- **One audio at a time**, briefing included.
- **No new dependencies** (just_audio is already in).

## How to test

- Backend: adapter unit tests (RSS + JSON enclosures, duration shapes, bad
  URLs null); API tests (rule-7 visibility, demo public, story link, limit,
  full history walk without gaps, mid-browse insert, show filter, forged
  cursor → 422).
- App: `flutter analyze` + `flutter test` in both projects; Widgetbook regen.
  Flow test: 55 fake episodes across two shows — first page holds fifty, the
  button pages in the rest (subtitle counts 55, button gone), a show chip
  filters to its own history. Render tests cover normal, filtered, loading
  older, empty and unavailable.
- By hand: `/demo` → Listen → play a sample; follow a real podcast feed,
  wait for fetch, play the enclosure, open "Discussed in".

## Whole playlist: history, paging, show filter

A reader with years of episodes reaches all of them, oldest last, and can
narrow to one show's history. Research consensus: cursor (keyset) paging on a
`(published_at, id)` composite with an opaque cursor — no skips or duplicates
when new episodes land mid-browse — plus explicit per-show filters and an
explicit older-action (no surprise infinite scroll).

- API: `GET /episodes` (and `/demo/episodes`) take `cursor` (opaque,
  base64url JSON of the last seen `(published_at, id)`; malformed → 422) and
  `source_id` (one show's history; unknown → empty list, not 404). Responses
  add `next_cursor` (null: history ends) and `shows` (every in-scope show with
  episodes, alphabetical — the chips stay stable while paging or filtering).
  `limit` stays the page size (default 50, max 100).
- App: a `PodcastsController` accumulates pages (`Show older episodes`
  appends; a filter resets to page one). Show chips sit under the header
  ("All shows" + each show, hidden for a single show); the list keeps its
  grouping, the subtitle names the filter.
- Samples paginate nowhere (three invented episodes); the filter still works
  over them so the demo shows the shape.
