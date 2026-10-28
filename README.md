# OSMS: One Story, Many Sources

A news reader that groups articles, newsletters, podcasts, videos and posts about the
same event into one story, then shows what's new since you last looked, where sources
disagree, and how the story developed.

Built for the Meta Global AI Developer Hackathon (Indie Developer track),
Oct 27 – Nov 4, 2026.

## What was built during the hackathon

_Filled in as work lands._

## Which Meta models do what

See [docs/architecture.md](docs/architecture.md).

## Built with Muse Code

_Which parts were written with Muse Code._

## How to run

Everything runs through `make` from the repo root. `make` on its own lists every command.
The backend arrives during the hackathon; today you can run the app and the Widgetbook
component catalogue.

### What you need

| Tool | For | Install |
|---|---|---|
| [Flutter](https://flutter.dev) (stable; built with 3.47) | the app and Widgetbook | `brew install --cask flutter` |
| Google Chrome | running in the browser | |
| [Tilt](https://tilt.dev) | running everything at once | `brew install tilt` |
| XCode | only for the macOS desktop app | App Store |

`make tools` tells you what is missing.

### First run

```bash
make setup      # fetch packages, generate Widgetbook's navigation
```

### Run one thing on its own

```bash
make app                    # the app in Chrome
make app DEVICE=macos       # the macOS desktop app (needs XCode)
make app DEVICE=web-server  # the app as a local web server, no browser opened
make widgetbook             # the component catalogue in Chrome
```

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
| Widgetbook | http://localhost:8090 |

Saving a file hot-reloads whatever it belongs to. Each part also has a **Hot restart**
button, and **flutter-checks** runs the analyzer and tests on demand. The first start
takes a minute or two while Flutter compiles.

### Stop and check what's running

```bash
make status           # what is running, on its own and in Tilt
make stop-app         # stop the app, wherever it runs
make stop-widgetbook  # stop Widgetbook, wherever it runs
make stop             # stop everything at once, including Tilt
```

A part stopped inside Tilt can be turned back on from the dashboard.

### Checks

```bash
make check   # analyze and test the app and Widgetbook
make ci      # start everything with Tilt, wait until it is healthy, then exit
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
cd frontend && flutter run -d chrome
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
- Run files (process ids, Tilt's empty kube config) live in `.tilt/`, which git ignores.
