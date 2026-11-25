# OPS-27: mise as the fleet loop front door

As the operator, I want the fleet loop (converge / update / verify)
driven by mise tasks instead of a Makefile, so the homelab repo
matches the tooling convention I already use everywhere else
(dotfiles, 8bit-computer: one mise.toml, self-documenting tasks,
`mise run <name>`).

**Status**: planned (recorded 2026-11-25, operator request)
**Arc**: v4 automation polish (small, mechanical; pull forward to
v3 freely if the operator wants it sooner -- nothing depends on
the era)

## The port

| make | mise task | what it does |
| --- | --- | --- |
| help | `mise tasks` (built-in) | mise lists tasks + descriptions from mise.toml |
| deps | deps | ansible-galaxy collection install |
| converge | converge | the idempotent fleet pass |
| update | update | the tier-gated patch pass |
| verify | verify | read-only drift check |

The env-sourcing preamble (export every `local/*.env`) becomes
each task's shell prologue -- identical semantics, one place per
task instead of Makefile prefix duplication.

## Honest notes

- **The mechanical port is trivial (an hour); the DOC SWEEP is
  the real work.** `make converge` is referenced across docs/
  (maintenance, verify, access), README.md, scripts/ headers, and
  the stories -- every call site flips to `mise run converge`, or
  a compatibility Makefile shim stays behind temporarily. Do the
  sweep in the same commit or the docs lie.
- **mise can also pin ansible** ([tools] in mise.toml) -- the
  repo's ansible version becomes declared, reproducible on a
  fresh machine (pairs with OPS-26's restore story: setup.sh
  installs mise tooling already).
- The Makefile is deleted, not kept alongside -- one front door,
  the same principle the 8bit-computer port applied.

## Acceptance criteria

- [ ] mise.toml carries converge/update/verify/deps with honest
      descriptions (what it does + why, the repo's style)
- [ ] `mise run verify` green against the live fleet
- [ ] ansible version pinned in mise.toml [tools]
- [ ] No `make` references left in docs/ scripts/ README (grep is
      the acceptance test)
- [ ] Makefile deleted
