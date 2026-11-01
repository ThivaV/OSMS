#!/usr/bin/env bash
# Puts OSMS's secrets into Secret Manager, where only the server can read them. Run it
# yourself, in your own terminal: it never prints a value, and a key never has to pass
# through a chat or a file in the repo.
#
#   bash deploy/gcp/secrets.sh
#
# - META_API_KEY, GOOGLE_CLIENT_ID and GOOGLE_CLIENT_SECRET come from your local .env
# - the sign-in secret is made fresh, once (making a new one later signs everyone out)
# - the Fireworks key is asked for, hidden as you type (Enter skips it)
set -euo pipefail
. "$(dirname "$0")/../lib.sh"
load_config

put() { # put NAME: the value arrives on stdin
  if g secrets describe "$1" >/dev/null 2>&1; then
    g secrets versions add "$1" --data-file=- >/dev/null
  else
    g secrets create "$1" --replication-policy automatic --data-file=- >/dev/null
  fi
  echo "stored $1"
}
from_env() { grep -E "^$1=" "$ROOT/.env" 2>/dev/null | head -1 | cut -d= -f2- || true; }

for pair in META_API_KEY:osms-meta-api-key GOOGLE_CLIENT_ID:osms-google-client-id \
  GOOGLE_CLIENT_SECRET:osms-google-client-secret; do
  value=$(from_env "${pair%%:*}")
  if [ -n "$value" ]; then printf %s "$value" | put "${pair#*:}"; else echo "skipped ${pair#*:}: ${pair%%:*} isn't in .env"; fi
done
unset value

if g secrets describe osms-better-auth-secret >/dev/null 2>&1; then
  echo "kept osms-better-auth-secret (a new one would sign everyone out)"
else
  openssl rand -hex 32 | tr -d '\n' | put osms-better-auth-secret
fi

read -rsp "Fireworks API key (hidden; Enter to skip): " key
echo
if [ -n "$key" ]; then printf %s "$key" | put osms-fireworks-api-key; fi
unset key
