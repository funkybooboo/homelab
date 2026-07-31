#!/bin/bash
# install-node-exporter-host.sh -- idempotent node_exporter install on a PVE host.
# Part of docs/observability.md Phase 1a. Pinned to node_exporter v1.12.1.
#
# Installs:  /usr/local/bin/node_exporter (static binary, arch-detected)
#            /etc/systemd/system/node_exporter.service
# Enables:   node_exporter.service (listens 0.0.0.0:9100)
#
# Run on the host (not inside a CT):
#   bash install-node-exporter-host.sh
# Re-running is safe (overwrites binary + unit, restarts service).
#
# Verify scrape from prometheus CT 122:
#   pct exec 122 -- wget -qO- 'http://localhost:9090/api/v1/query?query=up%7Bjob%3D%22node%22%7D'
#
# sha256s from https://github.com/prometheus/node_exporter/releases/download/v1.12.1/sha256sums.txt
set -euo pipefail

VERSION="1.12.1"
BASE="https://github.com/prometheus/node_exporter/releases/download/v${VERSION}"
declare -A SHA256=(
  [amd64]="b51d8a76aa2a9156a55d501aca6276fae09e262259a5e4e831d2c2222f084e63"
  [arm64]="ad35b605f9954b9f1ffddf5ba054bdc5a98d790b9eae5291e1eeb83f1ecbd0e7"
)

ARCH=$(uname -m)
case "$ARCH" in
  x86_64)  ARCH=amd64 ;;
  aarch64) ARCH=arm64 ;;
  *) echo "ERROR: unsupported arch $ARCH" >&2; exit 1 ;;
esac

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
TARBALL="node_exporter-${VERSION}.linux-${ARCH}.tar.gz"

echo "==> node_exporter v${VERSION} (${ARCH})"

# Download with checksum verification.
echo "-- downloading $TARBALL"
curl -fsSL -o "$TMP/$TARBALL" "${BASE}/${TARBALL}"
echo "${SHA256[$ARCH]}  $TMP/$TARBALL" | sha256sum -c -

# Extract the binary.
tar -xzf "$TMP/$TARBALL" -C "$TMP"
BIN="$TMP/node_exporter-${VERSION}.linux-${ARCH}/node_exporter"

# Install.
echo "-- installing /usr/local/bin/node_exporter"
install -m 0755 "$BIN" /usr/local/bin/node_exporter
/usr/local/bin/node_exporter --version | head -1

# systemd unit.
echo "-- writing /etc/systemd/system/node_exporter.service"
cat > /etc/systemd/system/node_exporter.service <<'UNIT'
[Unit]
Description=node_exporter (per-host metrics)
Documentation=https://github.com/prometheus/node_exporter
After=network-online.target
Wants=network-online.target

[Service]
User=root
Group=root
# Extra collectors beyond the defaults (see docs/observability.md Phase 1a):
#   systemd     -- per-unit state (active/failed/dead) -> alertable host services
#   mountstats  -- per-NFS-export ops/retransmits/rtt (smoking gun for NFS blips)
#   processes   -- per-process CPU/mem/IO (the "what's pounding the host" answer)
ExecStart=/usr/local/bin/node_exporter \
  --web.listen-address=0.0.0.0:9100 \
  --collector.systemd \
  --collector.mountstats \
  --collector.processes \
  --collector.filesystem.mount-points-exclude=^/(dev|proc|sys|run|var/lib/docker/.+)($|/) \
  --collector.filesystem.fs-types-exclude=^(tmpfs|overlay|squashfs|nsfs|autofs)$
Restart=on-failure
RestartSec=5
NoNewPrivileges=true
ProtectHome=true
ProtectSystem=strict
ReadWritePaths=/var/lib/node_exporter
StateDirectory=node_exporter

[Install]
WantedBy=multi-user.target
UNIT

mkdir -p /var/lib/node_exporter

# daemon-reload loads the unit; then enable + restart so a re-run ACTUALLY picks up
# ExecStart changes (enable --now alone is a no-op when already enabled+running).
systemctl daemon-reload
systemctl enable node_exporter.service
systemctl restart node_exporter.service

# Verify it's listening.
sleep 1
if curl -fsS -o /dev/null http://localhost:9100/metrics; then
  echo "==> OK: node_exporter serving :9100/metrics on $(hostname)"
else
  echo "==> ERROR: :9100/metrics not responding" >&2
  systemctl status node_exporter --no-pager | head -20 >&2
  exit 1
fi

echo "==> done. Add to prometheus.yml the 'node' job scraping <this-host>.tail54538d.ts.net:9100"