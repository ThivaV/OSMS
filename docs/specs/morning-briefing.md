# Spec: the morning briefing (built Oct 31)

**Goal:** OSMS's podcast. Each morning a short audio briefing, one chapter per story, in
the reader's language (English, Danish or Tamil), every sentence resting on the story's
checked facts, and every chapter checked by transcribing it back before anyone hears it.
AGENTS.md *Podcasts* sets what makes each part.

## Inputs

- The reader's stories (their sources pick them; rule 7) with kept facts, and which facts
  are new since their last briefing. Signed out: the demo's, from the seed sources.
- `META_API_KEY`: the editor and writer (Muse Spark) and the check (Muse Voice Transcribe).
- The speech models (`uv sync --extra models`, downloaded on first use): SeamlessM4T v2
  for English and Danish, MMS-TTS for Tamil. CC-BY-NC 4.0: check the hackathon's rules,
  never sell the audio.

## Outputs

- `briefings` (migration `0004`): one row per briefing, never overwritten: language,
  chapters (story, spoken title, cited sentences, new-fact count, start and length in the
  audio, which model checked it and how closely), one WAV in `data/briefings/`.
- Worker job `make-briefing` (ref: a reader's id, or `demo`): from 06:00 UTC daily for the
  demo and each onboarded reader; `make briefing`, Tilt's **Make briefing now**.
- API: `GET /briefings/latest` (signed in, only the reader's own), `GET /demo/briefing`,
  `GET /briefings/{id}/audio?expires=&signature=` (signed for 12 hours with a key that
  lives as long as the API process; byte ranges for seeking).
- App: the floating bar and the full player play the real audio (just_audio), on the
  web (an `<audio>` element) and on macOS (AVPlayer, with App Transport Security's
  local-networking exception for plain http to localhost); samples and Widgetbook keep
  simulated playback.
- Deleting an account deletes its briefings and their audio files.

## Steps

1. **Editor** (Muse Spark, `prompts/editor.md`): up to five stories, most important first,
   from the reader's stories with kept facts. Without it: new facts, then sources, then
   newest.
2. **Writer** (Muse Spark, `prompts/briefing.md`): a spoken title and two to four
   sentences per story, each citing its facts; code drops any sentence citing nothing the
   story has kept. Tamil names and numbers in Tamil script (MMS-TTS reads nothing else).
3. **Voice** (`services/speech.py`): sentence by sentence, short pauses between.
4. **Check:** each chapter transcribed back (Muse Voice Transcribe for English and Tamil;
   SeamlessM4T v2's own recognition for Danish) and compared with its script by
   characters. Below 0.8: remade once with another voice, then left out. The intro (no
   facts in it) is checked the same way. No way to check a language: no briefing.
5. One file, chapters by offset; the row is written last, so a failed run leaves nothing.

## Rules

- Nothing unchecked reaches a reader; nothing the facts don't say is spoken.
- A reader's briefing is theirs alone: their sources' stories, served only to them.
- No backup for the editor or writer (reader data); no web search.

## Open: the author decides

- **Danish audio's check.** Muse Voice Transcribe doesn't do Danish, so SeamlessM4T
  checks its own speech: a weaker check than "a different model". Options: keep it
  (labelled), or give Danish readers English audio until a second Danish recogniser
  exists.
- **The 0.8 bar** (`CHECK_SIMILARITY`), from real chapters.
- **Reader time zones:** 06:00 UTC is 07:00 in Denmark in winter, 08:00 in summer.
- Not yet: the editor's review-and-revise loop, cover art (Muse Image + SAM 3.1), the
  intro sting (MusicGen), questions while listening.

## How to test

- `make check-backend`: `tests/test_briefing.py` (cited script, drift remade then left
  out, no checker → no briefing, the similarity measure, the signed URL and byte ranges,
  rule 7, the daily schedule).
- `make check-flutter`: the demo briefing plays its audio and jumps by chapter (a fake
  player).
- `make test-macos`: the real macOS app plays, seeks and pauses a briefing served from
  localhost with byte ranges (`integration_test/briefing_audio_test.dart`). The same
  check passed in Chrome on Oct 31.
- By hand: `make briefing`, wait for the worker, open the app signed out and press play.
