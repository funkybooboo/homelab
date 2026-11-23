# USER-13: speedtest-tracker

As the operator, I want the speedtest history back -- the
running record of LAN/ISP performance over time -- so that the
measurement series continues unbroken.

**Status**: planned (operator-confirmed keep, 2026-11-23)
**Arc**: v3

## Acceptance criteria

- [ ] App state from the Nov-21 vzdump of old CT 103
      (`/opt/speedtest-tracker/` + `.env`)
- [ ] Manifest + role; laravel app pinned
- [ ] Database restored (sqlite in the app dir, or its schema in
      the old PGDATA -- prove which at extract time)
- [ ] A new test result lands; the old history charts; serve
      front live

## Notes

Small and self-contained; scheduled tests run from the guest on
the same cadence the old one did. The chart's value IS the
history -- restore the db before the first test runs so the
series stays continuous.
