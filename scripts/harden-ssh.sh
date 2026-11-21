#!/usr/bin/env bash
# harden-ssh.sh -- the good-ssh pass for a revived PVE node (operator
# decisions 2026-11-21: least privilege always, no root ssh ever,
# good ssh practices first). Run from debbie after the node is revived
# + verified:  scripts/harden-ssh.sh <node-name>
#
# What it does (as the nate account, via sudo):
#   - sshd drop-in /etc/ssh/sshd_config.d/50-harden.conf:
#       PasswordAuthentication no        (password ssh dies everywhere)
#       KbdInteractiveAuthentication no
#       PermitRootLogin prohibit-password (root ssh KEY-ONLY)
#   - validates (sshd -t) + reloads sshd
#   - prints the effective values for verification
#
# THE LOAD-BEARING NUANCE: root ssh stays key-only (not "no") because
# PVE ITSELF uses root ssh BETWEEN nodes for cluster operations --
# live migration, pvecm, qm remote operations. Killing root ssh
# outright breaks the cluster. With password auth dead, root is
# reachable only via the inter-node keys + the physical console; the
# humans + their assistants use the nate identity. The console (physical) remains
# the break-glass path.
#
# Rollback if you lock yourself out: at the node's PHYSICAL console,
# delete /etc/ssh/sshd_config.d/50-harden.conf + reload sshd.

set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
HOSTVARS="$REPO/ansible/inventory/host_vars"
SSH_USER="${SSH_USER:-nate}"

[ $# -eq 1 ] || { echo "usage: harden-ssh.sh <node-name>" >&2; exit 1; }
NODE="$1"
IP=$(awk '/^ansible_host:/ {print $2}' "$HOSTVARS/$NODE.yml")
[ -n "$IP" ] || { echo "no host_vars/$NODE.yml" >&2; exit 1; }

echo "== harden sshd on $NODE ($IP) as $SSH_USER"
ssh -o BatchMode=yes "$SSH_USER@$IP" sudo bash -s <<'REMOTE'
  set -e
  mkdir -p /etc/ssh/sshd_config.d
  cat > /etc/ssh/sshd_config.d/50-harden.conf <<'EOF'
# good-ssh pass 2026-11-21: passwords die everywhere; root ssh is
# key-only (PVE inter-node ops need it -- see scripts/harden-ssh.sh)
PasswordAuthentication no
KbdInteractiveAuthentication no
PermitRootLogin prohibit-password
EOF
  sshd -t && echo "sshd config valid"
  systemctl reload sshd || systemctl reload ssh
  echo "-- effective values:"
  sshd -T | grep -iE "^passwordauthentication|^permitrootlogin|^kbdinteractiveauthentication"
REMOTE
echo "== done. nate + inter-node key auth still work; verify from debbie:"
echo "   ssh $SSH_USER@$IP true && echo ok"
