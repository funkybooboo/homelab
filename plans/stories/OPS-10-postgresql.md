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

Old CT 108 held it; check `docs/legacy/` (OPS-1) for the database and
role inventory before creating anything by hand.
