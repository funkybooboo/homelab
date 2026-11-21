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

REVISED 2026-11-21 (revival): vaultwarden comes back ALIVE with the
fleet on revival night (OPS-18). This story becomes: verify alive
(unlock + one known credential from phone + laptop) + the tier-0
backup extraction runs as insurance, not as a dependency.
