#!/bin/sh
# Development only: sign a test reader in with a development link and print their
# session cookie (name=value), for the macOS integration test (`make test-macos`).
# Needs sign-in running with OSMS_DEV_SIGN_IN=1, and reads its log with $AUTH_LOG
# (default `tilt logs auth`). Production never prints links, so this can't work there.
set -eu
email="${1:?usage: dev-session.sh <email>}"
auth="${BETTER_AUTH_URL:-http://localhost:3000}"
app="${OSMS_APP_ORIGIN:-http://localhost:8080}"
log="${AUTH_LOG:-tilt logs auth}"

links() { $log 2>/dev/null | grep '\[dev sign-in\]' || true; }

before=$(links | wc -l)
curl -fsS -o /dev/null -X POST "$auth/api/auth/sign-in/magic-link" \
  -H 'Content-Type: application/json' -H "Origin: $app" \
  -d "{\"email\":\"$email\",\"callbackURL\":\"$app/\"}"

# The link reaches the log at once; through Tilt it can take a moment.
link=""
for _ in 1 2 3 4 5 6 7 8 9 10; do
  if [ "$(links | wc -l)" -gt "$before" ]; then
    link=$(links | tail -1 | sed 's/.*sign in: //')
    break
  fi
  sleep 1
done
[ -n "$link" ] || { echo "No sign-in link in the log. Is sign-in running with OSMS_DEV_SIGN_IN=1?" >&2; exit 1; }

curl -fsS -o /dev/null -D - "$link" | tr -d '\r' \
  | sed -n 's/^[Ss]et-[Cc]ookie: \(better-auth\.session_token=[^;]*\).*/\1/p' | head -1
