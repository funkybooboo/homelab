# The legacy dump archive

The old fleet is gone; its vzdump archives remain on truenas and
are the only restorable source of old-fleet data. This is the
reference for what remains in the archive and how to pull it.

## Where the data is

- `pve-backups/dump/vzdump-lxc-<ctid>-<date>.tar.zst` on truenas:
  weekly snapshots of every old CT, keep-last rotation. The newest
  per CT is the relevant one.
- The raw disk images no longer exist; vmids 101-106 are reused
  by the new fleet's infra guests, and the extractor skips those
  vmids.

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

## What remains in the archive

- **Already consumed** (jellyfin, navidrome, audiobookshelf,
  forgejo, postgres, vaultwarden, n8n): the dated ledger is in
  [plans/history.md](../plans/history.md) (the extraction ledger).
  Re-extraction stays possible for all of them.
- **firefox sync (CT 131)**: no dump exists; USER-5 opens with a
  B2 check and expects a fresh start.
- **linkwarden, omnivore, opengist, jupyter, bichon,
  protonmail-bridge, speedtest**: dumps exist; each restores in
  its own story.
- **grafana**: dump 123 holds the old dashboards if a restore is
  ever wanted.
- **CTs 110 and 116** (Sept-26 dumps only): stopped templates;
  resurrect on demand.

Anything not listed here is not coming back unless a story asks
for it.
