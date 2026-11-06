# OPS-5: Node bootstrap

As the operator, I want one command that turns a fresh PVE 9.2 install
into a fleet node (hostname, static IP from `ips.yaml`, ssh key,
tailscale, no-subscription repo, cluster join), so that a node is a
replaceable part.

**Status**: planned
**Arc**: v1 (blocked: [../issues.md](../issues.md) item 2)

## Acceptance criteria

- [ ] `scripts/bootstrap.sh` idempotent; cluster join via the
      community.proxmox `proxmox_cluster` module
- [ ] Per-node glue codified from the inventory in
      [../design/proxmox-iac.md](../design/proxmox-iac.md) section 1:
      renew-pve-tls crons, laptop lid-ignored + screen-off units
- [ ] Node facts live in `infra/nodes/`

## Notes

The only manual step remains the PVE ISO install itself; everything
after enrollment is code (rule 1).
