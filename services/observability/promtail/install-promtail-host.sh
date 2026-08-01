#!/bin/bash
# install-promtail-host.sh -- install promtail on a PVE host or CT,
# reading local journald and pushing to central Loki at
# https://loki.tail54538d.ts.net. Idempotent: safe to re-run.
#
# Self-contained: downloads the binary, writes the config + unit, starts
# it. Run as root, on any host/CT that has systemd + journald.
#
# VERSION pin: promtail 3.6.11 (last release bundling promtail, wire-
# compatible with Loki 3.7.x). amd64 only -- arm64 hosts (raspberrypi)
# need the arm64 variant; this script downloads the matching arch.

set -euo pipefail
VER=3.6.11
ARCH="$(uname -m)"
case "$ARCH" in
  x86_64)  ARCH=amd64 ;;
  aarch64) ARCH=arm64 ;;
  armv7l)  ARCH=arm   ;;
  *) echo "unsupported arch $ARCH" >&2; exit 1 ;;
esac

URL="https://github.com/grafana/loki/releases/download/v${VER}/promtail-linux-${ARCH}.zip"

if [ ! -x /usr/bin/promtail ] || ! /usr/bin/promtail --version 2>&1 | grep -q "version ${VER}"; then
  echo "installing promtail ${VER} (${ARCH})"
  cd /tmp
  curl -fsSL "$URL" -o /tmp/promtail.zip
  apt-get install -y --no-install-recommends unzip >/dev/null 2>&1 || true
  unzip -o /tmp/promtail.zip promtail-linux-${ARCH} -d /tmp/pt >/dev/null
  install -m 0755 /tmp/pt/promtail-linux-${ARCH} /usr/bin/promtail
  rm -rf /tmp/promtail.zip /tmp/pt/
else
  echo "promtail ${VER} already installed"
fi

mkdir -p /etc/promtail /var/lib/promtail /var/log/journal

HOST=$(hostname)
cat > /etc/promtail/config.yml <<EOF
server:
  http_listen_port: 9080
  grpc_listen_port: 0
  log_level: warn

positions:
  filename: /var/lib/promtail/positions.yaml

clients:
  - url: https://loki.tail54538d.ts.net/loki/api/v1/push
    tls_config:
      # Loki's cert is a real Let's Encrypt for loki.tail54538d.ts.net,
      # so promtail can verify it directly. No insecure_skip_verify.
      {}

scrape_configs:
  - job_name: journal
    journal:
      path: /var/log/journal
      max_age: 24h
      labels:
        job: systemd-journal
        host: ${HOST}
    relabel_configs:
      - source_labels: ["__journal_priority_keyword"]
        target_label: severity
      - source_labels: ["__journal__systemd_unit"]
        target_label: unit
      - source_labels: ["__journal_priority"]
        regex: "7"
        action: drop
    pipeline_stages:
      - template:
          source: level
          template: '{{ if le .Value "2" }}error{{ else if le .Value "4" }}warning{{ else }}info{{ end }}'
      - labels:
          level:
EOF

cat > /etc/systemd/system/promtail.service <<EOF
[Unit]
Description=promtail (journald -> Loki pusher)
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=/usr/bin/promtail -config.file=/etc/promtail/config.yml
Restart=on-failure
RestartSec=5
NoNewPrivileges=true
ProtectSystem=full
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable promtail >/dev/null
# enable --now does NOT restart on config change; restart explicitly so
# re-running this script picks up config updates.
systemctl restart promtail
sleep 2
systemctl is-active promtail
echo "promtail installed + active -- pushing to https://loki.tail54538d.ts.net"