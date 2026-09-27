#!/bin/bash
# auto-update-maint.sh -- Sunday maintenance for PVE hosts (design:
# "Sundays apt autoclean + journalctl --vacuum-time=7d, separate cron,
# no ntfy unless it errors"). Scheduled via /etc/cron.d/auto-update-maint.

set -u

[ -r /usr/local/sbin/ntfy-publish.sh ] && . /usr/local/sbin/ntfy-publish.sh
HOSTNAME_S=$(hostname -s)

rc=0
out1=$(apt-get autoclean 2>&1) || rc=1
out2=$(journalctl --vacuum-time=7d 2>&1) || rc=1

if [ $rc -ne 0 ]; then
        if type ntfy_publish >/dev/null 2>&1; then
                ntfy_publish "Auto-update maint FAILED ($HOSTNAME_S)" \
                        "$(printf '%s\n%s' "$out1" "$out2" | tail -c 400)" urgent rotating_light
        fi
        exit 1
fi
exit 0