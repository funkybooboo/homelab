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

REVISED 2026-11-21 (revival): everything revives first, so this story
becomes the CURATION PASS -- decide the stop-list (issues item 6,
~12-15 keepers), stop + disable the rest, document each one-liner.

REVISED 2026-11-22 (plan shift final form): the fleet was cleaned out
(OPS-20), so curation = the BUILD LIST: decide which services get
manifests at all (~12-15 keepers, issues item 6); the legacy archive
(dumps + docs/) keeps lazy resurrection cheap for anything left off.

RESTORE NOTE 2026-11-23: the old fleet's assets (services/) were
   deleted from the tree per the git-history principle. When the
   freshrss story lands, pull the operator's feed list from history:
   `git log --oneline -- services/freshrss/feeds.opml` then
   `git show <commit>:services/freshrss/feeds.opml`.
