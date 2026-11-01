# Deploying OSMS on Google Cloud

The deployed OSMS is one virtual machine in Google Cloud. It serves the web app, sign-in,
the API and the worker; the databases stay what they are locally (SQLite and Milvus Lite,
files on the server's disk, snapshotted daily). GitHub Actions tests every push and
deploys `main` when the tests pass. Running OSMS on your Mac is in [SETUP.md](SETUP.md).

| | Where |
|---|---|
| The web app | `https://app.<name>.duckdns.org` |
| Sign-in | `https://auth.<name>.duckdns.org` |
| The API | `https://api.<name>.duckdns.org` |
| The server | one Compute Engine VM, `e2-highmem-4` (4 vCPU, 32 GB), `europe-north1` (Finland), Ubuntu 24.04, 100 GB disk |
| The data | `/var/lib/osms/data` on the server's disk: `osms.db`, `auth.db`, `milvus.db`, briefings, illustrations; a snapshot every night, kept a week |
| Secrets | Google Secret Manager; only the server's own identity can read them |
| Open-weight models | Fireworks: Muse Spark Open (the judge); Baseten stays first for it once it is set up. Muse Glimmer isn't serverless on Fireworks, so triage runs on Muse Spark here |
| Other models | Meta Model API (your hackathon credit) |

Caddy answers on ports 80 and 443 and gets the HTTPS certificates on its own; sign-in,
the API, the worker and Milvus Lite listen on `127.0.0.1` only. SSH is closed to the
internet: it goes through Google's Identity-Aware Proxy.

## What it costs

| Item | Per month | Paid by |
|---|---|---|
| The VM, about $0.20 an hour | about $145 | the free trial's $300 credit |
| Disk, static IP, snapshots, traffic | about $15 | credit |
| **Google Cloud** | **about $160**: the credit lasts about two months | **$0 from you** |
| DuckDNS | free | |
| Fireworks (the judge) | a few dollars in all | you |
| Meta models | | your $150 hackathon credit |

Prices are estimates; Google's pricing calculator has the exact ones. When the trial
ends, the VM stops unless you upgrade: Google doesn't charge you on its own.

## Setting it up, once

The steps marked **you** need your accounts or your keys. The rest are `make` targets
anyone signed in to the project can run.

1. **You: Google Cloud.** Start the free trial at
   [cloud.google.com/free](https://cloud.google.com/free) with your **personal** Google
   account (never a work account), create a project, and add a budget alert (Billing →
   Budgets, say $50). Then install the command-line tool and sign in:

   ```bash
   brew install --cask gcloud-cli
   gcloud auth login
   gcloud config set project <your project id>
   ```

2. **You: DuckDNS.** Sign in at [duckdns.org](https://www.duckdns.org) and add a name
   (`<name>.duckdns.org`). Leave its IP for now. Keep brand names out of it: Chrome took
   `meta-osms.duckdns.org` (a brand, a free address and a sign-in button) for phishing
   and warned visitors off, so OSMS moved to `onestory-osms.duckdns.org`.

3. **You: Fireworks.** Create an account at [fireworks.ai](https://fireworks.ai) and an API
   key, and put it in your `.env` as `FIREWORKS_API_KEY`. Keep it to yourself (never in a
   chat): step 6 stores it.

4. **The settings.** Fill in `GCP_PROJECT_ID` and `OSMS_DOMAIN` (`<name>.duckdns.org`) in
   `deploy/config.env`, and commit it: nothing in it is secret.

5. **The cloud resources:**

   ```bash
   make provision
   ```

   It prints the server's IP. Put that IP on your DuckDNS name; `app.`, `auth.` and `api.`
   follow it. Check: `dig +short app.<name>.duckdns.org` prints the same IP.

6. **You: the secrets.** In your own terminal:

   ```bash
   bash deploy/gcp/secrets.sh
   ```

   It copies `META_API_KEY`, `GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET` and
   `FIREWORKS_API_KEY` from your `.env` to Secret Manager (it asks for the Fireworks key,
   with your typing hidden, when `.env` has none), and makes a fresh sign-in secret. It
   stores the Fireworks key only once Fireworks accepts it, and leaves a key that is
   already stored as it is. It prints names, never values. Run it again any time to
   replace a key.

7. **You: Google sign-in.** In the Google Cloud console that holds your OAuth client
   (APIs & Services → Credentials), add:
   - Authorised JavaScript origin: `https://app.<name>.duckdns.org`
   - Authorised redirect URI: `https://auth.<name>.duckdns.org/api/auth/callback/google`

   Then, on the OAuth consent screen, **Publish app** so any Google account can sign in.
   OSMS asks only for name and email, which need no review from Google. Google may refuse
   a duckdns.org address; the demo then still works signed out.

8. **The server, its stories and the first release:**

   ```bash
   make server-setup     # Caddy, Node 24, uv, the osms user and folders
   make stop-worker      # the local worker must be stopped to copy its data
   make seed-server      # your local stories, facts and the demo's briefing; no readers
   make deploy           # build and deploy what is committed
   ```

   `make seed-server` copies stories, facts, summaries, the demo's briefing and the
   illustrations, but no reader: no accounts, emails, interests or read state, and not
   sign-in's database. It saves paying for those model calls again. Skip it to let the
   server collect from scratch.

9. **Deploys from GitHub:**

   ```bash
   bash deploy/gcp/github.sh   # the repo's Actions variables; none is secret
   ```

   From now on every push to `main` deploys once the tests pass.

10. **Check it:** open `https://app.<name>.duckdns.org`, then:

    ```bash
    make server-check-models   # one tiny call per agent: models and keys right?
    make server-status         # the services, and what the pipeline has stored
    ```

## How CI/CD works

- **`check`** (`.github/workflows/check.yml`) runs on every push and pull request: the app
  and Widgetbook (analyze and test), the macOS build, the backend (Ruff and pytest,
  without the model weights), the eval harness and sign-in.
- **`deploy`** (`.github/workflows/deploy.yml`) runs when `check` passes for a push to
  `main`, or when you start it from the Actions tab. It builds the web app for the
  deployed addresses, packs a release of what was tested, and runs
  `deploy/release.sh`, the same script `make deploy` runs. A last step checks that the
  live site answers.
- **On the server**, `deploy/server/deploy.sh` installs the release next to the previous
  ones, refreshes the settings from Secret Manager, restarts the services and checks that
  sign-in and the API are healthy. If they aren't, it goes back to the previous release
  and the deploy fails. It runs as a service of its own, `osms-deploy`, so a dropped
  connection can't stop it halfway, and only one deploy runs at a time.
- **No keys in GitHub.** GitHub Actions signs in to Google Cloud with Workload Identity
  Federation, as the `osms-deploy` account, and only from `main` of this repo.
- **During judging**, to deploy only by hand: `gh variable set DEPLOY_ON_PUSH --body false`.
  Pushes are still tested; run `deploy` from the Actions tab when you mean it.

## The macOS app

The desktop app talks to sign-in and the API over HTTPS, like the web app; only the
API touches the databases. Build it for the deployed site:

```bash
make build-macos-prod      # frontend/build/macos/Build/Products/Release/OSMS.app
```

**Continue with Google** opens your browser at the deployed sign-in and hands the session
back to the app. Email sign-in links are off in production.

## Running it

```bash
make server-status                 # services, and what is stored and queued
make server-logs SERVICE=worker    # follow a log: worker, api, auth, deploy or caddy
make server-check-models           # models and keys
make server-ssh                    # a shell on the server
make deploy                        # deploy what is committed, from your Mac
```

- **New or changed secret:** run `bash deploy/gcp/secrets.sh` again, then `make deploy`
  (each deploy reads them fresh).
- **Rollback:** each deploy keeps the last five releases. On the server:
  `ls -t /opt/osms/releases`, then
  `sudo bash /opt/osms/releases/<id>/deploy/server/deploy.sh <id>` for the one you want.
  Or run `deploy` on an older commit from the Actions tab.
- **Backups:** a snapshot of the disk every night at 02:00 UTC, kept seven days (Compute
  Engine → Snapshots). To restore, create a disk from a snapshot and attach it.
- **Saving money after judging:** `gcloud compute instances stop osms --zone
  europe-north1-a` stops the VM (the disk still costs about $11 a month); release the
  static IP too if you won't start it again. Deleting the project removes everything.

## Security

- SSH only through Identity-Aware Proxy; ports 80 and 443 are the only open ones.
- Secrets live in Secret Manager and on the server in `/etc/osms/osms.env` (readable by
  root and the services only). They are never in the repo, in GitHub or in CI logs.
- Sign-in runs with `NODE_ENV=production`, which refuses development sign-in links.
- The services run as the unprivileged `osms` user, and can write only to
  `/var/lib/osms`.
- `make seed-server` refuses to send a copy that still holds reader data.
- The speech models' weights are CC-BY-NC 4.0: fine for the hackathon demo, never sell
  the audio.
