# Observability -- current state (what's deployed now)

What the homelab's monitoring / alerting / logging stack looks like today.
Everything here was **probed live on 2026-08-30** -- not transcribed from
older docs (note: `services.md` is stale on CT placement after the
2026-07-30 HA migrations; this doc is the corrected, live view).

The **build plan / proposal** for what to add on top of this is in
[`../ideas/observability.md`](../ideas/observability.md). Related:
[`services.md`](./services.md) (CT catalog), [`notifications.md`](./notifications.md)
(the ntfy phone pipeline), [`nodes.md`](./nodes.md), [`cluster.md`](./cluster.md).

## TL;DR

The monitoring stack exists but is half-built:

* **Prometheus (CT 122, pve-thermaltake)** scrapes 3 jobs / 7 targets, all
  UP. ~7,144 series, all from the PVE aggregate view (`pve_ha_state`,
  `pve_lock_state`, `pve_disk_*`, `pve_memory_*`, `pve_cpu_*`). **No rules,
  no Alertmanager** (still the commented-out defaults).
* **Grafana (CT 123, pve-framework)** is Grafana **13.1.0** with a working
  Prometheus datasource (`prometheus`, uid `afrtfru117lz4c`, created in the
  grafana DB not a provisioning file). **3 dashboards** across 6 folders
  (NAS, Nodes, Services, Router, Network, Apps; see Phase 1b below), **0
  alert rules, 0 contact points.** `unified_alerting` is structurally
  configured but unused.
* **node_exporter deployed** to all 5 PVE hosts (`:9100`) with the extra
  `systemd`/`mountstats`/`processes` collectors; scraped by prometheus as
  `job=node` (TSDB series 7,144 -> 31,020, all 13 targets UP). Host-level
  CPU/mem/disk/net now captured alongside the PVE-aggregate view.
* **ntfy (CT 128, pve-framework)** is wired to **exactly one source: TrueNAS
  alerts** (one Slack-type `alertservice`, id 3). Every other failure path
  (vzdump, cert-renewal crons, the NFS-remount script, HA state changes, a
  CT going `error`, a disk filling, a cert not renewing) is **silent**.
  Confirmed by cross-host grep: zero other ntfy publishers on any cron or
  systemd unit across the 5 PVE nodes.
* **No centralized logging.** `systemd-journal-remote` /
  `systemd-journal-upload` inactive on all 5 PVE hosts; no promtail / vector /
  loki in any CT. Journals accumulate **unbounded** (framework 1.2G). The
  router (BusyBox `logd`) keeps a ring buffer only.

So: the plumbing exists (prometheus scrapes + a grafana datasource + the
ntfy phone pipeline with one publisher). What's missing is everything that
renders it human-visible and everything that turns failures into phone
pushes -- see [`../ideas/observability.md`](../ideas/observability.md).

## Live CT placements

Post-2026-07-30 HA migrations (supersedes the stale placement column in
`services.md`):

| node | running CTs |
| --- | --- |
| pve-thermaltake | 101, 102, 104, 107, 111, 122, 127 |
| pve-aspiree15 | 109, 119, 124 |
| pve-aspires | 103, 105, 106, 112, 113, 118, 120, 121 |
| pve-framework | 108, 123, 125, 126, 128 |
| raspberrypi | (witness only) |

## Prometheus (CT 122, pve-thermaltake)

* Config: `/etc/prometheus/prometheus.yml` holds only that file + two
  Jul-11 `prometheus.yml.bak` files. No `rules/`, no `conf.d/`.
* 3 jobs, 7 targets, all `health: up`:
  * `prometheus` -- self (`localhost:9090`).
  * `pve` -- the 5 PVE nodes, via the standard `__param_target`/instance
    relabel to `prometheus-pve-exporter.tail54538d.ts.net:9221`,
    `metrics_path: /pve`, `module: default`.
  * `speedtest-tracker` -- `speedtest-tracker.tail54538d.ts.net:80`,
    `metrics_path: /prometheus`.
* `scrape_interval: 15s`, `evaluation_interval: 15s`.
* `/api/v1/rules` -> `{"groups":[]}`. `alerting.alertmanagers.targets` is
  still the commented-out `# - alertmanager:9093` default.
* TSDB (`/api/v1/status/tsdb`): 7,144 series. Top metrics by series count --
  `pve_ha_state` (1720), `pve_lock_state` (1305), `pve_up` (270),
  `pve_disk_usage_bytes` (265), `pve_disk_size_bytes` (265),
  `pve_memory_usage_bytes` (170), `pve_uptime_seconds` (170),
  `pve_cpu_usage_limit` (170), `pve_memory_size_bytes` (170),
  `pve_cpu_usage_ratio` (170).

## Prometheus-pve-exporter (CT 124, pve-aspiree15)

* Service `active`. `?target=pve-thermaltake...` returns `pve_up`,
  `pve_ha_state`, etc. Scraped on its raw tailnet port `:9221` over HTTP
  (NOT through its serve TLS front -- the `:443` serve listener is for
  browser access only; both coexist).
* NOTE: the `/etc/prometheus-pve-exporter/` dir documented elsewhere does
  NOT exist on this CT; the config/credentials live elsewhere -- the service
  runs regardless.

## Grafana (CT 123, pve-framework)

* Version **13.1.0** (`/api/health` -> `version 13.1.0`; `database: ok`).
* `/etc/grafana/provisioning/` holds the stock sample yamls + one real file:
  `datasources/prometheus.yml` which is intentionally `datasources: []` with
  a comment: "already exists in the DB as 'prometheus' (uid afrtfru117lz4c).
  No file-based provisioning needed". Keep this convention -- the datasource
  is DB-created, not file-provisioned.
* `grafana.db` = 1.7M. sqlite counts:
  `dashboard` 0, `data_source` 1, `alert_rule` 0, `alert_rule_group_v2` 0,
  `notification_policy` 0, `contact_point` 0.
* Datasource row: name=`prometheus`, type=`prometheus`,
  url=`http://prometheus.tail54538d.ts.net:9090`, uid=`afrtfru117lz4c`
  (raw HTTP over the tailnet, NOT through the serve TLS front).
* `unified_alerting` is structurally configured (section present in
  `grafana.ini`) but entirely unused -- zero rules, zero contact points.
* tailscale serve: `https://grafana.tail54538d.ts.net` -> `localhost:3000`.

Net: a working datasource, no dashboards, no alerts.

## ntfy (CT 128, pve-framework)

* ntfy server active on `127.0.0.1:2586`; `ntfy-slack-bridge.py` (the
  reverse-proxy + Slack->ntfy forwarder) active on `127.0.0.1:2587`.
* `base-url: https://ntfy.tail54538d.ts.net`, `auth-default-access: deny-all`,
  admin user `nate`.
* Exposed over the tailnet by `tailscale serve` -> `localhost:2587` (the
  bridge is the single serve backend; ntfy itself is localhost-only).
* **Exactly one publisher today**: TrueNAS `alertservice.query` returns one
  service:
  `{"name":"ntfy (homelab)","type":"Slack","url":"https://ntfy.tail54538d.ts.net/truenas-f7e57b5f699d3d35","level":"WARNING","enabled":true,"id":3}`.
* Cross-host grep of `/etc/cron*` + `/etc/systemd/system/*.service` on all
  5 PVE nodes for the string "ntfy" -> **no other publishers**. So every
  non-TrueNAS failure path (vzdump, cert-renewal crons, the pve-shared
  NFS-remount script, HA state changes, a CT going `error`, disk fill, cert
  non-renewal) pushes nothing today. See [`notifications.md`](./notifications.md)
  (which lists these as "wire later").

## Host-level (all 5 PVE nodes)

* `systemd-journal-remote` + `systemd-journal-upload` -> `inactive` on all 5.
* No `promtail` / `vector` / `loki` / `node_exporter` / `journal-remote`
  binaries present on any host. No `journal-upload.conf` /
  `journal-remote.conf` configured.
* No `ntfy` curl in any cron or systemd unit on any host (see ntfy section).
* Journals **accumulate unbounded** -- `journalctl --disk-usage`:

  | node | journal disk |
  | --- | --- |
  | pve-thermaltake | 641.3M |
  | pve-aspiree15 | 242.3M |
  | pve-aspires | 656.4M |
  | pve-framework | 1.2G |
  | raspberrypi | 117.7M |

  No retention cap is enforced on any host.

## Per-CT agents

* Probed all 23 CTs for `promtail` / `node_exporter` / `vector` / `loki`
  binaries -> **none present in any CT**.
* Probed app-native metrics endpoints:
  * forgejo CT 107 `/metrics` -> empty (metrics NOT enabled in `app.ini`).
  * jellyfin CT 102 has a listener on `:9079` but `/metrics` returns
    nothing -- not a metrics exporter (jellyfin has no native prom exporter).
  * postgres CT 108 -> no `postgres_exporter`, no `:9187` listener.
* tailscale serve (sampled): every web CT proxies `/` ->
  `http://localhost:<port>` only; NONE expose a separate `/metrics` path.
  The precedent for any future raw-port scrape is the existing config --
  pve-exporter `:9221` and speedtest `:80` are scraped on their raw tailnet
  ports over HTTP, separate from the `:443` serve TLS front used for
  browser access.

## Router (GL-MT2500)

`root@gl-mt2500.tail54538d.ts.net`. Kernel
`5.4.211 #0 SMP Tue Jun 24 10:48:30 2025 aarch64` -- a June-2025 build
(newer than older docs implied; NOT a frozen old OpenWrt).
Interfaces: `eth0` (WAN), `eth1` / `br-lan`, `wgclient` (a WireGuard client
tunnel, separate from tailscale), `tailscale0`, `lo`. No `snmpd` /
`collectd` / `node_exporter` / `promtail` installed. No syslog/logd
remote-forward configured. `tailscale serve status` returns nothing (it is
a subnet-router / exit node, not a serve host).

## TrueNAS (nate@truenas)

RESTful API v2.0 reachable. One `alertservice` (the ntfy/Slack one above,
id 3). `cloudsync` tasks 4-8 (the 5 per-leaf B2 tasks from the 2026-07-30
rearchitect -- see [`backups.md`](./backups.md)). No grafana/loki app
currently installed (no `app.available` match).

## Repo + dotfiles

* `~/Projects/homelab` git history (as of 2026-08-30): no
  observability-related commits beyond the existing `services/ntfy/` +
  `docs/notifications.md`. No `services/grafana/`, `services/prometheus/`,
  or `services/observability/` dir exists yet.
* `~/dotfiles` migrations: none observability-related (`rg` for
  grafana/prometheus/loki/alertmanager/node_exporter/promtail/tailscale-export
  across `root/` -> nothing).

Confirms the **deploy gap**: nothing in either repo provisions any of the
monitoring components -- it is all live-only, deployed by hand over SSH.
The plan to close it (and the build proposal) is in
[`../ideas/observability.md`](../ideas/observability.md); the underlying
PVE-provisioner gap is in [`../ideas/proxmox-iac.md`](../ideas/proxmox-iac.md).