# USER-18: host the books

As the operator, I want my book collection (Crafting Interpreters,
Game Programming Patterns, Nine Algorithms..., papers/) served from
the homelab so I can read anywhere and the PDFs stop living only
on my laptop.

**Status**: planned (idea recorded 2026-11-25)
**Corpus**: ~/Books (a handful of purchased/reference PDFs +
papers/)
**Arc**: v3 (personal-content family)

## The operator's instinct + honest options

The idea on the table: **omnivore** (USER-8). Omnivore can ingest
PDFs, but it is read-it-later shaped -- article flow, highlights,
ephemeral library -- and its upstream is dead (the restore carries
a frozen pin). A personal BOOK library wants library things:
covers, metadata, reading position, collections, maybe OPDS.

Options, recorded for the build-time decision:

1. **calibre-web** -- the library-shaped answer: calibre metadata
   engine, web reader, OPDS feed (any reader app on the phone can
   subscribe), collections and covers. The classic for exactly
   this corpus.
2. **kavita** -- reading-server shaped (comics/manga/books),
   slicker reader, no calibre baggage.
3. **omnivore** -- the operator's instinct; only if the books
   should live in the same flow as saved articles.

Adjacent but distinct: plans/design/offline-docs-library.md is the
PUBLIC reference corpus (re-fetchable, no backup needed); these
books are the PERSONAL corpus (purchased, tier-0: back them up).

## Acceptance criteria

- [ ] Books live on the fleet, readable from any operator device
- [ ] Backup path verified (purchased PDFs are tier-0)
- [ ] OPDS or equivalent so a phone reader app works, if the
      chosen service supports it
