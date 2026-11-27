# USER-21: Immich -- the photo library

As a household member, I want my phone's photos and videos backed
up to my own library, so that the camera roll is preserved,
searchable, and mine.

**Status**: planned
**Arc**: v3 (personal-content family; pairs with the media fleet)

## Workflow

The phone app uploads on wifi; photos land on truenas storage and
appear in the web library (search by face/place/thing). Replaces
Proton Drive's photo backup with a self-hosted library.

## Acceptance criteria

- [ ] Manifest + role; storage on truenas (the media family's
      pattern); phone app enrolled and uploading
- [ ] The Proton Drive photos export imported
- [ ] Library visible via the tailnet front; growth visible on the
      storage dashboard (OPS-29c)

## Lenses

- Security: photos are private data -- tailnet-only front; storage
  dataset rides the B2 snapshot tasks.
- Reliability: uploads tolerate offline intervals (phone-side
  retry); the library survives a guest rebuild (data on NFS,
  metadata backed per docs/data.md media class).
