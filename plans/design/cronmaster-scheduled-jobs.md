# Scheduled jobs: cronmaster is the scheduler

Operator directive: cronmaster is the fleet's scheduled-jobs
service. When cronmaster is up (OPS-24), every scheduled job
moves to it; systemd timers and cron-on-boxes are not the
fleet's scheduling model. Until cronmaster exists, jobs that
cannot wait use systemd timers as a temporary measure and carry
a port-to-cronmaster note.

## The first jobs (operator-named)

1. **migrate-github-to-codeberg** -- the operator's
   github.com/funkybooboo/migrate-github-to-codeberg: the
   codeberg leg becomes a cronmaster job. (Today the leg is
   forgejo native push mirrors on an 8h interval; the port
   replaces or supplements that mechanism -- the OPS-24 story
   decides which, with the no-data-loss rule applying.)
2. **sync-protonpass-to-bitwarden** -- the operator's
   github.com/funkybooboo/sync-protonpass-to-bitwarden: the
   Proton Pass -> vaultwarden sync, scheduled.
3. The observability textfile collectors (packages pending,
   reboot flags, tailscale key ages, library counts, watts/cost)
   -- planned as timers in the observability design; they become
   cronmaster jobs instead.

## Consequences for existing records

- OPS-24's scope changes: cronmaster is now a SERVICE the fleet
  runs (not just job dispositions), deployed as a manifest +
  role, with the old fleet's job list ported plus the jobs above.
- The observability design's "systemd timers" wording for
  collectors: read as "cronmaster jobs once cronmaster is live;
  timers only as a temporary measure."
- The security lens (quality-lenses.md): every job's secrets
  land in the pass vault (OPS-26 pattern); jobs run under the
  operator identity; job logs ship to loki like any service.

## Reliability lens

cronmaster becomes a dependency of the jobs it runs; its own
recovery is `onboot: true` + converge, and a dead cronmaster is
visible on the OPS-29 dashboards (the job-results panel). A
missed schedule degrades to "the job did not run," never to fleet
damage.
