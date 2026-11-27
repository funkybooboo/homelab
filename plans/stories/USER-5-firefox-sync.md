# USER-5: Firefox sync, from scratch

As a household member, I want self-hosted Firefox Sync (Mozilla's
syncstorage-rs), so that every Firefox instance in the household
syncs bookmarks, passwords, history, and tabs through our own
hardware instead of Mozilla's cloud.

**Status**: planned (operator directive 2026-11-28: build it from
scratch -- no legacy-data recovery; the old CT 131 payloads are
declared lost, browsers re-sync from a live client profile on
first pairing)
**Arc**: v3 (next-build after the framework re-homing move)
**Design context**: [../design/firefox-sync-server.md](../design/firefox-sync-server.md)
(architecture research -- tokenserver, MySQL choice, client prefs)
and [../design/browser-off-cloud.md](../design/browser-off-cloud.md)
(the full map this story is one cell of).

## Acceptance criteria

- [ ] syncstorage-rs deployed as a container_guest manifest on the
      current cluster (Mozilla image, digest-pinned; tokenserver
      enabled via env, per the design record)
- [ ] MySQL 8.0 in-guest (the design record's verdict: mysql is
      better-tested than postgres here; do NOT reuse the shared
      postgres for this schema)
- [ ] Client prefs deployed: every household browser's
      `identity.sync.tokenserver.uri` points at the serve front;
      desktop + mobile paired and syncing against our hardware
- [ ] Nightly mysqldump to /var/backups (in-guest) -- sync data is
      tier-1 (recreatable in principle, but passwords/bookmarks
      make loss expensive)
- [ ] The story closes with the browser-off-cloud map's
      "sync storage" cell checked and its follow-on cells named

## Notes

- FROM SCRATCH per operator: no B2 hunt for old CT 131 payloads,
  no restore window, no dump dependency. First pairing re-seeds
  from a client's local profile.
- The honest scope note (unchanged from the design record):
  self-hosting the sync STORAGE does not remove the Mozilla
  dependency from the auth path -- FxA still issues the OAuth
  tokens our tokenserver validates. The browser-off-cloud map
  records what remains cloud-touched after this ships.
- Node placement: framework is re-entering guest rotation
  (roadmap); this guest is a candidate for landing there -- the
  split is picked at migration time.
