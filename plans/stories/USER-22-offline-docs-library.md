# USER-22: The offline docs library

As the operator, I want a private reference library on the LAN, so
that the docs I code and learn against are always reachable and
mine.

**Status**: planned (operator: important)
**Arc**: v3 (personal-content family)

## Workflow

Look something up while coding (DevDocs, the Arch wiki, security
references) at a LAN URL that works even when the internet does
not.

## Acceptance criteria

- [ ] DevDocs-first (one image covers most languages + tools);
      Arch/Gentoo wikis + a security corpus as later additions
- [ ] Stored on truenas: re-fetchable, so no tier-0 backup
      (docs/data.md media class)
- [ ] Served via the tailnet front

## Lenses

- Visibility: nothing to watch beyond the front being up.
- Scalability: content size is bounded (tens of GB); growth is
  additive datasets.

Design: [../design/offline-docs-library.md](../design/offline-docs-library.md)
