#!/bin/sh
# console-setup-operator.sh -- THE ONLY THING THE OPERATOR TYPES AT EACH
# NODE'S CONSOLE (the identity model: one operator account,
# least privilege always, no root ssh ever, humans operate --
# assistants help). Log in as root at the node's PHYSICAL console
# (PVE 8), then paste the one-liner below.
#
# It creates the operator's account (key-only, no password)
# + the NOPASSWD sudo entry, prints OPS-READY, and shows the node's
# temporary DHCP address. `nate` is the operator's own account:
# it is THE operations account -- the operator uses it directly from
# debbie (their key is installed), and an AI assistant runs the same
# commands under the same identity on the operator's behalf when
# directed. One identity, one audit trail, human-controlled.
#
# The key in the paste line is the same material as
# ansible/playbooks/files/keys/admin.ed25519.pub (inlined because a
# console paste cannot read the repo) -- rotate BOTH together.
#
# Paste ONE LINE (as root at the console):
useradd -m -s /bin/bash nate && mkdir -p /home/nate/.ssh && echo 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFd52mRENjyFAQC5oCVE6aBEhhbr0zEcwzMwKlKhlh+x nate.stott@pm.me' > /home/nate/.ssh/authorized_keys && chmod 700 /home/nate/.ssh && chmod 600 /home/nate/.ssh/authorized_keys && chown -R nate:nate /home/nate/.ssh && echo 'nate ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/nate && chmod 440 /etc/sudoers.d/nate && visudo -c && echo OPERATOR-READY && ip -4 addr show vmbr0 | grep inet
#
# Verify: OPERATOR-READY prints, sudoers parse OK (visudo -c), and the
# last line shows the temp IP (e.g. inet 192.168.1.15x/24). Then
# fleet operations continue from debbie via: ssh nate@<temp-ip>
# (everything else tonight runs through sudo as this identity).
#
# LATER THE SAME EVENING, scripts/harden-ssh.sh <node> (run from
# debbie) turns OFF password ssh entirely + root ssh becomes
# key-only -- root's key stays because PVE itself uses root ssh
# BETWEEN nodes for migration/cluster operations; humans (and
# assistants they direct) use this account instead.
