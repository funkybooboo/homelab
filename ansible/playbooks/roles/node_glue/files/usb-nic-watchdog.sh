#!/bin/bash
# usb-nic-watchdog -- the node detects its own dead uplink and
# heals it (framework's RTL8156; docs/quirks.md). The udev
# self-heal covers the re-enumerate-and-return case; THIS covers
# everything else, including "vanished and stayed gone".
# Runs every minute from nic-watchdog.timer. Ladder, one rung per
# minute of continuous failure:
#   1-2   ifreload -a        (fresh device, config not applied)
#   3     bus replug          (authorized toggle = remote hands)
#   5     second replug       (the first may race the settle)
#   6+    reboot, guarded     (the operator-verified cure; max
#                             one per 30 min -- a repeat flapper
#                             goes passive + CRITICAL instead of
#                             reboot-looping the node)
GW=192.168.1.1
COUNT=/run/nic-watchdog.count          # tmpfs: a reboot clears it
LASTREBOOT=/var/lib/nic-watchdog/last-reboot

log() { logger -t nic-watchdog "$*"; }

if ping -c1 -W3 -I vmbr0 "$GW" >/dev/null 2>&1; then
  if [ -f "$COUNT" ]; then
    log "uplink healthy again after $(cat "$COUNT") failure round(s)"
    rm -f "$COUNT"
  fi
  exit 0
fi

n=$(( $(cat "$COUNT" 2>/dev/null || echo 0) + 1 ))
echo "$n" > "$COUNT"
log "uplink dead (gateway $GW unreachable): failure round $n"

if [ "$n" -le 2 ]; then
  log "rung $n: ifreload -a"
  /sbin/ifreload -a >/dev/null 2>&1 || /usr/sbin/ifreload -a >/dev/null 2>&1
  exit 0
fi

# find the RTL8156 on the bus (top-level devnodes only; the
# :1.0 subdirs carry no idVendor)
dev=""
for d in /sys/bus/usb/devices/*; do
  [ -f "$d/idVendor" ] || continue
  if [ "$(cat "$d/idVendor")" = "0bda" ] && [ "$(cat "$d/idProduct" 2>/dev/null)" = "8156" ]; then
    dev="$d"
    break
  fi
done

if [ "$n" -eq 3 ]; then
  if [ -n "$dev" ]; then
    log "rung 3: bus replug via authorized toggle on ${dev##*/}"
    echo 0 > "$dev/authorized"
    sleep 3
    echo 1 > "$dev/authorized"
  else
    log "rung 3: NIC absent from the bus entirely -- nothing to replug"
  fi
  exit 0
fi

if [ "$n" -eq 5 ] && [ -n "$dev" ]; then
  log "rung 5: second bus replug attempt"
  echo 0 > "$dev/authorized"
  sleep 3
  echo 1 > "$dev/authorized"
  exit 0
fi

if [ "$n" -ge 6 ]; then
  now=$(date +%s)
  if [ -f "$LASTREBOOT" ] && [ $(( now - $(cat "$LASTREBOOT") )) -lt 1800 ]; then
    log "CRITICAL: uplink still dead, but a watchdog reboot already ran in the last 30 min -- staying hands-off; this needs the human"
    exit 1
  fi
  log "rung $n: REBOOT as last resort (no guests on this node; cluster quorum survives a single member)"
  mkdir -p "$(dirname "$LASTREBOOT")"
  echo "$now" > "$LASTREBOOT"
  sync
  systemctl reboot
fi
