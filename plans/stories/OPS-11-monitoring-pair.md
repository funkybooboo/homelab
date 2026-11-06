# OPS-11: The monitoring pair

As the operator, I want prometheus + grafana watching the rebuild from
arc v2 onward, so that the fleet is observable while it is being
rebuilt, not only after.

**Status**: planned
**Arc**: v2

## Acceptance criteria

- [ ] prometheus + grafana deployed from guest manifests; pve-exporter
      scrape targets the new cluster
- [ ] Dashboards: node health, guest inventory, NFS/truenas basics
- [ ] Alert routing into ntfy (OPS-8)

## Notes

The old stack is described in `docs/observability.md` (as-built at
2026-08-30) + `docs/observability-build-plan.md` (the old-cluster build
plan; treat as input, not spec -- the fleet it planned for is gone).
Loki/centralized logging is deliberately out of scope here; revisit
after v4.
