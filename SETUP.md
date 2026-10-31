# Setting up and running OSMS

Everything runs on your own machine, through `make` from the repo root (`make` on its own
lists every command). There are two ways to run it: **with Tilt**, one command for
everything plus a dashboard, or **without Tilt**, one terminal per service.

## What you need

| Tool | For | Install |
|---|---|---|
| [Flutter](https://flutter.dev) (stable; built with 3.47) | the app and Widgetbook | `brew install --cask flutter` |
| [Node](https://nodejs.org) 24 or newer | sign-in (Better Auth) | `brew install node` |
| [uv](https://docs.astral.sh/uv/) | the API and the worker (Python 3.12+) | `brew install uv` |
| Google Chrome | the web app | |
| [Tilt](https://tilt.dev) | running everything at once (optional) | `brew install tilt` |
| Xcode | only for the macOS desktop app | App Store |
| [Ollama](https://ollama.com) | only for triage on Muse Glimmer; without it, a word list | `brew install ollama` |

`make tools` tells you what is missing.

Models download on first use, so leave room on the disk: BGE-M3 (about 2.3 GB) on the
worker's first run, the briefing's voices (about 9.5 GB) on the first briefing, and Muse
Glimmer (18 GB) when you ask for it. Muse Glimmer takes about 16 GB of memory while it
triages.

## The first time

1. **Packages and settings:**

   ```bash
   make setup
   ```

   This creates `.env` (with a fresh sign-in secret, and development sign-in links on),
   fetches every package for the app, Widgetbook, sign-in and the backend (the models
   included), and generates Widgetbook's navigation.

2. **Keys**, in `.env` only (git ignores it; never paste a key anywhere else):

   | Setting | Gives you | Without it |
   |---|---|---|
   | `META_API_KEY` | facts, summaries, Ask, the briefing, illustrations | stories still form, titled by their first headline, with no facts |
   | `BASETEN_API_KEY`, `BASETEN_BASE_URL` | the judge on Muse Spark Open | Muse Spark judges instead |
   | `GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET` | Continue with Google | sign in with an email link from the sign-in log |

3. **Muse Glimmer, once** (skip it to triage with the word list). Start Ollama, either in
   its own terminal or as part of `make up`, then download the model:

   ```bash
   make glimmer          # Ollama on 127.0.0.1:11434 (not needed if Tilt is running)
   make glimmer-model    # 18 GB, once
   ```

## Run everything with Tilt

```bash
make up
```

Use `make up`, not `tilt up`: OSMS doesn't use Kubernetes, and `make up` hides any kube
context you have from Tilt (the Tiltfile refuses to start if it can see one).

The dashboard is at http://localhost:10350 (press space in Tilt's terminal to open it).
It starts:

| Service | Where | Starts |
|---|---|---|
| `glimmer`: Ollama with Muse Glimmer, only when Ollama is installed; it uses an Ollama that is already running | 127.0.0.1:11434 | at once |
| `auth`: sign-in | http://localhost:3000 | at once |
| `api`: the API | http://localhost:8000/docs | after `auth` |
| `worker`: the story pipeline (fetch, triage, cluster, facts, summaries, briefings, illustrations) | – | after `api` and `glimmer` |
| `app`: the web app | http://localhost:8080 | at once |
| `widgetbook`: the component catalogue | http://localhost:8090 | after `widgetbook-gen` builds its navigation |

These wait for a click in the dashboard: `app-macos` (the macOS desktop app, needs
Xcode), the `flutter-checks`, `backend-checks` and `auth-checks` buttons, and the
worker's **Fetch now**, **Make briefing now** and **Pipeline status** buttons.

Saving a file reloads whatever it belongs to; each Flutter part also has a **Hot
restart** button. The first start takes a minute or two while Flutter compiles.

`make ci` starts the same set, waits until everything is healthy, then exits: a quick
check that the whole stack still starts. It runs the worker too (see below).

## Run without Tilt

One terminal per service, in this order:

```bash
make glimmer              # 1. Ollama, for triage (skip it to use the word list)
make auth                 # 2. sign-in, http://localhost:3000
make api                  # 3. the API, http://localhost:8000/docs
make worker               # 4. the story pipeline
make app                  # 5. the web app in Chrome, http://localhost:8080
```

- **The order matters a little.** The worker checks for Muse Glimmer when it starts:
  started before Ollama (or before the model is downloaded), it triages with the word
  list until you restart it. The app needs sign-in and the API to sign in; without them
  it shows the demo and says sign-in is unavailable.
- **Other ways to run the app:** `make app DEVICE=macos` (the desktop app, needs Xcode)
  or `make app DEVICE=web-server` (a local web server, no browser opened). The web app
  always uses port 8080: sign-in only trusts the origins it knows.
- **Widgetbook**, if you want it: `make widgetbook`.
- Each one stops with Ctrl+C in its terminal, or with `make stop-<service>` from anywhere.

### Without make

Every target wraps a plain command, so this works too:

```bash
OLLAMA_HOST=127.0.0.1:11434 ollama serve
cd auth && npm start
cd backend && uv run uvicorn app.main:app --reload --host 127.0.0.1 --port 8000
cd backend && uv run python -m app.worker run
cd frontend && flutter run -d chrome --web-port=8080      # or: flutter run -d macos
cd frontend/widgetbook && dart run build_runner build && flutter run -d chrome
```

## The worker spends credits

When it starts, the worker carries on with its saved queue: Muse Glimmer triage is free,
but whatever Glimmer is unsure about, and the facts and summaries for what it keeps, are
paid Muse Spark calls. It also makes each day's briefings from 06:00 UTC, and illustrates
stories that reach three sources.

To look around without spending: with Tilt, `make up` and then `make stop-worker`;
without Tilt, start everything but `make worker`.

## While it runs

```bash
make status             # what of OSMS's is running, however it was started
make fetch-now          # fetch every followed source now
make briefing           # the demo's morning briefing now (READER=<id> for a reader's)
make illustrations      # illustrate stories that earned one (LIMIT=10; paid calls)
make pipeline-status    # what the pipeline has stored, clustered and queued
```

**Signing in locally:** with development sign-in on (`make setup` turns it on), the
sign-in page offers **Email me a sign-in link**. Nothing is emailed: the link appears in
the sign-in log (Tilt's `auth` resource, or the terminal running `make auth`). Open it in
the same browser; it works once, for five minutes.

## Stopping

```bash
make stop               # everything, however it was started (Tilt first)
make stop-worker        # one service: stop-app, stop-widgetbook, stop-auth, stop-api,
                        # stop-worker, stop-glimmer
```

These find OSMS's processes however they were started (with or without Tilt, by make or
by hand): only ones running an OSMS service from inside this repo, and Ollama's server.
They never touch your shells, editors or other projects. A stopped worker keeps its
queue, and the next start carries on.

## The macOS app

```bash
make app DEVICE=macos   # with sign-in and the API running; or the app-macos button in Tilt
make build-macos        # a release build: frontend/build/macos/Build/Products/Release/OSMS.app
make test-macos         # with make up running: the real app end to end, and its briefing audio
```

On the desktop, **Continue with Google** opens your default browser and brings you back
signed in. Email links work in the web app only.

## Checks

```bash
make check              # everything below, in a row
make check-flutter      # analyze and test the app and Widgetbook
make check-backend      # lint and test the API and the worker
make check-auth         # type-check and test sign-in
```

## When something is off

- **"Port already in use":** `make status`, then `make stop`.
- **The worker says `triage: the word list`:** Ollama wasn't running, or Muse Glimmer
  wasn't downloaded, when it started. Run `make glimmer` (or check `glimmer` in Tilt) and
  `make glimmer-model`, then restart the worker.
- **No facts, answers or briefing:** `META_API_KEY` is missing from `.env`.
- **The first briefing takes a while:** the voices download first (about 9.5 GB).
- **Tilt refuses to start because it can see a kube context:** start it with `make up`.
