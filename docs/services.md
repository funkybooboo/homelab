# Services -- container & VM catalog

Every running workload in the homelab, plus the stopped templates. All
HTTP services are exposed **tailnet-only** as `https://<host>.tail54538d.ts.net`
via `tailscale serve --https 443` (Let's Encrypt cert auto-renewed by
tailscaled). See [`https.md`](./https.md) for the cert machinery and
[`cluster.md`](./cluster.md) for HA.

Live tailnet IPs are captured as of 2026-07; they're stable per-node but
re-verify with `tailscale status` if you need current values.

## Running CTs (23)

| vmid | name | node | tailnet IP | app port | HTTPS URL | HA | onboot | cores / mem | rootfs | notes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 101 | alpine-it-tools | pve-thermaltake | 100.99.169.73 | 80 | https://alpine-it-tools.tail54538d.ts.net | yes | 1 | 1 / 256M | pve-shared 1G | Alpine + nginx serving static IT-tools; tiny |
| 102 | jellyfin | pve-thermaltake | 100.116.144.120 | 8096 | https://jellyfin.tail54538d.ts.net | no | 0 | 2 / 2G | pve-shared 16G | media server; **NVIDIA GPU passthrough** for hw transcode; 5 NFS media mounts (mp0-mp4); onboot:0 + start-jellyfin.service boot-race fix (see [`storage.md`](./storage.md)) |
| 103 | speedtest-tracker | pve-aspires | 100.94.66.77 | 80 | https://speedtest-tracker.tail54538d.ts.net | yes | 1 | 2 / 2G | pve-shared 4G | Laravel; `APP_URL=https://speedtest-tracker.tail54538d.ts.net` in `/opt/speedtest-tracker/.env` |
| 104 | freshrss | pve-thermaltake | 100.64.32.24 | 80 | https://freshrss.tail54538d.ts.net | yes | 1 | 2 / 1G | pve-shared 4G | apache2 + postgresql; OPML subscription list in [`services/freshrss/`](../services/freshrss/) |
| 105 | forgejo-mirror | pve-aspiree15 | 100.92.84.39 | 4321 | https://forgejo-mirror.tail54538d.ts.net | yes | 1 | 2 / 2G | pve-shared 6G | Forgejo instance #2 (mirror); ROOT_URL set to https |
| 106 | n8n | pve-aspiree15 | 100.66.194.38 | 5678 | https://n8n.tail54538d.ts.net | yes | 1 | 2 / 2G | pve-shared 10G | workflow automation |
| 107 | forgejo | pve-thermaltake | 100.123.168.15 | 3000 | https://forgejo.tail54538d.ts.net | yes | 1 | 2 / 2G | pve-shared 50G | self-hosted git; `ROOT_URL=https://forgejo.tail54538d.ts.net/`, `SSH_DOMAIN=forgejo.tail54538d.ts.net` in `/etc/forgejo/app.ini` (SSH clone on :22 over tailnet); big disk for repos |
| 108 | postgresql | pve-aspires | 100.84.74.74 | -- | -- | yes | 1 | 1 / 1G | pve-shared 4G | database; **no web port**, no tailscale serve (consumed by other CTs over tailnet :5432) |
| 109 | vaultwarden | pve-aspiree15 | 100.111.2.125 | 8000 | https://vaultwarden.tail54538d.ts.net | yes | 1 | 4 / 6G | pve-shared 20G | Bitwarden-compatible password manager; the reference "works great" deployment the rest of the rollout was modeled on |
| 111 | adminer | pve-thermaltake | 100.90.49.116 | 80 | https://adminer.tail54538d.ts.net | yes | 1 | 1 / 512M | pve-shared 8G | single-file PHP DB admin (apache2); no URL config -- pass-through |
| 112 | linkwarden | pve-aspires | 100.77.18.16 | 3000 | https://linkwarden.tail54538d.ts.net | yes | 1 | 2 / 4G | pve-shared 12G | bookmark manager; **Next.js -- audit `INTERNAL_API_URL`/`NEXTAUTH_URL`/`AUTH_URL`** (see [`nextjs-behind-tls-proxy.md`](./nextjs-behind-tls-proxy.md)) |
| 113 | opengist | pve-aspiree15 | 100.100.194.23 | 6157 | https://opengist.tail54538d.ts.net | yes | 1 | 1 / 1G | pve-shared 8G | pastebin/code snippet host |
| 118 | jupyternotebook | pve-aspires | 100.107.246.121 | 8888 | https://jupyternotebook.tail54538d.ts.net | yes | 1 | 2 / 2G | pve-shared 4G | Jupyter; Ubuntu base |
| 119 | searxng | pve-aspiree15 | 100.114.222.45 | 8888 | https://searxng.tail54538d.ts.net | yes | 1 | 2 / 2G | pve-shared 7G | meta-search engine |
| 120 | excalidraw | pve-aspires | 100.102.24.61 | 3000 | https://excalidraw.tail54538d.ts.net | yes | 1 | 2 / 3G | pve-shared 10G | whiteboard; **Next.js -- audit `INTERNAL_API_URL`/`AUTH_URL`** (see [`nextjs-behind-tls-proxy.md`](./nextjs-behind-tls-proxy.md)) |
| 121 | drawio | pve-aspiree15 | 100.120.62.38 | 8080 | https://drawio.tail54538d.ts.net | yes | 1 | 1 / 2G | pve-shared 4G | diagrams; tomcat11 backend |
| 122 | prometheus | pve-thermaltake | 100.120.214.89 | 9090 | https://prometheus.tail54538d.ts.net | yes | 1 | 1 / 2G | pve-shared 4G | metrics scraper; scrapes 124 over http :9221 (see 124) |
| 123 | grafana | pve-aspires | 100.106.54.110 | 3000 | https://grafana.tail54538d.ts.net | yes | 1 | 1 / 512M | pve-shared 4G | dashboards; grafana-server.service |
| 124 | prometheus-pve-exporter | pve-aspiree15 | 100.74.15.91 | 9221 | https://prometheus-pve-exporter.tail54538d.ts.net | yes | 1 | 1 / 512M | pve-shared 2G | exposes PVE metrics for prometheus; scrapeUrl=http://prometheus-pve-exporter.tail54538d.ts.net:9221/pve (raw HTTP -- the HTTP scrape is SEPARATE from the :443 serve listener for browser access; both coexist, neither breaks the other) |
| 125 | bichon | pve-framework | 100.119.58.80 | 15630 | https://bichon.tail54538d.ts.net | yes | 1 | 1 / 1G | pve-shared 4G | email archive; bichon-server on 0.0.0.0:15630 (no URL config needed). Migrated Pi -> pve-framework (Pi has no pve-lrm; see [`cluster.md`](./cluster.md) "Pi rule") |
| 126 | protonmail-bridge | pve-framework | 100.121.124.92 | -- | -- | yes | 1 | 2 / 1G | pve-shared 8G | SMTP relay to Proton Mail; **no web port, no tailscale serve**; consumed over tailnet :25/SMTP or app-specific port |
| 127 | cronmaster | pve-thermaltake | 100.93.253.126 | 3000 | https://cronmaster.tail54538d.ts.net | yes | -- | 1 / 512M | pve-shared 8G | Next.js 16.2.6 standalone cron scheduler; **`INTERNAL_API_URL=http://localhost:3000` required** in `/opt/cronmaster/.env` (see [`nextjs-behind-tls-proxy.md`](./nextjs-behind-tls-proxy.md)); onboot unset but HA-managed so LRM restarts on boot |
| 128 | ntfy | pve-framework | 100.106.74.87 | 2587 (bridge) | https://ntfy.tail54538d.ts.net | no | 1 | 1 / 512M | local-lvm 4G | self-hosted push notifications; Slack->ntfy bridge :2587 reverse-proxies to ntfy :2586. **NOT HA-managed** (rootfs on local-lvm, not pve-shared). See [`services/ntfy/`](../services/ntfy/) + [`notifications.md`](./notifications.md) |

## Stopped templates (6)

Not running; used as clone sources for new CTs/VMs. All on pve-thermaltake.

| vmid | name | type | rootfs | notes |
| --- | --- | --- | --- | --- |
| 100 | ubuntu-template | QEMU VM | local-lvm 7G | cloud-init; OVMF/UEFI; virtio-scsi |
| 110 | adminer-template | LXC | pve-shared 8G | template for adminer CTs |
| 114 | debian-template | QEMU VM | pve-shared 8G | cloud-init; OVMF |
| 115 | almalinux-template | QEMU VM | pve-shared 10G | cloud-init; OVMF; TPM v2.0; x86-64-v3 cpu |
| 116 | alpine-template | LXC | pve-shared 1G | template for Alpine CTs |
| 117 | arch-linux-template | QEMU VM | pve-shared 4G | cloud-init; OVMF |

## Common CT conventions

Applied to every running web CT (see [`https.md`](./https.md) + [`cluster.md`](./cluster.md)):

* `lxc.cgroup2.devices.allow: c 10:200 rwm` + `lxc.mount.entry: /dev/net/tun ...` -- required so tailscaled can start inside the unprivileged CT.
* `--nameserver 192.168.8.1 --searchdomain tail54538d.ts.net` + `tailscale set --accept-dns=false` -- public DNS independent of MagicDNS flakiness (cert renewal reliability; see [`https.md`](./https.md) "DNS gotcha").
* `tailscale serve --bg --https 443 --yes http://localhost:<port>` -- the tailnet-only HTTPS front.
* `timezone: America/Denver` on most.
* HA membership via `ha-manager add ct:<vmid>` for everything that should auto-failover (everything except 102 jellyfin and 128 ntfy). **Never** on the Pi (no pve-lrm there).

## Per-service notes (the non-trivial ones)

### jellyfin (102)
* NVIDIA GPU passthrough: `lxc.cgroup2.devices.allow: c 195:*` + `c 243:*` + mount entries for `/dev/nvidia0`, `/dev/nvidiactl`, `/dev/nvidia-modeset`, `/dev/nvidia-uvm`, `/dev/nvidia-uvm-tools` (all `optional`). pve-thermaltake is the only node with a GPU.
* 5 mount-points (mp0-mp4) for the NFS media libraries -- see [`storage.md`](./storage.md) for the full fstab + the `/media/media` double-nest + the jellyfin DB library paths.
* `onboot:0` + `/etc/systemd/system/start-jellyfin.service` on pve-thermaltake gates start on `remote-fs.target` + `RequiresMountsFor=` the 5 media paths, so libraries aren't empty after a host reboot.

### forgejo (107)
* `/etc/forgejo/app.ini`: `ROOT_URL=https://forgejo.tail54538d.ts.net/`, `SSH_DOMAIN=forgejo.tail54538d.ts.net`. SSH git clone uses :22 over the tailnet (works because the CT runs its own tailscale). 50G rootfs for repos.

### vaultwarden (109)
The reference deployment ("works great") that the rest of the HTTPS rollout was modeled on. 4 cores / 6G -- the heaviest web CT.

### grafana + prometheus + pve-exporter (122 + 124 + 123)
Monitoring stack:
* `prometheus-pve-exporter` (124) exposes PVE cluster metrics on `:9221/pve`.
* `prometheus` (122) scrapes 124 at `http://prometheus-pve-exporter.tail54538d.ts.net:9221/pve?...` (raw HTTP, NOT through the serve TLS front -- 5 targets UP). The serve :443 on 124 is only for browser access.
* `grafana` (123) dashboards read from prometheus. Note grafana has just 512M -- light.

### bichon (125)
Email archive. `bichon-server` on `0.0.0.0:15630`, no app URL config needed. Was stuck on the Pi (frozen, no pve-lrm) -> migrated back to pve-framework (`ha-manager remove` / `pct migrate` / `ha-manager add`). See [`cluster.md`](./cluster.md) "Pi rule".

### protonmail-bridge (126)
SMTP relay to a Proton Mail account. No web UI, no tailscale serve. Other CTs (bichon, cronmaster, anything that sends mail) talk to it over the tailnet on its SMTP port.

### cronmaster (127)
Next.js 16.2.6 standalone cron scheduler. **Canonical example of the `INTERNAL_API_URL` bug** -- see [`nextjs-behind-tls-proxy.md`](./nextjs-behind-tls-proxy.md). `/opt/cronmaster/.env` must contain `INTERNAL_API_URL=http://localhost:3000` or login succeeds but every page bounces back to `/login`.

### freshrss (104)
RSS aggregator. apache2 + postgresql. The feed list (OPML, 214 feeds across 13 categories) lives in [`services/freshrss/`](../services/freshrss/) -- import it into the web UI; FreshRSS has no live-subscribe-from-file mode so it is a manual re-import on change.

### ntfy (128)
See [`notifications.md`](./notifications.md) + [`services/ntfy/`](../services/ntfy/) + [`ntfy-flow.md`](./ntfy-flow.md). Only CT with `rootfs` on `local-lvm` (not pve-shared) -> not migration-eligible, not HA-managed. Lives on pve-framework permanently.

## Audit todos

* **linkwarden (112)** and **excalidraw (120)** are both Next.js behind tailscale serve -- check `.env` for `INTERNAL_API_URL` / `APP_URL` / `NEXTAUTH_URL` / `AUTH_URL` and whether middleware self-fetches session. If login-then-bounce appears, apply the cronmaster fix. (Not yet audited as of 2026-07.)
* verify vzdump notify endpoint still = mail-to-root (silent); fold into ntfy topic.