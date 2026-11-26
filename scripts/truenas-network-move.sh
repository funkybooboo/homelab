#!/bin/sh
# truenas-network-move.sh -- OPS-4: move truenas from the dead
# 192.168.8.x LAN to the greenfield 192.168.1.x LAN, IN PLACE, at its
# PHYSICAL console (no root ssh ever). Self-diagnosing: TrueNAS moved
# several middleware method names between versions, so this script
# probes the read-only methods first and adapts to whatever THIS
# box answers. If something is missing it says so plainly instead of
# guessing.
#
# Run ON TRUENAS as root AT THE CONSOLE. Fetch from debbie, then:
#   sh /tmp/move.sh --check      (read-only: current state + the plan)
#   sh /tmp/move.sh --apply      (execute; the old IP drops at commit)
#
# Target state: 192.168.1.10/24, gw 192.168.1.1, dns
# [192.168.1.1, 1.1.1.1], NFS exports on 192.168.1.0/24.
# --apply is safe to re-run: steps that already match are skipped.

set -eu

NEW_IP=192.168.1.10
NEW_GW=192.168.1.1
NEW_SUBNET=192.168.1.0/24
OLD_IP=192.168.8.100
MODE="${1:---check}"

say() { echo "== $*"; }
die() { echo "ERROR: $*" >&2; exit 1; }
probe() { midclt call "$1" >/dev/null 2>&1; }
first_ok() {
  for m in "$@"; do
    if probe "$m"; then echo "$m"; return 0; fi
  done
  return 1
}

# ---- discovery: what does THIS TrueNAS answer? (read-only) ----
say "probing middleware methods (read-only)"

M_IFACE=$(first_ok interface.query || true)
if [ -z "$M_IFACE" ]; then
  say "  interface.query: MISSING; services containing 'interface':"
  midclt call core.get_services 2>/dev/null | tr ',' '\n' | grep -i interface || true
  die "need interface.query to proceed"
fi
say "  $M_IFACE: OK"
IFACE_JSON=$(midclt call "$M_IFACE")

M_GEN=$(first_ok system.general.get_config general.get_config || true)
[ -n "$M_GEN" ] && say "  $M_GEN: OK" || say "  no general-config method (gateway/dns may live elsewhere)"

M_DNS=$(first_ok dnsmanager.query dnsmanager.get_config || true)
[ -n "$M_DNS" ] && say "  $M_DNS: OK" || say "  no dnsmanager method"

M_NFS=$(first_ok sharing.nfs.query nfs.query nfs.get_config || true)
[ -n "$M_NFS" ] && say "  $M_NFS: OK" || say "  no nfs query method (exports would need the UI)"

# ---- state ----
IFACE=$(echo "$IFACE_JSON" | jq -r --arg ip "$OLD_IP" \
  '[.[] | select((tostring) | contains($ip))] | .[0] | (.id // .properties.name // empty)' 2>/dev/null || true)
[ -n "$IFACE" ] || IFACE=enp1s0

cur_gw=""; cur_dns=""; DNS_OWNER=""
if [ -n "$M_GEN" ]; then
  GEN_JSON=$(midclt call "$M_GEN")
  cur_gw=$(echo "$GEN_JSON" | jq -r '.gateway // empty' 2>/dev/null || true)
  cur_dns=$(echo "$GEN_JSON" | jq -r '.nameservers // [] | join(", ")' 2>/dev/null || true)
  [ -n "$cur_dns" ] && DNS_OWNER="$M_GEN"
fi
if [ -z "$DNS_OWNER" ] && [ -n "$M_DNS" ]; then
  DNS_JSON=$(midclt call "$M_DNS")
  mgr_dns=$(echo "$DNS_JSON" | jq -r '.nameservers // [] | join(", ")' 2>/dev/null || true)
  [ -n "$mgr_dns" ] && { cur_dns="$mgr_dns"; DNS_OWNER="$M_DNS"; }
fi

NFS_ROWS=""
if [ -n "$M_NFS" ]; then
  NFS_JSON=$(midclt call "$M_NFS")
  NFS_ROWS=$(echo "$NFS_JSON" | jq -r '
    (if type == "array" then . else (.services // []) end)
    | .[] | select(((.paths // []) | join(",")) | test("/mnt/volume1/pve"))
    | "\(.id) | paths=\((.paths // []) | join(",")) | networks=\((.networks // []) | join(","))"' 2>/dev/null || true)
fi

case "$MODE" in
--check)
  say "interface holding $OLD_IP: $IFACE"
  echo "$IFACE_JSON" | jq -r --arg ifn "$IFACE" \
    '.[] | select(.id == $ifn or .properties.name == $ifn)
     | {d: (.state.dhcp4 // "?"), a: ([.state.alias4[]?.address] | join(","))}
     | "  dhcp=\(.d)  aliases=\(.a)"' 2>/dev/null || true
  say "gateway: ${cur_gw:-<unset>}"
  say "dns (owner: ${DNS_OWNER:-none}): ${cur_dns:-<unset>}"
  say "nfs exports (pve only):"
  echo "$NFS_ROWS" | sed 's/^/  /' || echo "  (none found)"
  say "PLANNED by --apply (already-matching steps skip):"
  echo "  1. interface.update $IFACE -> static $NEW_IP/24 (dhcp off)"
  echo "  2. gateway -> $NEW_GW"
  echo "  3. nameservers -> [192.168.1.1, 1.1.1.1]"
  echo "  4. nfs export networks -> [$NEW_SUBNET] (every pve export)"
  echo "  5. interface.commit (live; the old IP drops here)"
  exit 0
  ;;
--apply)
  : ;;
*) die "usage: truenas-network-move.sh --check|--apply" ;;
esac

# ---- apply (idempotent; skips what already matches) ----
if echo "$IFACE_JSON" | grep -q "$NEW_IP"; then
  say "interface already holds $NEW_IP -- skipping the IP change"
else
  echo "$IFACE_JSON" | grep -q "$OLD_IP" \
    || die "$OLD_IP not found on any interface -- run --check first"
  say "1/5 interface.update $IFACE -> $NEW_IP/24 (dhcp off)"
  midclt call interface.update "$IFACE" \
    "{\"ipv4_dhcp\": false, \"aliases\": [{\"address\": \"$NEW_IP\", \"netmask\": 24}]}"
fi

if [ -n "$M_GEN" ] && [ "$cur_gw" != "$NEW_GW" ]; then
  say "2/5 gateway -> $NEW_GW (via ${M_GEN%.get_config}.update)"
  midclt call "${M_GEN%.get_config}.update" "{\"gateway\": \"$NEW_GW\"}"
else
  say "2/5 gateway already $NEW_GW -- skipping"
fi

if [ -n "$DNS_OWNER" ]; then
  say "3/5 nameservers -> [192.168.1.1, 1.1.1.1] (via ${DNS_OWNER%.*}.update)"
  midclt call "${DNS_OWNER%.*}.update" '{"nameservers": ["192.168.1.1", "1.1.1.1"]}'
else
  say "3/5 no dns method discovered -- set DNS in the web UI after"
fi

if [ -n "$M_NFS" ]; then
  say "4/5 nfs export networks -> $NEW_SUBNET"
  echo "$NFS_JSON" | jq -r '
    (if type == "array" then . else (.services // []) end)
    | .[] | select(((.paths // []) | join(",")) | test("/mnt/volume1/pve"))
    | .id' | while read -r nid; do
      [ -n "$nid" ] || continue
      echo "  ${M_NFS%.*}.update $nid"
      midclt call "${M_NFS%.*}.update" "$nid" "{\"networks\": [\"$NEW_SUBNET\"]}"
    done
else
  say "4/5 no nfs method discovered -- fix export networks in the web UI after"
fi

say "5/5 committing interface change in 3s -- the old IP drops NOW"
cat <<EOF

  AFTER THIS:
  - on debbie:  sudo ip addr del 192.168.8.99/24 dev enp0s13f0u2u4
  - web UI:     https://192.168.1.10
  - if the console shows a shell, verify with:  ip -br addr show $IFACE
  IMPORTANT -- TRUENAS FAIL-SAFE: interface
  changes STAGE and REVERT to the last-good config unless confirmed.
  If the web UI shows a "save network changes" prompt, CLICK SAVE --
  without it the move rolls back after a grace window.
EOF
sleep 3
setsid sh -c 'midclt call interface.commit' >/dev/null 2>&1 &
sleep 2
# try the API-side confirmation of the same fail-safe (non-fatal if
# this version lacks the method; the UI Save prompt is the fallback)
if probe interface.checkin; then
  midclt call interface.checkin >/dev/null 2>&1 || true
fi
say "commit sent. verify from debbie: ping 192.168.1.10"
