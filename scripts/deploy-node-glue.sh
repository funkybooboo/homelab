#!/usr/bin/env bash
# deploy-node-glue.sh -- OPS-5 phase 2: push each node's per-node glue
# (the old fleet's hand-placed files, now codified) from this repo to
# the node, over ssh from debbie. Runs AFTER bootstrap.sh (needs the
# admin key in place).
#
# Usage: scripts/deploy-node-glue.sh <node-name>
# Glue per ansible/inventory/host_vars/<name>.yml (the glue lists):
#   ALL nodes:      renew-pve-tls.sh + weekly cron (services/pve-tls/)
#                   pve-shared-nfs-remount helper
#   laptops:        no-lid-suspend logind drop-in + screen-off.service
#   pve-thermaltake: nvidia-uvm-devnodes hook + the 5-line NFS media
#                    fstab (points at truenas 192.168.1.10 -- valid only
#                    after OPS-4's move; script checks reachability)

set -euo pipefail

[ $# -eq 1 ] || { echo "usage: deploy-node-glue.sh <node-name>" >&2; exit 1; }
NODE="$1"
REPO="$(cd "$(dirname "$0")/.." && pwd)"
HOSTVARS="$REPO/ansible/inventory/host_vars"
FACTS="$HOSTVARS/$NODE.yml"
[ -f "$FACTS" ] || { echo "no host_vars/$NODE.yml" >&2; exit 1; }
IP=$(awk '/^ansible_host:/ {print $2}' "$FACTS")
[ -n "$IP" ] || { echo "no ansible_host for $NODE" >&2; exit 1; }

say() { echo "== $*"; }
SSH="ssh -o BatchMode=yes root@$IP"
scp_to() { scp -q "$@"; }

ssh "$IP" true 2>/dev/null || { echo "cannot ssh root@$IP" >&2; exit 1; }

say "ALL nodes: renew-pve-tls.sh + cron"
scp_to "$REPO/services/pve-tls/renew-pve-tls.sh" "root@$IP:/usr/local/sbin/renew-pve-tls.sh"
$SSH 'chmod 700 /usr/local/sbin/renew-pve-tls.sh
      cat > /etc/cron.d/renew-pve-tls <<"EOF2"
# weekly Sunday 04:30 -- re-issue native pveproxy LE cert if <30d validity
30 4 * * 0 root /usr/local/sbin/renew-pve-tls.sh >/var/log/renew-pve-tls.log 2>&1
EOF2
      chmod 644 /etc/cron.d/renew-pve-tls
      systemctl reload cron || systemctl reload cron.service
      echo installed: $(ls -l /usr/local/sbin/renew-pve-tls.sh)'

if grep -q "laptop" "$FACTS" || grep -qE "aspiree15|aspires" <<<"$NODE"; then
  say "laptop glue: no-lid-suspend + screen-off"
  $SSH 'mkdir -p /etc/systemd/logind.conf.d
        cat > /etc/systemd/logind.conf.d/no-lid-suspend.conf <<"EOF2"
[Login]
HandleLidSwitch=ignore
HandleLidSwitchExternalPower=ignore
EOF2
        systemctl reload systemd-logind || killall -HUP systemd-logind
        cat > /etc/systemd/system/screen-off.service <<"EOF2"
[Unit]
Description=Turn off laptop panel backlight at boot
After=basic.target
[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/bin/sh -c "echo 4 > /sys/class/backlight/intel_backlight/bl_power 2>/dev/null; setterm --blank force --powersave powerdown >/dev/console 2>&1 </dev/console || true"
[Install]
WantedBy=multi-user.target
EOF2
        systemctl daemon-reload
        systemctl enable --now screen-off.service
        echo laptop glue done'
fi

if [ "$NODE" = "pve-thermaltake" ]; then
  say "thermaltake glue: nvidia hook + media fstab (needs truenas .10)"
  scp_to "$REPO/services/nvidia-uvm-devnodes/"* "root@$IP:/root/glue-nvidia/" 2>/dev/null \
    || { echo "  (no nvidia-uvm-devnodes dir? check services/)" >&2; }
  $SSH 'if ping -c1 -W2 192.168.1.10 >/dev/null 2>&1; then
          grep -q tnas-media /etc/fstab || cat >> /etc/fstab <<"EOF2"
192.168.1.10:/mnt/volume1/media/movies        /mnt/tnas-media/media/movies      nfs _netdev,auto 0 0
192.168.1.10:/mnt/volume1/media/tvshows       /mnt/tnas-media/media/tvshows     nfs _netdev,auto 0 0
192.168.1.10:/mnt/volume1/home/nate/Music     /mnt/tnas-media/media/music       nfs _netdev,auto 0 0
192.168.1.10:/mnt/volume1/home/nate/Audiobooks /mnt/tnas-media/media/audiobooks  nfs _netdev,auto 0 0
192.168.1.10:/mnt/volume1/home/nate/Books     /mnt/tnas-media/media/books       nfs _netdev,auto 0 0
EOF2
          mkdir -p /mnt/tnas-media/media/{movies,tvshows,music,audiobooks,books}
          mount -a || true
          df -h | grep tnas-media || echo "  mounts pending (check after truenas up)"
        else
          echo "  truenas (.10) not reachable -- run me again after OPS-4"
        fi'
fi

if [ "$NODE" = "pve-framework" ]; then
  say "framework glue: NONE until the USB-NIC fix soaks (OPS-5 criterion)"
fi

say "glue pass complete on $NODE"
