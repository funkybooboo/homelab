#!/bin/sh
# alpine-upgrade-wrapper.sh -- nightly auto-update runner for the one apk
# CT (101 alpine-it-tools). apk update + upgrade, ntfy push ONLY on failure
# (design: silent on a clean run). Scheduled via /etc/crontabs/root.

[ -r /usr/local/sbin/ntfy-publish.sh ] && . /usr/local/sbin/ntfy-publish.sh

HOSTNAME_S=$(hostname -s)

out=$(apk update 2>&1 && apk upgrade 2>&1)
rc=$?

[ $rc -eq 0 ] && exit 0

snippet=$(printf '%s' "$out" | tail -c 500)
if type ntfy_publish >/dev/null 2>&1; then
        ntfy_publish "Auto-update FAILED ($HOSTNAME_S)" "$snippet" urgent rotating_light
fi
exit 1