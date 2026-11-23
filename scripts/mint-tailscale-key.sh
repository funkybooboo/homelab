#!/bin/bash
# scripts/mint-tailscale-key.sh -- mint a fresh reusable PREAUTHORIZED
# tailscale auth key (model B: guests enroll with it; 90-day expiry,
# re-mint when `make update` warns). Updates local/tailscale-authkey.env.
# Run from the repo root; needs local/tailscale-api.env sourced.
#
# The API on this tailnet: key endpoints WORK (device endpoints 404).
set -euo pipefail
source local/tailscale-api.env
RESP=$(curl -s -X POST "https://api.tailscale.com/api/v2/tailnet/-/keys" \
  -H "Authorization: Bearer $TAILSCALE_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"capabilities":{"devices":{"create":{"reusable":true,"ephemeral":false,"preauthorized":true,"tags":[]}}},"expirySeconds":7776000}')
KEY=$(printf '%s' "$RESP" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['key'])")
ID=$(printf '%s' "$RESP" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['id'])")
EXP=$(printf '%s' "$RESP" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['expires'])")
if [ -z "${KEY:-}" ] || [ "$KEY" = "None" ]; then
  echo "mint failed:"; printf '%s\n' "$RESP" | head -3; exit 1
fi
# retire the old key if present (best effort; tailnet-level endpoint)
if [ -f local/tailscale-authkey.env ] && [ -n "${TS_AUTH_KEY_ID:-}" ]; then
  source local/tailscale-authkey.env
  curl -s -X DELETE "https://api.tailscale.com/api/v2/tailnet/-/keys/$TS_AUTH_KEY_ID" \
    -H "Authorization: Bearer $TAILSCALE_API_TOKEN" -o /dev/null || true
fi
printf 'TS_AUTH_KEY_ID=%s\nTS_AUTH_KEY=%s\n# reusable, preauthorized, expires %s (minted %s)\n' \
  "$ID" "$KEY" "$EXP" "$(date +%F)" > local/tailscale-authkey.env
chmod 600 local/tailscale-authkey.env
echo "minted key $ID (expires $EXP) -> local/tailscale-authkey.env"
