# The legacy dump archive

The old fleet is gone; its vzdump archives remain on truenas and
are the only restorable source of old-fleet data. This is the
reference for what exists and how to pull it.

## Where the data is

- `pve-backups/dump/vzdump-lxc-<ctid>-<date>.tar.zst` on truenas:
  weekly snapshots of every old CT, keep-last rotation. The newest
  per CT is the relevant one.
- The raw disk images (`pve-shared/images/`) were removed in the
  OPS-20 cleanout. Nothing reads them now, and vmids 101-106 are
  reused by the new fleet's infra guests.

## How to pull

```sh
sudo ./scripts/extract-legacy.sh --copy-from-dump <ctid>
```

The script mounts the truenas backup export read-only and extracts
the newest archive to `legacy-extraction/from-dump-<ctid>/`. Run it
from the repo root; it needs root for the NFS mount.

Two facts about the output:

- The extracted tree is root-owned with restrictive modes. Ansible
  runs as nate and cannot read it until you
  `sudo chown -R nate:nate legacy-extraction`.
- Service roles pick the extraction up on the next `make converge`:
  each restore is gated on files being present, runs once, and
  never overwrites live data.

## What has been consumed

| CT | Service | Newest dump | Status |
| --- | --- | --- | --- |
| 106 | n8n | 2026-11-21 | extracted (tier 0) |
| 107 | forgejo hub | 2026-11-21 | restored (OPS-9) |
| 108 | postgres | 2026-11-21 | restored (OPS-10) |
| 109 | vaultwarden | 2026-11-21 | restored (USER-1) |
| 102 | jellyfin | 2026-09-26 | restored (USER-2) |
| 132 | navidrome | 2026-09-26 | restored (USER-2) |
| 133 | audiobookshelf | 2026-11-21 | restored (USER-2) |

## What remains, by story

- USER-5 (firefox sync, CT 131): no dump exists. The story opens
  with a B2 check; expect a fresh start.
- USER-7/8/9/10/11/12/13 (linkwarden, omnivore, opengist, jupyter,
  bichon, protonmail-bridge, speedtest): dumps exist; each story
  restores from them.
- CTs 110 and 116 (Sept-26 dumps only): presumed stopped templates;
  resurrect on demand.

Anything not listed here is not coming back unless a story asks
for it.
