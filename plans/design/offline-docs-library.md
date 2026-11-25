# Offline docs library (operator design, 2026-11-25)

**Status**: design recorded -- someday era, not queued
**Why**: a private, self-hosted reference library in the homelab,
reachable only by the operator.

## The operator's executive summary (as supplied)

The stack, in three layers:

1. Ingest -- official artifacts only, never live scraping at volume.
2. Store -- read-only volume, per-corpus, on cheap SSD.
3. Serve -- Caddy file_server behind Tailscale, with Authelia in
   front if it ever leaves the tailnet.

What to host, in priority order:

- DevDocs container -- one image, ~500 docsets, covers nearly every
  language and framework. Do this first and skip most of the rest.
- Arch Wiki via the official arch-wiki-docs package (170 MiB,
  monthly refresh). Gentoo Wiki via WikiTeam dumps. Both sanctioned.
- Security corpus -- NVD JSON feeds, OSV bulk export, ATT&CK STIX,
  OWASP, GTFOBins, SecLists. Highest offline value, lowest
  searchability elsewhere.
- Officially downloadable references -- Python, PostgreSQL, SQLite,
  cppreference, kernel htmldocs, POSIX. All first-party.
- RFCs, standards drafts, free books -- bulk fetch, no mirroring.

Build order: DevDocs, then Arch/Gentoo mirrors, then the security
corpus, then anything with a Sphinx or Antora tree via one generic
CI job. Automate every refresh from a systemd timer, keep two
generations, prune the third.

Search: Pagefind for static output, Meilisearch for the rest,
ripgrep as the fallback. An unsearchable library is a directory
listing.

Non-negotiables: keep GFDL/CC BY-SA attribution (Arch and Gentoo
require it); kiwix-serve has no auth (bind localhost, proxy it);
re-importing wikis into own MediaWiki breaks on templates and Lua
(prefer HTML or ZIM); budget ~100 GiB; exclude the security volume
from nightly backups.

Skip: paywalled standards, vendor docs for gear not owned,
Windows/macOS internals.

Effort: an evening for DevDocs + the two wikis; a weekend for the
security corpus and search. Ongoing cost is a cron job and an
occasional disk prune.

## Review notes (agent, same day)

- Fits the fleet pattern cleanly: one guest (manifest + role), the
  corpus volumes read-only, refresh via systemd timer, front via
  tailscale serve like every other guest. The Caddy/Authelia layers
  are unnecessary while serve-fronts carry TLS + the tailnet's own
  auth -- serve alone IS the access model (model B, issues 4).
- Storage home: truenas dataset (not node-local) -- this corpus is
  re-fetchable, so it needs neither tier-0 placement nor backup.
- DevDocs-first is the right call; it obsoletes most per-project
  doc hosting in one move.
- The refresh job belongs in the OPS-23 world: a systemd timer +
  `make update` awareness, two-generation retention, no
  auto-reboot nonsense.

## Queued as

Someday (demand recorded) -- a LEARN-adjacent service; build when
the operator asks for it.
