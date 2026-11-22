# OPS-10: postgresql

As the operator, I want postgresql back as the shared database,
restored from the legacy dumps, so that the services that depend on it
can return.

**Status**: planned
**Arc**: v2

## Acceptance criteria

- [ ] postgres deployed from a guest manifest, static IP per the plan
- [ ] Databases + roles restored from the v0 legacy extraction
      (linkwarden, omnivore, others per the curated list)
- [ ] Backup story connected: dumps land wherever OPS-14 decides

## Notes

Old CT 108 held it; the July catalog (docs/services.md) lists its
consumers (freshrss, linkwarden, omnivore) -- verify those DBs are
reachable once revived.

REVISED 2026-11-21 (revival): postgres revives with the fleet; the
story becomes verify (all expected DBs reachable) + the backup story
connection (OPS-14).

REVISED 2026-11-22 (plan shift final form): the old CT was cleaned out
(OPS-20). BUILD FRESH: manifest + role (PG 17), PGDATA restored from
the tier-0 extraction
(legacy-extraction/from-dump-108/var/lib/postgresql/17 on debbie);
dumps on pve-backups + B2 remain the deeper fallback.
