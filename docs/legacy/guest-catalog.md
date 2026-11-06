# Guest catalog (final state at the 2026-10 wind-down)

28 running CTs + 6 stopped templates. Sources: `docs/services.md`
(2026-07 snapshot) + the skill's final live inventory (2026-10) +
`docs/observability.md` (CT 130, as-built 2026-08-30). See
[README.md](./README.md) for provenance; placement drift between the
two snapshots is HA failovers + pve-balance doing its job.

**Node** column = final placement (2026-10); **Jul** = the July
snapshot where it differs (migration history, not a correction).

## Running CTs

| vmid | name | purpose | node | Jul | port | rootfs | HA | restore story | data |
|------|------|---------|------|-----|------|--------|----|----------------|------|
| 101 | alpine-it-tools | static IT-tools page | framework | thermaltake | 80 | pve-shared 1G | yes | curate (issues 6) | none |
| 102 | jellyfin | media server, GPU transcode | thermaltake | = | 8096 | pve-shared 16G | no | [USER-2](../../plans/stories/USER-2-media-fleet.md) | config+metadata (high) |
| 103 | speedtest-tracker | speed history | thermaltake | aspires | 80 | pve-shared 4G | yes | curate | laravel db (med) |
| 104 | freshrss | RSS | aspiree15 | thermaltake | 80 | pve-shared 4G | yes | [USER-3](../../plans/stories/USER-3-daily-tools.md) | PG in 108 + OPML in repo (high) |
| 105 | forgejo-mirror | read mirror of GitHub repos | framework | aspiree15 | 4321 | pve-shared 6G | yes | [OPS-9](../../plans/stories/OPS-9-forgejo-mirror.md) | repos (low) |
| 106 | n8n | workflow automation | framework | aspiree15 | 5678 | pve-shared 10G | yes | [USER-3](../../plans/stories/USER-3-daily-tools.md) | `~/.n8n` sqlite (critical) |
| 107 | forgejo | self-hosted git | aspires | thermaltake | 3000 | pve-shared 50G | yes | [OPS-9](../../plans/stories/OPS-9-forgejo-mirror.md) | `/var/lib/forgejo` (high) |
| 108 | postgresql | shared DB | aspires | = | none | pve-shared 4G | yes | [OPS-10](../../plans/stories/OPS-10-postgresql.md) | PGDATA (critical) |
| 109 | vaultwarden | password manager | aspiree15 | = | 8000 | pve-shared 20G | yes | [USER-1](../../plans/stories/USER-1-vaultwarden-restore.md) | **bitwarden db (FIRST)** |
| 111 | adminer | DB admin page | aspires | thermaltake | 80 | pve-shared 8G | yes | curate | none |
| 112 | linkwarden | bookmarks | aspiree15 | aspires | 3000 | pve-shared 12G | yes | [USER-3](../../plans/stories/USER-3-daily-tools.md) | PG in 108 (high) |
| 113 | opengist | snippets | framework | aspiree15 | 6157 (+2222 ssh) | pve-shared 8G | yes | curate | gist data (med) |
| 118 | jupyternotebook | notebooks | framework | aspires | 8888 | pve-shared 4G | yes | curate | notebooks dir (med) |
| 119 | searxng | meta-search | aspiree15 | = | 8888 | pve-shared 7G | yes | [USER-3](../../plans/stories/USER-3-daily-tools.md) | settings (low) |
| 120 | excalidraw | whiteboard | thermaltake | aspires | 3000 | pve-shared 10G | yes | curate | scenes local-only (low) |
| 121 | drawio | diagrams | thermaltake | aspiree15 | 8080 | pve-shared 4G | yes | curate | none |
| 122 | prometheus | metrics | aspiree15 | thermaltake | 9090 | pve-shared 4G | yes | [OPS-11](../../plans/stories/OPS-11-monitoring-pair.md) | TSDB (none) |
| 123 | grafana | dashboards | aspires | = | 3000 | pve-shared 4G | yes | [OPS-11](../../plans/stories/OPS-11-monitoring-pair.md) | dashboards (med) |
| 124 | prometheus-pve-exporter | PVE metrics | framework | aspiree15 | 9221 | pve-shared 2G | yes | replaced by new stack | none |
| 125 | bichon | email archive | framework | = | 15630 | pve-shared 4G | yes | curate; skill table omits it* | mail archive (med) |
| 126 | protonmail-bridge | SMTP relay | framework | = | none | pve-shared 8G | yes | curate; skill table omits it* | bridge creds (med) |
| 127 | cronmaster | cron scheduler (Next.js) | aspiree15 | thermaltake | 3000 | pve-shared 8G | yes | curate | jobs db + `.env` (med) |
| 128 | ntfy | push notifications | framework (local-lvm; skill says aspires**) | = | 443 -> 2587/2586 | **local-lvm 4G** | no | [OPS-8](../../plans/stories/OPS-8-ntfy-alerting.md) | user/access db (local-lvm!) |
| 130 | loki | log store 3.7.4 | thermaltake | n/a (Aug) | 443 -> 3100 | **local-lvm 16G** | yes | revisit post-v4 | logs (none) |
| 131 | syncstorage-rs | Firefox sync | thermaltake | n/a (media batch) | 8000 | pve-shared | yes | [USER-5](../../plans/stories/USER-5-firefox-sync.md) | syncstorage db (high) |
| 132 | navidrome | music server | thermaltake | n/a | 4533 | pve-shared | yes | [USER-2](../../plans/stories/USER-2-media-fleet.md) | navidrome.db (high) |
| 133 | audiobookshelf | audiobooks | thermaltake | n/a | 13378 | pve-shared | yes | [USER-2](../../plans/stories/USER-2-media-fleet.md) | metadata db (high) |
| 134 | omnivore | read-it-later | thermaltake | n/a | web 3000 / api 4000 | pve-shared | yes | curate | PG in 108 (med) |

\* The skill's final table omits 125/126; services.md (July) +
observability.md (Aug, promtail list) both had them running. Either
they were decommissioned in Sept-Oct, or the skill table has a gap.
Settled by extraction time: `vm-125`/`vm-126` raw images in
pve-shared = still existed at shutdown.

\** ntfy: services.md + ha-recovery.md + storage.md all pin rootfs to
framework's local-lvm (non-migratable by design); the skill's
"@ aspires" is presumed a table slip. Either way its data is NOT in
pve-shared -- see [data-to-extract.md](./data-to-extract.md).

vmid 129 was never used. 130's rootfs is local-lvm even though the July
build plan sketched it on pve-shared -- the as-built moved it
(observability.md).

## Stopped templates (do not resurrect)

| vmid | name | type | storage |
|------|------|------|---------|
| 100 | ubuntu-template | QEMU VM (cloud-init, OVMF) | local-lvm 7G |
| 110 | adminer-template | LXC template | pve-shared 8G |
| 114 | debian-template | QEMU VM (cloud-init, OVMF) | pve-shared 8G |
| 115 | almalinux-template | QEMU VM (cloud-init, OVMF, TPM) | pve-shared 10G |
| 116 | alpine-template | LXC template | pve-shared 1G |
| 117 | arch-linux-template | QEMU VM (cloud-init, OVMF) | pve-shared 4G |

The greenfield build creates fresh PVE 9.2 / Debian 13 templates from
the IaC skeleton (OPS-7); these are era artifacts. The 6 VM templates
were stopped, so they cost nothing but pve-shared bytes.

## Common conventions (applied to every web CT)

- Own tailscale node per CT; `tailscale serve --bg --https 443 --yes
  http://localhost:<port>` front; LE cert auto-renewed by tailscaled.
- `nameserver 192.168.8.1` + `--accept-dns=false` (cert-renewal DNS
  hardening; docs/https.md "DNS gotcha").
- `/dev/net/tun` + `c 10:200` device entries for tailscaled in
  unprivileged CTs.
- Timezone `America/Denver`.
- HA via `ha-manager add ct:<vmid>` for everything except 102 + 128
  (+ 130, local-lvm). Never HA on the Pi.
