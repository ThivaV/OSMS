#!/usr/bin/env bash
# Puts OSMS's secrets into Secret Manager, where only the server can read them. Run it
# yourself, in your own terminal: it never prints a value, and a key never has to pass
# through a chat or a file in the repo.
#
#   bash deploy/gcp/secrets.sh
#
# - META_API_KEY, GOOGLE_CLIENT_ID, GOOGLE_CLIENT_SECRET and FIREWORKS_API_KEY come from
#   your local .env; the Fireworks key is asked for, hidden as you type, when .env has
#   none (Enter skips it)
# - the sign-in secret is made fresh, once (making a new one later signs everyone out)
# - a value that is already the latest version is left as it is
set -euo pipefail
. "$(dirname "$0")/../lib.sh"
load_config

put() { # put NAME: the value arrives on stdin
  local value
  value=$(cat)
  if g secrets describe "$1" >/dev/null 2>&1; then
    if [ "$(g secrets versions access latest --secret "$1" 2>/dev/null || true)" = "$value" ]; then
      echo "unchanged $1"
      return
    fi
    printf %s "$value" | g secrets versions add "$1" --data-file=- >/dev/null
  else
    printf %s "$value" | g secrets create "$1" --replication-policy automatic --data-file=- >/dev/null
  fi
  echo "stored $1"
}
from_env() { # a value from .env, without the quotes around it
  local value
  value=$(grep -E "^$1=" "$ROOT/.env" 2>/dev/null | head -1 | cut -d= -f2- | tr -d '\r' || true)
  case "$value" in \"*\" | \'*\') value=${value:1:${#value}-2} ;; esac
  printf %s "$value"
}

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

key=$(from_env FIREWORKS_API_KEY)
where="FIREWORKS_API_KEY in .env"
if [ -z "$key" ]; then
  read -rsp "Fireworks API key (hidden; Enter to skip): " key
  echo
  where="that key"
fi
if [ -n "$key" ]; then
  # Fireworks must accept it first: a mistyped key only shows up as a 401 on the server.
  # The key reaches curl on stdin, never on a command line.
  code=$(printf 'Authorization: Bearer %s' "$key" |
    curl -s -o /dev/null -w '%{http_code}' -H @- https://api.fireworks.ai/inference/v1/models || true)
  if [ "$code" != 200 ]; then
    unset key
    echo "Fireworks refused $where (HTTP $code), so it wasn't stored: copy it again from fireworks.ai." >&2
    exit 1
  fi
  printf %s "$key" | put osms-fireworks-api-key
fi
unset key
