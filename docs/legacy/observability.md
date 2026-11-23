# Observability -- current state

The homelab's full monitoring, alerting, and centralized logging stack as
deployed today. Everything here was **built 2026-07-31 through 2026-08-01**
and verified live.

Related: [`services.md`](./services.md) (CT catalog),
[`notifications.md`](./notifications.md) (ntfy phone pipeline),
[`nodes.md`](./nodes.md), [`cluster.md`](./cluster.md).

## TL;DR

The observability stack is complete (Phase 1 + Phase 2). Phase 3
(tailscale-exporter, router node_exporter scrape, app exporters like
jellyfin/postgres) is deferred.

**Metrics pipeline:** Prometheus scrapes 41 targets across 6 jobs; 5 alert
rules fire through Alertmanager -- ntfy-slack-bridge -- ntfy -- phone.

**Logging pipeline:** Promtail on 14 hosts/CTs + TrueNAS syslog + router
syslog (via PVE relay) all push to Loki on CT 130 with TLS.

**Dashboards:** 11 Grafana dashboards across 7 categories.

## Prometheus (CT 122, pve-thermaltake)

Scrapes 6 jobs / 41 targets, all UP:

| Job | Targets | What |
|---|---|---|
| prometheus | 1 (self) | self-metrics |
| pve | 5 | PVE cluster via pve-exporter (relabeled to one exporter host) |
| speedtest-tracker | 1 | speedtest /prometheus endpoint |
| node | 6 | node_exporter on 5 PVE hosts + TrueNAS (systemd/mountstats/processes collectors) |
| blackbox_http | 27 | blackbox_exporter probing all tailnet HTTPS endpoints + PVE consoles |
| app_metrics | 2 | Grafana + Forgejo native /metrics |

Config at `services/observability/prometheus.yml`. Rules at
`services/observability/prometheus-rules.yml`.

**5 alert rules** (1 group):
- `blackbox:probe_up` (recording)
- `blackbox:cert_days_remaining` (recording)
- `BlackboxEndpointDown` -- 3-probe (90s) gate, critical
- `BlackboxCertExpiringSoon` -- cert < 14 days, warning
- `DiskSpaceLow` -- root FS > 85% for 5m, warning

## Alertmanager (CT 122, pve-thermaltake)

Prometheus Alertmanager 0.28.1 on `:9093`. Single route to the `ntfy`
webhook receiver. `send_resolved: true`, `group_wait: 30s`,
`repeat_interval: 4h`.

Config template at `services/observability/alertmanager.yml.example`
(live file has the real webhook secret; not in repo).

## ntfy pipeline (CT 128, pve-framework)

**7 notification paths** to the phone:
1. TrueNAS alerts (original Slack-type alertservice)
2. Alertmanager -- ntfy-slack-bridge AM route -- ntfy (Phase 1d)
3. renew-pve-tls.sh on failure (5 PVE hosts)
4. renew-truenas-tls.py on failure (wrapper script)
5. pve-shared-remount.sh on actual remount
6. vzdump-ntfy-hook.sh on backup job error/end
7. ha-state-watch.sh on HA state transitions (error/stopped only)

Bridge source: `services/ntfy/ntfy-slack-bridge.py` (extended with AM route).
Shared publisher helper: `services/observability/ntfy-publish.sh`.

## Grafana (CT 123, pve-framework)

Grafana 13.1.0. Two datasources:
- `prometheus` (uid `afrtfru117lz4c`) -- Prometheus, HTTP
- `loki` (uid `loki`) -- Loki, HTTPS (LE cert verified)

**11 dashboards** (flat, no folders, `<Category> -- <Name>` naming):

| Dashboard | Source | What |
|---|---|---|
| Proxmox -- Host Health | node_exporter | CPU, memory, disk, network, load, failed systemd, temperatures |
| Proxmox -- Cluster Status | pve-exporter | Quorum, guests, per-node CPU/mem, storage pools, PVE version per node |
| Proxmox -- CT Resources | pve-exporter | Per-CT/VM CPU, memory, disk, IO, network + allocation table |
| Network -- Uptime and Certificates | blackbox_exporter | Up/down stats, probe latency, cert days remaining bargauge |
| Network -- Speedtest | speedtest-tracker | Download/upload Mbps, latency, jitter (pre-existing board) |
| NAS -- TrueNAS Health | node_exporter | ZFS pools, ARC cache, disk I/O, filesystem, CPU/mem/network |
| App -- Grafana | grafana metrics | API responses, inflight, datasource proxy latency, logins |
| App -- Forgejo | gitea metrics | Repos, users, issues, orgs, stars, watches, mirrors |
| App -- Prometheus | prometheus metrics | Scrape duration, rule eval, ingestion rate, TSDB series |
| Logs -- Incident Timeline | Loki | All error/warning journal lines across every host (24h) |
| Logs -- Proxmox HA Narrative | Loki | Corosync + HA-manager + storage thrash filter on PVE hosts |
| Logs -- SSH and sudo Audit | Loki | Accepted/failed SSH + sudo invocations (24h) |

Dashboard manifests: `services/observability/grafana/*.dashboard.yaml`.
Managed via `gcx` CLI (Grafana resource API, `dashboard.grafana.app/v1beta1`).

## node_exporter (5 PVE hosts + TrueNAS + GL-MT2500 router)

- **5 PVE hosts** (pve-thermaltake, pve-aspiree15, pve-aspires,
  pve-framework, raspberrypi): node_exporter v1.12.1 with extra
  `systemd`/`mountstats`/`processes` collectors. Static binary at
  `/usr/local/bin/node_exporter`, systemd unit.
- **TrueNAS**: node_exporter v1.12.1 at `/mnt/volume1/.admin/node_exporter`
  (TrueNAS root FS is read-only -- binary lives on the ZFS pool).
  systemd unit at `/etc/systemd/system/node_exporter.service`.
- **GL-MT2500 router**: node_exporter v1.12.1 (arm64) deployed, but
  tailscale routing quirk prevents scraping from prometheus (same issue
  as the router syslog relay). Deferred to Phase 3b.

Install script: `services/observability/install-node-exporter-host.sh`
(idempotent, arch-detected, sha256-verified).

## blackbox_exporter (CT 122)

Prometheus blackbox_exporter 0.26.0 (apt-installed) on `:9115`. Default
`http_2xx` module (IPv4, follow_redirects). Probes 27 endpoints over the
tailnet: 20 web CT HTTPS fronts + TrueNAS UI + 5 PVE `:8006` consoles +
prometheus native HTTP `:9090/-/healthy`.

## Loki (CT 130, loki.tail54538d.ts.net)

Loki 3.7.4 (GitHub .deb), single-node monolithic, tsdb/v13 schema, 30-day
compactor retention. Data on local-lvm (NOT pve-shared NFS). HTTPS via
tailscale serve + real Let's Encrypt cert (auto-renewed by tailscaled).

Config: `services/observability/loki/loki-config.yaml`.

**CT 130 networking**: static IP 192.168.8.130 (the original DHCP IP .120
was silently blocked by the GL-MT2500 router -- likely a stale lease/MAC
mismatch). DNS via 192.168.8.1 (router). tailscale serve on :443 proxies
to localhost:3100.

## Promtail (5 PVE hosts + 8 curated CTs + CT 130 receiver)

- **5 PVE hosts**: promtail 3.6.11 reads `/var/log/journal`, pushes to
  `https://loki.tail54538d.ts.net/loki/api/v1/push` (TLS-verified).
- **8 curated CTs** (107 forgejo, 102 jellyfin, 104 freshrss, 122 prometheus,
  108 postgresql, 125 bichon, 126 protonmail-bridge, 128 ntfy): same config.
- **raspberrypi**: reads `/run/log/journal` (volatile, not persistent).
- **CT 130 receiver**: promtail listens on `:1514` (TCP syslog from TrueNAS)
  + file-scraper for router logs at `/var/log/promtail-syslog/router.log`.
  Also runs the request-side promtail pushing to local Loki.

Install script: `services/observability/promtail/install-promtail-host.sh`.
Receiver config: `services/observability/promtail/receiver-config.yml`.

14 distinct host labels confirmed in Loki.

## TrueNAS syslog

TrueNAS web UI: System Settings > Advanced > Syslog Server set to
`loki.tail54538d.ts.net:1514` (TCP, Warning level, no FQDN, no audit logs).
Confirmed `source=truenas` in Loki.

## Router syslog (GL-MT2500)

Router's BusyBox logread can't reach CT 130 directly (the GL-MT2500 blocks
traffic from certain CT IPs on the br-lan interface). Solved with a PVE
host TCP relay:
- Router logread sends to `pve-thermaltake:1515` (TCP)
- PVE host socat relay (`router-syslog-relay.service`) forwards to CT 130:1515
- CT 130 socat bridge (`router-syslog-bridge.service`) writes to
  `/var/log/promtail-syslog/router.log`
- CT 130 promtail file-scraper reads it + pushes to Loki

Confirmed `source=router` in Loki. The 3-service relay chain is a
workaround for the router's firewall blocking CT 130's old IP.

## Known deferred items (Phase 3)

- **tailscale-exporter** -- needs a read-only Tailscale OAuth key
- **Router node_exporter scrape** -- blocked by same routing quirk as syslog
- **Jellyfin exporter** -- needs API key from Jellyfin admin UI
- **Postgres exporter** -- needs sidecar deploy on CT 108
- **Forgejo-mirror** -- CT 105 is NOT Forgejo (it's a Bun app); no metrics