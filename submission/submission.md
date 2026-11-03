# Submission text

Drafts for the hackathon form and the launch post. Every claim here is true of the live
site on Nov 3; check the numbers again on the day you submit.

## One line

OSMS turns ten articles, papers, podcasts and posts about the same event — in any
language — into one story that shows what's new since you last looked, where sources
disagree, and how it developed, with every sentence traced to its sources.

## Links

- Live app: https://app.onestory-osms.duckdns.org (sign in with Google), or the demo
  without an account: https://app.onestory-osms.duckdns.org/#/demo
- Code: https://github.com/ThivaV/OSMS
- macOS app: built from the same code (`make build-macos`, see SETUP.md)
- Demo video (3:00, 1080p): `submission/osms-demo.mp4`, to upload with the form.
  Biscuit, a cartoon dog, presents it: the problem and how OSMS solves it, the live web
  app, the seven Meta models and the architecture. Every line is in
  [`video/script.md`](video/script.md).

## What it does

Every morning the same news reaches you many times: three tech sites, a newspaper in
your own language, a podcast, an arXiv paper. OSMS reads all of them and groups the
reports of one event into one story:

- **One summary, every sentence cited.** Each fact is pulled from a report, checked by a
  second model against its quote, and shown with the sources behind it. A quote stays in
  its own language, with a labelled translation.
- **What's new since you last looked**, so a story you've read only shows what changed.
- **Where sources disagree**, side by side, and **corrections** kept in a dated timeline
  instead of silently overwritten.
- **How OSMS decided:** every model call behind a story is on its page — which model,
  what it changed, its tokens and latency.
- **A morning briefing** you can listen to: a few minutes on the top stories, every
  sentence citing a checked fact, voiced by open-weight speech models and transcribed
  back by Muse Voice Transcribe before anyone hears it.
- **Ask this story:** answers only from its checked facts, or says the sources never
  said it.
- **Research on arXiv:** type your interests; OSMS fetches the new papers that match and
  says why each one is there.
- **Yours:** add any site, feed or social handle by pasting it, save stories across
  devices, and share a story as links to its original reports. Web and macOS, one
  sign-in.

## How Meta's models are used

| Model | Job |
|---|---|
| Muse Spark | Triage of every incoming item; the claims, verifier, editor, writer, interest and ask agents |
| Muse Spark Open (Fireworks) | The judge: are two reports about the same event? A different model from the one that writes |
| Muse Image | An illustration for a story no source has a picture for |
| SAM 3.1 | Checks each illustration for people, faces, logos and text, and crops it around its subject |
| Muse Voice Transcribe | Listens back to every briefing chapter and checks it against the script |
| SeamlessM4T v2 | The briefing's voice in English and Danish |
| MMS-TTS | The briefing's voice in Tamil |

The rule throughout: nothing generated reaches a reader unchecked. Facts are verified
against their quotes, illustrations by SAM 3.1, the briefing's audio by Muse Voice
Transcribe, and whether two reports are one event by a different model from the one that
writes. Every agent run is logged with its model, prompt version, reason, tokens and
latency, and shown on the story it decided about.

## How it's built

- **Backend:** FastAPI and a worker over SQLite and Milvus Lite. A polite, safe fetcher
  (public addresses only, redirects re-checked, robots.txt for article pages); BGE-M3
  vectors; clustering by meaning, time and names, with the judge deciding close calls; a
  claims history that never overwrites; a jobs queue with retries.
- **Agents:** a small loop of our own (one call, or a bounded tool loop), frozen
  guardrails as code (backup models, no search grounding, log scrubbing), and a routing
  table checked at startup.
- **Apps:** Flutter for the web and macOS from one codebase; every component in a
  Widgetbook catalogue with normal, empty and extreme cases in light and dark.
- **Sign-in:** Better Auth with Google; the Mac app signs in through the browser and
  takes over a signed-in session with one click.
- **Deployment:** one Google Cloud VM behind Caddy, deployed keyless from GitHub Actions
  when the tests pass.
- **Content rights:** OSMS stores links, never the publishers' articles, pictures or
  audio; pictures and episodes are shown from their publishers, credited.

## Challenges

- Grouping reports across languages without merging different events: the judge is a
  separate model, and the clustering rule leaves it only the close calls.
- Making generated audio trustworthy: every chapter is transcribed back and checked
  before it's published.
- Keeping one reader's data away from every other reader, down to signed, short-lived
  audio links and stories that 404 rather than peek.

## What's next

OPML import, related-by-meaning papers, a language toggle, the editor reviewing its own
picks, and more of the world's languages in the briefing.

## The post on X

> Ten tabs, one event. For the Meta AI hackathon I built OSMS, One Story, Many Sources:
> articles, papers and podcasts in any language become one story with what's new, where
> sources disagree and every sentence cited, plus a morning briefing.
> https://app.onestory-osms.duckdns.org/#/demo

(263 characters as X counts them: any link counts as 23.)
