#!/bin/bash
# pve-shared-remount.sh -- auto-remount the pve-shared + pve-backups NFS
# storages on a PVE node when pvesm reports them inactive.
#
# Safe to run from cron. Logs to /var/log/pve-shared-remount.log.
# Idempotent: exits 0 if already active.

set -u
LOG=/var/log/pve-shared-remount.log
NFS_SERVER=192.168.8.100

log() { echo "$(date -Iseconds) $*" >> "$LOG"; }

# Phase 1e: push to ntfy when an actual remount happens (this is the event
# you want to know about -- a silent NFS blip recovered automatically, OR
# didn't recover and needs a human). No-op if /etc/ntfy-publish.env is absent.
NTFY_HELPER=/usr/local/sbin/ntfy-publish.sh
[ -r "$NTFY_HELPER" ] && . "$NTFY_HELPER"
ntfy_publish() { :; }

# name  export-path  mount-point
declare -A STORES=(
  [pve-shared]="/mnt/volume1/pve/shared"
  [pve-backups]="/mnt/volume1/pve/backups"
)
declare -A MOUNTS=(
  [pve-shared]="/mnt/pve/pve-shared"
  [pve-backups]="/mnt/pve/pve-backups"
)

any_failed=0
for name in pve-shared pve-backups; do
  export_path="${STORES[$name]}"
  mount_point="${MOUNTS[$name]}"
  state=$(pvesm status 2>/dev/null | awk -v n="$name" '$1==n {print $3}')

  if [ "$state" = "active" ]; then
    continue
  fi

  any_failed=1
  log "WARN: $name state='$state' -- attempting remount"

  # Unmount any stale handle first (ignore errors if not mounted)
  umount "$mount_point" 2>>"$LOG" || true

  # Re-mount NFSv4 (matches /etc/pve/storage.cfg options soft,timeo=5,retrans=2)
  mount -t nfs4 -o soft,timeo=5,retrans=2 \
    "${NFS_SERVER}:${export_path}" "$mount_point" 2>>"$LOG"

  # Ask PVE storage plugin to re-evaluate
  pvesm nfsscan "$NFS_SERVER" "$export_path" 2>>"$LOG" || true
done

# Final verification pass
if [ "$any_failed" = "1" ]; then
  sleep 2
  pvesm status >/dev/null 2>&1
  recovered=""; still_down=""
  for name in pve-shared pve-backups; do
    state=$(pvesm status 2>/dev/null | awk -v n="$name" '$1==n {print $3}')
    if [ "$state" != "active" ]; then
      log "ERROR: $name STILL inactive after remount attempt -- needs human"
      still_down="$still_down $name"
    else
      log "OK: $name recovered (active)"
      recovered="$recovered $name"
    fi
  done
  # Phone pushes: one per outcome. Both fire if mixed.
  if [ -n "$recovered" ]; then
    ntfy_publish "[OK] pve-shared remounted on $(hostname)" "recovered:$recovered -- NFS blip auto-recovered, no action needed" default wrench
  fi
  if [ -n "$still_down" ]; then
    ntfy_publish "[FAIL] pve-shared STILL down on $(hostname)" "still inactive:$still_down -- needs human. See /var/log/pve-shared-remount.log" urgent rotating_light
  fi
fi

exit 0