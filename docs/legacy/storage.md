# Storage

TrueNAS is the single storage backend for the whole cluster, served over
NFS. Plus the special-case jellyfin media mount puzzle.

## NFS exports -> PVE storage

| PVE storage | TrueNAS NFS export | contents | mount on PVE |
| --- | --- | --- | --- |
| `pve-shared` | `192.168.8.100:/mnt/volume1/pve/shared` | live container disks (`*.raw`) + CT configs under `lxc/` | all nodes, persistent |
| `pve-backups` | `192.168.8.100:/mnt/volume1/pve/backups` | `vzdump` artifacts (`dump/vzdump-*`), gangs of `.vma.zst` | all nodes, persistent |

`192.168.8.100` is `truenas`. NFS + CIFS + SSH services all enable=True at
boot. Pool `volume1` is ~3.2 T, ~1% used. NFS is the cluster's storage
transport; tailnet is not used for storage traffic.

CT rootfs lives on each node's `local-lvm` (thin LVM) by default; the
`pve-shared` volume holds the storage-heavy disks only when shared access is
needed. See `docs/backups.md` for the single-box risk (live + backups on the
same pool).

## Periodic snapshot tasks

TrueNAS: 4 daily snapshots at 00:00, auto-pruned to retain 2 weeks:

- `volume1/pve/shared` -- live container disks (crash-consistent, not app-consistent)
- `volume1/pve/backups` -- vzdump artifacts
- `volume1/home/nate`
- `volume1/media`

## media: jellyfin's NFS mount puzzle

Jellyfin (CT 102 on pve-thermaltake) indexes media split across 5 TrueNAS NFS
exports. A plain PVE mount-point bind does NOT carry child submounts into a
CT for you -- so each library needs its **own** `mp` bind.

### On the pve-thermaltake HOST (/etc/fstab)

```fstab
192.168.8.100:/mnt/volume1/media/movies     /mnt/tnas-media/media/movies     nfs _netdev,auto 0 0
192.168.8.100:/mnt/volume1/media/tvshows    /mnt/tnas-media/media/tvshows    nfs _netdev,auto 0 0
192.168.8.100:/mnt/volume1/home/nate/Music    /mnt/tnas-media/media/music     nfs _netdev,auto 0 0
192.168.8.100:/mnt/volume1/home/nate/Audiobooks /mnt/tnas-media/media/audiobooks nfs _netdev,auto 0 0
192.168.8.100:/mnt/volume1/home/nate/Books     /mnt/tnas-media/media/books       nfs _netdev,auto 0 0
```

(Old single `tnas.tail54538d.ts.net:/Volume1/public /mnt/tnas-media` line
removed; backups of `102.conf.bak.*` and `fstab.bak.*` kept on the node.)

### In the CT (lxc/102.conf)

Each host path gets its own mount-point entry, each with `backup=0`:

```
mp0: /mnt/tnas-media/media/movies,mp=/mnt/media/media/movies,backup=0
mp1: /mnt/tnas-media/media/tvshows,mp=/mnt/media/media/tvshows,backup=0
mp2: /mnt/tnas-media/media/music,mp=/mnt/media/media/music,backup=0
mp3: /mnt/tnas-media/media/audiobooks,mp=/mnt/media/media/audiobooks,backup=0
mp4: /mnt/tnas-media/media/books,mp=/mnt/media/media/books,backup=0
```

Note the `/media/media` double-nest: container sees
`/mnt/media/media/<sub>`. Jellyfin DB library paths in
`/var/lib/jellyfin/root/default/*/options.xml`:
Movies=`/mnt/media/media/movies`, Shows=`/mnt/media/media/tvshows`,
Music=`/mnt/media/media/music`,
Audiobooks=`/mnt/media/media/audiobooks`, Books=`/mnt/media/media/books`.

Media counts: movies 715 / tvshows 2 / music 488 / audiobooks 69 / books 5.

## Jellyfin boot-race fix (the onboot ordering problem)

`pve-guests.service` does NOT wait for `remote-fs.target`, and jellyfin
(`onboot:1`) started before the 5 NFS media mounts finished -> empty
libraries.

Fix: set `lxc/102 onboot:0` and gate the start on a host-level systemd unit
that waits for `remote-fs.target`:

```ini
# /etc/systemd/system/start-jellyfin.service  (on pve-thermaltake)
[Unit]
After=basic.target
Wants=remote-fs.target
After=remote-fs.target
RequiresMountsFor=/mnt/tnas-media/media/movies /mnt/tnas-media/media/tvshows /mnt/tnas-media/media/music /mnt/tnas-media/media/audiobooks /mnt/tnas-media/media/books

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/bin/sh -c 'pct status 102 | grep -q running || pct start 102'
ExecStop=/bin/sh -c 'pct shutdown 102 || true'

[Install]
WantedBy=multi-user.target
```

(`Documentation=` lines trigger systemd URL-parse warnings on this version;
the `onboot:0` + this unit together make the boot order deterministic.

Idempotent -- already-running path returns SUCCESS cleanly. After host
reboot, systemd guarantees the media mounts are up, THEN jellyfin starts.