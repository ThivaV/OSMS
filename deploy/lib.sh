# shellcheck shell=bash
# Shared by the deploy scripts that run on your Mac or in GitHub Actions: `. deploy/lib.sh`.
# Never `set -x` in these scripts: some of them handle secrets.

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

# deploy/config.env, without overriding what the environment already says (CI sets these).
load_config() {
  local key value
  while IFS='=' read -r key value; do
    case "$key" in '' | \#*) continue ;; esac
    if [ -z "${!key:-}" ]; then export "$key=$value"; fi
  done <"$ROOT/deploy/config.env"
  local missing=""
  for key in GCP_PROJECT_ID GCP_REGION GCP_ZONE GCP_VM OSMS_DOMAIN; do
    [ -n "${!key:-}" ] || missing="$missing $key"
  done
  if [ -n "$missing" ]; then
    echo "Set$missing in deploy/config.env (or the environment) first: see DEPLOY.md." >&2
    exit 1
  fi
}

# gcloud for this project, never asking questions.
g() { gcloud --project "$GCP_PROJECT_ID" --quiet "$@"; }

# A command on the server, over SSH through Identity-Aware Proxy (port 22 is closed to the internet).
on_server() { g compute ssh "$GCP_VM" --zone "$GCP_ZONE" --tunnel-through-iap --command "$1"; }

# Copy a local file to the server.
to_server() { g compute scp "$1" "$GCP_VM:$2" --zone "$GCP_ZONE" --tunnel-through-iap; }
