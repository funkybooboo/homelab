# OPS-1: The legacy archive

As the operator, I want the old homelab fully documented (CT catalog,
IP scheme, quirks, data inventory) before anything is wiped, so that
the rebuild starts from a record instead of from memory.

**Status**: done (shipped 2026-11-06)
**Arc**: v0

## Acceptance criteria

- [x] `docs/legacy/` written: CT catalog, IP scheme, HA quirks and
      incidents, per-service state at the shutdown
- [x] `scripts/extract-legacy.sh`: mount the old `pve-shared` rootfs
      read-only; inventory per-service data to extract (vaultwarden db,
      postgres dumps, n8n workflows, forgejo repos, jellyfin metadata)
- [x] Timeline cross-checked against
      [../history.md](../history.md)

## Notes

Shipped as 5 archive files + the script. What the reconciliation
found (all recorded in `docs/legacy/README.md`):

- Final running set was **28 CTs**, not services.md's 23: the media
  batch (131 syncstorage-rs, 132 navidrome, 133 audiobookshelf, 134
  omnivore) + loki 130 shipped after the July catalog snapshot.
- Two CTs have rootfs on **local-lvm**, not pve-shared (128 ntfy,
  130 loki) -- extract-legacy.sh falls back to their weekly vzdump
  artifacts in pve-backups (`--copy-from-dump`).
- The skill's final table omits 125/126 (bichon, protonmail-bridge)
  and misplaces 128 -- the archive records both readings and the
  script's full `images/` listing settles what really existed.
- Node placements drifted so much between snapshots that the archive
  records "final placement" as history, never as a restore source.

The script RUNS at the first hardware touch (after OPS-4's truenas
move); its tier-0 report gate feeds USER-1's vaultwarden restore.
