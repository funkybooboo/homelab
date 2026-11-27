#!/usr/bin/env bash
# proton-wg-switch.sh -- switch the router's Proton WireGuard
# tunnel between the NetShield variants (OPS-28).
#
# The three configs in local/ (proton-wg.conf = block-malware-
# ads-and-trackers, proton-wg-malware-only.conf,
# proton-wg-no-filter.conf) share ONE Proton server but each
# carries its OWN keypair: Proton binds the NetShield level to
# the keypair server-side. Switching = updating the WG
# instance's private key on the router -- the peer (server
# pubkey + endpoint) never changes.
#
# Usage:
#   ./scripts/proton-wg-switch.sh list            # variants + which is live
#   ./scripts/proton-wg-switch.sh status          # tunnel + handshake state
#   ./scripts/proton-wg-switch.sh switch ads       # -> block-malware-ads-and-trackers
#   ./scripts/proton-wg-switch.sh switch malware   # -> block-malware-only
#   ./scripts/proton-wg-switch.sh switch nofilter  # -> no filtering
#
# Records the choice: the chosen conf is copied over
# local/proton-wg.conf (the documented "active" pointer).
# Secrets stay in local/ (gitignored); this script and the
# router state hold no key material in the repo.

set -euo pipefail
cd "$(dirname "$0")/.."

ENV_FILE="local/opnsense-api.env"
[ -f "$ENV_FILE" ] || { echo "no $ENV_FILE (see local/opnsense-api.env.example)" >&2; exit 1; }
# shellcheck disable=SC1090
. "$ENV_FILE"

ROPT="-sk -u $OPNSENSE_KEY:$OPNSENSE_SECRET"

api() { curl $ROPT "$@"; }

VARIANTS=(
  "ads:proton-wg.conf:block-malware-ads-and-trackers"
  "malware:proton-wg-malware-only.conf:block-malware-only"
  "nofilter:proton-wg-no-filter.conf:no-filter"
)

conf_for() {
  for v in "${VARIANTS[@]}"; do
    [ "${v%%:*}" = "$1" ] && { cut -d: -f2 <<<"$v"; return 0; }
  done
  return 1
}

privkey_of() { grep '^PrivateKey' "$1" | awk '{print $NF}'; }
pubkey_of()  { wg pubkey <<<"$(privkey_of "$1")"; }

live_instance_uuid() {
  api "https://192.168.1.1/api/wireguard/server/get" \
    | /usr/bin/python3 -c "import json,sys; d=json.load(sys.stdin); print(next(iter(d['server']['servers']['server'])))"
}

live_iface_pubkey() {
  api "https://192.168.1.1/api/wireguard/service/show" \
    | /usr/bin/python3 -c "import json,sys; d=json.load(sys.stdin); print(next(r['public-key'] for r in d['rows'] if r['type']=='interface'))"
}

case "${1:-}" in
list)
  LIVE="$(live_iface_pubkey 2>/dev/null || true)"
  for v in "${VARIANTS[@]}"; do
    name="${v%%:*}"; conf="$(cut -d: -f2 <<<"$v")"; label="$(cut -d: -f3 <<<"$v")"
    if [ -f "local/$conf" ]; then
      k="$(pubkey_of "local/$conf" 2>/dev/null || echo '?')"
      mark=""
      [ "$k" = "$LIVE" ] && mark="<- LIVE"
      printf '%-9s %-30s %-30s %s\n' "$name" "$label" "$conf" "$mark"
    else
      printf '%-9s %-30s (missing local/%s)\n' "$name" "$label" "$conf"
    fi
  done
  ;;
status)
  api "https://192.168.1.1/api/wireguard/service/show" \
    | /usr/bin/python3 -c "
import json,sys
d=json.load(sys.stdin)
for r in d['rows']:
    if r['type']=='peer':
        print('peer     :', r['name'], r['endpoint'])
        print('handshake:', r['peer-status'], '(%ss ago)' % r['latest-handshake-age'])
        print('transfer : rx %s / tx %s' % (r['transfer-rx'], r['transfer-tx']))
"
  ;;
switch)
  [ -n "${2:-}" ] || { echo "usage: $0 switch <ads|malware|nofilter>" >&2; exit 1; }
  CONF="$(conf_for "$2")" || { echo "unknown variant: $2 (ads|malware|nofilter)" >&2; exit 1; }
  KEY="$(privkey_of "local/$CONF")"
  [ "${#KEY}" -eq 44 ] || { echo "local/$CONF has no real PrivateKey (re-download redaction: generate a fresh conf in Proton)" >&2; exit 1; }
  UUID="$(live_instance_uuid)"
  echo "switching $UUID to $CONF ..."
  RES="$(api -X POST -H "Content-Type: application/json" \
    -d "{\"server\":{\"privkey\":\"$KEY\"}}" \
    "https://192.168.1.1/api/wireguard/server/setServer/$UUID")"
  grep -q '"result":"saved"' <<<"$RES" || { echo "router refused the update: $RES" >&2; exit 1; }
  api -X POST "https://192.168.1.1/api/wireguard/service/reconfigure" >/dev/null
  sleep 8
  cp "local/$CONF" local/proton-wg.conf
  chmod 600 local/proton-wg.conf
  echo "switched. new handshake:"
  exec "$0" status
  ;;
*)
  echo "usage: $0 list|status|switch <ads|malware|nofilter>" >&2
  exit 1
  ;;
esac
