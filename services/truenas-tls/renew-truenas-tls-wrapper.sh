#!/bin/bash
# renew-truenas-tls-wrapper.sh -- wraps renew-truenas-tls.py to publish an
# ntfy phone push on failure (TrueNAS cronjobs have no native on-failure
# hook, and mail-to-root is often unset -- the silent failure path this
# cert renew had before Phase 1e).
#
# Deployed to /mnt/volume1/.admin/renew-truenas-tls-wrapper.sh on TrueNAS
# alongside renew-truenas-tls.py. The TrueNAS cronjob (id 1, "Renew truenas
# tailscale TLS cert") is updated to call THIS wrapper instead of the
# python directly:
#   /mnt/volume1/.admin/renew-truenas-tls-wrapper.sh
#
# Sources /etc/ntfy-publish.env (mode 600, root-only) for credentials.
# Exits with the python's status so the TrueNAS job still surfaces failure
# in its job history.

set -u
PY=/mnt/volume1/.admin/renew-truenas-tls.py
ENV=/etc/ntfy-publish.env
HOST=truenas.tail54538d.ts.net

# Load credentials + helper.
[ -r "$ENV" ] && . "$ENV"
: "${NTFY_TOPIC:=}"
: "${NTFY_TOKEN:=}"
: "${NTFY_URL:=https://ntfy.tail54538d.ts.net}"

ntfy_publish() {
  local title="$1" message="$2" priority="${3:-default}" tags="${4:-bell}"
  [ -z "$NTFY_TOPIC" ] || [ -z "$NTFY_TOKEN" ] && return 0
  curl -sS -o /dev/null --max-time 10 -X POST \
    -H "Authorization: Bearer $NTFY_TOKEN" \
    -H "Title: $title" \
    -H "Priority: $priority" \
    -H "Tags: $tags" \
    -d "$message" \
    "$NTFY_URL/$NTFY_TOPIC" 2>/dev/null
}

if ! out=$(/usr/bin/python3 "$PY" 2>&1); then
  rc=$?
  # Truncate to ~400 chars so the phone notification stays readable.
  snippet=$(printf '%s' "$out" | tail -c 400)
  ntfy_publish "[FAIL] renew-truenas-tls" "truenas cert renew failed (exit $rc). Tail: $snippet" urgent rotating_light
  printf '%s\n' "$out"
  exit $rc
fi

# Optional success ping only when output indicates a rotation happened
# (the python logs "re-import" / "rebind" on a real change). Keep it
# low-priority so the renew path is observably alive without noise.
case "$out" in
  *re-import*|*rebind*|*rotated*)
    ntfy_publish "[OK] renew-truenas-tls" "truenas cert rotated. See TrueNAS cronjob 1 log." low white_check_mark
    ;;
esac

printf '%s\n' "$out"
exit 0
