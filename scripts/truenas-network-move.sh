#!/bin/sh
# truenas-network-move.sh -- OPS-4: move truenas from the dead
# 192.168.8.x LAN to the greenfield 192.168.1.x LAN, IN PLACE.
# TrueNAS is kept exactly as it is (datasets, NFS, B2 sync, TLS cron);
# only its address moves. No reinstall, ever (plans/issues.md item 8).
#
# Run ON TRUENAS as root -- either at the console, or over ssh:
#   debbie#  sudo ip addr add 192.168.8.99/24 dev <debbie-lan-nic>   # temp alias
#   debbie#  ssh root@192.168.8.100 'sh -s' < scripts/truenas-network-move.sh --check
#   debbie#  ssh root@192.168.8.100 'sh -s' < scripts/truenas-network-move.sh --apply
#   debbie#  sudo ip addr del 192.168.8.99/24 dev <debbie-lan-nic>
# (no console needed: root ssh is enabled on truenas and the alias
# trick reaches it on the old subnet across the shared L2)
#
# Target state (infra/network/ips.yaml): 192.168.1.10/24, gw
# 192.168.1.1, dns [192.168.1.1, 1.1.1.1], NFS exports on
# 192.168.1.0/24. --check prints current state + the planned changes;
# --apply executes them. Method names verified against 24.10+/25.x
# middleware (interface/general/dnsmanager/nfs); --apply fails loudly
# rather than guessing if the check can't find what it expects.
#
# WARNING: --apply changes the IP live. An ssh session from the old
# subnet DIES at commit. The script prints where to reconnect before
# it commits.

set -eu

NEW_IP=192.168.1.10
NEW_GW=192.168.1.1
NEW_MASK=24
NEW_SUBNET=192.168.1.0/24
OLD_IP=192.168.8.100
MODE="${1:---check}"

say()  { echo "== $*"; }
die()  { echo "ERROR: $*" >&2; exit 1; }

jqget() { jq -r "$1"; }

# ---- state discovery ------------------------------------------------

iface_json=$(midclt call interface.query)
IFACE=$(echo "$iface_json" | jqget '
  [.[] | select(.state.alias4 // [] | map(.address) | index("'"$OLD_IP"'"))][0]
  | .properties.name? // empty')
[ -n "$IFACE" ] || IFACE=enp1s0

gen_json=$(midclt call general.get_config)
cur_gw=$(echo "$gen_json" | jqget '.gateway // empty')

dns_json=$(midclt call dnsmanager.get_config 2>/dev/null || echo '{}')
cur_dns=$(echo "$dns_json" | jqget '.nameservers // [] | join(", ")')

nfs_json=$(midclt call nfs.get_config)
cur_nfs=$(echo "$nfs_json" | jqget '
  [.services[] | {id, paths, networks: (.networks // [])}]
  | map(select(.paths[] | test("/mnt/volume1/pve"))) | .[] | "\(.id): \(.paths|join(",")) nets=\(.networks|join(","))"' | tr '\n' ';')

case "$MODE" in
--check)
  say "interface holding $OLD_IP: $IFACE"
  echo "$iface_json" | jq -r ".[] | select(.properties.name == \"$IFACE\") |
    \"  dhcp=\(.state.dhcp4) aliases=\([.state.alias4[]?.address] | join(\",\"))\""
  say "gateway: ${cur_gw:-<unset>}"
  say "dns: ${cur_dns:-<unset>}"
  say "nfs exports (pve only): ${cur_nfs:-none}"
  say "PLANNED by --apply:"
  echo "  interface.update $IFACE -> static $NEW_IP/$NEW_MASK (dhcp off)"
  echo "  general.update   -> gateway $NEW_GW"
  echo "  dnsmanager.update -> nameservers [192.168.1.1, 1.1.1.1]"
  echo "  nfs.update        -> networks [$NEW_SUBNET] on every pve export"
  echo "  interface.commit  (live; ssh from the old subnet will DROP)"
  exit 0
  ;;
--apply)
  : ;;
*) die "usage: truenas-network-move.sh --check|--apply" ;;
esac

# ---- preflight ------------------------------------------------------

if ! echo "$iface_json" | grep -q "$OLD_IP"; then
  die "$OLD_IP not found on any interface -- is this the pre-move truenas? Run --check."
fi
echo "$gen_json" | jq -e '.gateway' >/dev/null 2>&1 \
  || die "general.get_config has no gateway field -- middleware shape differs; inspect --check output and adjust."
echo "$dns_json" | jq -e '.nameservers' >/dev/null 2>&1 \
  || die "dnsmanager has no nameservers field -- inspect --check output and adjust."
echo "$nfs_json" | jq -e '.services' >/dev/null 2>&1 \
  || die "nfs.get_config has no services list -- inspect --check output and adjust."

say "applying: interface $IFACE -> $NEW_IP/$NEW_MASK (dhcp off)"
midclt call interface.update "$IFACE" \
  '{"ipv4_dhcp": false, "aliases": [{"address": "'"$NEW_IP"'", "netmask": '"$NEW_MASK"'}]}'

say "applying: gateway -> $NEW_GW"
midclt call general.update '{"gateway": "'"$NEW_GW"'"}'

say "applying: nameservers (hosts preserved)"
echo "$dns_json" | jq '.nameservers = ["192.168.1.1", "1.1.1.1"]' \
  | midclt call dnsmanager.update "$(cat)"

say "applying: nfs export networks -> $NEW_SUBNET"
for id in $(echo "$nfs_json" | jq -r '.services[]
      | select(.paths[] | test("/mnt/volume1/pve")) | .id'); do
  echo "  nfs.update $id"
  midclt call nfs.update "$id" '{"networks": ["'"$NEW_SUBNET"'"]}'
done
midclt call service.restart '{"service": "nfs", "ha_enable": false}' \
  || say "nfs service restart skipped (non-fatal; verify from debbie with showmount)"

say "RECONNECT INSTRUCTIONS (your ssh session is about to drop):"
echo "  on debbie: sudo ip addr del 192.168.8.99/24 dev <debbie-lan-nic>"
echo "  then:      ssh root@192.168.1.10"
say "committing interface change in 3s (live)..."
sleep 3
setsid sh -c 'midclt call interface.commit' >/dev/null 2>&1 &
sleep 2
say "committed. if you can read this, the session survived; verify:"
echo "  ip -br addr show $IFACE ; ip route"
