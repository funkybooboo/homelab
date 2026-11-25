# Off-site alerting architecture (operator design, 2026-11-25)

**Status**: design recorded (v4 alerting tier) -- not queued for build
**Supersedes**: the "alertmanager is the v4 upgrade" note in the lean
alerting decision -- this design is bigger and better reasoned.

## The operator's executive summary (as supplied)

Homelab alerting fails when the monitoring stack shares a power
supply with the thing it monitors. The fix is architectural, not a
product choice: detection stays in the lab, delivery and a
dead-man's switch live on a $5 VPS, and silence itself is what pages
you.

Cost: roughly $5/month and a weekend of setup. Stack is all OSS --
Prometheus and Alertmanager for detection and routing, ntfy for
push, Healthchecks and Gatus as independent watchdogs, Grafana for
dashboards only.

Expected outcome: you hear about real failures -- host down, disk
full, backup didn't run -- within minutes, and you hear nothing the
rest of the time. The main failure mode to avoid is skipping the
watchdog; without it, a dead box is silent.

## Review notes (agent, same day)

- The core insight is sound and matches the fleet's own history:
  the watcher was dead-from-birth for 14h in plain sight
  (2026-11-23 audit), and the current daily heartbeat is a
  dead-man's switch living INSIDE the thing it watches. Moving the
  switch off-power-supply is the structural fix.
- The $5 VPS is the fleet's first recurring paid dependency; the
  identity model (secrets out of git, operator-minted creds) applies
  unchanged. B2 is the existing off-site paid precedent, so the
  pattern is established.
- Detection stays as built: prometheus (14/14 targets) + the debbie
  watcher. What MOVES is delivery (ntfy reachable from outside) and
  the dead-man's switch (Healthchecks/Gatus pinging the watcher's
  heartbeat from the VPS, alerting when the heartbeat stops).
- Alertmanager enters here (v4 as planned) for routing/dedup on the
  lab side; ntfy stays the last mile.
- Gatus/Healthchecks are alternatives for the switch role; pick ONE
  at build time. Gatus config-as-code fits the repo's declarative
  style better.
- Blackbox-exporter (in the services backlog) pairs with this:
  external probe of the fronts FROM the VPS = seeing the lab the way
  the world does.

## Queued as

v4 arc (with OPS-12 push-to-apply, OPS-13 auto-update port,
OPS-14 PBS, OPS-15 drift) -- this becomes the v4 alerting story's
design home.
