# USER-15: Fizzy

As a household member, I want ONCE Fizzy -- Basecamp's
kanban-as-it-should-be -- running on-cluster, so that household
boards (projects, chores, plans) live on our hardware.

**Status**: planned (operator request 2026-11-23; one of the
ONCE trio with USER-14/USER-16)
**Arc**: v3

## Acceptance criteria

- [ ] Manifest + role; nested CT, docker compose, image pinned
      by digest (the USER-14 pattern note applies verbatim)
- [ ] Setup wizard completed by the operator; a board exists with
      a card moved across a column
- [ ] Serve front live (`fizzy.tail54538d.ts.net`); journals
      shipping

## Notes

Fizzy is the youngest of the trio (upstream still moving daily
as of 2026-11) -- the pin matters more here than for the other
two: pick a digest that upstream has actually shipped, not
`latest`. Same deliberate container-guest exception as USER-14;
same rejection of the `once` installer (it self-updates).
