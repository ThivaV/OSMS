# "OSMS, presented by Biscuit": the script (3:00)

Every line Biscuit says, and what's on screen while it says it. The lines live in
`scenes.py`. This page is for reading; `compose.py` times the cut from Biscuit's real speech
(the final times are in `build/timeline.json` after a build). Biscuit's lines are spelled
for the voice there ("O S M S", "Sam three point one"); the captions here spell them for
the eye.

The order follows the brief: the problem, then how OSMS solves it in the live app, then
the Meta models and the architecture, then where to try it.

| # | Time | On screen | Biscuit says |
|---|---|---|---|
| 0 | 0:00 | **Title.** OSMS, One Story, Many Sources; Biscuit beside it. | |
| 1 | 0:01 | **The problem.** Ten source tabs, then three real headlines for one event (Apple's next iPads, Nov 2: 9to5Mac, Engadget, GSMArena), then the questions. Biscuit beside it, waving. | Hi, I'm Biscuit! Every morning, the same news reaches you ten times: tech sites, a Danish paper, a podcast, a research paper. What's new? Where do they disagree? Who said what? Ten tabs, one story. |
| 2 | 0:18 | **Meet OSMS.** The live demo's Today, scrolling: one card per event, the publishers' own pictures. | Meet OSMS: One Story, Many Sources. It reads every source you follow, in any language, turns each event into one story, and traces every sentence back to its sources. |
| 3 | 0:34 | **One story.** Search opens #706 *Apple Launches iPad Mini*: three sources, every sentence with its source chips, then **What's new**. | Here's one story from three sources. Every sentence names its sources, and a tap opens the original: OSMS links, it never copies. What's new shows only what changed since your last visit. |
| 4 | 0:49 | **Disagreements, corrections, languages.** #516: *Sources agree so far*, then the timeline's **Corrected** entry (9to5Mac changed a date). #309: a Danish quote with **TRANSLATED BY OSMS**. | When sources disagree, both sides sit next to each other. Corrections land in a dated timeline, never quietly overwritten. And languages mix: a Danish quote stays Danish, with a labelled translation. |
| 5 | 1:04 | **How OSMS decided.** #706's decisions: *Checked the item* (Muse Spark), *Same story?* (Muse Spark Open), *Found the facts*, *Checked the facts*, *Wrote the summary*, each with tokens and seconds. | My favourite part: How OSMS decided. Every model call behind a story is on its page: which Meta model, what it changed, its tokens and latency. Nothing generated reaches you unchecked. |
| 6 | 1:20 | **Listen.** The Listen hub: today's briefing and its five chapters, played; earlier briefings; podcasts. | Every morning, OSMS makes you a short podcast of your top stories. Each sentence cites a checked fact, and Muse Voice Transcribe listens back to every chapter before you hear it. |
| 7 | 1:36 | **Listen in.** #706's own **Listen** button plays its chapter, and the real briefing speaks: SeamlessM4T v2's voice. | (the briefing) "Engadget reports that Apple launched its iPad mini last week." |
| 8 | 1:40 | **Ask this story.** *What is new here?* A real answer from Muse Spark, every sentence with its sources, "answered only from this story's verified facts". | Curious? Ask the story. Answers come only from its checked facts, with sources. If the sources never said it, OSMS says so instead of guessing. |
| 9 | 1:53 | **Make it yours** (signed in). **Add a source** → `macrumors.com` → **Find**: a feed in English, about 19 posts a day, its latest three → **Subscribe**. Then a story **saved**, and **Saved**. | And it's your reader. Paste any site, feed or social handle: OSMS finds the feed and previews it before you follow. Save a story, and it's there on the web and your Mac. |
| 10 | 2:10 | **Seven Meta models.** Each lights up as Biscuit names it, with its job. | Seven Meta models do the work. Muse Spark triages, checks facts and writes. Muse Spark Open decides which reports are one event. Muse Image illustrates, SAM 3.1 checks each picture, and SeamlessM4T and MMS-TTS speak the briefing. |
| 11 | 2:30 | **Architecture.** Sources → safe fetcher → worker; the pipeline (triage, embed, cluster with the judge, facts and their check, writing, voice); SQLite + Milvus Lite → FastAPI → the Flutter app. Links only; one reader's data never reaches another. | Under the hood, a pipeline, not a chatbot. A safe fetcher feeds a FastAPI worker that triages, clusters, checks and writes. One Flutter app serves web and Mac, and articles stay as links, never copies. |
| 12 | 2:48 | **Try it.** github.com/ThivaV/OSMS, app.onestory-osms.duckdns.org/#/demo, the seven models; Biscuit waves goodbye. Held to 3:00. | OSMS is live today, and open source. Try the demo, no account needed. One story, many sources. Biscuit out! |

## What's real, and what's made

- **Every app shot is the real app.** Scenes 2 to 8 are the live demo at
  app.onestory-osms.duckdns.org, recorded on 3 November. Scene 9 is the same app on a local
  copy of OSMS, signed in as a made-up test reader. The demo has no account, and the
  video shouldn't show anyone's real one.
- **The Ask answer and the decision log are live output** of OSMS's Muse Spark and Muse
  Spark Open calls. The listen-in is the real briefing's audio, voiced by SeamlessM4T v2.
- **Biscuit is AI-generated.** The picture comes from an image model. LTX-2.5 by
  Lightricks (not a Meta model) animates it and makes its voice. The closing card says so.
  Every line is transcribed back by Meta's SeamlessM4T v2 and matched against the script
  (`check_speech.py`).
