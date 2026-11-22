# USER-1: Vaultwarden restore

As a household member, I want vaultwarden back with the old data
restored, so that the passwords are available again.

**Status**: planned
**Arc**: v2

## Acceptance criteria

- [ ] vaultwarden deployed from a guest manifest
- [ ] Database restored from the v0 legacy extraction FIRST (it is the
      passwords) -- before the old rootfs is touched by anything
- [ ] HTTPS access per the issues item 4 decision; unlock + one known
      credential verified from a phone + a laptop

## Notes

Priority order within v2: this story is why the core batch exists.
Nothing wipes old CT rootfs until this and every later data extraction
completes (rule 10).

REVISED 2026-11-22 (plan shift final form): the old CT was cleaned
out (OPS-20), so this story is BUILD-FRESH + RESTORE: vaultwarden
deployed from a guest manifest (OPS-7 skeleton), db.sqlite3 restored
from the extraction
(legacy-extraction/from-dump-109/opt/vaultwarden/data/db.sqlite3 on
debbie; systemd unit + /opt/vaultwarden layout recorded there),
HTTPS via the tailnet serve-front model (issues item 4a). Dumps on
pve-backups + B2 remain the deeper fallback.
