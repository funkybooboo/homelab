# OPS-2: The network plan

As the operator, I want the 192.168.1.0/24 IP plan in one file
(`infra/network/ips.yaml`) consumed by guest manifests, node bootstrap,
and the router playbooks, so that addresses never drift or conflict
again.

**Status**: planned
**Arc**: v1

## Acceptance criteria

- [ ] `ips.yaml`: nodes `.2`-`.9`, truenas `.10`, infrastructure
      `.11`-`.19`, guests `.50`-`.99`, DHCP pool `.100`-`.249`
- [ ] Flat-LAN decision + VLAN deferral documented
- [ ] Guest IP mechanism pinned (static at pct level unless
      [../issues.md](../issues.md) item 7 is overridden)

## Notes

The old lesson stays law: static at the OS (pct), not DHCP-lease
pinning -- see `services/network/README.md`.
