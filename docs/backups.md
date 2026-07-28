# Backups & DR

What's backed up, how, where it goes, and the single-box risk that still
needs an off-box target.

## vzdump (PVE guest backups)

A single cluster-wide `vzdump` job: weekly Saturday 21:00, all guests,
storage `pve-backups` (the TrueNAS NFS export). Snapshot mode with suspend
fallback, zstd compression, prune `keep-last=4 keep-monthly=3`.

```sh
# jobs.cfg has backup-6b4b8255-4743 -- verify on any node:
pvesh get /cluster/backup-info
# staging dir on every node (fast local tmp, not over NFS):
#   /etc/vzdump.conf has tmpdir=/var/tmp/vzdump   (755 perms)
```

A sample CT (101) backed up in ~4s producing a ~98M artifact, so the whole
set completes in well under an hour.

## Snapshots (TrueNAS)

Four periodic snapshot tasks, daily 00:00, `lifetime_value=2 lifetime_unit=WEEK`
auto-pruned:

- `volume1/pve/shared` -- live container disks
- `volume1/pve/backups` -- vzdump artifacts
- `volume1/home/nate`
- `volume1/media`

Caveat: snapshots of `pve/shared` capture live `*.raw` mid-write, so they are
**crash-consistent, not app-consistent**. Acceptable for a homelab; not a
substitute for proper quiesced backups.

## Off-box replication (the DR hole)

TrueNAS currently holds **both** the live container disks (`pve-shared`) **and**
the vzdump backups (`pve-backups`) on the same pool. If that box/pool dies, you
lose live + backups + snapshots together. vzdump-to-truenas is only useful for
guest-migration + config-botched rollback, **not real disaster recovery**.

The actual off-box attempt today is the TrueNAS **cloud sync** task:

- `Backblaze B2 - /mnt/volume1/home//media//pve` -> bucket
  `funkybooboo-truenas-backup`, SYNC/PUSH, schedule weekly Sunday 00:00.
- Credentials: TrueNAS credential id=1 (`Backblaze B2`).

### Known cloud-sync problems (being fixed in waves)

1. **B2 storage cap exceeded** (job 818 failure). The B2 application key used
   has a cap; once it's hit, the `403 storage_cap_exceeded` aborts the run.
   Fix: exclude the live `pve/shared/images/**/*.raw` disks from the sync
   (they are crash-inconsistent when re-read mid-write anyway, AND they're
   the bulk of the bytes), and/or raise the B2 key's cap. DO NOT sync live
   `.raw` images -- direct-publish the vzdump `*.vma.zst` artifacts instead
   (already app-consistent snapshots from the vzdump job).
2. **No alerting when the cloud-sync fails.** Previously there was no working
   alertservice (the Mail one had an empty recipient + no SMTP server). Now
   wired: TrueNAS `alertservice id=3` type=Slack -> ntfy bridge -> phone push
   for any alert >= WARNING. See `docs/notifications.md`.

### Better DR options (not yet done)

- Nightly `restic` or `borg` of `pve-backups` (the vzdump `.vma.zst` files)
  to `middlechild` or a second drive on different hardware.
- A second PVE storage target on different physical hardware so a TrueNAS
  failure doesn't take the cluster down.
- Keep the cloud-sync as the *truly* off-site copy, but only for the vzdump
  artifacts + user data, NOT the live disks.

## Notifications

Backup failures now (post Jul-2026) push to the ntfy topic -- see
[`notifications.md`](./notifications.md). vzdump notify is still
mail-to-root locally (silent unless postfix relays); PVE notification
endpoint (gotify/SMTP) is a follow-up. The cloud sync job failure will
fire the TrueNAS `>= WARNING` alert per the alertservice in
[`notifications.md`](./notifications.md).