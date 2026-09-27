#!/bin/bash
# pve-cluster-reboot-controller.sh -- serialized, quorum-gated cluster
# reboot choreography for auto-update (design ideas/auto-update.md, Tier B,
# S-variant -- the recommended implementation, chosen 2026-09-27).
#
# WHY: unattended-upgrades lands the same new kernel on all 5 nodes the same
# night; naive Automatic-Reboot=true would reboot them simultaneously,
# risking corosync quorum loss + HA fence churn (the classic Proxmox
# auto-reboot footgun). Instead the wrapper on each node NEVER reboots; it
# writes /etc/pve/nodes/<host>/reboot-required on pmxcfs (cluster-visible)
# and THIS controller reboots flagged nodes ONE AT A TIME:
#   order : arm64 witness (raspberrypi) first, non-master x86, master LAST,
#           the local node (self) always very last (a self-reboot ends the
#           run; the next hourly cycle continues from a peer if needed)
#   gates : cluster quorate, every node online, every HA service settled
#   waits : node leaves, returns, quorum restored, HA services recovered
# then clears the flag and pushes an ntfy per completed reboot (urgent on
# any failure). Scheduled hourly on EVERY node via /etc/cron.d; a heartbeat
# lock on pmxcfs (pve-balance pattern -- pmxcfs has no real POSIX locks)
# elects a single actor per cycle: holder refreshes the lock each step,
# peers defer while it is fresh, a stale lock (dead holder) is taken over
# after TTL.

set -u

HOST=$(hostname -s)
SHARED=/etc/pve/auto-update
LOCK="$SHARED/lock"
TTL=900            # seconds a held lock is considered fresh
WAIT_GONE=180      # max seconds for a node to leave after reboot command
WAIT_ONLINE=600    # max seconds for a node to come back
WAIT_HA=600         # max seconds for HA services to settle
LOG=/var/log/pve-reboot-controller.log

[ -d /etc/pve/nodes ] || exit 0
[ -r /usr/local/sbin/ntfy-publish.sh ] && . /usr/local/sbin/ntfy-publish.sh
mkdir -p "$SHARED" 2>/dev/null || true

log() { echo "$(date '+%Y-%m-%d %H:%M:%S') [$HOST] $*" >> "$LOG" 2>/dev/null; }
notify() { type ntfy_publish >/dev/null 2>&1 && ntfy_publish "$1" "$2" "${3:-default}" "${4:-bell}"; }
now_s() { date +%s; }
refresh_lock() { echo "$HOST $$ $(now_s)" > "$LOCK" 2>/dev/null; }

acquire_lock() {
        local holder ts age
        if [ -r "$LOCK" ]; then
                holder=$(awk '{print $1}' "$LOCK" 2>/dev/null)
                ts=$(awk '{print $3}' "$LOCK" 2>/dev/null)
                age=$(( $(now_s) - ${ts:-0} ))
                if [ -n "$holder" ] && [ "$holder" != "$HOST" ] && [ "$age" -ge 0 ] && [ "$age" -lt "$TTL" ]; then
                        return 1        # a peer is actively running a cycle
                fi
        fi
        refresh_lock
        sleep 1
        holder=$(awk '{print $1}' "$LOCK" 2>/dev/null)
        [ "${holder:-}" = "$HOST" ] || return 1
        return 0
}

all_nodes_online() {
        pvesh get /nodes --output-format json 2>/dev/null | python3 -c '
import json,sys
try: d=json.load(sys.stdin)
except Exception: print("no"); raise SystemExit
total=len(d); online=sum(1 for n in d if n.get("status")=="online")
print("yes" if total>=3 and online==total else "no")' 2>/dev/null | grep -q yes
}

cluster_healthy() {
        pvecm status 2>/dev/null | grep -q "Quorate: Yes" || return 1
        all_nodes_online || return 1
        # HA services settled: allow started + parked freeze, block anything mid-motion
        [ -z "$(ha-manager status 2>/dev/null | grep '^service' | grep -vE ', started\)|, freeze\)')" ] || return 1
        return 0
}

node_is_online() {
        pvesh get "/nodes/$1/status" --output-format json 2>/dev/null | python3 -c '
import json,sys
try: print(json.load(sys.stdin).get("status",""))
except Exception: print("")' 2>/dev/null
}

wait_gone() {  # target $1
        local t=0
        while [ $t -lt $WAIT_GONE ]; do
                [ "$(node_is_online "$1")" != "online" ] && return 0
                sleep 10; t=$((t+10))
        done
        return 1
}

wait_back() {  # target $1
        local t=0
        while [ $t -lt $WAIT_ONLINE ]; do
                [ "$(node_is_online "$1")" = "online" ] && return 0
                sleep 15; t=$((t+15))
        done
        return 1
}

wait_ha() {   # all HA services settled
        local t=0
        while [ $t -lt $WAIT_HA ]; do
                [ -z "$(ha-manager status 2>/dev/null | grep '^service' | grep -vE ', started\)|, freeze\)')" ] && return 0
                sleep 20; t=$((t+20))
        done
        return 1
}

# ---------------- main ----------------

acquire_lock || exit 0

cluster_healthy || { log "defer: cluster not fully healthy"; exit 0; }

master=$(ha-manager status 2>/dev/null | awk '/^master/{print $2}')
[ -n "$master" ] || master="$HOST"

all_nodes=$(pvesh get /nodes --output-format json 2>/dev/null | python3 -c '
import json,sys
try: print(" ".join(sorted(n["node"] for n in json.load(sys.stdin))))
except Exception: pass' 2>/dev/null)
[ -n "$all_nodes" ] || { log "defer: cannot enumerate nodes"; exit 0; }

todo=()
for n in $all_nodes; do
        [ -f "/etc/pve/nodes/$n/reboot-required" ] && todo+=("$n")
done
[ ${#todo[@]} -eq 0 ] && exit 0

order=()
for n in "${todo[@]}"; do [ "$n" = "raspberrypi" ] && order+=("$n"); done
for n in "${todo[@]}"; do [ "$n" != "raspberrypi" ] && [ "$n" != "$master" ] && [ "$n" != "$HOST" ] && order+=("$n"); done
for n in "${todo[@]}"; do [ "$n" = "$master" ] && [ "$n" != "$HOST" ] && order+=("$n"); done
for n in "${todo[@]}"; do [ "$n" = "$HOST" ] && order+=("$n"); done

log "cycle start; flagged: ${todo[*]}; order: ${order[*]:-none}; master: $master"

for target in "${order[@]}"; do
        refresh_lock
        pvecm status 2>/dev/null | grep -q "Quorate: Yes" || { log "abort: lost quorum before $target"; exit 1; }

        if [ "$target" = "$HOST" ]; then
                rm -f "/etc/pve/nodes/$HOST/reboot-required"
                log "self reboot (last): $HOST"
                notify "Cluster reboot: $HOST" "auto-update: rebooting self (last in cycle)" low arrow_up
                sleep 2
                pvesh create "/nodes/$HOST/status" --command reboot >/dev/null 2>&1
                exit 0        # run ends with the reboot; peers continue hourly
        fi

        log "rebooting $target"
        notify "Cluster reboot: $target" "auto-update: rebooting $target (serialized, $(( ${#order[@]} )) in cycle)" low arrow_up
        pvesh create "/nodes/$target/status" --command reboot >/dev/null 2>&1

        if ! wait_gone "$target"; then
                log "FAIL: $target never went down (reboot command not effective?)"
                notify "Cluster reboot FAILED: $target" "auto-update: $target did not reboot within ${WAIT_GONE}s -- needs human" urgent rotating_light
                exit 1
        fi
        if ! wait_back "$target"; then
                log "FAIL: $target did not come back online"
                notify "Cluster reboot FAILED: $target" "auto-update: $target did not return within ${WAIT_ONLINE}s -- needs human" urgent rotating_light
                exit 1
        fi
        if ! wait_ha; then
                log "FAIL: HA services did not settle after $target"
                notify "Cluster reboot FAILED: $target" "auto-update: $target online but HA services unsettled after ${WAIT_HA}s -- needs human" urgent rotating_light
                exit 1
        fi

        rm -f "/etc/pve/nodes/$target/reboot-required"
        log "OK: $target rebooted, quorate, HA settled"
        notify "Cluster reboot OK: $target" "auto-update: $target back online, quorate, HA services started" low arrow_up
done

log "cycle complete"
exit 0