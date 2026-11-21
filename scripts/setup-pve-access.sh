#!/usr/bin/env bash
# setup-pve-access.sh -- create the PVE-side access for the v2 ansible
# skeleton (OPS-7): the operator's PVE user + a revocable API token.
# NO root login anywhere: run from debbie over ssh AS NATE with sudo
# escalation, on any QUORATE node (post-quorum, revival evening).
#
#   scripts/setup-pve-access.sh pve-thermaltake
#
# Creates (idempotent, cluster-wide -- pmxcfs replicates it):
#   - PVE user nate@pam        (matches the OS account)
#   - Administrator role on /  (full operator rights for the user)
#   - API token "homelab-ops" (nate@pam!homelab-ops, no privilege
#     separation, no expiry -- revocable on its own without touching
#     anything else)
#
# The token SECRET prints ONCE at creation. Save it to
# local/pve-api.env (gitignored):
#   PVE_API_TOKEN_SECRET=<paste>
# group_vars/all.yml already carries the non-secret parts
# (pve_api_user / pve_api_token_id / pve_api_host).
#
# To ROTATE the secret later: on any node run
#   sudo pveum user token remove nate@pam homelab-ops
# then re-run this script.

set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
HOSTVARS="$REPO/ansible/inventory/host_vars"
SSH_USER="${SSH_USER:-nate}"

[ $# -eq 1 ] || { echo "usage: setup-pve-access.sh <pve-node-name>" >&2; exit 1; }
NODE="$1"
IP=$(awk '/^ansible_host:/ {print $2}' "$HOSTVARS/$NODE.yml")
[ -n "$IP" ] || { echo "no host_vars/$NODE.yml" >&2; exit 1; }

echo "== creating PVE access via $NODE ($IP) as $SSH_USER (sudo, no root login)"
ssh -o BatchMode=yes "$SSH_USER@$IP" sudo bash -s <<'REMOTE'
  set -e
  if pveum user list 2>/dev/null | grep -q "nate@pam"; then
    echo "user nate@pam: exists"
  else
    pveum user add nate@pam -comment "operator (ansible v2, OPS-7)"
    echo "user nate@pam: created"
  fi
  pveum acl modify / -user nate@pam -role Administrator
  echo "role: Administrator on / for nate@pam"
  if pveum user token list nate@pam 2>/dev/null | grep -q homelab-ops; then
    cat <<'EOF'
token homelab-ops: EXISTS (secret from its creation is not shown again).
To rotate: pveum user token remove nate@pam homelab-ops && re-run the script.
EOF
  else
    echo "token homelab-ops: creating -- COPY THE SECRET NOW:"
    pveum user token add nate@pam homelab-ops -privsep 0 -expire 0 \
      -comment "v2 ansible (OPS-7)"
    echo "(the value= line above is the one-time secret -> local/pve-api.env)"
  fi
  echo "-- summary:"
  pveum user list | head -4
  pveum user token list nate@pam 2>/dev/null | head -4 || true
REMOTE
echo "== done. local/pve-api.env should hold PVE_API_TOKEN_SECRET=<secret>"
