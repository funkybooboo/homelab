# OPS-1: The legacy archive

As the operator, I want the old homelab fully documented (CT catalog,
IP scheme, quirks, data inventory) before anything is wiped, so that
the rebuild starts from a record instead of from memory.

**Status**: planned
**Arc**: v0

## Acceptance criteria

- [ ] `docs/legacy/` written: CT catalog, IP scheme, HA quirks and
      incidents, per-service state at the shutdown
- [ ] `scripts/extract-legacy.sh`: mount the old `pve-shared` rootfs
      read-only; inventory per-service data to extract (vaultwarden db,
      postgres dumps, n8n workflows, forgejo repos, jellyfin metadata)
- [ ] Timeline cross-checked against
      [../history.md](../history.md)

## Notes

No hardware beyond truenas required. Sources: this repo's `docs/`,
`services/*`, and the 2026-11-04 network-forensics report. Design
record: [../design/greenfield-rebuild.md](../design/greenfield-rebuild.md)
(phase 0).
