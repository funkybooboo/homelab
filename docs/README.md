# Documentation index

The tree describes the fleet NOW; the old fleet's docs live in git
history, not the tree (deleted 2026-11-22 -- retrievable via
`git log -- docs/` when restore-time reference is ever wanted).

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

## Restore references

- `services/` (repo root) -- old-fleet assets the future stories
  consume (feeds.opml is DATA, not docs -- the freshrss story needs
  it); see its README.
- `data-to-extract.md` -- the extraction reference; dumps remain on
  pve-backups so re-extracts stay possible.
