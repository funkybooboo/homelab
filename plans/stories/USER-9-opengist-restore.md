# USER-9: opengist

As the operator, I want my opengist instance back -- the gist
collection with their revisions -- so that my snippet archive keeps
living on-cluster.

**Status**: planned (operator-confirmed keep, 2026-11-23)
**Arc**: v3

## Acceptance criteria

- [ ] Manifest + role; opengist pinned (single Go binary, sqlite
      by default)
- [ ] `/var/lib/opengist/` from the Nov-21 vzdump of old CT 113,
      restored only-while-absent (the established pattern)
- [ ] Operator logs in; an old gist renders with history; serve
      front live

## Notes

Self-contained and cheap: one binary + one data dir + sqlite --
the vaultwarden shape, no postgres dependency. Reads live over
https on the tailnet front.

## Re-baseline (2026-11-28)

The body above was written against the old cluster. For the
current build: the deployment target is the CURRENT cluster via
a guest manifest + role (or container_guest where an official
digest-pinned image exists -- see USER-3's mechanism); old-CT
IDs above name the DUMP or extraction source, not a machine to
revive; node placement is picked at story-open with the guest
rotation in view (framework is re-entering it). The data
restoration intent of the acceptance criteria stands unchanged.
