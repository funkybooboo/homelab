# OPS-30: Repo text + structure

As the operator, I want every file in the repo to be about one
topic, current, and plainly written, so the repo is easy to follow
for a human.

**Status**: SHIPPED (four passes, as-built below)
**Arc**: era-independent hygiene

## Acceptance criteria

- [x] Each kind of content has one home; other files link to it
      (plans/README.md placement doctrine + writing rules;
      docs/quirks.md is the traps home)
- [x] The roadmap is forward-looking only; shipped records live in
      history.md
- [x] No file carries dated revision markers; git owns timing
- [x] docs/README.md indexes every doc once, grouped by reader
      intent
- [x] docs/quirks.md exists and is the single home for traps;
      code comments link to it instead of retelling incidents
- [x] The writing rules live in plans/README.md and the grep
      audit is clean (zero hedge words, zero caps-drama, zero
      dated comments outside history/issues)
- [x] make verify green after every pass; no behavior changes
      (one nuance found and fixed: comments inside managed-file
      bodies are content, so the last converge applied the
      cleaned comment text fleet-wide)

## As-built

- Pass 1: docs/ rewritten (index, quirks.md, backups, maintenance,
  data-to-extract, debugging, network, data, access, verify).
- Pass 2: roadmap forward-only; 34 revision markers folded; USER-2
  and OPS-9 slimmed with as-built moved to history.md; root
  README state block; writing rules added.
- Pass 3: 28 code files de-dated; host_vars became pure
  registries; scripts' headers de-journaled.
- Residuals: hedge words in unshipped stories + design records;
  the last dated asides in guests/, guests.yml, truenas.sh.

## Notes

Two operator decisions are recorded in the design record:
domain-standard vocabulary stays (tombstone); "deliberate" keeps
only its exception-marking uses. Design:
[../design/repo-text-structure.md](../design/repo-text-structure.md).
