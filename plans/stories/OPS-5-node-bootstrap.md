# OPS-5: Node bootstrap

As the operator, I want one command that turns a fresh PVE 9.2 install
into a fleet node (hostname, static IP from `ips.yaml`, ssh key,
tailscale, no-subscription repo, cluster join), so that a node is a
replaceable part.

**Status**: superseded 2026-11-21 by [OPS-18 node revival](./OPS-18-node-revival.md)
**Arc**: n/a (tooling parked for future new/rebuilt nodes)

## Acceptance criteria

- [ ] `scripts/bootstrap.sh` idempotent; cluster join via ssh-agent-forwarded
      `pvecm add` at bring-up (folded into the community.proxmox
      `proxmox_cluster` module when OPS-7's ansible skeleton lands)
- [ ] Per-node glue codified from the inventory in
      [../design/proxmox-iac.md](../design/proxmox-iac.md) section 1:
      renew-pve-tls crons, laptop lid-ignored + screen-off units
- [ ] pve-framework enrolls with its USB-NIC fix in place (powered
      hub or PCIe NIC, per issues item 2) + a stability soak before
      it hosts HA-managed guests again
- [ ] Node facts live in `ansible/inventory/host_vars/`

## Notes

Superseded by OPS-18 (the nodes revived in place). The tooling
stays valid and parked: `bootstrap.sh` + `deploy-node-glue.sh` +
`ansible/inventory/host_vars/` serve any future fresh install (a
rebuilt node, a new machine).
