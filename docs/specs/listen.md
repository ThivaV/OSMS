# Listen: one hub for every audio and video

The sidebar Podcasts row becomes **Listen**: the reader's whole listenable
world in one list — today's briefing, past briefings, podcast episodes, and
videos — where every row names the source documents behind it. Research
consensus: one library with explicit type filters (Spotify's All/Music/Podcasts
chips, Pocket Casts' filter tab), the briefing as a made-for-you hero rather
than one more row (it is narrated for this reader, this morning), an explicit
older-action instead of infinite scroll, and episode detail that resolves to
show notes with links (our story detail already is that page: summary, claims
with cited quotes, disagreements, timeline, every source).

## What lives here

- **Briefing hero.** Today's briefing, playable, with its date, duration and
  chapter count — then the stories it covers, as story links. A briefing is a
  spoken pass over documents; the documents stay one tap away.
- **Past briefings.** The reader's own earlier briefings, newest first, each
  playable. Playing one swaps the briefing slot to it (one audio at a time);
  the hub names which briefing is playing and offers the way back to today's.
- **Podcast episodes.** Unchanged mechanics: show chips, cursor paging behind
  `Show older episodes`, `Discussed in` opens the story, no-audio rows labelled.
- **Videos.** Rows, not a player: OSMS adds no video dependency. Each names its
  publisher and duration when stated, opens the publisher page in the browser,
  and opens the story when clustering placed it in one. A video in no story
  says so honestly instead of offering a dead link.

Type chips sit under the header — All, Briefings, Episodes, Videos — and the
show chips appear as today under Episodes. The header counts what the filter
holds. Empty states stay specific per type, never a shared shrug.

## API

- `GET /briefings` (reader): the reader's own briefings that have audio,
  newest first, `limit` default 30 max 100. The envelope is `{"briefings":
  [...]}` of full `BriefingOut` rows, each with a freshly signed `audio_url`
  — signatures are short-lived, so history signs at request time like latest
  does. Empty: `[]`, never 404.
  `GET /demo/briefings`: the seed rows, public.
- `GET /videos` (reader): video items from the reader's followed sources,
  newest first, `limit` default 50 max 100. Each: id, title, source, published
  date, duration when the feed states one, the publisher `link`, and
  `story_id`/`story_title` when clustering placed it in one. Dropped items
  excluded. Empty: `[]`. `GET /demo/videos`: the seed rows, public.
- Rule 7 throughout: briefings are the reader's own rows; videos come only
  from sources they follow. Nothing about interests or questions is logged.

## App

- `ListenScreen` replaces `PodcastsScreen` (same frozen look, new title and
  type chips). Sidebar row, command palette action and phone entry point move
  to Listen; the phone Briefing tab keeps playing what the slot holds.
- `selectedBriefingProvider`: the briefing the slot plays — latest by default,
  a past one while the reader chose it. Home's floating bar, mini player and
  phone tab all read the slot; Listen's hero offers `Back to today's briefing`
  while a past one plays. Choosing a past briefing pauses any episode, and
  playing an episode or the latest briefing clears nothing — the slot simply
  holds what was chosen last.
- Briefing rows (hero and history) list their chapters' stories as links; the
  links open story detail, whose Every-source section is the source documents.
- Video rows open the publisher page with `launchUrl` (already a dependency,
  as story detail does); without a URL there is no Watch button, only the
  publisher's name.

## Rules

- **Media stays where it is.** Enclosure links, signed briefing URLs, publisher
  pages — OSMS stores and serves links, never media files.
- **No silent or dead buttons.** No-audio episodes labelled; videos without a
  link get no Watch button; a briefing whose audio file is gone drops out of
  history like latest does (audio rows only).
- **One audio at a time**: briefing slot or one episode, never both.
- **No new dependencies** (`url_launcher`, `just_audio` already in).

## How to test

- Backend: history newest-first, only the reader's own rows, audio-less rows
  excluded, per-row signed audio URLs verify; demo public; videos scoped to
  followed sources, dropped excluded, story link present/absent honestly.
- App: `flutter analyze` + `flutter test` in both projects; Widgetbook regen.
  Flow: type chips narrow the list; playing a past briefing swaps the slot and
  the hero offers the way back; a video with a story opens it; a video without
  one says so. Render: hero, history, filtered, video rows, empty per type.
- By hand: `/demo` → Listen → play today's briefing, open a chapter's story,
  page episodes, filter, open a video's publisher page.
