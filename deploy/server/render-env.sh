#!/usr/bin/env bash
# Writes /etc/osms/osms.env: the services' settings, and their secrets from Secret Manager,
# read with the server's own identity. Readable by root and the osms group only. Never
# prints a value. Runs as root on each deploy.
set -euo pipefail
domain=$(cat /etc/osms/domain)
metadata=http://metadata.google.internal/computeMetadata/v1
token=$(curl -fsS -H 'Metadata-Flavor: Google' "$metadata/instance/service-accounts/default/token" |
  python3 -c 'import json, sys; print(json.load(sys.stdin)["access_token"])')
project=$(curl -fsS -H 'Metadata-Flavor: Google' "$metadata/project/project-id")

secret() { # the latest version of a secret, or nothing when it doesn't exist
  curl -fsS -H "Authorization: Bearer $token" \
    "https://secretmanager.googleapis.com/v1/projects/$project/secrets/$1/versions/latest:access" 2>/dev/null |
    python3 -c 'import base64, json, sys; print(base64.b64decode(json.load(sys.stdin)["payload"]["data"]).decode(), end="")' \
      2>/dev/null || true
}

fireworks=$(secret osms-fireworks-api-key)
umask 077
tmp=$(mktemp)
{
  echo "NODE_ENV=production"
  echo "BETTER_AUTH_URL=https://auth.$domain"
  echo "OSMS_APP_ORIGINS=https://app.$domain"
  echo "AUTH_HOST=127.0.0.1"
  echo "AUTH_PORT=3000"
  echo "AUTH_DATABASE_PATH=/var/lib/osms/data/auth.db"
  echo "DATABASE_URL=sqlite:////var/lib/osms/data/osms.db"
  echo "OSMS_MILVUS_PATH=/var/lib/osms/data/milvus.db"
  echo "OSMS_BRIEFINGS_DIR=/var/lib/osms/data/briefings"
  echo "OSMS_VISUALS_DIR=/var/lib/osms/data/visuals"
  echo "HF_HOME=/var/lib/osms/cache/huggingface"
  echo "BETTER_AUTH_SECRET=$(secret osms-better-auth-secret)"
  echo "META_API_KEY=$(secret osms-meta-api-key)"
  echo "GOOGLE_CLIENT_ID=$(secret osms-google-client-id)"
  echo "GOOGLE_CLIENT_SECRET=$(secret osms-google-client-secret)"
  # Fireworks runs Muse Spark Open (the judge) here. Not Muse Glimmer: Fireworks serves it
  # only from a paid dedicated deployment (checked Nov 1), so triage runs on Muse Spark,
  # and the word list when that can't answer.
  if [ -n "$fireworks" ]; then
    echo "FIREWORKS_API_KEY=$fireworks"
  fi
} >"$tmp"
unset fireworks token
install -m 0640 -o root -g osms "$tmp" /etc/osms/osms.env
rm -f "$tmp"
grep -q '^BETTER_AUTH_SECRET=.\{32,\}' /etc/osms/osms.env ||
  { echo "osms-better-auth-secret is missing from Secret Manager: run deploy/gcp/secrets.sh" >&2; exit 1; }
echo "settings written for $domain"
