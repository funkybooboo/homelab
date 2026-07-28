#!/bin/bash
# renew-pve-tls.sh -- re-issue a tailscale Let's Encrypt cert for THIS PVE node's
# tailscale hostname and install it as the pveproxy cert (pveproxy-ssl.pem via
# pvenode cert set). Idempotent: only reinstalls when the SHA1 changes.
# Run weekly via /etc/cron.d/renew-pve-tls. Logs to stdout (cron -> /var/log/renew-pve-tls.log).
# Revert to cluster-CA self-signed: pvenode cert delete
set -euo pipefail
HOST="$(hostname).tail54538d.ts.net"
WORK=$(mktemp -d); trap "rm -rf $WORK" EXIT
CRT=$WORK/cert.crt; KEY=$WORK/cert.key
log() { echo "[$(date -u +%FT%TZ)] $HOST $1"; }

# 1. issue (cached unless <30d validity left via --min-validity 720h)
tailscale cert --cert-file "$CRT" --key-file "$KEY" --min-validity 720h "$HOST" >/dev/null
NEW_FP=$(openssl x509 -in "$CRT" -noout -fingerprint -sha1 | cut -d= -f2 | tr -d ":" | tr "a-f" "A-F")
INSTALLED=/etc/pve/local/pveproxy-ssl.pem
OLD_FP=""
[ -f "$INSTALLED" ] && OLD_FP=$(openssl x509 -in "$INSTALLED" -noout -fingerprint -sha1 2>/dev/null | cut -d= -f2 | tr -d ":" | tr "a-f" "A-F" || echo "")

if [ -n "$NEW_FP" ] && [ "$NEW_FP" = "$OLD_FP" ]; then
  log "fingerprint matches installed pveproxy-ssl.pem; nothing to do. Exit 0."
  exit 0
fi
log "installing new cert (old=${OLD_FP:-none})."
pvenode cert set "$CRT" "$KEY" >/dev/null
systemctl restart pveproxy
sleep 1
log "installed + pveproxy restarted. new fp=$NEW_FP"