# OSMS: One Story, Many Sources

A news reader that groups articles, research papers, newsletters, podcasts, videos and
posts about the same event into one story, then shows what's new since you last looked,
where sources disagree, and how the story developed.

arXiv is one of its main sources: type your research interests as keywords, and OSMS
pulls every new paper that mentions them or is related to them by meaning, and tells you
why each one is there.

Built for the Meta Global AI Developer Hackathon (Indie Developer track),
Oct 27 – Nov 4, 2026.

## What was built during the hackathon

- [x] **Widgetbook UI design (Oct 28):** every component with fake data —
  `StoryCard`, what's-new, disagreements, timeline, briefing player, source
  chips, three-pane shell, item cards incl. the arXiv paper variant,
  add-source sheet, onboarding, sign-in, settings + five palettes, Today
  overview, floating bars, ⌘K palette, research interests editor. Each with
  Normal / Empty / Extreme use cases, light + dark, phone / tablet / desktop.
  Open it with `make widgetbook` (http://localhost:8090).
- [x] **Sign-up and sign-in, end to end (Oct 29):** an open-source sign-in service
  ([Better Auth](https://better-auth.com), in `auth/`) with Google and, in local
  development, email links; the API (`backend/`) checks its short-lived tokens and keeps
  each reader's onboarding picks, research interests and settings; the web app is wired
  through sign-up, onboarding, Today, Settings and "Delete my account". Signed in, Today
  stays empty until OSMS collects your sources' stories; signed out, the demo shows
  invented sample stories, labelled as such.
- [x] **The macOS desktop app (Oct 30):** everything the web app has, built and tested in
  its sandbox against the real sign-in service and API. Sign-in opens your own browser
  and hands the session back to the app; a native menu bar; a desktop-sized window.
- [x] **Ask this story, UI-first (Oct 30):** `AskStoryBox` at the end of the story
  page with its five states (idle, thinking, answered, not reported, unavailable),
  story-derived suggestions, and a toolbar jump; the sidebar now filters the list
  (Today, topic, source, Saved); ⌘K hover/keyboard polish; the demo Today shows
  "New research for you". The wire contract (`AskRequest`/`AskResponse`, cited
  sentences enforced) lives in `backend/app/schemas/ask.py` with tests; the ask
  agent and route land Day 8, so asking today ends in the spec'd unavailable state.
- [ ] Ingestion, clustering + judge, agents, arXiv matching, briefing audio,
  illustrations — in build-plan order (see AGENTS.md).

## How judging maps to the repo

| Criterion | Where to look |
|---|---|
| Impact | One story, not ten summaries: `StoryCard`, `WhatsNewSection`, `DisagreementPanel`, `TodayOverview` |
| Meta AI tooling | Table below; agents in `backend/app/agent/`, routing in `backend/app/config.py` |
| Technical depth | Clustering + eval in `eval/`, decision log (`agent_runs`, `agent_steps`), `docs/architecture.md` |
| Demo | 3-min video + `make widgetbook` catalogue + clickable shell (`[Layout]` → shell use cases) |

## Which Meta models do what

The plan; each line is marked as it lands. Muse Spark agents make the judgement calls,
and a different model checks every generated output before a reader sees it.

| Model | What OSMS uses it for |
|---|---|
| Muse Spark | The interest, claims, verifier, editor and writer agents |
| Muse Spark Open (open weights, Baseten) | The judge: are two items about the same event? |
| Muse Glimmer (open weights, local) | Triage of every incoming item |
| Muse Wonder | The overnight editor, if our agent tests favour it |
| Muse Image | One illustration per story |
| SAM 3.1 | Checks and crops each illustration |
| Muse Voice Transcribe | Podcast episodes, and a check on the briefing audio |
| Muse Code | Parts of the build (listed below) |

Details and diagrams: [docs/architecture.md](docs/architecture.md).

## Built with Muse Code

_Which parts were written with Muse Code._

## Thanks

Thank you to arXiv for use of its open access interoperability. OSMS shows arXiv's
metadata and links to each paper on arXiv; it is not endorsed by arXiv.

## How to run

Everything runs through `make` from the repo root. `make` on its own lists every command.
Today that is the app (web; macOS with Xcode), sign-in, the API and the Widgetbook
component catalogue. The story pipeline arrives during the hackathon.

### What you need

| Tool | For | Install |
|---|---|---|
| [Flutter](https://flutter.dev) (stable; built with 3.47) | the app and Widgetbook | `brew install --cask flutter` |
| [Node](https://nodejs.org) 24 or newer | sign-in (Better Auth) | `brew install node` |
| [uv](https://docs.astral.sh/uv/) | the API (Python 3.12+) | `brew install uv` |
| Google Chrome | running in the browser | |
| [Tilt](https://tilt.dev) | running everything at once | `brew install tilt` |
| XCode | only for the macOS desktop app | App Store |

`make tools` tells you what is missing.

### First run

```bash
make setup      # create .env (with a fresh sign-in secret), fetch every package,
                # generate Widgetbook's navigation
```

`.env` holds your local settings and secrets; git ignores it. `make env` creates it on
its own, and never overwrites a value you set.

### Run one thing on its own

```bash
make auth                   # sign-in (Better Auth) on http://localhost:3000
make api                    # the API on http://localhost:8000 (docs at /docs)
make app                    # the app in Chrome, on http://localhost:8080
make app DEVICE=macos       # the macOS desktop app (needs XCode)
make app DEVICE=web-server  # the app as a local web server, no browser opened
make widgetbook             # the component catalogue in Chrome
```

The app needs `auth` and `api` running to sign in; without them it shows the demo and
says sign-in is unavailable.

### The macOS app

It needs [Xcode](https://apps.apple.com/app/xcode/id497799835) (the full app, not only
the command line tools) and runs on macOS 12 or later.

```bash
make up                     # sign-in and the API (and the web app)
make app DEVICE=macos       # then the desktop app; or the app-macos button in Tilt
make build-macos            # a release build: frontend/build/macos/Build/Products/Release/OSMS.app
make test-macos             # with make up running: the real app, end to end (opens a window)
```

On the desktop, sign in with **Continue with Google**: it opens your default browser,
and when you're done the browser tab says so and OSMS comes back with you signed in.
Email links work in the web app only. If Google says the app is blocked, add your Google
account as a test user on the OAuth consent screen.

Builds are signed to run on this Mac. Sharing the app with others needs an Apple
Developer ID and notarisation.

These run in the foreground: press `r` to hot reload, `R` to hot restart, `q` to quit.

### Run everything at once

```bash
make up
```

[Tilt](https://tilt.dev) starts every part of OSMS and serves a dashboard (press space in
its terminal to open it):

| What | Where |
|---|---|
| Tilt dashboard: status, logs, buttons | http://localhost:10350 |
| The app | http://localhost:8080 |
| Sign-in (Better Auth) | http://localhost:3000 |
| The API, with its docs | http://localhost:8000/docs |
| Widgetbook | http://localhost:8090 |

Saving a file hot-reloads whatever it belongs to. Each Flutter part also has a **Hot
restart** button, and **flutter-checks**, **backend-checks** and **auth-checks** run the
tests on demand. The first start takes a minute or two while Flutter compiles.

### Signing in locally

- **Without any keys:** `make env` turns on development sign-in, so the sign-in page
  offers **Email me a sign-in link**. Nothing is emailed: the link appears in the
  sign-in log (the `auth` resource in Tilt, or the terminal running `make auth`). Open
  it in the same browser and you're signed in. It works once, for five minutes.
- **With Google:** create an OAuth client (type *Web application*) in Google Cloud,
  with the redirect URI `http://localhost:3000/api/auth/callback/google`. Put its id and
  secret in `.env` as `GOOGLE_CLIENT_ID` and `GOOGLE_CLIENT_SECRET`, then restart
  sign-in. **Continue with Google** appears on its own.
- The first sign-in creates your account and goes to onboarding; afterwards you land on
  Today. It stays empty until OSMS has collected stories from your sources; with no
  sources, it offers **Choose topics and sources**. Signed out, the demo's stories are
  labelled samples until OSMS starts collecting real ones.

### Stop and check what's running

```bash
make status           # what is running, on its own and in Tilt
make stop-app         # stop the app, wherever it runs
make stop-widgetbook  # stop Widgetbook, wherever it runs
make stop-auth        # stop sign-in, wherever it runs
make stop-api         # stop the API, wherever it runs
make stop             # stop everything at once, including Tilt
```

A part stopped inside Tilt can be turned back on from the dashboard.

### Checks

```bash
make check           # everything: the next three in a row
make check-flutter   # analyze and test the app and Widgetbook
make check-backend   # lint and test the API
make check-auth      # type-check and test sign-in
make ci              # start everything with Tilt, wait until it is healthy, then exit
```

### Other commands

```bash
make widgetbook-gen    # regenerate Widgetbook's navigation after adding a use case
make widgetbook-build  # build Widgetbook as a static site (frontend/widgetbook/build/web)
make clean             # stop everything, remove build output and run files
```

### Without make

Every target wraps a plain command, for example:

```bash
cd auth && npm start
cd backend && uv run uvicorn app.main:app --reload
cd frontend && flutter run -d chrome --web-port=8080
cd frontend/widgetbook && dart run build_runner build && flutter run -d chrome
cd frontend && flutter analyze && flutter test
```

### Good to know

- **Start Tilt with `make up`, not `tilt up`.** OSMS doesn't use Kubernetes, so `make`
  gives Tilt an empty kube config and it never touches a cluster you may have
  configured. The Tiltfile refuses to start if it can see one.
- **Usage data.** Tilt's analytics and the Widgetbook generator's telemetry are switched
  off in this repo. Flutter's own analytics are a per-machine setting; turn them off
  with `flutter --disable-analytics`.
- **"Port already in use"?** Run `make status`, then `make stop`.
- **Run the web app on port 8080.** Sign-in only trusts the app origins it knows
  (`OSMS_APP_ORIGINS`, default `http://localhost:8080`); `make app` uses that port.
- Run files (process ids, Tilt's empty kube config) live in `.tilt/`, which git ignores.
