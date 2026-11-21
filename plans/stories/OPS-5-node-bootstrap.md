# OPS-5: Node bootstrap

As the operator, I want one command that turns a fresh PVE 9.2 install
into a fleet node (hostname, static IP from `ips.yaml`, ssh key,
tailscale, no-subscription repo, cluster join), so that a node is a
replaceable part.

**Status**: planned
**Arc**: v1

## Acceptance criteria

- [ ] `scripts/bootstrap.sh` idempotent; cluster join via agent-forwarded
      `pvecm add` at bring-up (folded into the community.proxmox
      `proxmox_cluster` module when OPS-7's ansible skeleton lands)
- [ ] Per-node glue codified from the inventory in
      [../design/proxmox-iac.md](../design/proxmox-iac.md) section 1:
      renew-pve-tls crons, laptop lid-ignored + screen-off units
- [ ] pve-framework enrolls with its USB-NIC fix in place (powered
      hub or PCIe NIC, per issues item 2) + a stability soak before
      it hosts HA-managed guests again
- [ ] Node facts live in `infra/nodes/`

## Notes

The only manual step remains the PVE ISO install itself (physical +
console + the ips.yaml static IP + a root password + the admin pub key
into authorized_keys); the agent drives everything after via ssh from
debbie (the recorded bring-up mode, 2026-11-06). SHIPPED ARTIFACTS:
`scripts/bootstrap.sh` + `scripts/deploy-node-glue.sh` +
`infra/nodes/*.yaml` + `infra/keys/admin.ed25519.pub`.
