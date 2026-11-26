#!/usr/bin/env bash
# reboot-node.sh -- the node reboot runbook (docs/maintenance.md),
# executable. One node at a time, full verification between each,
# abort on any failed gate.
#
# HUMAN-GATED: this script is only ever operator-invoked (or run by
# a directed assistant on the operator's word). Nothing schedules
# it; OPS-23's never-self-reboot rule stands.
#
# Usage:
#   scripts/reboot-node.sh --dry-run [node ...]   rehearse (no reboots)
#   scripts/reboot-node.sh [node ...]             reboot the named
#                                                 nodes, in order
#   scripts/reboot-node.sh                        reboot every node
#                                                 currently flagging
#                                                 reboot-required
#
# The gates, per the runbook:
#   1. cluster quorate before we start
#   2. no vzdump backup job mid-run (Sat 21:00 window can run long)
#   3. ONE node at a time; after each: node ssh back, quorum full,
#      every guest on that node ssh-reachable -- or ABORT before
#      touching the next node
#   4. never two nodes at once (sequential by construction)
#
# Notifications ride ntfy (LAN form; when ntfy's own host is the
# node being rebooted the posts pause and resume after).
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

DRY_RUN=0
[ "${1:-}" = "--dry-run" ] && { DRY_RUN=1; shift; }

# ---- fleet facts (from the repo, the source of truth) ----
declare -A NODE_IP=( [pve-thermaltake]=192.168.1.3 [pve-framework]=192.168.1.4
                     [pve-aspiree15]=192.168.1.5 [pve-aspires]=192.168.1.6
                     [raspberrypi]=192.168.1.11 )
API=https://192.168.1.3:8006/api2/json
TOKEN="nate@pam!homelab-ops=$(grep PVE_API_TOKEN_SECRET local/pve-api.env | cut -d= -f2)"
NTFY=http://192.168.1.16:8080/homelab

api() { curl -sk -H "Authorization: PVEAPIToken=$TOKEN" "$@"; }
notify() { curl -sf -d "$1" "$NTFY" >/dev/null 2>&1 || true; }
die() { echo "ABORT: $*" >&2; notify "node reboot ABORT: $*"; exit 1; }

# ---- gate 1: quorate ----
QUORATE=$(api "$API/cluster/status" | /usr/bin/python3.14 -c "import json,sys
print(1 if json.load(sys.stdin)['data'][0].get('quorate') else 0)")
[ "$QUORATE" = 1 ] || die "cluster not quorate"
MEMBERS=$(api "$API/cluster/status" | /usr/bin/python3.14 -c "import json,sys
print(json.load(sys.stdin)['data'][0].get('nodes', 0))")
echo "quorum: OK ($MEMBERS members)"

# ---- gate 2: no vzdump mid-run ----
VZDUMP=$(api "$API/cluster/tasks" | /usr/bin/python3.14 -c "import json,sys
print(sum(1 for t in json.load(sys.stdin)['data'] if not t.get('endtime') and 'vzdump' in (t.get('type','')+t.get('id',''))))")
[ "$VZDUMP" = 0 ] || die "a vzdump job is running -- reboot after the backup window"
echo "vzdump: none running"

# ---- targets: args, or every node flagging reboot-required ----
flagged() { ssh -o BatchMode=yes -o ConnectTimeout=8 "nate@${NODE_IP[$1]}" \
            "test -f /var/run/reboot-required && echo FLAGGED || echo clear" 2>/dev/null; }
if [ $# -gt 0 ]; then
    TARGETS=("$@")
else
    TARGETS=()
    for n in "${!NODE_IP[@]}"; do
        [ "$(flagged "$n")" = FLAGGED ] && TARGETS+=("$n")
    done
fi
[ ${#TARGETS[@]} -gt 0 ] || { echo "no nodes flag reboot-required -- nothing to do"; exit 0; }

# ---- guests per node, from the manifests ----
guests_on() { for f in guests/*.yaml; do
    grep -q "^node: $1\$" "$f" || continue
    grep -q "^state: present" "$f" || continue
    grep "^ip:" "$f" | head -1 | awk '{print $2}'
done; }

echo "targets (${#TARGETS[@]}): ${TARGETS[*]}"
for n in "${TARGETS[@]}"; do
    echo "  $n: guests: $(guests_on "$n" | tr '\n' ' ')"
done

[ "$DRY_RUN" = 1 ] && { echo "dry run -- gates passed, no reboots performed"; exit 0; }

# ---- one node at a time, verify between each ----
for node in "${TARGETS[@]}"; do
    ip="${NODE_IP[$node]}"
    mapfile -t GL < <(guests_on "$node")
    echo; echo "=== $node: rebooting (${#GL[@]} guests expect to recover) ==="
    notify "node reboot: $node going down (${#GL[@]} guests; back via onboot)"

    api -X POST "$API/cluster/tasks" >/dev/null 2>&1 || true   # warm the connection
    api -X POST "$API/nodes/$node/status" -d command=reboot > /dev/null \
        || die "$node: reboot command rejected by the API"

    # node down then up (10 min cap)
    echo "waiting for $node to drop + return..."
    for _ in $(seq 1 120); do sleep 5
        ssh -o BatchMode=yes -o ConnectTimeout=4 "nate@$ip" true 2>/dev/null && break
    done
    ssh -o BatchMode=yes -o ConnectTimeout=8 "nate@$ip" true 2>/dev/null \
        || die "$node did not come back (10 min) -- STOP; investigate before any further reboots"

    # quorum full again (all members online)
    for _ in $(seq 1 24); do sleep 5
        Q=$(api "$API/cluster/status" | /usr/bin/python3.14 -c "import json,sys
d=json.load(sys.stdin)['data']
print(1 if d[0].get('quorate') and sum(1 for x in d[1:] if x.get('online'))==d[0].get('nodes') else 0)")
        [ "$Q" = 1 ] && break
    done
    [ "$Q" = 1 ] || die "$node back but cluster not quorate -- STOP before any further reboots"

    # every guest on the node back (5 min cap each)
    for g in "${GL[@]}"; do
        echo "waiting for guest $g..."
        ok=""
        for _ in $(seq 1 60); do sleep 5
            ssh -o BatchMode=yes -o ConnectTimeout=4 "nate@$g" true 2>/dev/null && { ok=1; break; }
        done
        [ -n "$ok" ] || die "guest $g did not recover on $node -- STOP before any further reboots"
    done

    echo "$node: back, quorate, ${#GL[@]} guests recovered"
    notify "node reboot: $node back, quorate, ${#GL[@]} guests recovered"
done

echo; echo "all targets rebooted; cluster quorate; guests recovered"
notify "node reboot run complete: ${TARGETS[*]}"
