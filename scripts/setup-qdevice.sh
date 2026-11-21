#!/usr/bin/env bash
# setup-qdevice.sh -- OPS-6: the Raspberry Pi as a corosync QDevice.
# The Pi NEVER hosts guests and never runs PVE again (issues.md item
# 2): fresh Raspberry Pi OS Lite (64-bit) + corosync-qnetd, that is all.
#
# Two phases:
#   --prepare-pi   ON THE PI (ssh pi@192.168.1.11): installs
#                  corosync-qnetd, enables root key-ssh (for pvecm),
#                  opens the qnetd port. Run once, right after the
#                  user flashes + first-boots the Pi.
#   --join <node>  FROM DEBBIE: runs `pvecm qdevice setup 192.168.1.11`
#                  on the given PVE node (agent-forwarded ssh). This is
#                  the supported Proxmox path: it installs the
#                  corosync-qdevice client on the node, generates +
#                  distributes certs to the Pi, and wires datacenter.cfg.
#                  Re-run per node as nodes join (idempotent).
#
# Order on hardware night: Pi flashed + powered -> bootstrap.sh every
# node (installs corosync-qdevice) -> first cluster node up ->
# --prepare-pi -> --join <first-node> -> --join <each subsequent node>.

set -euo pipefail

PI_IP=192.168.1.11
MODE="${1:---usage}"

say() { echo "== $*"; }

case "$MODE" in
--prepare-pi)
  [ "$(id -u)" = 0 ] || { echo "run me as root on the Pi (sudo)" >&2; exit 1; }
  say "corosync-qnetd install"
  apt-get update -qq
  apt-get install -y -qq corosync-qnetd >/dev/null
  systemctl enable --now corosync-qnetd
  systemctl is-active corosync-qnetd
  say "root key-ssh (for pvecm qdevice setup; password login stays off)"
  mkdir -p /root/.ssh && chmod 700 /root/.ssh
  PUBKEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFd52mRENjyFAQC5oCVE6aBEhhbr0zEcwzMwKlKhlh+x nate.stott@pm.me"
  grep -qF "$PUBKEY" /root/.ssh/authorized_keys 2>/dev/null \
    || echo "$PUBKEY" >> /root/.ssh/authorized_keys
  chmod 600 /root/.ssh/authorized_keys
  sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin prohibit-password/' \
    /etc/ssh/sshd_config
  systemctl reload ssh 2>/dev/null || systemctl reload sshd
  say "fire-and-forget check: qnetd listening on 5403"
  ss -tlnp | grep 5403 || echo "  (qnetd listens on-demand; verify from a node)"
  say "Pi side done. From debbie: setup-qdevice.sh --join <node-name>"
  ;;
--join)
  NODE="${2:?--join needs the pve node name}"
  REPO="$(cd "$(dirname "$0")/.." && pwd)"
  IP=$(awk "/^  $NODE:/{found=1} found && /ip:/ {print \$2; exit}" \
        "$REPO/infra/network/ips.yaml")
  [ -n "$IP" ] || { echo "no ip for $NODE in ips.yaml" >&2; exit 1; }
  say "pvecm qdevice setup $PI_IP (on $NODE, agent-forwarded)"
  ssh -A -o BatchMode=yes "root@$IP" "pvecm qdevice setup $PI_IP"
  say "verify on $NODE:"
  ssh -o BatchMode=yes "root@$IP" 'pvecm status | tail -8; pvecm qdevice status || true'
  ;;
*)
  echo "usage: setup-qdevice.sh --prepare-pi | --join <pve-node-name>" >&2
  exit 1
  ;;
esac
