# OPS-10: postgresql

As the operator, I want postgresql back as the shared database,
restored from the legacy dumps, so that the services that depend on it
can return.

**Status**: done (shipped 2026-11-22 -- the infra batch; see as-built notes)
**Arc**: v2

## Acceptance criteria

- [x] postgres deployed from a guest manifest, static IP per the plan
      -- DONE 2026-11-22: guests/postgres.yaml (vmid 101, .14,
      thermaltake); adminer (vmid 102, .15, aspiree15) added to scope
      as the DB UI
- [x] Databases + roles restored from the v0 legacy extraction
      -- DONE 2026-11-22: PGDATA from from-dump-108 restored into
      the fresh PG17 cluster (staged by scripts/stage-pgdata.sh;
      the role gates it with a marker + generates the en_US.UTF-8
      locale the minimal template lacks); the old fleet's `forgejo` +
      `freshrss` databases are live again. Operator login = role
      `nate` (password in local/pg-operator.env; CREATEDB/CREATEROLE,
      no superuser); service roles land per-service as their stories
      run (docs/data.md policy)
- [x] Backup story connected -- vzdump Sat 21:00 covers the CT
      (OPS-14 decides PBS); the shared-cluster policy +
      per-database pg_dump plan live in docs/data.md

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
