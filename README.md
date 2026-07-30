# Homelab

Documentation for the current homelab: a 5-node Proxmox cluster on a
[Tailscale](https://tailscale.com) tailnet, backed by a TrueNAS storage box.
All web surfaces are HTTPS over the tailnet -- nothing is exposed to the
public internet.

> This is the live, Proxmox-based homelab (post-2026-07). It supersedes the
> older Docker-on-Pi service configs that used to live in this repo.

## Start here

Docs (`docs/`):

* [`overview.md`](docs/overview.md) -- nodes, tailnet, services, doc map.
* [`services.md`](docs/services.md) -- every running CT + VM template, with vmid / node / tailnet IP / port / URL / HA / notes.
* [`nodes.md`](docs/nodes.md) -- per-node detail (hardware role, what runs where, per-node admin commands).
* [`https.md`](docs/https.md) -- the three TLS cert mechanisms + the MagicDNS
  renewal time bomb + the `accept-dns=false` fix.
* [`cluster.md`](docs/cluster.md) -- 5-node PVE cluster, HA, the
  quorum-witness Pi rule (never host HA CTs there).
* [`backups.md`](docs/backups.md) -- vzdump, TrueNAS snapshots, the
  cloud-sync B2 task, the single-box DR hole.
* [`storage.md`](docs/storage.md) -- NFS / `pve-shared` / `pve-backups`, +
  the jellyfin multi-mount + boot-race fix.
* [`laptop-nodes.md`](docs/laptop-nodes.md) -- lid-ignored + screen-off on
  the two laptop PVE nodes.
* [`notifications.md`](docs/notifications.md) -- ntfy push pipeline for
  TrueNAS + homelab-wide alerts.
* [`ntfy-flow.md`](docs/ntfy-flow.md) -- ASCII diagram of request flow
  through the ntfy CT.
* [`nextjs-behind-tls-proxy.md`](docs/nextjs-behind-tls-proxy.md) -- the
  cronmaster `INTERNAL_API_URL` bug; reusable gotcha for Next.js behind
  tailscale serve (audit linkwarden + excalidraw).
* [`ha-recovery.md`](docs/ha-recovery.md) -- clearing an `error` state on
  a stopped CT after an NFS / host-blip: the `ha-manager set ct:N
  --state disabled -> pct start -> ha-manager set ct:N --state started`
  dance, plus the `emergency_ro` rootfs case.

Service configs (`services/`):

* [`services/ntfy/`](services/ntfy/) -- self-hosted ntfy + a Slack-to-ntfy
  bridge so TrueNAS's native Slack alert type publishes to ntfy. Includes
  reproducible deploy steps + the (scrubbed) bridge source.
* [`services/pve-tls/`](services/pve-tls/) -- `renew-pve-tls.sh` weekly cron
  that keeps the native PVE `pveproxy-ssl.pem` (-backend `:8006`) LE cert
  fresh.
* [`services/truenas-tls/`](services/truenas-tls/) -- `renew-truenas-tls.py`
  weekly TrueNAS cron that re-imports a fresh LE cert into the TrueNAS UI
  cert store.
* [`services/freshrss/`](services/freshrss/) -- `feeds.opml`, the canonical
  214-feed developer firehose (languages, devops, security, AI, databases,
  GitHub releases + trending) imported into the FreshRSS instance on CT 104.
* [`services/network/`](services/network/) -- TrueNAS static `.100` + the
  6 DHCP reservations on the GL-MT2500 (TrueNAS + 5 PVE nodes pinned to
  their current LAN IPs). Includes `set-reservations.sh` idempotent
  reproducible script (router has no sftp-server; pipe via ssh stdin).
* [`services/pve-shared-nfs-remount/`](services/pve-shared-nfs-remount/) --
  cron + script that auto-remount `pve-shared` + `pve-backups` NFS storages
  on every PVE node if `pvesm status` shows them inactive. Prevents the
  CT-stop-then-HA-error cascade at source.

## Conventions

* No secrets in this repo. Configs that need a secret are committed only as
  `*.example` templates; the real filled-in files (with tokens/passwords)
  live on the hosts they run on and are gitignored.
* Service dirs hold config files, helper scripts, and a per-service `README.md`
  with deploy notes + revert paths.
* Renewal scripts (`renew-pve-tls.sh`, `renew-truenas-tls.py`, the ntfy bridge)
  are version-controlled here (scrubbed of secrets) AND deployed across the
  PVE nodes / TrueNAS / the ntfy CT; the running copies are the source of
  truth and the repo is the reproducible backup. See each script's directory
  README for the install path.