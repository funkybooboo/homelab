#!/bin/bash
# unattended-upgrade-wrapper.sh -- nightly auto-update runner for CTs and
# PVE hosts (design: services/auto-update). Runs unattended-upgrade with the
# full-update allowlist and pushes an ntfy phone alert ONLY on failure
# (locked user decision: silent on a clean run).
#
# PVE host mode is auto-detected (/etc/pve/nodes exists). Hosts additionally
# maintain the cluster-visible reboot-required flag:
#   /etc/pve/nodes/<host>/reboot-required     (pmxcfs, cluster-replicated)
# so pve-cluster-reboot-controller.sh (hourly, pmcfs-heartbeat-lock elected)
# can reboot flagged nodes SERIALIZED (witness first, HA master last) --
# never a self-reboot (Automatic-Reboot is false by design).
#
# Reboot-needed detection (hosts): any installed kernel tree newer than the
# current boot (arch-agnostic: works for proxmox-kernel AND the Raspberry Pi
# kernel variants), plus the classic /var/run/reboot-required if present.

set -u

[ -r /usr/local/sbin/ntfy-publish.sh ] && . /usr/local/sbin/ntfy-publish.sh

HOSTNAME_S=$(hostname -s)
LOGDIR=/var/log/unattended-upgrades
LOG="$LOGDIR/unattended-upgrades.log"
mkdir -p "$LOGDIR" 2>/dev/null || true

out=$(unattended-upgrade 2>&1)
rc=$?

{
        echo "--- $(date '+%Y-%m-%d %H:%M:%S') $HOSTNAME_S unattended-upgrade rc=$rc ---"
        printf '%s\n' "$out"
} >> "$LOG" 2>/dev/null

failed=0
if [ $rc -ne 0 ]; then
        failed=1
elif printf '%s' "$out" | grep -q "returned an error"; then
        failed=1
fi

if [ $failed -ne 0 ]; then
        snippet=$(printf '%s' "$out" | tail -c 500)
        if type ntfy_publish >/dev/null 2>&1; then
                ntfy_publish "Auto-update FAILED ($HOSTNAME_S)" "$snippet" urgent rotating_light
        fi
        exit 1
fi

# ---- host mode: manage the cluster-visible reboot-required flag ----
if [ -d /etc/pve/nodes ]; then
        FLAG="/etc/pve/nodes/$HOSTNAME_S/reboot-required"
        need=0

        # a kernel tree installed since this boot => reboot will pick it up
        up=$(awk '{print int($1)}' /proc/uptime 2>/dev/null || echo 0)
        boot_epoch=$(( $(date +%s) - ${up:-0} ))
        for d in /usr/lib/modules/*; do
                [ -d "$d" ] || continue
                m=$(stat -c %Y "$d" 2>/dev/null) || continue
                [ "$m" -gt "$boot_epoch" ] && need=1
        done

        # classic signal if anything else installs it
        [ -f /var/run/reboot-required ] && need=1

        if [ "$need" -eq 1 ]; then
                date > "$FLAG" 2>/dev/null || true
        else
                rm -f "$FLAG" 2>/dev/null || true
        fi
fi

exit 0