# Recording the demo video by hand

The finished video is `osms-demo.mp4` in this folder, presented by Biscuit and made by the
scripts in `video/` (see [README.md](README.md)). This page is for recording the tour
yourself instead, with your own voice.

A shot-by-shot script for the hackathon video, using stories that are live on the demo
today (Nov 3). Story numbers are the demo's ids; open one with the ⌘K palette or from
Today. The judges weigh four things equally — Impact, Use of Meta AI tooling, Technical
depth and execution, the Demo — and each scene says which one it earns.

## Before recording

- **Two windows.** The web app in Chrome at 1440×900, signed out, at
  https://app.onestory-osms.duckdns.org/#/demo (the story scenes). The Mac app, signed
  in, for the scenes that need an account (Add a source, Saved on every device).
- **Light theme**, the default palette, the browser zoomed to 100%. Close other tabs.
- **Sign in beforehand**, on the web in a second profile and on the Mac, so no sign-in
  screen eats the clock. Follow at least the *Startups and product* topic so story #706
  is in your own Today too.
- **Have the link ready to paste** for Add a source: `macrumors.com`. It is not a seed
  source, it publishes the same Apple news as 9to5Mac, and its home page names its feed.
  Try it once before recording; if it is slow, `theverge.com` works the same way.
- **Turn off auto-deploy while judging** (`DEPLOY_ON_PUSH=false` in the repository's
  Actions variables) so a late push can't restart the site in the middle of a judge's
  visit.
- Record at 1080p or higher. Speak over it afterwards rather than live; the script's
  lines are timed for a calm pace (about 150 words a minute).

## The script

| Time | On screen | Say | Earns |
|---|---|---|---|
| 0:00–0:15 | Today in the demo: the overview, story cards with their publishers' pictures. Scroll once. | "Every morning, the same news reaches me ten times: three tech sites, a Danish paper, a podcast, an arXiv paper. OSMS — One Story, Many Sources — turns all of it into one story per event." | Impact |
| 0:15–0:45 | Open **#706** *Apple Launches iPad Mini, Plans More iPad Updates for 2027*. Pause on the summary, then tap **What's new**, **Sources agree so far**, **Timeline**, **Every source** in the toolbar. | "This is one story from 9to5Mac, Engadget and GSMArena. Every sentence in the summary names the sources behind it. What's new shows only facts added since I last looked. Where sources disagree, it says so; here they agree. And the picture is the publisher's own, credited and linked, never copied." | Impact, Demo |
| 0:45–1:05 | Open **#309** *Apple unveils M6 iMac and 14-inch MacBook Pro*. Scroll to a fact quoted from Recordere.dk, with **TRANSLATED BY OSMS** under it. | "Sources don't have to share a language. This story joins an English and a Danish site: the Danish quote stays in Danish, with a labelled translation, so nothing is put in a source's mouth." | Impact, Technical depth |
| 1:05–1:35 | Back on **#706**, scroll to **How OSMS decided** and open it. Point at each row: triage, the judge, claims, verifier, writer, illustration. | "Every model call behind a story is on its page. Muse Spark triages each item, pulls out its facts, checks them and writes the summary. Muse Spark Open, a different model, is the judge that decided these three reports are the same event. Muse Image drew an illustration and SAM 3.1 checked it for faces, logos and text. Tokens, latency, and what each call changed." | Meta AI tooling, Technical depth |
| 1:35–2:00 | Tap **Listen** in #706's toolbar: the briefing jumps to its chapter. Then the sidebar's **Listen**: today's briefing, its five chapters, past briefings, podcasts. | "Each morning OSMS makes a short podcast of the top stories. Every sentence cites a checked fact. SeamlessM4T voices it, and Muse Voice Transcribe listens back to every chapter before anyone hears it. Listen on a story plays its chapter." | Meta AI tooling, Demo |
| 2:00–2:20 | In #706, **Ask this story** → tap the suggestion *What is new here?* Wait for the answer; point at its citations. | "I can ask the story a question. The answer comes only from its checked facts, with sources; if the sources never said it, OSMS says that instead of guessing." | Meta AI tooling |
| 2:20–2:45 | The Mac app, signed in. Sidebar → **Add a source** → paste `macrumors.com` → **Find**: the preview shows its type and latest posts → **Subscribe**. Then save #706 with the bookmark, open **Saved**, and show it on the web too. | "It's my reader: I add any site, feed or handle by pasting it, and OSMS finds the feed and shows what I'd get before I follow it. Its articles join the stories they belong to. What I save is there on every device, and I signed in on this Mac without Google again, in one click." | Demo, Technical depth |
| 2:45–3:00 | The repository on GitHub: the README's model table, then back to the live app. | "OSMS is live on the web and the Mac, open source, built in a week with seven Meta models: Muse Spark, Muse Spark Open, Muse Image, SAM 3.1, Muse Voice Transcribe, SeamlessM4T and MMS-TTS. One story, many sources." | All four |

## If something on the day differs

- **#706 left the demo's top 100**, or today's briefing no longer has it: use the newest
  story with three or more sources and a briefing chapter. In the web console:
  `fetch('https://api.onestory-osms.duckdns.org/demo/briefing').then(r => r.json()).then(b => b.chapters.map(c => c.story_id))`.
- **A story shows a real disagreement** by then: show it in place of "here they agree".
  The panel puts each side with its sources.
- **A correction** is worth a second: #516 *Apple sets December China debut for Apple
  Intelligence* has one in its timeline (a beta date that 9to5Mac changed).
- **Ask is slow or rate-limited**: the demo allows six questions per ten minutes per
  address. Record that scene first.
