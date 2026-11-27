# USER-7: linkwarden

As the operator, I want my linkwarden instance back -- the saved
links, collections, and user accounts -- so that my read-it-later
archive keeps growing where it left off.

**Status**: planned
**Arc**: v3 (carved out of USER-3's build list per operator
directive 2026-11-23)

## Acceptance criteria

- [ ] Manifest + role; linkwarden pinned
- [ ] Database live from the restored PGDATA (old CT 108 rode
      postgres; OPS-10 restored it) -- verify the schema against
      the pinned app version before first boot
- [ ] `.env` (auth secrets) extracted from the Nov-21 vzdump of
      old CT 112 and applied
- [ ] Operator logs in with old credentials; a saved link opens;
      serve front live

## Notes

Postgres-backed per the data policy (docs/data.md): points at
CT 101's instance, database-per-service, role-per-service --
the forgejo DO-block pattern transfers (restored tables are
postgres-owned and need the per-relkind reassignment).

## Re-baseline (2026-11-28)

The body above was written against the old cluster. For the
current build: the deployment target is the CURRENT cluster via
a guest manifest + role (or container_guest where an official
digest-pinned image exists -- see USER-3's mechanism); old-CT
IDs above name the DUMP or extraction source, not a machine to
revive; node placement is picked at story-open with the guest
rotation in view (framework is re-entering it). The data
restoration intent of the acceptance criteria stands unchanged.
