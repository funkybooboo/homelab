# OPS-24: cronmaster -- the fleet's scheduled-jobs service

As the operator, I want cronmaster running as the fleet's
scheduled-jobs service with every scheduled job ported to it, so
that one place owns what happens on a schedule.

**Status**: planned (operator directive: cronmaster IS the
scheduler -- see
[../design/cronmaster-scheduled-jobs.md](../design/cronmaster-scheduled-jobs.md))
**Arc**: v3 (after the keeps that restore its data)

## Acceptance criteria

- [ ] Jobs db + `.env` extracted from the Oct-17 vzdump of old
      CT 127 (`/opt/cronmaster/`); INTERNAL_API_URL rewritten for
      the new fleet
- [ ] cronmaster deployed as a manifest + role on the shared
      postgres (data.md policy)
- [ ] The operator's repos land as its first new jobs:
      [migrate-github-to-codeberg]
      (https://github.com/funkybooboo/migrate-github-to-codeberg)
      (the codeberg leg) and
      [sync-protonpass-to-bitwarden]
      (https://github.com/funkybooboo/sync-protonpass-to-bitwarden)
      (the Proton Pass -> vaultwarden sync)
- [ ] Every scheduled job in the fleet runs under cronmaster:
      the old CT 127 job list dispositioned (PORTED or RETIRED
      with reasons), the debbie watcher, and any temporary
      systemd timers created before cronmaster was live
- [ ] Job results visible (a dashboard panel or an ntfy failure
      topic); job secrets in the pass vault (OPS-26 pattern)

## Lenses

- Security: job secrets in the pass vault; jobs run under the
  operator identity; no secrets in job definitions.
- Visibility: job results on a dashboard; failures notify.
- Reliability: a dead cronmaster degrades to "jobs did not run"
  (onboot + converge recovery), never to fleet damage.
