# Documentation index

Two tiers: what describes the fleet NOW, and the old-fleet archive
(moved to [legacy/](./legacy/) 2026-11-22 when the v2 docs landed).

## Current

- [`access.md`](./access.md) -- the sign-in table for every guest
  (URLs, credentials, first-use notes)
- [`data.md`](./data.md) -- the data architecture: one postgres,
  database-per-service, what centralizes + what deliberately does
  not, the practices (credentials, migrations, layered backups)
- [`maintenance.md`](./maintenance.md) -- update tiers, the
  converge/update/verify loop, the backup baseline, the node reboot
  runbook
- [`network.md`](./network.md) -- the LAN + tailnet access layer
  (mermaid diagrams), boot-order law
- [`backups.md`](./backups.md) -- vzdump + snapshots + B2 (PBS lands
  at OPS-14)
- [`data-to-extract.md`](./data-to-extract.md) -- the extraction
  reference (`scripts/extract-legacy.sh`); dumps remain on
  pve-backups so re-extracts stay possible

## Archive

- [`legacy/`](./legacy/) -- the old fleet's operational docs
  (cluster, HA quirks, TLS workflows, the 23-CT catalog, ...) as the
  phase-0 record. History, not guidance.
- `services/` (repo root) -- old-fleet assets + restore references;
  see its README.
