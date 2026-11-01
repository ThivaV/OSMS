#!/usr/bin/env bash
# Prepares the server, once (DEPLOY.md): Caddy (HTTPS), Node 24, uv, the osms user and
# the folders. Safe to run again. Runs as root on the VM: `make server-setup` sends it.
#
#   /opt/osms/releases/<id>   each release: backend/, auth/, deploy/, scripts/, web/
#   /opt/osms/current         the live release
#   /opt/osms/venv            the backend's Python environment, shared by releases
#   /var/lib/osms/data        the databases (SQLite, Milvus Lite), briefings, illustrations
#   /var/lib/osms/cache       downloaded models (Hugging Face)
#   /etc/osms/osms.env        settings and secrets, from Secret Manager (root and osms only)
set -euo pipefail
domain=${1:?usage: setup.sh <domain, e.g. yourname.duckdns.org>}
UV_VERSION=0.12.1

export DEBIAN_FRONTEND=noninteractive
apt-get update -q
apt-get install -yq curl ca-certificates gnupg debian-keyring debian-archive-keyring apt-transport-https \
  python3 sqlite3 xz-utils

# Caddy, from its own package repository: HTTPS certificates are automatic.
if ! command -v caddy >/dev/null; then
  curl -1sLf https://dl.cloudsmith.io/public/caddy/stable/gpg.key |
    gpg --dearmor --yes -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
  curl -1sLf https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt >/etc/apt/sources.list.d/caddy-stable.list
  apt-get update -q && apt-get install -yq caddy
fi

# Node 24 (sign-in), the official build, checked against its published checksum.
if ! node --version 2>/dev/null | grep -q '^v24\.'; then
  tmp=$(mktemp -d)
  base=https://nodejs.org/dist/latest-v24.x
  curl -fsSL "$base/SHASUMS256.txt" -o "$tmp/SHASUMS256.txt"
  file=$(grep -o 'node-v24[0-9.]*-linux-x64\.tar\.xz' "$tmp/SHASUMS256.txt" | head -1)
  curl -fsSL "$base/$file" -o "$tmp/$file"
  (cd "$tmp" && grep " $file\$" SHASUMS256.txt | sha256sum -c -)
  tar -xJf "$tmp/$file" -C /usr/local --strip-components=1
  rm -rf "$tmp"
fi

# uv (the backend's Python and packages), pinned.
if ! uv --version 2>/dev/null | grep -q " $UV_VERSION"; then
  curl -LsSf "https://astral.sh/uv/$UV_VERSION/install.sh" | env UV_INSTALL_DIR=/usr/local/bin INSTALLER_NO_MODIFY_PATH=1 sh
fi

# The user the services run as, and their folders.
id osms >/dev/null 2>&1 || useradd --system --home-dir /var/lib/osms --shell /usr/sbin/nologin osms
install -d -o osms -g osms -m 0750 /var/lib/osms /var/lib/osms/data /var/lib/osms/cache
install -d -m 0755 /opt/osms /opt/osms/releases /opt/osms/uv
install -d -g osms -m 0750 /etc/osms
printf '%s\n' "$domain" >/etc/osms/domain

# A little swap, so a briefing's voices loading never meets an out-of-memory kill.
if ! swapon --show | grep -q /swapfile; then
  fallocate -l 4G /swapfile && chmod 600 /swapfile && mkswap /swapfile >/dev/null && swapon /swapfile
  grep -q '^/swapfile' /etc/fstab || echo '/swapfile none swap sw 0 0' >>/etc/fstab
fi

echo "Server ready for $domain: caddy $(caddy version | cut -d' ' -f1), node $(node --version), $(uv --version)"
