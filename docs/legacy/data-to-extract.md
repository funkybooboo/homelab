# Data to extract (the whole point of OPS-1)

What must come off the old pve-shared rootfs disks before the
greenfield wipes them, per CT, in priority order. Everything lives in
`images/vm-<CTID>-disk-0.raw` on the truenas export
`/mnt/volume1/pve/shared` EXCEPT the two local-lvm CTs (128, 130) --
for those, the weekly vzdump artifacts in `/mnt/volume1/pve/backups`
are the fallback source (the job covered all guests, keep-last=4
weekly, so the last Saturday 2026-10-17-ish dump of each CT likely
exists).

`scripts/extract-legacy.sh` walks this table. "To locate" = standard
app default path; the script probes + the report shows what it found
-- paths are proven at extraction time, not trusted from here.

## Tier 0 -- critical (extraction gate; nothing wipes before these land)

| CT | data | path (to locate unless marked) | notes |
|----|------|-------------------------------|-------|
| 109 | vaultwarden db + attachments + RSA keys | `/var/lib/vaultwarden/` | bitwarden.sqlite3, attachments/, rsa_key.* -- THE passwords. First out, verified copy |
| 108 | postgres PGDATA | `/var/lib/postgresql/` | raw copy restorable at matching PG major (check version file); serves freshrss, linkwarden, omnivore (+ any other DBs) |
| 106 | n8n workflows + credentials | `~/.n8n/` (root's home, likely `/root/.n8n`) | database.sqlite = workflows; credentials encrypted with a key that lives in `.n8n/config` |

## Tier 1 -- high (the curated restores depend on them)

| CT | data | path | notes |
|----|------|------|-------|
| 102 | jellyfin config + library metadata | `/etc/jellyfin/` + `/var/lib/jellyfin/` | avoids full media re-scan (715 movies et al.); media itself is safe on truenas |
| 107 | forgejo repos + gitea.db | `/var/lib/forgejo/` + `/etc/forgejo/app.ini` (known) | 50G -- the biggest pull |
| 132 | navidrome.db | `/var/lib/navidrome/` | music library pointer state |
| 133 | audiobookshelf metadata + config | `/var/lib/audiobookshelf/` (to locate; possibly `/audiobookshelf`) | progress/reading state |
| 131 | syncstorage-rs database | `/var/lib/syncstorage-rs/` (to locate; check its systemd unit) | the actual Firefox sync payloads |
| 104 | freshrss app state | `/opt/freshrss/data/` | OPML is already in-repo (services/freshrss/); DB comes from 108 |
| 112 | linkwarden app data | `/opt/linkwarden/` + `.env` | DB from 108; .env holds the auth secrets |

## Tier 2 -- medium (decide during curation, issues item 6)

| CT | data | path | notes |
|----|------|------|-------|
| 105 | mirror repos | `/var/lib/forgejo/` | read-only mirror; cheap to skip if forgejo re-mirrors |
| 113 | opengist gists | `/var/lib/opengist/` | |
| 118 | jupyter notebooks | `/root/` or `/home/*/` notebooks dir | find `*.ipynb` |
| 123 | grafana dashboards + datasources | `/var/lib/grafana/` | new grafana gets rebuilt but dashboards port |
| 125 | bichon mail archive | `/var/lib/bichon/` (to locate) | whole point of bichon; check size before pulling |
| 126 | protonmail-bridge credentials | `/var/lib/protonmail/bridge/` (to locate) | saves re-login+2FA dance; gpg state |
| 127 | cronmaster jobs | `/opt/cronmaster/` + `.env` (known: INTERNAL_API_URL) | jobs db + env |
| 103 | speedtest history | `/opt/speedtest-tracker/` + `.env` | laravel db (sqlite or in 108) |
| 134 | omnivore app data | `/opt/omnivore/` (to locate) | DB from 108 |

## Tier 3 -- none/low (skip unless trivial)

- 101 alpine-it-tools, 111 adminer, 119 searxng (settings only),
  120 excalidraw (scenes were browser-local), 121 drawio, 122
  prometheus (TSDB expires), 124 pve-exporter, 130 loki (logs), all
  six stopped templates.
- 128 **ntfy**: user/access db (`/var/lib/ntfy/`) is on framework's
  LOCAL-LVM -- pull from the newest `vzdump-lxc-128-*.tar.zst` in
  pve-backups, or skip: creds live in services/ntfy/README.md + the
  phone, and OPS-8 rebuilds the topic fresh anyway.

## Not extract targets (already safe)

- The media libraries + `/home/nate` -- live truenas datasets, B2-synced,
  untouched by the rebuild.
- CT configs (`lxc/<vmid>.conf` mount + device entries) are
  documentation-of-record; the script copies them (tiny) since they
  encode the old conventions exactly.

## Verification discipline

Every pulled artifact gets a sha256 in the manifest the script
writes. Tier-0 counts as "landed" only when a copy exists OUTSIDE the
truenas pool (debbie) AND the manifest hash matches. Rule 10: extract
before wipe; B2 never stops.
