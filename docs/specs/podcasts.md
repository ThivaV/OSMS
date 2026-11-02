# Spec: Podcasts — browse, play, sources (Nov 2026)

**Goal:** a reader can see all their podcasts in one place, play any episode,
and see where it came from — the show, and the story it joined. Today episodes
are a dead end: ingestion drops enclosures, no endpoint serves them, and every
Play button is unwired. This spec closes the slice end to end.

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
- App: a Podcasts screen in the list pane (`_nav == 'podcasts'`), grouped by
  show: each row plays/pauses, shows duration and date, names its show, and
  links "Discussed in {story}" to the story when clustered. A now-playing card
  pins the current episode; one audio plays at a time (starting an episode
  pauses the briefing and vice versa). Entry points: the sidebar Podcasts row
  (phones get it through the Sources tab) and a ⌘K action. Empty state points
  at adding a podcast; episodes without audio say so instead of a dead button.
- `Episode` model + wire parsing, `EpisodePlayback` (just_audio, fakes in
  tests), Widgetbook cases (Normal/Empty/Extreme + playing/failed).

## Rules

- **Media stays where it is.** OSMS stores enclosure links, never audio files;
  playback streams from the publisher.
- **No silent items.** An episode without playable audio is labelled, not a
  dead Play button.
- **One audio at a time**, briefing included.
- **No new dependencies** (just_audio is already in).

## How to test

- Backend: adapter unit tests (RSS + JSON enclosures, duration shapes, bad
  URLs null); API tests (rule-7 visibility, demo public, story link, limit).
- App: `flutter analyze` + `flutter test` in both projects; Widgetbook regen.
- By hand: `/demo` → Podcasts → play a sample; follow a real podcast feed,
  wait for fetch, play the enclosure, open "Discussed in".
