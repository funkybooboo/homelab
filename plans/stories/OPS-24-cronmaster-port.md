# OPS-24: cronmaster job port

As the operator, I want the jobs the old cronmaster ran either
ported into the new fleet's model or consciously retired -- so
that nothing the old fleet did on a schedule silently stops
happening.

**Status**: planned (operator-confirmed keep, 2026-11-23)
**Arc**: v3

## Acceptance criteria

- [ ] Jobs db + `.env` extracted from the Oct-17 vzdump of old
      CT 127 (`/opt/cronmaster/`; the env's INTERNAL_API_URL
      points at the OLD fleet -- it needs rewriting either way)
- [ ] Every job in the db listed with a disposition: PORTED (to
      a systemd timer, an ansible cron role, or the watcher) or
      RETIRED (with the one-line reason)
- [ ] Zero jobs left undispositioned; the disposition list lives
      in this story

## Notes

The new fleet ALREADY has a scheduler layer (the debbie watcher
timer + guest systemd timers), so cronmaster-the-software is
likely superseded -- this story is about the JOB CONTENTS, not
the tool. Do not rebuild cronmaster unless a job genuinely needs
its web-ui/API shape; a ported job is a unit file + a log line,
and it inherits observability for free.
