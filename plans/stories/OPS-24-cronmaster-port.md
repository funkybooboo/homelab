# OPS-24: cronmaster, from scratch

As the operator, I want cronmaster running as the fleet's
scheduled-jobs service with every scheduled job owned by it, so
that one place owns what happens on a schedule.

**Status**: planned (operator directive 2026-11-28: build it
from scratch on the current cluster, port the job list, no
legacy-system carry-over)
**Arc**: v3 (paired with USER-5 as the two from-scratch
next-builds; runs after it)
**Design context**:
[../design/cronmaster-scheduled-jobs.md](../design/cronmaster-scheduled-jobs.md)
(the service's research + the port note).

## Acceptance criteria

- [ ] cronmaster deployed as a container_guest manifest
      (digest-pinned image) with its database on the shared
      postgres (.14, the data.md policy) -- a fresh, empty
      jobs db; nothing restored from the old CT 127 vzdump
- [ ] The operator's repos land as its first jobs:
      [migrate-github-to-codeberg]
      (https://github.com/funkybooboo/migrate-github-to-codeberg)
      (the codeberg leg of the mirror chain) and
      [sync-protonpass-to-bitwarden]
      (https://github.com/funkybooboo/sync-protonpass-to-bitwarden)
      (the Proton Pass -> vaultwarden sync)
- [ ] Every scheduled job in the fleet is dispositioned into
      PORTED or RETIRED with reasons -- the old CT 127 job list,
      the debbie watcher, every temporary systemd timer created
      before cronmaster was live (including framework's
      nic-watchdog.timer, which stays node-local BY DESIGN: a
      self-heal probe must never depend on the network it
      guards), and any converge-side scheduled behavior
- [ ] Job results visible (dashboard panel or an ntfy failure
      topic); job secrets in the pass vault via the OPS-26
      pattern (no secrets in job definitions or manifests)

## Lenses

- Security: job secrets in the pass vault; jobs run under the
  operator identity; no secrets in job definitions.
- Visibility: job results on a dashboard; failures notify.
- Reliability: a dead cronmaster degrades to "jobs did not run"
  (onboot + converge recovery), never to fleet damage. Node-local
  self-heal probes (framework's watchdog) are explicitly exempt
  from the port -- they keep running where the failure hits.

## Notes

FROM SCRATCH per operator: the old deployment is not resurrected
(the Oct-17 CT 127 vzdump stays in the archive as reference for
the job LIST, not as a data source). The dispositioned port of
the job list is the story's real work -- cronmaster becomes THE
scheduler (standing doctrine), so every schedule in the fleet
either runs under it or has a recorded reason not to.
