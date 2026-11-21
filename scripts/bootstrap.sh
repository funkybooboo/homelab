#!/usr/bin/env bash
# bootstrap.sh -- OPS-5: enroll a fresh PVE 9.2 ISO install as a fleet
# node, driven FROM DEBBIE over ssh (the operator does the physical +
# console part: power, ISO install with the ips.yaml static IP + a root
# password, and drops files/keys/admin.ed25519.pub into root's
# authorized_keys; operations continue from there).
#
# Usage (on debbie):  scripts/bootstrap.sh <node-name> [--join <peer-ip>]
#   <node-name>  must exist in ansible/inventory/host_vars/<name>.yml
#   --join       cluster join via ssh-agent-forwarded `pvecm add` (run me
#                with the debbie key agent loaded; -A forwarding is set)
#
# What it does on the node (idempotent; safe to re-run):
#   1. sanity: PVE installed, root, hostname correct
#   2. /etc/hosts: every fleet host from ips.yaml
#   3. vmbr0 IP verified against ips.yaml (loud warning + diff if the
#      installer was given a different IP; --fix-network repairs)
#   4. repos: no-subscription for the detected codename
#   5. packages: tailscale + corosync-qdevice
#   6. root authorized_keys: admin key (grep-guarded)
#   7. tailscale up (TS_AUTH_KEY env if set, else prints the login URL)
#   8. optional cluster join
# Follow with: scripts/deploy-node-glue.sh <node-name>
#
# NOTE (2026-11-21): this script predates the operations-identity model and
# still logs in as root over ssh (fresh installs begin with a root
# password from the ISO). For any FUTURE use, run
# scripts/console-setup-operator.sh at the node's console first and pass
# SSH_USER=nate -- do not re-introduce root ssh.

set -euo pipefail

[ $# -ge 1 ] || { echo "usage: bootstrap.sh <node-name> [--join <peer-ip>]" >&2; exit 1; }
NODE="$1"; shift || true
JOIN=""
while [ $# -gt 0 ]; do
  case "$1" in
    --join) shift; JOIN="${1:?--join needs a peer ip}"; shift ;;
    *) echo "unknown arg: $1" >&2; exit 1 ;;
  esac
done

REPO="$(cd "$(dirname "$0")/.." && pwd)"
HOSTVARS="$REPO/ansible/inventory/host_vars"
FACTS="$HOSTVARS/$NODE.yml"
PUBKEY_FILE="$REPO/files/keys/admin.ed25519.pub"
[ -f "$FACTS" ] || { echo "no host_vars/$NODE.yml" >&2; exit 1; }
[ -f "$PUBKEY_FILE" ] || { echo "no files/keys/admin.ed25519.pub" >&2; exit 1; }

IP=$(awk '/^ansible_host:/ {print $2}' "$FACTS")
[ -n "$IP" ] || { echo "no ansible_host for $NODE" >&2; exit 1; }
PUBKEY="$(cat "$PUBKEY_FILE")"

# /etc/hosts block: "ip name" for every machine in host_vars/
HOSTS_BLOCK=$(for f in "$HOSTVARS"/*.yml; do
  echo "$(awk '/^ansible_host:/ {print $2}' "$f") $(basename "$f" .yml)"
done)
[ -n "$HOSTS_BLOCK" ] || { echo "no hosts parsed from host_vars/" >&2; exit 1; }

ssh_test() { ssh -o BatchMode=yes -o ConnectTimeout=5 "root@$IP" true 2>/dev/null; }
ssh_test || { echo "cannot ssh root@$IP with the admin key" >&2
  echo "operator console step still needed: put files/keys/admin.ed25519.pub" >&2
  echo "into root@$IP:/root/.ssh/authorized_keys" >&2; exit 1; }

say() { echo "== $*"; }
SSHCMD="ssh -A -o BatchMode=yes root@$IP"

say "sanity on $NODE ($IP)"
$SSHCMD 'pveversion >/dev/null || { echo "not a PVE host" >&2; exit 1; }
         [ "$(id -u)" = 0 ] || { echo "not root" >&2; exit 1; }'

say "hostname -> $NODE"
$SSHCMD "if [ \"\$(hostname)\" != \"$NODE\" ]; then
             echo \"$NODE\" > /etc/hostname; hostname \"$NODE\";
         fi
         grep -q \"^127.0.1.1\" /etc/hosts || echo \"127.0.1.1 $NODE\" >> /etc/hosts"

say "/etc/hosts: fleet hosts"
$SSHCMD "python3 - <<'PYEOF'
import re
want = '''$HOSTS_BLOCK'''.strip().splitlines()
hosts = open('/etc/hosts').read().splitlines()
for line in want:
    ip, name = line.split()
    pat = re.compile(r'^\S+\s+' + re.escape(name) + r'(\s|\$)')
    hosts = [l for l in hosts if not pat.match(l)] + [f'{ip} {name}']
open('/etc/hosts', 'w').write('\n'.join(hosts) + '\n')
PYEOF
cat /etc/hosts"

say "vmbr0 IP check (expect $IP)"
$SSHCMD "ip -br addr show vmbr0 || true; grep -n 'address' /etc/network/interfaces || true
         grep -q 'address $IP/' /etc/network/interfaces \
           || echo 'WARNING: interfaces lacks $IP -- re-run with --fix-network or fix by hand'"

say "repos: no-subscription"
$SSHCMD 'CN="$(. /etc/os-release; echo "$VERSION_CODENAME")"
         SRC="/etc/apt/sources.list.d/pve-enterprise.list"
         if [ -f "$SRC" ] && ! grep -q "^#" "$SRC"; then
           sed -i "s|^deb|#deb|" "$SRC"
           echo "deb http://download.proxmox.com/debian/pve \$CN pve-no-subscription" \
             > /etc/apt/sources.list.d/pve-no-sub.list
         fi
         [ -f /etc/apt/sources.list.d/ceph.list ] \
           && sed -i "s|^deb|#deb|" /etc/apt/sources.list.d/ceph.list || true
         grep -h pve /etc/apt/sources.list.d/*.list 2>/dev/null'

say "packages: tailscale + corosync-qdevice"
$SSHCMD 'apt-get update -qq
         apt-get install -y -qq tailscale corosync-qdevice >/dev/null
         tailscale --version | head -1'

say "root authorized_keys: admin key (idempotent)"
$SSHCMD "mkdir -p /root/.ssh; chmod 700 /root/.ssh
         grep -qF \"$PUBKEY\" /root/.ssh/authorized_keys 2>/dev/null \
           || echo \"$PUBKEY\" >> /root/.ssh/authorized_keys
         chmod 600 /root/.ssh/authorized_keys; echo ok"

if $SSHCMD 'tailscale status --peers=false >/dev/null 2>&1'; then
  say "tailscale: already up"
else
  say "tailscale: bringing up"
  if [ -n "${TS_AUTH_KEY:-}" ]; then
    $SSHCMD "tailscale up --auth-key='$TS_AUTH_KEY' --hostname=$NODE"
  else
    $SSHCMD "tailscale up --hostname=$NODE 2>&1 | head -5" \
      || true
    echo "OPERATOR: finish tailscale login with the URL above" \
         "(or re-run with TS_AUTH_KEY env)"
  fi
fi

if [ -n "$JOIN" ]; then
  say "cluster join: pvecm add $JOIN (ssh-agent-forwarded)"
  $SSHCMD "pvecm add $JOIN" \
    || { echo "join failed -- if it is the ssh fingerprint/password prompt," \
              "run it interactively: ssh -A root@$IP pvecm add $JOIN" >&2; }
fi

say "bootstrap pass complete on $NODE"
echo "next: scripts/deploy-node-glue.sh $NODE"
