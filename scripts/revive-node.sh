#!/usr/bin/env bash
# revive-node.sh -- OPS-18: revive an existing PVE 8 node in place on
# the new 192.168.1.0/24 LAN, without reinstalling anything (issues.md
# item 8, revised 2026-11-21). Run FROM DEBBIE over ssh AS THE
# OPERATIONS USER `nate` (least privilege, no root ssh; humans operate
# -- an AI assistant may run these steps on the operator's behalf).
# The operator ran scripts/console-setup-operator.sh at the node's physical
# console first; every remote privileged step goes through sudo, so
# the audit trail shows the single operations identity.
#
# Usage (on debbie):
#   scripts/revive-node.sh --survey <temp-ip>            # read-only state dump
#   scripts/revive-node.sh --renumber <node-name> --at <temp-ip>
#   scripts/revive-node.sh --verify <node-name>          # at the NEW ip
#   scripts/revive-node.sh --post-quorum <node-name>     # after 3rd node; on any quorate member
#
# Order on the evening:
#   1. truenas move FIRST (OPS-4, at ITS console -- no root ssh ever);
#      NFS must be right before LRM starts CTs
#   2. boot thermaltake, aspires, aspiree15 (they DHCP into the pool)
#   3. --survey each (sanity: expected old cluster state)
#   4. --renumber pve-thermaltake -> pve-aspires -> pve-aspiree15
#      (3rd up = real 3-of-5 quorum; framework + Pi stay OFF)
#   5. --post-quorum pve-thermaltake
#   6. starts settle; error states -> docs/ha-recovery.md dance
#   7. scripts/harden-ssh.sh per node (good-ssh pass)
#
# The renumber dance per node (all edits backed up to /root/*.pre-revive):
#   - static IP from host_vars onto vmbr0 (replaces the DHCP stanza)
#   - fleet /etc/hosts block
#   - `pvecm expected 1` (pmxcfs becomes writable when inquorate)
#   - corosync.conf: every nodelist entry's ring0_addr replaced with
#     the host_vars IP for that nodelist NAME (self-verifying -- the
#     name->addr map comes from the live config, no guessed old IPs)
#   - detached: ifreload -a + corosync restart (the ssh session dies;
#     reconnect at the new static IP and --verify)
# No disk is touched beyond config edits; CT rootfs lives on truenas NFS.

set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
HOSTVARS="$REPO/ansible/inventory/host_vars"
SSH_USER="${SSH_USER:-nate}"

MODE="${1:---usage}"
arg() { echo "${2:?missing arg}"; }

node_ip() { awk '/^ansible_host:/ {print $2}' "$HOSTVARS/$1.yml"; }

hosts_block() { # "ip name" lines for every machine
  local f
  for f in "$HOSTVARS"/*.yml; do
    echo "$(awk '/^ansible_host:/ {print $2}' "$f") $(basename "$f" .yml)"
  done
}

sshn() { ssh -o BatchMode=yes -o ConnectTimeout=8 "$@"; }
# every remote privileged block runs through: sshn nate@ip sudo bash -s
# (stdin heredoc) -- no nested quoting, auditable as the nate identity.

case "$MODE" in
--survey)
  IP=$(arg survey "$2")
  say() { echo "== $*"; }
  say "survey $IP (as $SSH_USER)"
  sshn "$SSH_USER@$IP" sudo bash -s <<'REMOTE'
    echo "hostname: $(hostname)"; pveversion | head -1
    echo "uptime: $(uptime -p)"
    ip -br addr | grep -v "^lo"
    echo "--- corosync.conf ---"; cat /etc/pve/corosync.conf 2>/dev/null || cat /etc/corosync/corosync.conf
    echo "--- storage.cfg (pve entries) ---"; grep -A2 "pve-" /etc/pve/storage.cfg 2>/dev/null
    echo "--- interfaces vmbr0 ---"; sed -n "/auto vmbr0/,/^$/p" /etc/network/interfaces
    echo "--- quorum ---"; pvecm status 2>/dev/null | tail -12
    echo "--- pct list ---"; pct list 2>/dev/null | head -32
REMOTE
  ;;
--renumber)
  NODE=$(arg node "$2"); TEMP=$(arg at "$3")
  NEWIP=$(node_ip "$NODE")
  [ -n "$NEWIP" ] || { echo "no host_vars/$NODE.yml (or no ansible_host)" >&2; exit 1; }
  say() { echo "== $*"; }
  say "renumber $NODE: $TEMP -> $NEWIP (as $SSH_USER, sudo)"
  HOSTS=$(hosts_block | tr '\n' ';')
  say "gathering live corosync nodelist"
  sshn "$SSH_USER@$TEMP" true || { echo "cannot ssh $SSH_USER@$TEMP -- run scripts/console-setup-operator.sh at its console first" >&2; exit 1; }
  say "applying: static IP + hosts + expected-1 + corosync.conf swap"
  sshn "$SSH_USER@$TEMP" "sudo env NODE='$NODE' NEWIP='$NEWIP' HOSTS='$HOSTS' bash -s" <<'REMOTE'
set -euo pipefail
echo "-- backups"
cp -a /etc/network/interfaces /root/interfaces.pre-revive
cp -a /etc/pve/corosync.conf /root/corosync.conf.pre-revive 2>/dev/null \
  || cp -a /etc/corosync/corosync.conf /root/corosync.conf.pre-revive
echo "-- /etc/hosts"
HOSTS="$HOSTS" python3 - <<'PYEOF'
import re, os
want = [h.split() for h in os.environ["HOSTS"].strip().rstrip(";").split(";")]
hosts = open("/etc/hosts").read().splitlines()
for ip, name in want:
    pat = re.compile(r"^\S+\s+" + re.escape(name) + r"(\s|$)")
    hosts = [l for l in hosts if not pat.match(l)] + [f"{ip} {name}"]
open("/etc/hosts", "w").write("\n".join(hosts) + "\n")
PYEOF
echo "-- vmbr0 -> static $NEWIP"
NEWIP="$NEWIP" python3 - <<'PYEOF'
import re, os
newip = os.environ["NEWIP"]
d = open("/etc/network/interfaces").read()
old = re.search(r"auto vmbr0\n.*?(?=\n\n|\Z)", d, flags=re.S)
ports = "en*"
if old:
    m = re.search(r"bridge-ports\s+(\S+)", old.group(0))
    if m: ports = m.group(1)          # keep the REAL port name
block = f"""auto vmbr0
iface vmbr0 inet static
        address {newip}/24
        gateway 192.168.1.1
        bridge-ports {ports}
        bridge-stp off
        bridge-fd 0
"""
out = re.sub(r"auto vmbr0\n.*?(?=\n\n|\Z)", block, d, count=1, flags=re.S)
if "iface vmbr0 inet static" not in out:   # no auto-line form; append instead
    out = d + "\n" + block
open("/etc/network/interfaces", "w").write(out)
PYEOF
ip -br addr show vmbr0; sed -n "/vmbr0/,/^$/p" /etc/network/interfaces
echo "-- LRM watchdog disarm (HA self-reboot guard while inquorate)"
systemctl stop pve-ha-lrm 2>/dev/null || echo "  (pve-ha-lrm not running)"
echo "-- pmxcfs writable (expected 1 if inquorate)"
pvecm status | grep -qE 'Quorate: *Yes|Flags:.*Quorate' || pvecm expected 1
echo "-- corosync.conf ring0_addr swap (names -> host_vars map)"
HOSTS="$HOSTS" python3 - <<'PYEOF'
import re, os
pairs = [p.split() for p in os.environ["HOSTS"].strip().rstrip(";").split(";")]
ipmap = {name: ip for ip, name in pairs}
cf_path = "/etc/pve/corosync.conf"
d = open(cf_path).read()
def fix_block(m):
    block = m.group(0)
    nm = re.search(r"name:\s*(\S+)", block)
    if nm and nm.group(1) in ipmap:
        block = re.sub(r"ring0_addr:\s*\S+", "ring0_addr: " + ipmap[nm.group(1)], block)
    return block
out = re.sub(r"node\s*\{[^}]*\}", fix_block, d)
open(cf_path, "w").write(out)
for line in out.splitlines():
    if "name:" in line or "ring0_addr" in line: print(line)
PYEOF
echo "-- detached apply in 3s: ifreload -a + corosync restart"
echo "   (your session will drop; reconnect at $NEWIP)"
sleep 3
setsid sh -c 'nohup sh -c "ifreload -a; systemctl restart corosync; systemctl restart pve-cluster" >/root/revive-apply.log 2>&1' &
exit 0
REMOTE
  say "done pushing. reconnect: ssh $SSH_USER@$NEWIP then: revive-node.sh --verify $NODE"
  ;;
--verify)
  NODE=$(arg node "$2"); NEWIP=$(node_ip "$NODE")
  say() { echo "== $*"; }
  say "verify $NODE at $NEWIP (as $SSH_USER)"
  sshn "$SSH_USER@$NEWIP" sudo bash -s <<'REMOTE'
    hostname; ip -br addr show vmbr0
    grep -E "ring0_addr" /etc/pve/corosync.conf
    pvecm status | grep -E "Quorate|Expected|Total|Name" | head -6
    corosync-cfgtool -s 2>/dev/null | head -8 || true
    pvesm status | grep -E "pve-shared|pve-backups" || true
REMOTE
  ;;
--post-quorum)
  NODE=$(arg node "$2"); QIP=$(node_ip "$NODE")
  say() { echo "== $*"; }
  say "post-quorum fixes via $NODE ($QIP) (as $SSH_USER, sudo)"
  sshn "$SSH_USER@$QIP" true || { echo "cannot ssh $SSH_USER@$QIP" >&2; exit 1; }
  say "storage.cfg: 192.168.8.100 -> 192.168.1.10"
  sshn "$SSH_USER@$QIP" sudo bash -s <<'REMOTE'
    set -e
    pvecm status | grep -qE 'Quorate: *Yes|Flags:.*Quorate' || { echo "not quorate yet -- run me on the 3rd node up" >&2; exit 1; }
    grep -n "192.168.8.100" /etc/pve/storage.cfg && sed -i "s/192.168\.8\.100/192.168.1.10/g" /etc/pve/storage.cfg
    grep -A1 "pve-shared\|pve-backups" /etc/pve/storage.cfg | grep -E "server|path"
    pvesm status | grep -E "pve-shared|pve-backups" || echo "  (storage still activating; re-check with pvesm status)"
REMOTE
  say "thermaltake fstab: .100 -> .10 + remount"
  sshn "$SSH_USER@$(node_ip pve-thermaltake)" sudo bash -s <<'REMOTE' \
    || echo "  (thermaltake not reachable yet -- re-run after it is up)"
    grep -q "192.168.8.100" /etc/fstab && { cp -a /etc/fstab /root/fstab.pre-revive
      sed -i "s/192.168\.8\.100/192.168.1.10/g" /etc/fstab; }
    mount -a 2>/dev/null || true
    df -h | grep tnas-media || echo "  (media mounts pending)"
REMOTE
  say "CT nameservers: every CT -> 192.168.1.1"
  sshn "$SSH_USER@$QIP" sudo bash -s <<'REMOTE'
    for id in $(pct list 2>/dev/null | awk "NR>1 {print \$1}"); do
      pct set "$id" --nameserver 192.168.1.1 2>/dev/null && echo "  ct $id nameserver set" \
        || echo "  ct $id SKIP (template or error)"
    done
REMOTE
  say "starts: HA auto-starts its CTs; then:"
  cat <<'EOF'
  jellyfin:  ssh nate@pve-thermaltake 'sudo systemctl start start-jellyfin'
  ntfy:      ssh nate@<its node> 'sudo pct start 128'
  re-arm HA (watchdogs back on, now quorate):
    for n in pve-thermaltake pve-aspires pve-aspiree15; do
      ssh nate@$n 'sudo systemctl start pve-ha-lrm'; done
  any HA error states -> the documented dance in docs/ha-recovery.md:
    ha-manager set ct:N --state disabled; sleep 15; pct start N;
    ha-manager set ct:N --state started
  watch settle: ha-manager status; pct list; tailscale status on debbie
  then: sudo ./scripts/extract-legacy.sh --copy 1   (tier-0 backup snapshot)
  finally: scripts/harden-ssh.sh <node> (good-ssh pass, per node)
EOF
  ;;
*)
  sed -n '2,30p' "$0"; exit 1 ;;
esac
