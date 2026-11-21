#!/usr/bin/env bash
# revive-node.sh -- OPS-18: revive an existing PVE 8 node in place on
# the new 192.168.1.0/24 LAN, without reinstalling anything (issues.md
# item 8, revised 2026-11-21). Driven FROM DEBBIE over ssh; the
# operator's per-node console step is only dropping
# infra/keys/admin.ed25519.pub into root's authorized_keys (and reading
# back the node's temporary DHCP address).
#
# Usage (on debbie):
#   scripts/revive-node.sh --survey <temp-ip>            # read-only state dump
#   scripts/revive-node.sh --renumber <node-name> --at <temp-ip>
#   scripts/revive-node.sh --verify <node-name>          # at the NEW ip
#   scripts/revive-node.sh --post-quorum <node-name>     # after 3rd node; on any quorate member
#
# Order on the evening:
#   1. truenas move FIRST (OPS-4) -- NFS must be right before LRM starts CTs
#   2. boot thermaltake, aspires, aspiree15 (they DHCP into the pool)
#   3. --survey each (sanity: expected old cluster state)
#   4. --renumber pve-thermaltake -> pve-aspires -> pve-aspiree15
#      (3rd up = real 3-of-5 quorum; framework + Pi stay OFF)
#   5. --post-quorum pve-thermaltake
#   6. starts settle; error states -> docs/ha-recovery.md dance
#
# The renumber dance per node (all edits backed up to /root/*.pre-revive):
#   - static IP from ips.yaml onto vmbr0 (replaces the DHCP stanza)
#   - fleet /etc/hosts block
#   - `pvecm expected 1` (pmxcfs becomes writable when inquorate)
#   - corosync.conf: every nodelist entry's ring0_addr replaced with
#     the ips.yaml IP for that nodelist NAME (self-verifying -- the
#     name->addr map comes from the live config, no guessed old IPs)
#   - detached: ifreload -a + corosync restart (the ssh session dies;
#     reconnect at the new static IP and --verify)
# No disk is touched beyond config edits; CT rootfs lives on truenas NFS.

set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
IPS="$REPO/infra/network/ips.yaml"

MODE="${1:---usage}"
arg() { echo "${2:?missing arg}"; }

node_ip() { # name -> ip from ips.yaml
  awk -v n="$1" '$0 ~ "^  "n":" {found=1} found && /ip:/ {print $2; exit}' "$IPS"
}

hosts_block() { # "ip name" lines for every host in ips.yaml
  awk '
    /^  [a-z][a-z0-9-]*:$/ { name=$1; gsub(":","",name); inhost=1; next }
    inhost && /ip:/ { print $2, name; inhost=0 }
  ' "$IPS" | grep -v '^tbd'
}

sshn() { ssh -o BatchMode=yes -o ConnectTimeout=8 "$@"; }

case "$MODE" in
--survey)
  IP=$(arg survey "$2")
  say() { echo "== $*"; }
  say "survey $IP"
  sshn "root@$IP" '
    echo "hostname: $(hostname)"; pveversion | head -1
    echo "uptime: $(uptime -p)"
    ip -br addr | grep -v "^lo"
    echo "--- corosync.conf ---"; cat /etc/pve/corosync.conf 2>/dev/null || cat /etc/corosync/corosync.conf
    echo "--- storage.cfg (pve entries) ---"; grep -A2 "pve-" /etc/pve/storage.cfg 2>/dev/null
    echo "--- interfaces vmbr0 ---"; sed -n "/auto vmbr0/,/^$/p" /etc/network/interfaces
    echo "--- quorum ---"; pvecm status 2>/dev/null | tail -12
    echo "--- pct list ---"; pct list 2>/dev/null | head -32
  '
  ;;
--renumber)
  NODE=$(arg node "$2"); TEMP=$(arg at "$3")
  NEWIP=$(node_ip "$NODE")
  [ -n "$NEWIP" ] || { echo "no ip for $NODE in ips.yaml" >&2; exit 1; }
  say() { echo "== $*"; }
  say "renumber $NODE: $TEMP -> $NEWIP"
  HOSTS=$(hosts_block | tr '\n' ';')
  say "gathering live corosync nodelist"
  sshn "root@$TEMP" true || { echo "cannot ssh root@$TEMP (key dropped at console?)" >&2; exit 1; }
  say "applying: static IP + hosts + expected-1 + corosync.conf swap"
  sshn "root@$TEMP" "NODE='$NODE' NEWIP='$NEWIP' HOSTS='$HOSTS' bash -s" <<'REMOTE'
set -euo pipefail
echo "-- backups"
cp -a /etc/network/interfaces /root/interfaces.pre-revive
cp -a /etc/pve/corosync.conf /root/corosync.conf.pre-revive 2>/dev/null \
  || cp -a /etc/corosync/corosync.conf /root/corosync.conf.pre-revive
echo "-- /etc/hosts"
python3 - <<'PYEOF'
import re
want = [h.split() for h in __import__("os").environ["HOSTS"].strip().rstrip(";").split(";")]
hosts = open("/etc/hosts").read().splitlines()
for ip, name in want:
    pat = re.compile(r"^\S+\s+" + re.escape(name) + r"(\s|$)")
    hosts = [l for l in hosts if not pat.match(l)] + [f"{ip} {name}"]
open("/etc/hosts", "w").write("\n".join(hosts) + "\n")
PYEOF
echo "-- vmbr0 -> static $NEWIP"
python3 - <<'PYEOF'
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
echo "-- pmxcfs writable (expected 1 if inquorate)"
pvecm status | grep -q "Quorate:          Yes" || pvecm expected 1
echo "-- corosync.conf ring0_addr swap (names -> ips.yaml map)"
NEWIP="$NEWIP" python3 - <<'PYEOF'
import re, os, subprocess
new = os.environ["NEWIP"]
# ips map shipped from debbie: NAME IP pairs on one line each via env HOSTS
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
  say "done pushing. reconnect: ssh root@$NEWIP then: revive-node.sh --verify $NODE"
  ;;
--verify)
  NODE=$(arg node "$2"); NEWIP=$(node_ip "$NODE")
  say() { echo "== $*"; }
  say "verify $NODE at $NEWIP"
  sshn "root@$NEWIP" '
    hostname; ip -br addr show vmbr0
    grep -E "ring0_addr" /etc/pve/corosync.conf
    pvecm status | grep -E "Quorate|Expected|Total|Name" | head -6
    corosync-cfgtool -s 2>/dev/null | head -8 || true
    pvesm status | grep -E "pve-shared|pve-backups" || true
  '
  ;;
--post-quorum)
  NODE=$(arg node "$2"); QIP=$(node_ip "$NODE")
  say() { echo "== $*"; }
  say "post-quorum fixes via $NODE ($QIP)"
  sshn "root@$QIP" true || { echo "cannot ssh root@$QIP" >&2; exit 1; }
  say "storage.cfg: 192.168.8.100 -> 192.168.1.10"
  sshn "root@$QIP" '
    set -e
    pvecm status | grep -q "Quorate:          Yes" || { echo "not quorate yet -- run me on the 3rd node up" >&2; exit 1; }
    grep -n "192.168.8.100" /etc/pve/storage.cfg && sed -i "s/192.168\.8\.100/192.168.1.10/g" /etc/pve/storage.cfg
    grep -A1 "pve-shared\|pve-backups" /etc/pve/storage.cfg | grep -E "server|path"
    pvesm status | grep -E "pve-shared|pve-backups" || echo "  (storage still activating; re-check with pvesm status)"
  '
  say "thermaltake fstab: .100 -> .10 + remount"
  sshn "root@$(node_ip pve-thermaltake)" '
    grep -q "192.168.8.100" /etc/fstab && { cp -a /etc/fstab /root/fstab.pre-revive
      sed -i "s/192.168\.8\.100/192.168.1.10/g" /etc/fstab; }
    mount -a 2>/dev/null || true
    df -h | grep tnas-media || echo "  (media mounts pending)"
  ' || echo "  (thermaltake not reachable yet -- re-run after it is up)"
  say "CT nameservers: every CT -> 192.168.1.1"
  sshn "root@$QIP" '
    for id in $(pct list 2>/dev/null | awk "NR>1 {print \$1}"); do
      pct set "$id" --nameserver 192.168.1.1 2>/dev/null && echo "  ct $id nameserver set" \
        || echo "  ct $id SKIP (template or error)"
    done
  '
  say "starts: HA auto-starts its CTs; then:"
  cat <<'EOF'
  jellyfin:  ssh root@pve-thermaltake 'systemctl start start-jellyfin'
  ntfy:      ssh root@<its node> 'pct start 128'
  any HA error states -> the documented dance in docs/ha-recovery.md:
    ha-manager set ct:N --state disabled; sleep 15; pct start N;
    ha-manager set ct:N --state started
  watch settle: ha-manager status; pct list; tailscale status on debbie
  then: sudo ./scripts/extract-legacy.sh --copy 1   (tier-0 backup snapshot)
EOF
  ;;
*)
  sed -n '2,25p' "$0"; exit 1 ;;
esac
