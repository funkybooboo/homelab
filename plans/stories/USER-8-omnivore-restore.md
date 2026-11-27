# USER-8: omnivore

As the operator, I want my omnivore read-it-later archive back --
saved articles with their extracted content -- so that the reading
library survives the upstream shutdown.

**Status**: planned (operator-confirmed keep, 2026-11-23)
**Arc**: v3

## Acceptance criteria

- [ ] Manifest + role; omnivore pinned at its FINAL upstream
      release (the project is dead upstream -- no more releases,
      no security fixes; the pin is terminal)
- [ ] App data from the Nov-21 vzdump of old CT 134
- [ ] Database from the restored PGDATA, schema verified against
      the pinned version
- [ ] Operator logs in; a saved article renders; serve front live

## Notes

HONEST CAVEAT (operator accepted 2026-11-23): omnivore's upstream
shut down -- building it means running a frozen app forever, and
new saves may break as sites evolve. Linkwarden (USER-7) covers
overlapping ground and is alive upstream; the two are being
restored side by side per the operator's keep-everything directive
-- retiring omnivore later is a one-line manifest change (state:
absent) plus the dumps staying in the archive.

## Re-baseline (2026-11-28)

The body above was written against the old cluster. For the
current build: the deployment target is the CURRENT cluster via
a guest manifest + role (or container_guest where an official
digest-pinned image exists -- see USER-3's mechanism); old-CT
IDs above name the DUMP or extraction source, not a machine to
revive; node placement is picked at story-open with the guest
rotation in view (framework is re-entering it). The data
restoration intent of the acceptance criteria stands unchanged.
