#!/usr/bin/env bash
# opnsense.sh -- thin CLI over the OPNsense RESTCONF API, so the agent
# (and later the oxlorg.opnsense collection at v5) can operate the
# router from debbie without touching the web UI.
#
# Credentials live in local/opnsense-api.env (gitignored; created from
# local/opnsense-api.env.example). Web UI steps to make them:
#   System > Access > Users > edit your admin user > API keys >
#   create keypair, then copy key + secret into the env file.
#
# Usage:
#   scripts/opnsense.sh status                 # whoami-ish sanity call
#   scripts/opnsense.sh GET  core/system/status
#   scripts/opnsense.sh GET  dhcpd/leases       # find freshly booted nodes
#   scripts/opnsense.sh GET  routes/search
#   scripts/opnsense.sh POST interfaces/apply   # (example) trigger apply
# Paths are the API paths AFTER /api/. Output is pretty-printed JSON.
#
# Read-only calls are safe; POST calls change live router state --
# they stay in the human-gated category (identity rule 2) and the
# helper prints what it is about to send before sending it.

set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="$REPO/local/opnsense-api.env"
[ -f "$ENV_FILE" ] || { echo "no local/opnsense-api.env -- copy it from local/opnsense-api.env.example and fill it in" >&2; exit 1; }
# shellcheck disable=SC1090
source "$ENV_FILE"
: "${OPNSENSE_HOST:?OPNSENSE_HOST missing} ${OPNSENSE_KEY:?OPNSENSE_KEY missing} ${OPNSENSE_SECRET:?OPNSENSE_SECRET missing}"

MODE="${1:-status}"
api() { # api METHOD PATH [JSON_BODY]
  local method="$1" path="$2" body="${3:-}"
  local url="https://${OPNSENSE_HOST}/api/${path}"
  echo "--> $method $url${body:+ (body: $body)}" >&2
  if [ -n "$body" ]; then
    curl -sk -u "$OPNSENSE_KEY:$OPNSENSE_SECRET" -H 'Content-Type: application/json' \
      -X "$method" -d "$body" "$url"
  else
    curl -sk -u "$OPNSENSE_KEY:$OPNSENSE_SECRET" -H 'Content-Type: application/json' \
      -X "$method" "$url"
  fi
  echo >&2
}

case "$MODE" in
status) api GET core/system/status | jq . ;;
GET)  api GET "$2" | jq . ;;
POST) api POST "$2" "${3:-}" | jq . ;;
*)    echo "usage: opnsense.sh status | GET <path> | POST <path> [json-body]" >&2; exit 1 ;;
esac
