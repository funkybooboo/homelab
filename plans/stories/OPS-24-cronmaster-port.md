# OPS-24: cronmaster, from scratch

As the operator, I want cronmaster running as the fleet's
scheduled-jobs service with every scheduled job owned by it, so
that one place owns what happens on a schedule.

**Status**: in progress (operator directive 2026-11-28: build it
from scratch on the current cluster, port the job list, no
legacy-system carry-over). FACT CORRECTION discovered during the
build: cronmaster is the public fccview/cronmaster app, and it is
CRONTAB-based, not database-backed -- the old story wording "jobs
db on the shared postgres" predates verifying the app and is
unmeetable as written. Re-scoped criterion below. The old CT 127
vzdump proved richer than planned: it holds the app source (the
deployment was a bare systemd node run, not docker), the root
crontab with BOTH ported jobs (the real job list -- two jobs,
not a db), the job repos with their live .env creds, and the
proton pass-cli session -- all extracted to
legacy-extraction/from-dump-127 and staged by the role.
**Arc**: v3 (paired with USER-5 as the two from-scratch
next-builds; runs after it)
**Design context**:
[../design/cronmaster-scheduled-jobs.md](../design/cronmaster-scheduled-jobs.md)
(the service's research + the port note).

## Acceptance criteria

- [ ] cronmaster deployed as a manifest + role on a dedicated CT
      (digest-pinned public image, nsenter-controller shape:
      privileged + pid: host inside the CT, no docker socket --
      HOST_CRONTAB_USER pinned). The app is crontab-based: job
      definitions are SEEDED declaratively (marker-gated, the
      app's own comment format + the old job ids) and the app's
      UI owns edits after the seed. App state (scripts, data,
      snippets) + the job repos live on the CT's pve-shared
      rootfs. No database exists to put on postgres -- the
      criterion's original wording predates this fact.
- [ ] The operator's repos land as its jobs (BOTH -- the
      operator briefly retired the first, then restored it
      2026-11-28: its repoMigrate API auto-creates NEW github
      repos on codeberg, which push mirrors cannot do):
      [migrate-github-to-codeberg]
      (https://github.com/funkybooboo/migrate-github-to-codeberg)
      (the codeberg leg's discovery/creation layer) and
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
