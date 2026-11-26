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
- [ ] Old sync data (if wanted) recovered -- but see the 2026-11-23
      warning below; likely a FRESH START instead

## Notes

DATA WARNING (found in the 2026-11-23 old-fleet completeness audit,
operator directed a story be made for it): old CT 131 has NO vzdump
anywhere in pve-backups (absent while neighbors 132-134 have Nov-21
dumps) and it was never part of the pre-clean-out extraction -- the
syncstorage payloads are likely GONE. The one remaining hope is the
B2 archive (the old volume1 datasets were cloud-synced); CHECK B2
FIRST as the story's opening move, before promising any data
restore. If B2 holds nothing, the acceptance criterion above flips
to a plain "fresh start, zero legacy sync payloads" and Firefox
re-syncs from a client's local profile on first pairing.

Native integration, no browser extensions -- the only self-host option
that gives that. The caveat in the design record stands:
self-hosting does not eliminate the Mozilla dependency entirely.
See [../design/firefox-sync-server.md](../design/firefox-sync-server.md).

Operator directive 2026-11-23: wanted, but explicitly FUTURE --
queued behind the v3 keeps. Arc stays someday until then.
