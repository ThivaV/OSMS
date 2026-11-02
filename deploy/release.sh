#!/usr/bin/env bash
# Builds a release from what is committed (never uncommitted work) and makes it live on
# the server. GitHub Actions runs it after every green push to main; `make deploy` runs it
# from your Mac. Needs `flutter`, and `gcloud` signed in (CI: keyless, as osms-deploy).
#
#   bash deploy/release.sh
set -euo pipefail
. "$(dirname "$0")/lib.sh"
load_config
cd "$ROOT"

if [ -n "$(git status --porcelain -- backend auth deploy scripts frontend/lib frontend/web 2>/dev/null)" ]; then
  echo "Note: uncommitted changes are not part of this release (it ships $(git rev-parse --short HEAD))."
fi
id="$(date -u +%Y%m%d-%H%M%S)-$(git rev-parse --short=10 HEAD)"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

echo "== the web app, for https://app.$OSMS_DOMAIN"
(cd frontend && flutter build web --release --no-web-resources-cdn \
  --dart-define="OSMS_AUTH_URL=https://auth.$OSMS_DOMAIN" \
  --dart-define="OSMS_API_URL=https://api.$OSMS_DOMAIN")

echo "== the release: $id"
mkdir -p "$work/release"
git archive --format=tar HEAD backend auth deploy scripts | tar -x -C "$work/release"
# The commit and its time: the server never lets an older release replace a newer one.
git log -1 --format='%H %ct' HEAD >"$work/release/COMMIT"
cp -R frontend/build/web "$work/release/web"
# Never macOS's ._ metadata files: Alembic loads backend/alembic/versions/._*.py as
# migrations, and the API then refuses to start.
COPYFILE_DISABLE=1 tar --no-xattrs --exclude='._*' -czf "$work/osms-$id.tgz" -C "$work/release" .
if tar -tzf "$work/osms-$id.tgz" | grep -q '/\._'; then
  echo "the release holds macOS ._ files; nothing was sent" >&2
  exit 1
fi

echo "== to $GCP_VM"
to_server "$work/osms-$id.tgz" "/tmp/osms-$id.tgz"
# deploy.sh runs on the server as its own service, osms-deploy: SSH through IAP drops
# during a long, quiet install, and that can't stop it halfway. A second deploy is
# refused while one runs.
run=$(on_server "sudo bash -c 'set -e
  if systemctl is-active --quiet osms-deploy; then echo \"another deploy is running on the server\" >&2; exit 1; fi
  mkdir -p /opt/osms/releases/$id
  tar -xzf /tmp/osms-$id.tgz -C /opt/osms/releases/$id; rm -f /tmp/osms-$id.tgz
  systemctl reset-failed osms-deploy 2>/dev/null || true
  systemd-run --quiet --unit=osms-deploy --setenv=HOME=/root bash /opt/osms/releases/$id/deploy/server/deploy.sh $id
  systemctl show osms-deploy --property=InvocationID --value'" | tail -1)

# Its log as it goes, until it ends: a finished run is unloaded (inactive), a failed one stays failed.
seen=0 state=active
for _ in $(seq 1 240); do
  sleep 10
  out=$(on_server "sudo journalctl _SYSTEMD_INVOCATION_ID=$run -o cat --no-pager | tail -n +$((seen + 1)); \
    systemctl show osms-deploy --property=ActiveState --value" 2>/dev/null) || continue
  state=${out##*$'\n'}
  new=$(printf '%s\n' "$out" | sed '$d')
  if [ -n "$new" ]; then
    printf '%s\n' "$new"
    seen=$((seen + $(printf '%s\n' "$new" | wc -l)))
  fi
  case "$state" in active | activating | deactivating) ;; *) break ;; esac
done
[ "$state" = inactive ] || { echo "the deploy on the server is $state: make server-logs SERVICE=deploy" >&2; exit 1; }
