# USER-5: Firefox sync

As a household member, I want self-hosted Firefox Sync (Mozilla's
syncstorage-rs), so that every Firefox instance in the household syncs
bookmarks, passwords, history, and tabs through our own hardware
instead of Mozilla's cloud.

**Status**: someday
**Arc**: unqueued (design written for the old cluster)

## Acceptance criteria

- [ ] syncstorage-rs CT deployed from a guest manifest; tokenserver
      config per the design record
- [ ] A desktop + a mobile Firefox paired and syncing against it
- [ ] Old sync data (if wanted) recovered from the legacy CT 131
      extraction

## Notes

Native integration, no browser extensions -- the only self-host option
that gives that. The honest caveat in the design record stands:
self-hosting does not eliminate the Mozilla dependency entirely.
See [../design/firefox-sync-server.md](../design/firefox-sync-server.md).
