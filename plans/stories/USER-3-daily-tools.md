# USER-3: Daily tools

As a household member, I want the daily-driver tools back -- freshrss,
searxng, linkwarden, n8n, and whatever else survives curation -- so that
everyday workflows return.

**Status**: planned
**Arc**: v3 (scope: [../issues.md](../issues.md) item 6)

## Acceptance criteria

- [ ] Curated list decided from the old ~28 (lean: ~12-15 total
      resurrected; the rest stay stopped + documented in the
      curation list)
- [ ] Each service: manifest + role, data extracted from old rootfs,
      verified, THEN old rootfs archived
- [ ] Postgres-backed services (linkwarden, omnivore if kept) point at
      OPS-10's instance

## Notes

The deliberately-not-resurrected get a one-line reason each in
one-liner each -- "unused", "superseded by X", or "resurrect on
demand"; that list is what makes lazy resurrection cheap later.

Curation is the build list: decide which services get manifests at
all (~12-15 keepers, issues item 6); the dump archive
([../docs/data-to-extract.md](../docs/data-to-extract.md)) keeps
lazy resurrection cheap for anything left off. The old-fleet keeps
(n8n, linkwarden, omnivore, opengist, jupyter, bichon,
protonmail-bridge, speedtest, cronmaster) each have their own story
now (USER-6 through USER-13 + OPS-24); this story keeps the tier-3
browser tools (it-tools, searxng, excalidraw, drawio) and the
curation decision itself.

The old fleet's assets (services/) live in git history. When the
freshrss story lands, pull the operator's feed list from there:
`git log --oneline -- services/freshrss/feeds.opml` then
`git show <commit>:services/freshrss/feeds.opml`.
