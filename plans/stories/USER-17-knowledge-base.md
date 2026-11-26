# USER-17: host the knowledge base

As the operator, I want my knowledge base (Daily/, Notes/, Personal/,
School/ + loose md like regex.md, numerical_bases.md) served to me
from the homelab so it is reachable from any device and backed up
with the fleet instead of living only on my laptop.

**Status**: planned (idea recorded 2026-11-25)
**Corpus**: ~/Documents/knowlege_base (~markdown, organized in dirs)
**Arc**: v3 (personal-content family)

## The operator's instinct + the options

The idea on the table: **writebook** (the ONCE trio, USER-16).
Writebook is book-shaped -- writing and PUBLISHING volumes with
structure and polish. A living knowledge base is notes-shaped:
edited often, browsed by topic, never "finished". The fit is
workable (organize each topic as a book) but it fights the tool.

Options, recorded for the build-time decision:

1. **forgejo + mdbook (the fleet-native answer)** -- the corpus is
   already markdown; the hub already hosts it; a small job renders
   mdbook static HTML served over tailscale serve. Zero new
   services, git history for free, private by default. Search is
   mdbook's built-in.
2. **writebook** -- the operator's instinct; best if the base
   should become curated, polished volumes over time.
3. **linkwarden** (USER-7, already restoring) -- if the base is
   mostly link-annotated research rather than original writing.

Whatever serves it, the corpus moves under the fleet's backup
umbrella (truenas tier-0 -- this one is NOT re-fetchable).

## Acceptance criteria

- [ ] Corpus lives on the fleet (NFS mount or git repo), not the
      laptop
- [ ] Readable from any operator device via the tailnet
- [ ] Backup path verified (this corpus is tier-0: original
      writing, unrecoverable)
- [ ] A write-from-phone story exists or is declined
