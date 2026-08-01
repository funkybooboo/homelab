#!/bin/bash
# ha-state-watch.sh -- poll PVE HA-manager service states and publish an
# ntfy phone push when a managed resource transitions into an
# error/stopped/blocked state (the silent failures -- planned migrations
# and clean restarts are NOT pushed, on purpose).
#
# Deployed to /usr/local/sbin/ha-state-watch.sh on every PVE node + a
# /etc/cron.d/ha-state-watch entry firing every 1 min. State is persisted
# to /var/lib/ha-state-watch.prev so only transitions are pushed (not every
# poll).
#
# Uses `ha-manager status` (works on any cluster node; one node running
# this is enough, but running on all 5 is safe -- the dedup is per-host
# and the bridge is idempotent on identical messages).
set -u

NTFY_HELPER=/usr/local/sbin/ntfy-publish.sh
[ -r "$NTFY_HELPER" ] && . "$NTFY_HELPER"
ntfy_publish() { :; }

STATE_FILE=/var/lib/ha-state-watch.prev
HOST=$(hostname)

# ha-manager status output (plain text):
#   quorum OK
#   master node: pve-thermaltake (id 1)
#   service ct:101 (pve-thermaltake, started)
#   service ct:102 (pve-thermaltake, error)
# The state is inside parens as the last comma-separated field. We watch
# every service line and push on transitions into {error, stopped, blocked,
# frozen}. Recoveries (-> started) ALSO push so you see the all-clear.
BAD_STATES='error|stopped|blocked|frozen'

# Build a per-service state map for diff. Format: "<svc>=<state>" with the
# trailing ')' stripped from the state.
cur_map=$(ha-manager status 2>/dev/null | \
  awk '/^service / {svc=$2; gsub(/[()]/, "", $NF); print svc"="$NF}')
prev_map=""
[ -r "$STATE_FILE" ] && prev_map=$(cat "$STATE_FILE")

# Only act on changes.
if [ "$cur_map" = "$prev_map" ]; then
  exit 0
fi

# Find services whose state changed into or out of a bad state.
while IFS= read -r line; do
  svc=${line%%=*}; state=${line#*=}
  prev_state=$(printf '%s\n' "$prev_map" | awk -v s="$svc" -F= '$1==s {print $2}')
  [ -z "$prev_state" ] && prev_state="(unknown)"
  if [ "$state" = "$prev_state" ]; then
    continue
  fi
  # Push on transitions involving a bad state (in either direction).
  if echo "$state"     | grep -qE "^($BAD_STATES)$" || \
     echo "$prev_state" | grep -qE "^($BAD_STATES)$"; then
    if echo "$state" | grep -qE "^($BAD_STATES)$"; then
      ntfy_publish "[FAIL] HA $svc on $HOST -> $state" \
        "ha-manager service $svc transitioned $prev_state -> $state on $HOST. Needs human." \
        urgent rotating_light
    else
      ntfy_publish "[OK] HA $svc on $HOST -> $state" \
        "ha-manager service $svc recovered: $prev_state -> $state on $HOST." \
        default white_check_mark
    fi
  fi
done <<< "$cur_map"

printf '%s\n' "$cur_map" > "$STATE_FILE"
exit 0
