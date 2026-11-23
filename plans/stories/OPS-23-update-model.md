# OPS-23: The v2 update + maintenance model

As the operator, I want every node and guest to carry an update plan
BEFORE more guests stand up, so that the fleet is born patchable.

**Status**: done (2026-11-22 -- the model is live; see the ticks;
`make update` first pass verified green + no reboot flags)
**Arc**: v2 (pulled forward from OPS-13's v4 scope; the full port --
ntfy digests, scheduled drift -- stays v4)

## Acceptance criteria

- [x] docs/maintenance.md: the tier model (A guests security-only
      auto + needrestart live restarts; B nodes security-only auto +
      never self-reboot; C truenas/router notify-only), the
      converge/update/verify loop, the backup baseline, the pre-HA
      node reboot runbook
- [x] guest_common: unattended-upgrades (security-only) + needrestart
      auto -- every guest born with the plan
- [x] node_glue: same security-only unattended config; NO needrestart
      auto on nodes (cluster services restart only with the node)
- [x] `make update` (maintenance.yml): tier-gated apt dist-upgrade
      pass, never reboots, surfaces reboot-required flags loudly;
      also checks the tailscale preauth key expiry (model B depends
      on it for new-guest enrollment)
- [x] First `make update` run across nodes + guests: green, no
      reboot triggered
- [x] Idempotent: re-run reports no changes

## Notes

The design conversation 2026-11-22 (operator answers on record):
infra batch BEFORE services (postgres, adminer, ntfy, prometheus,
grafana, loki -- the services layer depends on them); guests +
nodes = security-only auto (my lean, chosen); full upgrades in the
weekly operator pass; pre-HA reboot tolerance accepted (brief
per-guest downtime, onboot recovery).
Supersedes the old fleet's full-update allowlist (locked 2026-08) --
recorded in services/auto-update/unattended-50.example as history.
