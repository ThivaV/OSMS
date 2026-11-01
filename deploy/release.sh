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
cp -R frontend/build/web "$work/release/web"
tar -czf "$work/osms-$id.tgz" -C "$work/release" .

echo "== to $GCP_VM"
to_server "$work/osms-$id.tgz" "/tmp/osms-$id.tgz"
on_server "sudo bash -c 'set -e; mkdir -p /opt/osms/releases/$id; \
  tar -xzf /tmp/osms-$id.tgz -C /opt/osms/releases/$id; rm -f /tmp/osms-$id.tgz; \
  bash /opt/osms/releases/$id/deploy/server/deploy.sh $id'"
