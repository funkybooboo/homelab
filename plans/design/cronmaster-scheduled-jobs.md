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

## The fleet schedule disposition (OPS-24, surveyed 2026-11-27)

Every schedule found on the live fleet, dispositioned. The doctrine
holds: cronmaster is THE scheduler for app-layer jobs; everything
below carries a recorded reason to stay where it runs.

| Schedule | Where it runs | Disposition | Reason |
| --- | --- | --- | --- |
| migrate-github-to-codeberg, 23:00 | old CT 127 crontab | PORTED (final; operator 2026-11-28 after a brief retire) | its repoMigrate API auto-CREATES new github repos on codeberg, which push mirrors cannot do; the push mirrors stay for content freshness at 8h |
| sync-protonpass-to-bitwarden, 00:00 | old CT 127 crontab | PORTED | the story's job 2 (pass-cli session + bw CLI staged) |
| forgejo push mirrors -> codeberg, 8h | forgejo-native | STAYS | zero moving parts; job 1 covers the extras (issues, PR refs) |
| gitea-mirror nightly 22:00 | app-internal scheduler | STAYS | same class as freshrss CRON_MIN; an API hop adds failure modes, no gain |
| freshrss CRON_MIN 13,43 | in-container cron | STAYS | app-internal feed refresh |
| mysql-backup.timer 03:17 | CT 107 systemd | STAYS | a guest's own backup must not depend on another guest being up |
| nic-watchdog.timer, 1 min | framework node | STAYS | story-mandated: self-heal never depends on the network it guards |
| nfs-check.timer, 5 min | thermaltake node | STAYS | same self-heal class (media NFS mount) |
| homelab-watch + nas-sync x5 | debbie user timers | STAYS | laptop-local data sources; the CT cannot see a sleeping laptop's folders |
| vzdump / B2 cloud-sync / scrubs | PVE + truenas internal | STAYS | platform-owned backup machinery, one place per platform |
| debian stock timers (apt, logrotate, node-exporter) | every box | STAYS | OS hygiene, not fleet jobs |
| observability textfile collectors | planned, not built | WILL BE cronmaster jobs | the design already routes them here |
