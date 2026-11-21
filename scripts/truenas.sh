#!/usr/bin/env bash
# truenas.sh -- thin CLI over the TrueNAS REST API (v2), so fleet
# operations from debbie never need root ssh or the web UI. Same
# pattern as scripts/opnsense.sh.
#
# Credentials: local/truenas-api.env (gitignored; created from the
# committed .example). The key authenticates as the operator's own
# admin account -- the same privileges as your web UI session, no
# more. NEVER commit the file; never paste the key into chat.
# Root's only door on truenas is the physical console.
#
# Usage:
#   scripts/truenas.sh status                # system info sanity call
#   scripts/truenas.sh GET  pool             # -> /api/v2.0/pool
#   scripts/truenas.sh GET  cloudsync         # the 5 B2 tasks
#   scripts/truenas.sh GET  interface         # live interface state
#   scripts/truenas.sh GET  service           # services + state
#   scripts/truenas.sh POST <path> [json]     # gated write (see below)
# Paths are AFTER /api/v2.0/. Output is pretty-printed JSON.
#
# Read-only calls are safe; POST calls change live state -- they stay
# in the human-gated category (identity rule 2) and the helper echoes
# what it is about to send before sending it. TRAP from the move
# evening (TrueNAS fail-safe): interface changes stage + REVERT unless
# confirmed -- after any interface POST, watch the UI's save prompt
# (or call interface/checkin).
#
# Read-only ssh also works for diagnostics (no escalation):
#   ssh nate@192.168.1.10 '/usr/sbin/zpool status volume1'

set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="$REPO/local/truenas-api.env"
[ -f "$ENV_FILE" ] || { echo "no local/truenas-api.env -- copy it from local/truenas-api.env.example and fill in the API key" >&2; exit 1; }
# shellcheck disable=SC1090
source "$ENV_FILE"
: "${TRUENAS_HOST:?TRUENAS_HOST missing} ${TRUENAS_API_KEY:?TRUENAS_API_KEY missing}"

MODE="${1:-status}"

api() { # api METHOD PATH [JSON_BODY]
  local method="$1" path="$2" body="${3:-}"
  local url="https://${TRUENAS_HOST}/api/v2.0/${path}"
  echo "--> $method $url${body:+ (body: $body)}" >&2
  # (learned on the router evening: no Content-Type on bodyless GETs)
  if [ -n "$body" ]; then
    curl -sk -H "Authorization: Bearer $TRUENAS_API_KEY" \
      -H 'Content-Type: application/json' -X "$method" -d "$body" "$url"
  else
    curl -sk -H "Authorization: Bearer $TRUENAS_API_KEY" -X "$method" "$url"
  fi
  echo >&2
}

case "$MODE" in
status) api GET system/info | jq . ;;
GET)   api GET "$2" | jq . ;;
POST)  api POST "$2" "${3:-}" | jq . ;;
*)     echo "usage: truenas.sh status | GET <path> | POST <path> [json-body]" >&2; exit 1 ;;
esac
