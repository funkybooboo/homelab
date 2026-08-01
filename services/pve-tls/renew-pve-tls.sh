#!/bin/bash
# renew-pve-tls.sh -- re-issue a tailscale Let's Encrypt cert for THIS PVE node's
# tailscale hostname and install it as the pveproxy cert (pveproxy-ssl.pem via
# pvenode cert set). Idempotent: only reinstalls when the SHA1 changes.
# Run weekly via /etc/cron.d/renew-pve-tls. Logs to stdout (cron -> /var/log/renew-pve-tls.log).
# Revert to cluster-CA self-signed: pvenode cert delete
#
# Phase 1e: publishes an ntfy phone push on FAILURE (the silent-failure path
# this script used to have -- cron mail-to-root is often unset). Also pushes
# a low-priority confirmation when a cert is actually rotated, so the renew
# path is observably alive. Sources ntfy-publish.sh from the same services
# tree if present; otherwise a no-op notifier.
set -euo pipefail
HOST="$(hostname).tail54538d.ts.net"
WORK=$(mktemp -d); trap "rm -rf $WORK" EXIT
CRT=$WORK/cert.crt; KEY=$WORK/cert.key
log() { echo "[$(date -u +%FT%TZ)] $HOST $1"; }

# Load the ntfy publisher helper (no-op if /etc/ntfy-publish.env is missing).
NTFY_HELPER=/usr/local/sbin/ntfy-publish.sh
[ -r "$NTFY_HELPER" ] && . "$NTFY_HELPER"
ntfy_publish() { :; }  # override-safe no-op if helper didn't define it

# On any error: log + push to ntfy, then re-exit with the original status.
trap 'rc=$?; log "FAILED (exit $rc)"; ntfy_publish "[FAIL] renew-pve-tls $HOST" "cert renew failed on $HOST (exit $rc). See /var/log/renew-pve-tls.log." urgent rotating_light; exit $rc' ERR

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
# Confirms the renew path is alive -- only fires on an actual rotation.
ntfy_publish "[OK] renew-pve-tls $HOST" "cert rotated on $HOST. new fp=$NEW_FP" low white_check_mark