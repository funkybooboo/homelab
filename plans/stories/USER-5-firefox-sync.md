# USER-5: Firefox sync, from scratch

As a household member, I want self-hosted Firefox Sync (Mozilla's
syncstorage-rs), so that every Firefox instance in the household
syncs bookmarks, passwords, history, and tabs through our own
hardware instead of Mozilla's cloud.

**Status**: SHIPPED + PAIRED 2026-11-28 (built from scratch per
operator directive -- no legacy-data recovery; the old CT 131
payloads declared lost, browsers re-seed from a live client
profile on first pairing). END-TO-END VERIFIED: the operator's
LibreWolf paired via the dotfiles user.js channel (000326) and
the first sync landed 4501 client-encrypted records / 2.1 MB in
mysql CT 107's syncstorage.bso -- bookmarks, history, forms,
logins, tabs. Pairing scope recorded: the operator's laptop
(per operator -- the household reality); any future browser
joins by the same tracked user.js line. The pairing arc's
three server bugs are in quirks.md (placeholder FxA validation
creds, run_migrations off, the unseeded services/nodes rows).
**Arc**: v3 (next-build after the framework re-homing move)
**Design context**: [../design/firefox-sync-server.md](../design/firefox-sync-server.md)
(architecture research -- tokenserver, MySQL choice, client prefs)
and [../design/browser-off-cloud.md](../design/browser-off-cloud.md)
(the full map this story is one cell of).

## Acceptance criteria

- [ ] syncstorage-rs deployed as a container_guest manifest on the
      current cluster (Mozilla image, digest-pinned; tokenserver
      enabled via env, per the design record)
- [ ] MySQL 8.0 as the shared mysql guest CT 107 (decision #20:
      postgres impossible upstream -- no postgres backend; in-guest
      also rejected by the operator, other services reuse this
      guest; mysql:8.0.46 digest-pinned, LAN-listen like postgres,
      nightly --all-databases dump to /var/backups/mysql)
- [x] Client prefs deployed: the operator's LibreWolf
      `identity.sync.tokenserver.uri` points at the serve front
      via the tracked dotfiles user.js (declarative, every
      launch); paired + first sync verified 2026-11-28. Pairing
      scope = the operator's laptop (per operator); household /
      mobile browsers join by the same user.js line when they
      exist
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
- REBASED 2026-11-28 (decision #20): mysql moved out of the sync
  guest into the shared mysql CT 107 (.20) per the operator
  directive; the sync guest (CT 216, framework, pve-shared --
  stateless app, migratable) points its DATABASE_URLs across the
  LAN. Verified from the registry, not recall: image entrypoint
  /app/bin/syncserver, build args SYNCSTORAGE_DATABASE_BACKEND=
  mysql TOKENSERVER_DATABASE_BACKEND=mysql (bundled tokenserver,
  mysql-flavored); there is NO :latest tag -- tags are commit+
  timestamp, the manifest pins the 2026-02-04 build's amd64 digest.
