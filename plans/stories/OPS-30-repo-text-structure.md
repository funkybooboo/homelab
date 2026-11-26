# OPS-30: Repo text + structure

As the operator, I want every file in the repo to be about one
topic, current, and plainly written, so the repo is easy to follow
for a human.

**Status**: planned (design:
[../design/repo-text-structure.md](../design/repo-text-structure.md))
**Arc**: era-independent hygiene (runs between v3 stories)

## Acceptance criteria

- [ ] Each kind of content has one home; other files link to it
- [ ] The roadmap is forward-looking only; shipped records live in
      history.md
- [ ] No file carries dated revision markers; git owns timing
- [ ] docs/README.md indexes every doc once, grouped by reader
      intent
- [ ] docs/quirks.md exists and is the single home for traps;
      code comments link to it instead of retelling incidents
- [ ] The writing rules live in plans/README.md and pass 4's grep
      audit is clean
- [ ] make verify green after every pass; no behavior changes

## Notes

Two naming decisions are open with the operator (see the design
record): tombstone vs absent manifest, and the scope of the word
deliberate.
