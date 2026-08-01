#!/bin/bash
# ntfy-publish.sh -- shared helper for publishing ntfy phone pushes from
# PVE hosts + TrueNAS. Sourced by other scripts (renew-pve-tls.sh,
# pve-shared-remount.sh, vzdump-notify.sh, ha-state-watch.sh).
#
# Reads /etc/ntfy-publish.env (mode 600, root-only) for:
#   NTFY_TOPIC    -- the unguessable phone topic (e.g. homelab-XXXXXXXX)
#   NTFY_TOKEN    -- a long-lived ntfy access token with write on that topic
#   NTFY_URL      -- (optional) ntfy base URL, defaults to the tailnet serve front
#
# Exposes: ntfy_publish <title> <message> [priority] [tags]
#   priority: urgent|high|default|low|min (default: default)
#   tags:     comma-separated emoji shortcodes (default: bell)
# Exits non-zero only on a publish HTTP failure (so callers can chain on
# the ntfy failure path too if they care -- most don't; the alert itself
# is the primary signal).
#
# No secrets are baked in. The /etc/ntfy-publish.env file is deployed
# out-of-band (see services/observability/ntfy-publish.env.example).

NTFY_PUBLISH_ENV="${NTFY_PUBLISH_ENV:-/etc/ntfy-publish.env}"
if [ -r "$NTFY_PUBLISH_ENV" ]; then
  # shellcheck disable=SC1090
  . "$NTFY_PUBLISH_ENV"
fi

: "${NTFY_TOPIC:=}"
: "${NTFY_TOKEN:=}"
: "${NTFY_URL:=https://ntfy.tail54538d.ts.net}"

ntfy_publish() {
  local title="$1" message="${2:-}" priority="${3:-default}" tags="${4:-bell}"
  if [ -z "$NTFY_TOPIC" ] || [ -z "$NTFY_TOKEN" ]; then
    echo "ntfy-publish: NTFY_TOPIC/NTFY_TOKEN unset ($NTFY_PUBLISH_ENV missing?); not publishing" >&2
    return 0  # don't fail the caller just because the notifier is unconfigured
  fi
  local code
  code=$(curl -sS -o /dev/null -w '%{http_code}' \
    --max-time 10 \
    -X POST \
    -H "Authorization: Bearer $NTFY_TOKEN" \
    -H "Title: $title" \
    -H "Priority: $priority" \
    -H "Tags: $tags" \
    -d "$message" \
    "$NTFY_URL/$NTFY_TOPIC" 2>/dev/null)
  if [ "$code" != "200" ]; then
    echo "ntfy-publish: HTTP $code publishing to $NTFY_URL/$NTFY_TOPIC" >&2
    return 1
  fi
  return 0
}
