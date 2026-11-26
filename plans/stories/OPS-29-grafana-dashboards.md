# OPS-29: Grafana observability -- the dashboard layer

As the operator, I want one high-level dashboard that answers "is my
homelab healthy" at a glance, plus a set of low-level dashboards
that dive into each domain, so I can understand the fleet at every
altitude -- network, disks, CPUs, systemd, restarts, packages,
alerts, power/cost, GPU, ssh, ports, tailnet, backups, services.

**Status**: planned (design:
[../design/observability-dashboards.md](../design/observability-dashboards.md))
**Arc**: v3 (dashboards) + v4 dependency (alert counts ride the
alerting tier)

## The plan, in phases (design doc has the full detail)

- [ ] **OPS-29a -- close the data gaps**: pve-exporter (CT/vzdump/
      pools via the homelab-ops token), SNMP exporters for truenas
      + opnsense (network speed panels), DCGM for the GPU,
      blackbox for front/port probes, and the textfile-collector
      scripts (updates pending, reboot flags, tailscale key ages,
      library counts, watt/cost model) as systemd timers owned by
      cronmaster once it is live (see
      [../design/cronmaster-scheduled-jobs.md](../design/cronmaster-scheduled-jobs.md);
      systemd timers only as a temporary measure).
- [ ] **OPS-29b -- THE dashboard**: "Homelab at a glance" -- fleet
      health strip, per-host board, resource heatmaps, storage +
      backup ages, network, event feed; recording rules so it
      renders in one pass; provisioned from the grafana role (JSON
      in git, never hand-built UI state).
- [ ] **OPS-29c -- the low-level set**: node detail (click-through
      from the top), PVE cluster, truenas, router/network,
      postgres, forgejo hub, logs/loki (ssh auth + restarts live
      here TODAY -- dashboards, not new collection), storage/
      backups, media, power+cost, tailnet, security.

## Acceptance criteria

- [ ] One URL shows fleet health without scrolling
- [ ] Every panel on the high-level dashboard is a recording rule
- [ ] Dashboards + rules + collectors all converge-managed
      (provisioning files in git; make verify green; idempotent)
- [ ] The gap table in the design doc is either closed or
      explicitly deferred per item (menu, not mandate)
- [ ] ssh auth events, restarts, and journal errors visible from
      data we ALREADY collect (loki) -- zero new collectors for
      those panels

## Notes

- Alert counts/types wait for the v4 alerting tier
  (design/offsite-alerting.md); the panels land empty by design,
  labeled as such.
- Power/cost: static watts table (one meter reading per host) +
      the UPS story's nut-exporter later; external utility-rate
      API only if a live rate is actually wanted.
- v3 placement: pull-forwardable to run right after USER-2 if the
  operator wants to see the fleet before building more services.
