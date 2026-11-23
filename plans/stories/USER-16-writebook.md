# USER-16: Writebook

As a household member, I want ONCE Writebook -- instantly
publish books on the web -- running on-cluster, so that
long-form writing gets a durable home that is ours.

**Status**: planned (operator request 2026-11-23; one of the
ONCE trio with USER-14/USER-15)
**Arc**: v3

## Acceptance criteria

- [ ] Manifest + role; nested CT, docker compose, image pinned
      by digest (the USER-14 pattern note applies verbatim)
- [ ] Setup wizard completed by the operator; a book created
      with a chapter that renders
- [ ] Serve front live (`writebook.tail54538d.ts.net`); journals
      shipping

## Notes

The lightest of the trio (single-purpose app, small state);
this is the one guest where disk can stay minimal -- the books
are small text + a few images. Same container-guest exception,
same no-`once`-installer rule, same digest pinning.
