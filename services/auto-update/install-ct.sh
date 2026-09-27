#!/bin/bash
# install-ct.sh <vmid> -- idempotent per-CT installer. Run as root ON the
# node that currently hosts the CT (pct push only works there).
#
# Apt CTs (Debian trixie / Ubuntu noble):
#   unattended-upgrades + full-update allowlist (unattended-50.example)
#   needrestart auto-restart conf (services restart live; no CT reboot)
#   unattended-upgrade-wrapper.sh (ntfy on errors only)
#   ntfy-publish.sh + /etc/ntfy-publish.env (token, mode 600)
#   /etc/cron.d/auto-update  ->  nightly 03:30 America/Denver, tz-adaptive
#     (CTs run UTC, so 03:30 Denver == 09:30 UTC; the hour is computed from
#      the CT's own timezone at install time)
# Alpine CTs: alpine-upgrade-wrapper.sh (apk) + busybox crond entry instead.
#
# Re-run safe: every step overwrites or is guarded. Requires the CT running.

set -euo pipefail

id=${1:?usage: install-ct.sh <vmid>}
cd "$(dirname "$0")"

# pct push cannot create parent dirs; every target CT gets this dir
CT_PREP='mkdir -p /usr/local/sbin /etc/needrestart/conf.d 2>/dev/null || true'

name=$(pct list | awk -v i="$id" '$1==i{print $NF}')
[ -n "$name" ] || { echo "CT $id not found on $(hostname -s)"; exit 1; }
pct status "$id" | grep -q running || { echo "CT $id not running (start it first)"; exit 1; }
echo "[install-ct] $id $name on $(hostname -s)"

# ---------- Alpine path (CT 101) ----------
if pct exec "$id" -- sh -c 'command -v apk >/dev/null 2>&1' 2>/dev/null; then
        pct exec "$id" -- sh -c "$CT_PREP"
        pct push "$id" alpine-upgrade-wrapper.sh /usr/local/sbin/alpine-upgrade-wrapper.sh --perms 0755
        pct push "$id" /usr/local/sbin/ntfy-publish.sh /usr/local/sbin/ntfy-publish.sh --perms 0755
        [ -r /etc/ntfy-publish.env ] && pct push "$id" /etc/ntfy-publish.env /etc/ntfy-publish.env --perms 0600
        H=$(pct exec "$id" -- sh -c 'Z=$(date +%Z); case "$Z" in UTC) echo 9;; *) echo 3;; esac')
        pct exec "$id" -- sh -c "mkdir -p /etc/crontabs; touch /etc/crontabs/root
rc-update add crond default >/dev/null 2>&1 || true
/etc/init.d/crond status >/dev/null 2>&1 || /etc/init.d/crond start >/dev/null 2>&1 || true
grep -q alpine-upgrade-wrapper /etc/crontabs/root || echo \"30 $H * * * /usr/local/sbin/alpine-upgrade-wrapper.sh\" >> /etc/crontabs/root
grep alpine-upgrade-wrapper /etc/crontabs/root"
        echo "[install-ct] alpine path done (cron hour $H local)"
        exit 0
fi

# ---------- Apt path ----------
pct exec "$id" -- bash -c "$CT_PREP"
pct exec "$id" -- bash -c 'export DEBIAN_FRONTEND=noninteractive
apt-get update -qq >/dev/null 2>&1 || true
# DPkg::Lock::Timeout: wait politely (up to 10 min) if another apt run (e.g. a
# leftover sweep) holds the CT dpkg lock, instead of failing instantly.
apt-get install -y -o DPkg::Lock::Timeout=600 -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" unattended-upgrades needrestart >/dev/null 2>&1'

pct push "$id" unattended-50.example /etc/apt/apt.conf.d/50unattended-upgrades --perms 0644
pct push "$id" unattended-20.example /etc/apt/apt.conf.d/20auto-upgrades --perms 0644
pct push "$id" needrestart-auto.example /etc/needrestart/conf.d/auto-update.conf --perms 0644
pct push "$id" unattended-upgrade-wrapper.sh /usr/local/sbin/unattended-upgrade-wrapper.sh --perms 0755
pct push "$id" /usr/local/sbin/ntfy-publish.sh /usr/local/sbin/ntfy-publish.sh --perms 0755
[ -r /etc/ntfy-publish.env ] && pct push "$id" /etc/ntfy-publish.env /etc/ntfy-publish.env --perms 0600

H=$(pct exec "$id" -- bash -c 'Z=$(date +%Z); case "$Z" in UTC) echo 9;; MDT|MST) echo 3;; *) echo 9;; esac')
pct exec "$id" -- bash -c "printf '%s\n' '30 $H * * * root /usr/local/sbin/unattended-upgrade-wrapper.sh >/dev/null 2>&1' > /etc/cron.d/auto-update"
pct exec "$id" -- bash -c 'systemctl enable --now cron >/dev/null 2>&1 || service cron restart >/dev/null 2>&1 || true'

echo "[install-ct] done (cron: 30 $H * * * root wrapper, CT-local tz)"
pct exec "$id" -- bash -c 'unattended-upgrade --dry-run >/dev/null 2>&1 && echo "[install-ct] unattended-upgrade dry-run parses OK" || echo "[install-ct] WARN: dry-run failed"'