#!/bin/bash
# truenas-update-check.sh -- notify-only update poller for TrueNAS (design
# ideas/auto-update.md Tier C: TrueNAS is a ZFS appliance and is NEVER
# auto-patched; apply stays manual via System -> Update).
#
# Polls the middleware for a pending system update and pushes an ntfy phone
# alert ON TRANSITION to "update available" (urgent). Silent when steady.
# Scheduled daily 09:00 TrueNAS-local via a middleware cronjob (see README).
# State file lives on volume1 (root FS is mostly read-only).

set -u

ENV=/etc/ntfy-publish.env
[ -r "$ENV" ] && . "$ENV"
: "${NTFY_TOPIC:=}"
: "${NTFY_URL:=https://ntfy.tail54538d.ts.net}"
STATE=/mnt/volume1/.admin/.truenas-update-state

ntfy_publish() {
        # title message priority tags
        [ -n "$NTFY_TOPIC" ] || return 0
        curl -sS -o /dev/null --max-time 10 -X POST \
                -H "Title: $1" \
                -H "Priority: ${3:-default}" \
                -H "Tags: ${4:-bell}" \
                -d "$2" \
                "$NTFY_URL/$NTFY_TOPIC" 2>/dev/null
}

avail=$(midclt call update.status 2>/dev/null | jq -r '.status.new_version.version // empty' 2>/dev/null)
prev=$(cat "$STATE" 2>/dev/null)

if [ -n "$avail" ] && [ "$avail" != "$prev" ]; then
        ntfy_publish "TrueNAS update available" \
                "TrueNAS $avail is available. Apply manually: System -> Update (auto-apply disabled by design)." \
                urgent arrow_up
        printf '%s' "$avail" > "$STATE"
elif [ -z "$avail" ] && [ -n "$prev" ]; then
        : > "$STATE"        # update cleared (applied or withdrawn); silent
fi

exit 0