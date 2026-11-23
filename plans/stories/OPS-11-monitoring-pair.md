# OPS-11: The monitoring pair

As the operator, I want prometheus + grafana watching the rebuild from
arc v2 onward, so that the fleet is observable while it is being
rebuilt, not only after.

**Status**: in progress (the pair + loki live 2026-11-22; dashboards + alerts land as used)
**Arc**: v2

## Acceptance criteria

- [x] prometheus + grafana deployed from guest manifests -- DONE
      2026-11-22: prometheus (vmid 104, .17, aspiree15) + grafana
      (vmid 105, .18, aspires) + loki added to scope (vmid 106, .19,
      thermaltake); scrape targets are GENERATED from guests/*.yaml
      + the pve inventory at converge (12 targets UP); promtail on
      every node ships journald to loki (node_glue; the fs.protected_
      regular fossil + journal-group traps are recorded in the repo)
- [ ] Dashboards: node health, guest inventory, NFS/truenas basics
      -- datasources provisioned (prometheus + loki in grafana);
      dashboards build in the UI (old grafana data = dump 123 if a
      restore is wanted)
- [ ] Alert routing into ntfy (OPS-8) -- pending the alert wiring

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
