# pve-shared-nfs-remount -- automatic NFS storage recovery on every PVE node

When the TrueNAS NFS export at `192.168.8.100` flaps (network blip,
TrueNAS reboot, IP change -- see [`services/network/`](../network/)),
`pvesm status` on every PVE node flips `pve-shared` to `inactive`.
CTs that were running keep their cached pages; CTs that try to start
afterwards fail. HA services fall into `error` state (see
[`docs/ha-recovery.md`](../../docs/ha-recovery.md)).

This deployment watches the storage and remounts `pve-shared` +
`pve-backups` automatically -- restoring the system to a state where
`pct start` just works, no human needed.

## Files in this directory

| file | what
| --- | ---
| `pve-shared-remount.sh`     | The check/remount script; safe to run from cron.
| `pve-shared-remount.cron`   | `/etc/cron.d` entry (every 2 min).

## Deploy (idempotent; one node at a time, on each of the 5 x86/arm PVE nodes)

```sh
install -m 755 -o root -g root pve-shared-remount.sh /usr/local/sbin/pve-shared-remount.sh
install -m 644 -o root -g root pve-shared-remount.cron /etc/cron.d/pve-shared-remount
systemctl reload cron 2>/dev/null || service cron reload
```

## What it does (script logic)

1. `pvesm status` shows `pve-shared` (and `pve-backups`).
2. If the row says `active` -- exit 0, no-op.
3. Else -- the NFS mount is stale or gone. Re-mount:
   `mount -t nfs -o soft,timeo=5,retrans=2 192.168.8.100:/mnt/volume1/pve/shared /mnt/pve/pve-shared`
   (and the same for `/mnt/volume1/pve/backups`).
4. `pvesm nfsscan 192.168.8.100 /mnt/volume1/pve/shared && pvesm scan` to
   refresh the storage plugin's internal state
   (this is needed even after a successful re-mount -- PVE caches the
   last failure).
5. If still inactive after the re-mount, log a warning to `>>/var/log/pve-shared-remount.log`
   for human follow-up; do not loop forever (cron catches it next run).

## Why this helps even when TrueNAS never went down

A `pve-shared` mount can also fall to a soft-timeout state without
TrueNAS dying (a brief network spike, ENOSPC). The remountKick wakes
those up too.

## Caveats

- Script must run on every PVE NODE host (not inside CTs) -- `pvesm`
  reads `/etc/pve/storage.cfg`. Cron runs as root from the host.
- Does NOT restart any CT -- if a CT was put into `error` state, the
  CT-side dance in `docs/ha-recovery.md` is the follow-up. This script
  just gets the DISK back; CT recovery is the next layer.
- Store off TrueNAS first if the root cause is TrueNAS itself (e.g.
  full boot loss). This script silently fails if true NFS server is
  down. Logs only flag mount failures, not uplink faults.
- No file in this directory was deployed to the homelab yet -- this
  directory documents the reproducible fix (per the dotfiles no-
  provisioner gap pattern). It's pending live deploy.

## See also

- `docs/services.md`  -- the inventory of CTs that depend on pve-shared.
- `services/network/` -- root-cause prevention (static IPs).
- `docs/ha-recovery.md` -- human-side CT recovery once pve-shared is back.