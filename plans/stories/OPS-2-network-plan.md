# OPS-2: The network plan

As the operator, I want the 192.168.1.0/24 IP plan in one file
(`ansible/inventory/group_vars/all.yml` + per-machine
`host_vars/*.yml`) consumed by guest manifests, node bootstrap,
and the router playbooks, so that addresses never drift or conflict
again.

**Status**: done (shipped 2026-11-06)
**Arc**: v1

## Acceptance criteria

- [x] `ips.yaml`: nodes `.2`-`.9`, truenas `.10`, infrastructure
      `.11`-`.19`, guests `.50`-`.99`, DHCP pool `.100`-`.249`
- [x] Flat-LAN decision + VLAN deferral documented
- [x] Guest IP mechanism pinned (static at pct level unless
      [../issues.md](../issues.md) item 7 is overridden)

## Notes

Shipped as `ansible/inventory/` (group_vars/all.yml = LAN plan,
host_vars/*.yml = the per-machine registry with ansible_host, mac,
role, hardware, constraints, glue). RELOCATED 2026-11-21 to the
idiomatic ansible inventory layout (was infra/); the bash parsers
were updated with the move. The admin public key lives at
`files/keys/admin.ed25519.pub`. Consumers:
`scripts/bootstrap.sh`, `scripts/deploy-node-glue.sh`,
`scripts/truenas-network-move.sh`, and the v2 guest manifests.

Assignments: `.1` opnsense VM, `.2` pve-router (the V1210), `.3`
pve-thermaltake, `.4` pve-framework, `.5` pve-aspiree15, `.6`
pve-aspires, `.10` truenas, `.11` raspberrypi (QDevice), `.12` reserved
PBS, `.13` reserved subnet router. The old fleet's no-pattern node IPs
and DHCP-pinning are gone for good (the old fleet's record lives in
git history).
