#!/bin/bash
# install-host.sh -- idempotent per-PVE-node installer. Run as root ON the
# node. Deploys:
#   unattended-upgrades (full-update allowlist, Automatic-Reboot=false)
#   unattended-upgrade-wrapper.sh (host mode: pmcfs reboot-required flag)
#   systemd timer: nightly 03:30 LOCAL (nodes run America/Denver)
#   pve-cluster-reboot-controller.sh + hourly /etc/cron.d entry
#   auto-update-maint.sh + Sunday /etc/cron.d entry
# Re-runnable. Restarts nothing. Does NOT deploy to CTs (install-ct.sh does).

set -euo pipefail
cd "$(dirname "$0")"

echo "[install-host] $(hostname -s)"

export DEBIAN_FRONTEND=noninteractive
apt-get update -qq >/dev/null 2>&1 || true
apt-get install -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" \
        unattended-upgrades needrestart >/dev/null 2>&1

install -m 0644 unattended-50.example /etc/apt/apt.conf.d/50unattended-upgrades
install -m 0644 unattended-20.example /etc/apt/apt.conf.d/20auto-upgrades
# NOTE: no needrestart-auto.conf on hosts by design -- cluster services are
# restarted only by the serialized reboot cycle, never live by needrestart.
install -m 0755 unattended-upgrade-wrapper.sh /usr/local/sbin/unattended-upgrade-wrapper.sh
install -m 0755 pve-cluster-reboot-controller.sh /usr/local/sbin/pve-cluster-reboot-controller.sh
install -m 0755 auto-update-maint.sh /usr/local/sbin/auto-update-maint.sh

cat > /etc/systemd/system/auto-update.service <<'UNIT'
[Unit]
Description=Nightly unattended-upgrade wrapper (auto-update)

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/unattended-upgrade-wrapper.sh
UNIT

cat > /etc/systemd/system/auto-update.timer <<'UNIT'
[Unit]
Description=Nightly auto-update timer (03:30 local)

[Timer]
OnCalendar=*-*-* 03:30:00
Persistent=true

[Install]
WantedBy=timers.target
UNIT
systemctl daemon-reload
systemctl enable --now auto-update.timer >/dev/null 2>&1

# Hourly reboot controller. Keep the minute on re-runs (spread stays stable);
# fresh installs pick a random minute so the 5 nodes don't collide on the
# heartbeat lock (it would resolve anyway, but spread is polite).
if [ -r /etc/cron.d/pve-reboot-controller ]; then
        MIN=$(grep -oE '^[0-9]+' /etc/cron.d/pve-reboot-controller | head -1)
fi
[ -n "${MIN:-}" ] || MIN=$(shuf -i 5-54 -n 1)
cat > /etc/cron.d/pve-reboot-controller <<CRON
# Serialized cluster reboot controller (auto-update). Runs on every node;
# the pmcfs heartbeat lock elects one actor. See services/auto-update/README.
$MIN * * * * root /usr/local/sbin/pve-cluster-reboot-controller.sh >/dev/null 2>&1
CRON

cat > /etc/cron.d/auto-update-maint <<CRON
# Sunday maintenance: apt autoclean + journal vacuum (ntfy only on errors)
30 4 * * 0 root /usr/local/sbin/auto-update-maint.sh >/dev/null 2>&1
CRON

# shared pmcfs state dir for the heartbeat lock (cluster-replicated)
mkdir -p /etc/pve/auto-update

next=$(systemctl list-timers auto-update.timer --no-pager 2>/dev/null | sed -n '2p' | awk '{print $1, $2}')
echo "[install-host] done. timer active: $(systemctl is-active auto-update.timer); next run: ${next:-n/a}; controller minute: $MIN"