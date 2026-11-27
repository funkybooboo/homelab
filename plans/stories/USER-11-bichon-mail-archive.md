# USER-11: bichon mail archive

As the operator, I want my bichon mail archive back -- the whole
point of bichon: a searchable, on-cluster archive of my mail --
so that the archive keeps accumulating.

**Status**: planned (operator-confirmed keep, 2026-11-23)
**Arc**: v3

## Acceptance criteria

- [ ] `/var/lib/bichon/` extracted from the Nov-21 vzdump of old
      CT 125 (path "to locate" per the old inventory -- prove it
      at extract time; check the archive SIZE before pulling)
- [ ] Manifest + role; bichon running with the archive restored
      only-while-absent
- [ ] Operator searches an old thread; serve front live

## Notes

Pairs with USER-12 (protonmail-bridge): if the old bichon pulled
mail via the bridge's IMAP endpoint, the two stories land
together -- the bridge supplies the account, bichon keeps the
letters. The Nov-21 dump likely holds both halves.

## Re-baseline (2026-11-28)

The body above was written against the old cluster. For the
current build: the deployment target is the CURRENT cluster via
a guest manifest + role (or container_guest where an official
digest-pinned image exists -- see USER-3's mechanism); old-CT
IDs above name the DUMP or extraction source, not a machine to
revive; node placement is picked at story-open with the guest
rotation in view (framework is re-entering it). The data
restoration intent of the acceptance criteria stands unchanged.
