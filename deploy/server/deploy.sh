#!/usr/bin/env bash
# Installs one release on the server and makes it live; rolls back if it doesn't come up
# healthy. Runs as root on the VM: deploy/release.sh unpacks the release into
# /opt/osms/releases/<id> and calls `deploy.sh <id>`.
set -euo pipefail
id=${1:?usage: deploy.sh <release id>}
dir=/opt/osms/releases/$id
[ -d "$dir/backend" ] && [ -d "$dir/web" ] || { echo "no release at $dir" >&2; exit 1; }
previous=$(readlink -f /opt/osms/current 2>/dev/null || true)
domain=$(cat /etc/osms/domain)

echo "== packages"
export UV_PROJECT_ENVIRONMENT=/opt/osms/venv UV_PYTHON_INSTALL_DIR=/opt/osms/uv/python \
  UV_CACHE_DIR=/opt/osms/uv/cache UV_PYTHON=3.13
(cd "$dir/backend" && uv sync --frozen --extra models --no-dev --quiet)
(cd "$dir/auth" && npm ci --omit=dev --no-audit --no-fund --loglevel=error)

echo "== settings"
bash "$dir/deploy/server/render-env.sh"
sed "s/@DOMAIN@/$domain/g" "$dir/deploy/server/Caddyfile" >/etc/caddy/Caddyfile.new
if ! out=$(caddy validate --config /etc/caddy/Caddyfile.new --adapter caddyfile 2>&1); then
  echo "$out" >&2
  exit 1
fi
mv /etc/caddy/Caddyfile.new /etc/caddy/Caddyfile
install -m 0644 "$dir"/deploy/server/osms-*.service /etc/systemd/system/
systemctl daemon-reload

go_live() { # go_live <release dir>
  ln -sfn "$1" /opt/osms/current.new && mv -Tf /opt/osms/current.new /opt/osms/current
  systemctl enable --quiet osms-auth osms-api osms-worker
  systemctl restart osms-auth osms-api osms-worker
  systemctl reload caddy || systemctl restart caddy
}
healthy() { # sign-in and the API answer within a minute
  for _ in $(seq 1 30); do
    if curl -fsS http://127.0.0.1:3000/health >/dev/null 2>&1 && curl -fsS http://127.0.0.1:8000/health >/dev/null 2>&1; then
      return 0
    fi
    sleep 2
  done
  return 1
}

echo "== going live: $id"
go_live "$dir"
if ! healthy; then
  echo "release $id isn't healthy; its logs:" >&2
  journalctl -u osms-auth -u osms-api -n 40 --no-pager >&2 || true
  if [ -n "$previous" ] && [ "$previous" != "$dir" ]; then
    echo "rolling back to $(basename "$previous")" >&2
    go_live "$previous"
  fi
  exit 1
fi

# Keep the last five releases for rollbacks.
ls -1dt /opt/osms/releases/* | tail -n +6 | xargs -r rm -rf
echo "live: $id (https://app.$domain)"
