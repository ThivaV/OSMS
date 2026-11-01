#!/usr/bin/env bash
# Gives the server a copy of your local stories (DEPLOY.md), so the demo has real stories,
# facts, summaries and the demo's briefing from the first minute, without paying for
# those model calls again. Readers are left out: no accounts, emails, interests, read
# state or readers' briefings leave your Mac. Sign-in's own database (data/auth.db)
# stays here.
#
#   bash deploy/seed.sh          # refuses if the server already has stories
#   FORCE=1 bash deploy/seed.sh  # replaces the server's stories (theirs are lost)
#
# Stop the local worker first (`make stop-worker`): Milvus Lite must be closed to copy it.
set -euo pipefail
. "$(dirname "$0")/lib.sh"
load_config
data="$ROOT/data"
[ -f "$data/osms.db" ] || { echo "no local data/osms.db to copy" >&2; exit 1; }
if sh "$ROOT/scripts/processes.sh" list worker milvus | grep -q ': running'; then
  echo "The local worker is running: stop it first (make stop-worker)." >&2
  exit 1
fi

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/data/briefings" "$work/data/visuals"
sqlite3 "$data/osms.db" ".backup '$work/data/osms.db'"
sqlite3 "$work/data/osms.db" <<'SQL'
PRAGMA foreign_keys = ON;
DELETE FROM users;
DELETE FROM jobs WHERE kind = 'make-briefing' AND ref != 'demo';
VACUUM;
SQL
left=$(sqlite3 "$work/data/osms.db" "select (select count(*) from users) + (select count(*) from subscriptions) + (select count(*) from interests) + (select count(*) from read_state) + (select count(*) from briefings where user_id is not null);")
[ "$left" = 0 ] || { echo "reader data is still in the copy; nothing was sent" >&2; exit 1; }
cp -R "$data/milvus.db" "$work/data/milvus.db"
for name in $(sqlite3 "$work/data/osms.db" "select audio_path from briefings where audio_path is not null"); do
  [ -f "$data/briefings/$name" ] && cp "$data/briefings/$name" "$work/data/briefings/"
done
[ -d "$data/visuals" ] && cp -R "$data/visuals/." "$work/data/visuals/" 2>/dev/null || true
COPYFILE_DISABLE=1 tar --no-xattrs --exclude='._*' -czf "$work/seed.tgz" -C "$work" data
echo "== copying $(du -h "$work/seed.tgz" | cut -f1) of stories to $GCP_VM (no readers)"

to_server "$work/seed.tgz" /tmp/osms-seed.tgz
on_server "sudo bash -c 'set -e
  if [ -s /var/lib/osms/data/osms.db ] && [ \"${FORCE:-}\" != 1 ]; then
    echo \"The server already has stories: FORCE=1 replaces them.\" >&2; rm -f /tmp/osms-seed.tgz; exit 1
  fi
  systemctl stop osms-worker osms-api 2>/dev/null || true
  rm -rf /var/lib/osms/data/osms.db* /var/lib/osms/data/milvus.db /var/lib/osms/data/briefings /var/lib/osms/data/visuals
  tar -xzf /tmp/osms-seed.tgz -C /var/lib/osms && rm -f /tmp/osms-seed.tgz
  chown -R osms:osms /var/lib/osms/data
  if [ -e /opt/osms/current ]; then systemctl start osms-api osms-worker; fi
  echo seeded'"
