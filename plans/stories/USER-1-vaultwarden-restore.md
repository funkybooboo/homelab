# USER-1: Vaultwarden restore

As a household member, I want vaultwarden back with the old data
restored, so that the passwords are available again.

**Status**: done -- operator unlock check pending
**Arc**: v2

## Acceptance criteria

- [x] vaultwarden deployed from a guest manifest
- [x] Database restored from the v0 legacy extraction FIRST (it is the
      passwords) -- before the old rootfs is touched by anything
- [x] HTTPS access per the issues item 4 decision; unlock + one known
      credential verified from a phone + a laptop (DONE 2026-11-23, operator)

## As-built (2026-11-23)

- CT 201 on pve-thermaltake at 192.168.1.51, rootfs on LOCAL-LVM
  (tier-0: no truenas dependency; lvmthin cannot host vztmpl so the
  manifest carries an explicit ostemplate override from pve-shared)
- Build-from-source: upstream ships NO prebuilt binaries (0 assets on
  the last 10 releases); role pins vaultwarden 1.37.5 + rust 1.97.1
  (MSRV 1.97+; trixie's 1.85 rustc cannot) via rustup, --features
  sqlite, --locked. Build ~9 min on 2 cores; version-gated by a
  marker file so converges skip it
- WEB VAULT IS NOT EMBEDDED (the "since 1.29" lore is wrong): the
  vault client is a separate pinned artifact from
  dani-garcia/bw_web_builds (v2026.10.1) -- the missing-vault crash
  cost one iteration to discover
- Restore: db.sqlite3 + rsa_key.pem from the controller-side
  extraction (legacy-extraction/, gitignored), copy-only-while-absent
  + loud assert if the source is missing; WAL was 0 bytes so the
  single file IS the database. Post-boot: integrity ok, 1 user,
  664 ciphers, 0 orgs -- exact legacy counts
- Locked down: SIGNUPS_ALLOWED=false, admin panel disabled (empty
  ADMIN_TOKEN), systemd hardening (ProtectSystem=strict +
  ReadWritePaths, NoNewPrivileges, PrivateTmp), 0600 db
- Observable from birth: promtail journal -> loki, front watched by
  the watcher (manifest-driven), LAN fallback http://192.168.1.51:8222
  survives tailnet outages; front https://vaultwarden.tail54538d.ts.net

Build fresh and restore: vaultwarden deployed from a guest
manifest, db.sqlite3 restored from the extraction
(legacy-extraction/from-dump-109/opt/vaultwarden/data/db.sqlite3 on
debbie; systemd unit + /opt/vaultwarden layout recorded there),
HTTPS via the tailnet serve-front model (issues item 4a). Dumps on
pve-backups + B2 remain the deeper fallback.
