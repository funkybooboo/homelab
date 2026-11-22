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
2026-08-30) + the old build plan (in git history; treat as input,
Loki/centralized logging is deliberately out of scope here; revisit
after v4.

REVISED 2026-11-21 (revival): the pair revives with the fleet; the
story becomes verify scrape targets + dashboards for the revived
nodes/CTs, and re-wire the truenas alert bridge.

REVISED 2026-11-22 (plan shift final form): the old CTs were cleaned
out (OPS-20). BUILD FRESH: manifests + roles; scrape targets = the
new fleet as it lands; dashboards rebuilt fresh (old grafana data
sits in dump 123 if a restore is ever wanted); ntfy is the alert
channel (OPS-8).
