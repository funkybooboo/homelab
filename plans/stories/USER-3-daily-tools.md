# USER-3: Daily tools

As a household member, I want the daily-driver tools back -- freshrss,
searxng, linkwarden, n8n, and whatever else survives curation -- so that
everyday workflows return.

**Status**: planned
**Arc**: v3 (scope: [../issues.md](../issues.md) item 6)

## Acceptance criteria

- [ ] Curated list decided from the old ~28 (lean: ~12-15 total
      resurrected; the rest stay archived + documented in
      `docs/legacy/`)
- [ ] Each service: manifest + role, data extracted from old rootfs,
      verified, THEN old rootfs archived
- [ ] Postgres-backed services (linkwarden, omnivore if kept) point at
      OPS-10's instance

## Notes

The deliberately-not-resurrected get a one-line reason each in
`docs/legacy/` -- "unused", "superseded by X", or "resurrect on
demand"; that list is what makes lazy resurrection cheap later.
