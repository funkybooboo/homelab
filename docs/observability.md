# Homelab observability proposal -- metrics, logs, alerts, tailnet

> Status: PROPOSAL (not yet built). Read alongside [`notifications.md`](./notifications.md)
> (existing ntfy pipeline), [`services.md`](./services.md) (the CT catalog),
> and [`ideas/proxmox-iac.md`](../ideas/proxmox-iac.md) (the IaC gap this whole thing rubs against).

## Honest TL;DR

You have a monitoring **stack already** and it is half-built (verified live
2026-08-30 -- see "Verified current state" at the end):

* **Prometheus (CT 122)** scrapes exactly 3 jobs / 7 targets, all UP: itself,
  the 5 PVE nodes via `prometheus-pve-exporter` (CT 124), and
  `speedtest-tracker`. TSDB holds ~7,144 series (mostly `pve_ha_state` /
  `pve_lock_state` / `pve_disk_*` / `pve_memory_*` / `pve_cpu_*` from the
  pve-exporter -- the cluster-aggregate view). scrape_interval 15s. No rules,
  no alertmanager ref (still the commented-out defaults). Jul-11
  `prometheus.yml.bak` files show one earlier iteration.
* **Grafana (CT 123)** is Grafana **13.1.0** with a **working Prometheus
  datasource already** -- `prometheus` (uid `afrtfru117lz4c`, URL
  `http://prometheus.tail54538d.ts.net:9090`, raw HTTP over the tailnet, NOT
  through the serve TLS front). Created in the grafana DB, not a provisioning
  file (the provisioning `datasources/prometheus.yml` is deliberately empty
  with a comment pointing at the DB uid). `unified_alerting` is structurally
  configured but unused. Real state: **1 datasource, 0 dashboards, 0 alert
  rules, 0 contact points**. ("More dashboards" is really "any dashboards.")
* **No alert rules, no Alertmanager, no alerting loop.** Prometheus' rule/
  alert config files are still the commented-out defaults; grafana alerting
  tables are empty too.
* **No node_exporter anywhere** (verified on all 5 hosts) -- so there are no
  host-level metrics (CPU/RAM/disk/net per box) at all, only the PVE-aggregate
  view.
* **ntfy (CT 128) is wired to exactly one source: TrueNAS alerts**
  (`alertservice.query` confirms exactly one service: "ntfy (homelab)",
  Slack-type, id 3). A cross-host grep of `/etc/cron*` +
  `/etc/systemd/system` on all 5 PVE nodes found **zero** other publishers.
  Every other failure path (vzdump, cert-renewal crons, the NFS-remount
  script, HA state changes, a CT going `error`, a disk filling, a cert not
  renewing) is **silent** today. `notifications.md` explicitly lists these as
  "wire later"; confirmed none were wired.
* **No centralized logging at all.** `systemd-journal-remote` /
  `systemd-journal-upload` are **inactive on all 5 PVE hosts**; no promtail /
  vector / loki anywhere (verified across all CTs). Journals are
  **accumulating unbounded** -- `journalctl --disk-usage`: thermaltake 641M,
  aspires 656M, framework **1.2G**, aspiree15 242M, pi 118M. The router keeps
  a BusyBox `logd` ring buffer. Nothing is searchable in one place and
  nothing expires cleanly.

So the request is well-founded: the visibility gap is real. The plan below
gets to "one Grafana with the dashboards that actually matter, one Loki for
logs, one alert path that pushes to the phone" in three phases, ordered by
value/cost. It is deliberately **not** "instrument everything" -- 23 CTs is
a lot of moving parts, and the deploy gap (see the last section) means each
new per-CT agent is a hand-built, hand-recorded thing.

---

## Design principles (so the stack stays small)

1. **Co-locate, do not sprawl.** Reuse the existing prometheus CT 122 as the
   collector home (alertmanager, blackbox_exporter, tailscale-exporter all
   run there as extra binaries -- they are tiny). Add exactly **one new CT
   for logs** (`loki`, proposed CT 130). Do not give every exporter its own
   CT.
2. **Push-only notifications, pull-mostly metrics.** ntfy stays the single
   delivery channel to the phone (the existing pipeline is good -- no need
   to add PagerDuty/SMTP/etc. on a homelab). Metrics stay Prometheus
   pull-model. The bridge between them is **Alertmanager -> ntfy** (one
   small webhook shim), added once.
3. **node_exporter on the metal, not in every CT.** PVE-exporter already
   gives per-CT CPU/mem/disk/net; running node_exporter inside all 23 CTs
   is redundant churn. Run node_exporter on the 5 PVE hosts + the router +
   truenas (host view), and let PVE-exporter cover the CT-interior view.
4. **Logs: ship journald, do not install an agent in every box by hand
   when avoidable.** Use journald's native remote upload from the PVE hosts
   + run promtail/Alloy *inside* the CTs that matter (a curated subset, not
   all 23), and forward TrueNAS/router logs via their native syslog-to-remote
   so no agent touches the read-only/poky OSes.
5. **One "is it up" signal source, used three ways.** `blackbox_exporter`
   pings all HTTPS endpoints (the 20 web CTs + 5 PVE consoles + truenas UI).
   The same results feed a Grafana "service health" board, fire
   ntfy alerts on 3-consecutive-probe failure, and double as an uptime
   history. Don't build three separate health checks.

---

## Phase 1 -- make the existing stack actually useful (highest value, ~1 day)

This phase touches **only CT 122 (prometheus)** and the 5 PVE hosts. No new
CTs, no router yet.

### 1a. Add node_exporter to the 5 PVE hosts

`node_exporter` (static Go binary) on pve-thermaltake / -aspiree15 / -aspires
/ -framework / raspberrypi, on `:9100`, bound to the **LAN** interface
(scraper reaches it over the tailnet host IP which already routes). Add to
prometheus.yml a `node` job scraping `pve-<node>.tail54538d.ts.net:9100`.
Now you have real per-host CPU/RAM/disk/net/filesystem metrics for the
cluster fabric -- the missing layer that explains *why* a node flaked.

Honest caveat: PVE hosts run corosync over the LAN; put node_exporter on the
tailnet IP so scraping stays off corosync. The Pi is arm64 -- use the
`node_exporter` arm64 static build (it's not in raspbian apt by default, but
the binary Just Works).

### 1b. Add dashboards to Grafana (datasource already exists)

Grafana (CT 123) already has its Prometheus datasource (`prometheus`, uid
`afrtfru117lz4c`, `http://prometheus.tail54538d.ts.net:9090`). **No datasource
work needed** -- just add dashboards. Choose one mechanism:

* **Provisioning files** (recommended): put dashboard JSON in
  `/etc/grafana/provisioning/dashboards/` with a provider yaml, committed to
  this repo under `services/grafana/`. Nothing to gitignore (board JSON has
  no secrets). Leave the existing DB-created datasource as-is (the
  provisioning `datasources/prometheus.yml` is intentionally empty with a
  comment pointing at the DB uid; keep that convention).
* Or **API import**: `curl` the JSON via the grafana HTTP API. Less
  reproducible -- the file-in-repo path is the better one.

Dashboards to add:

  * **PVE cluster overview** -- the community `prometheus-pve-exporter`
    dashboard (njamemonen/proxmox-pve-dashboard or similar). The "is my
    cluster healthy" board: the 5 nodes' CPU/mem/write/read IOPS, per-CT
    resource snapshots, and the `pve_ha_state` / `pve_lock_state` counters
    (the HA/lock data prometheus already collects today, just unvisualized).
    Gives the macro view that is currently invisible.
  * **Node host overview** -- the standard node_exporter board
    (`node-exporter-full` JSON on grafana.com). Gives per-host CPU/mem/disk
    fill/net. Depends on 1a landing first (no node_exporter => this board is
    empty).

That's 2 dashboards, both free, community-maintained. The "more dashboards"
ask is *partially* satisfied here by making grafana non-empty and useful.
More boards land in Phases 2-3.

**Alerting-rail decision (Alertmanager vs grafana-native):** Grafana 13 has
`unified_alerting` already configured (just unused). Two viable rails to ntfy:

* **(A) Standalone Alertmanager** (on CT 122) -- the classic prometheus path;
  any prometheus rule fires; AM -> ntfy via a small webhook shim. Decouples
  alerting from grafana (grafana can be down, alerts still fire).
* **(B) Grafana-managed alerting** -- define alert rules inside grafana
  (unified alerting), contact point = webhook -> ntfy bridge. One fewer binary
  (no Alertmanager), but couples alert delivery to grafana uptime, and grafana
  is a single CT that can be HA-restarted/out during an incident.

I recommend **A** for the same reason prometheus scrapes are decoupled from
grafana today: a grafana rebuild shouldn't silence alerts. (Grafana-managed
alerting also has rough edges at homelab scale.) Either is buildable; A is
the lower-surprise choice.

### 1c. blackbox_exporter + a "service health" dashboard + 1 alert

`blackbox_exporter` (HTTP prober) on CT 122. Configure it to probe (over
the tailnet) all 20 web CT HTTPS endpoints + 5 PVE `:8006` consoles +
truenas UI -- i.e. **the same 25-endpoint set you already curl by hand**.
Add it as a prometheus scrape target with `__param_target` relabel.

Dashboards:

* **Service health / uptime** -- green/red grid of all 25 endpoints with
  latency history + cert-expiry countdown (blackbox gives
  `probe_ssl_cert_expiry` for free -- this single panel
  *replaces the manual cert-renewal verification*).

Alert (the first real alert rule -- goes to Alertmanager, see 1d):

* `up == 0` for any blackbox `instance` for **3 consecutive probes** (90s)
  -> `ntfy` phone push. The 3-probe gate kills the tailnet-IP-rotation
  flakiness that has burnt every ad-hoc probe check so far -- one blip is
  not an alert.

### 1d. Alertmanager -> ntfy (the alerting loop)

Run **Alertmanager** on CT 122 (same CT, one more binary). Wire it into
prometheus.yml `alerting.alertmanagers`. Then bridge to ntfy:

* Option A (recommended): the small `alertmanager-ntfy` webhook forwarder
  (one Go binary). Alertmanager's `webhook_configs` points at it; it
  formats the alert group and POSTs to
  `https://ntfy.tail54538d.ts.net/homelab-<secret>` with `Priority: high`.
  Reuses the existing ntfy topic + phone subscription -- zero new phone
  config.
* Option B: extend the existing `services/ntfy/ntfy-slack-bridge.py` (which
  already has the secret path + ntfy publish creds) with an
  `/alertmanager` endpoint that renders the AM JSON into a Title/Message.
  One less binary, one more thing in the bridge.

Result: **any prometheus rule** now reaches the phone. That is the rail that
all of Phase 2+ alerting rides.

### 1e. Wire the silent failure paths to ntfy directly (no metrics needed)

Several things alreadyJustNeedAPing and shouldn't wait for Phase 2. Each is
a one-line `curl` added to an existing cron/unit, publishing to the same
homelab-`<secret>` topic:

| script / path | today | add |
| --- | --- | --- |
| `renew-pve-tls.sh` (each node) `/etc/cron.d/renew-pve-tls` | logs to mail-to-root | `|| curl ntfy "cert renewal FAILED on $HOST"` |
| `renew-truenas-tls.py` cron (id=1) | silent | publish on non-zero exit |
| `pve-shared-remount.sh` (`services/pve-shared-nfs-remount/`) | logs `/var/log` silently | publish **when it actually remounts** (this is the event you'd want to know about -- it means NFS was down) |
| Proxmox vzdump finish | mail-to-root (often unset/SWAKS) | `notification target` webhook -> ntfy (PVE 8 supports notification targets incl. SendNotification endpoints; ntfy via the same Slack-bridge trick or an SMTP-to-ntfy) |
| PVE HA state change | not at all | the `ha-manager` master emits events in `/var/log/pve/ha/`; a small tailer (or `pvenode` notification) -> ntfy. This directly catches the `error`-state cascade from the 2026-07-30 outage |

These five close most of the "silent failure" holes from the existing runbook
without any new infrastructure.

Phase 1 net: real host metrics, 4 dashboards (PVE-overview, node-overview,
service-health, plus speedtest already collected), cert-expiry visibility,
and a working phone-alert rail. ~1 day, no new CTs.

---

## Phase 2 -- centralized logging with Loki (~1 day)

One new CT: **CT 130 `loki`** on pve-thermaltake (disk on `pve-shared`, 16G
-- enough for weeks of homelab text logs at default retention). Single-node
monolithic mode (the file TSDB, no object store needed at this scale).
Retention via the built-in compactor, 30-day cutoff -- configurable later.

### Grafana side

Add Loki as a second provisioned datasource (CT 123). The same Grafana now
has a "Logs" tab next to every dashboard panel (Grafana 11 natively toggles
between PromQL and LogQL) -- no extra UI.

### Collectors: three tiers, by host type (this is the honest part)

The hard part of "centralize logs for everything" is that you have **five
distinct host types** and they are not equally agent-installable. Don't
pretend they are.

| host class | count | transport | what runs where |
| --- | --- | --- | --- |
| PVE hosts | 5 | **journald remote upload** (`systemd-journal-upload` -> `systemd-journal-remote` on CT 130) | nothing extra on the host -- systemd is built in; one `/etc/systemd/journal-upload.conf` per host |
| CTs -- curated set | ~8 (see below) | **promtail inside the CT**, reading local journald -> over-the-tailnet push to CT 130 | promtail static binary + a tiny unit per CT |
| TrueNAS host | 1 | **remote syslog** (TrueNAS web UI "System > Advanced > Syslog server" -> CT 130:514) | no agent on the RO base -- native |
| GL-MT2500 router | 1 | **busybox syslogd -R <ct130>:514** (or `logd` forward) | no agent -- native |
| The other ~15 CTs | 15 | **skip for now** | leave local-via-pct-exec |

Which 8 CTs get promtail in Phase 2 (the ones whose logs you actually grep
during incidents): **107 forgejo, 108 postgresql, 104 freshrss, 102
jellyfin, 126 protonmail-bridge, 125 bichon, 122 prometheus, 128 ntfy**.
Everything else is a CT whose logs you've never needed to chase; adding an
agent to all 23 is churn that buys little. Add more later if a gap bites.
(Same logic as "node_exporter on hosts not CTs": collect where the
diagnostic value is, not at 100% coverage.)

### The receive side (CT 130)

CT 130 runs three small listeners, all behind tailscale (plan a second
tailnet node or share -- simplest is one more tailnet node for CT 130):

* `systemd-journal-remote` on `:19532` (HTTPS, accept the PVE-host uploads)
* `syslog-ng` (or Vector) on `:514` (RFC5424) for truenas + router
* `loki` itself, with sources = `journal` (the received .journal files)
  + `syslog` from the relay. Loki ingests both.

Honestly simpler variant if `systemd-journal-remote` feels fiddly: run
**Vector** on CT 130 as the single intake (Vector speaks journal-upload,
syslog, and pushes to Loki with one config) and dump `journal-remote`
entirely. Vector is a good single-knife choice here. Pick Vector if you want
one moving part; pick journal-remote if you'd rather stay on systemd-pure
components. Either is fine; Vector's fewer moving parts is what I'd build.

### Dashboards that come from having logs

* **Incident timeline** -- a dashboard whose only panel is a Loki "events"
  panel filtered to `severity=warning|error|crit` across all sources. During
  an outage this is the single thing you look at.
* **PVE HA / corosync board** -- Loki query on `journal` for the 5 PVE
  hosts filtered to `corosync|pve-ha-lrm|pvestatd` -- the *narrative* of an
  HA failover, which pure metrics can't give you. (This is exactly the
  2026-07-30 pve-framework watchdog story -- you'd have seen the
  corosync/storage-thrash in one place instead of grepping 5 nodes.)
* **Audit board** -- successful sudo / SSH login events across hosts (the
  node_exporter textfile or the journald `session` records).

### Honest caveats for Phase 2

1. **Disk.** 16G on pve-shared for Loki is a budget, not a guarantee.
   nginx journals can chatter; the prometheus CT already eats a few hundred
   MB/mo from TSDB. Watch the `loki_ingester_chunks_stored_total` / disk
   panel in the board and raise to a dedicated `pve-log` volume if it grew.
   Keep a 30-day compactor retention so it self-trims.
2. **Log volume honesty.** If forgejo's `DEBUG` or jellyfin's transcode
   logs are on, Loki eats disk fast. Promtail config should drop
   `level=debug` lines client-side for the noisy services -- one relabel.
3. **Deploy gap (see last section).** Each per-CT promtail unit is another
   hand-installed thing that `~/dotfiles/migrate.sh` can't reproduce. The
   services can be captured under `services/promtail/<ctid>/` here; the
   *install* is still manual SSH like every other PVE-side file.
4. **The Pi doesn't really have journals worth shipping.** It's a witness
   node with no workloads; upload its corosync/quorum lines only.

Phase 2 net: one searchable log store, an incident-timeline panel, a
HA/corosync narrative board, truenas + router logs forwarded with no agents
on the awkward boxes.

---

## Phase 3 -- tailnet stats, router involvement, app dashboards (~half day)

### 3a. Tailnet stats -- the tailscale-exporter

Run **`tailscale-exporter`** (community; queries the Tailscale HTTP API
with a tailnet-scoped OAuth key) on CT 122 as one more scrape target. It
exposes per-device: `last_seen`, `online`, `derp` region, advertised/accepted
subnet routes, exit-node flags, and rx/tx counters.

Dashboard: **Tailnet overview** -- a table of every node (the 5 PVE hosts +
truenas + router + 23 CTs + your laptops/phone), last-seen age, online flag,
DERP latency. One rule -> Alertmanager -> ntfy: `last_seen > 5m` for any
device that should be always-up (the PVE hosts + truenas + router + the 23
CTs). Catches a CT silently dropping its tailnet (a recurring failure mode
documented throughout this repo's tailscale notes).

Honest note: tailnet rx/tx counters from the Tailscale API are coarse and
per-device-aggregate; if you want per-destination flow, that's `tailscale
netcheck`/pcap territory and out of scope. The exporter is good enough for
"who's up, who's roaming, where's DERP routed."

### 3b. Router involvement -- yes, worth it, with caveats

The GL-MT2500 (OpenWrt 21.02, BusyBox, arm64) is the **WAN gateway + the
LAN DHCP/cert-pin authority + a tailnet subnet-router/exit node**. It is
unobservably central. Bring it in, but know its limits:

* **Metrics:** run a **static `node_exporter` arm64 build** on the router
  with the `--collector.textfile` + `--collector.netstat` + `--collector.network`
  + disable the ones OpenWrt lacks (`--no-collector.bonding` etc., the
  blocklist is small). Plus a tiny textfile script emitting WAN/LAN interface
  bytes (already in `/proc/net/dev`), wifi client count (`iw dev ... station`
  dump), PPPoE/WAN up-time. Scrape from CT 122 over the tailnet (the router
  is `gl-mt2500.tail54538d.ts.net`, already tailnet-addressable).
* **Logs:** forward the router syslog ring buffer to CT 130 via
  `logread | busybox syslog -R <ct130>:514` (or configure `logd`'s
  `-S <ct130>:514`). No agent install -- busybox ships the client.
* **Dashboard:** **Router / WAN** -- WAN rx/tx throughput (the only honest
  view of your uplink saturation), LAN per-host bytes, wifi client count, WAN
  uptime + error/drop counters, the tailscale interface on the router. Pair
  with a numeric "WAN down" alert -> ntfy (probe the router's
  `/proc/net/dev` WAN interface; if rx bytes flat for 2m, alert).
* **Caveat:** GL-MT2500 RAM is modest (often 512MB-1GB). The OpenWrt image is
  newer than the repo docs imply -- kernel 5.4.211, a **June 2025** aarch64
  build (NOT the frozen old OpenWrt I'd assumed), so a static arm64
  `node_exporter` (musl build) should run cleanly. The textfile-script +
  busybox-syslog approach is the lowest-RAM path; avoid collectd (more
  packages, more upgrade risk). If a static binary is flaky, fall back to
  **snmpd + snmp_exporter** from CT 122 (pulls, nothing to install but an
  snmpd config). node_exporter is the nicer choice given the recent image;
  SNMP is the fallback. The router also runs a **WireGuard client**
  (`wgclient` interface, alongside `tailscale0`) -- worth surfacing on the
  router board (is the WG tunnel up / last handshake).

### 3c. App dashboards (pick what you actually look at)

A few services have native exporters worth the install (each is a scrape
target + an imported board):

* **Jellyfin (102)** -- the jellyfin prometheus exporter: active streams,
  transcode HW/SW split, library item counts. Tells you when jellyfin is
  silently transcoding on CPU despite the GPU passthrough.
* **Forgejo (107)** -- forgejo exposes a `/metrics` endpoint natively
  (enable it): repo/users/PR counts, git operations. Gives a "is anyone
  using the git server" heartbeat.
* **Speedtest (103)** -- already scraped (`/prometheus`). Add a board that
  plots up/down/latency history + jitter. Trivial; it's free data you
  already collect.
* **Postgres (108)** -- `postgres_exporter` pointed at the postgres CT
  over the tailnet: connections, txn rate, db size, slow-query-ish. The
   backend for freshrss + others; worth one board.
* **Vaultwarden (109)** -- small `/metrics` exporter or skip. Low value.

Don't add an exporter to every service. Each is install + scrape config +
board maintenance. The five above are the ones with real diagnostic value
during incidents.

### 3d. Proxmox-native notification targets (the vzdump/HA case)

Proxmox 8 has a first-class notification system (Datacenter > Notifications)
with `match`-based routing and webhook/SMTP/gotify/etc. targets. Add an
**ntfy webhook target** there (the same homelab-`<secret>` path) and route:

* vzdump job results (success/fail) -> ntfy.
* HA state changes -> ntfy.
* package updates available -> ntfy (or drop these -- can be chatty).

This replaces the "wire vzdump mail-to-root" idea from Phase 1e with the
supported path. Keep the hand-rolled `curl` shims for the things PVE doesn't
emit (the cert crons, the NFS-remount script).

---

## What new CTs / binaries this all costs

| component | where | new CT? | new binary on existing box? |
| --- | --- | --- | --- |
| node_exporter (hosts) | 5 PVE hosts | no | 5x (one per host) |
| node_exporter (router) | GL-MT2500 | no | 1 (static arm64) |
| blackbox_exporter | CT 122 | no | 1 |
| alertmanager | CT 122 | no | 1 |
| alertmanager-ntfy shim | CT 122 (or CT 128 bridge) | no | 1 (or extend bridge .py) |
| tailscale-exporter | CT 122 | no | 1 + an OAuth key |
| loki | **CT 130 (new)** | **yes** | -- |
| syslog intake (Vector) | CT 130 | (same CT) | (part of loki CT) |
| promtail (curated CTs) | 8 CTs | no | 8 (one per curated CT) |
| jellyfin/postgres/etc. exporters | a few CTs | no | ~3-4 |

Net: **1 new CT** (130), a handful of binaries co-located on CT 122, a
static binary on each PVE host + the router, and promtail on 8 CTs. Not a
fleet.

---

## The deploy gap (be honest about it)

Per [`ideas/proxmox-iac.md`](../ideas/proxmox-iac.md), **nothing in `~/dotfiles/migrate.sh`
provisions PVE hosts or PVE CTs.** That means every new thing above
(node_exporter on the 5 hosts, blackbox/alertmanager/tailscale-exporter on
CT 122, promtail on the 8 CTs, node_exporter on the router) is a
**hand-install over SSH**, recorded in a `services/<name>/README.md` like
the existing `renew-pve-tls.sh` / `renew-truenas-tls.py` pattern. The repo
captures *what to deploy*; it does not *deploy* it. Re-converging a rebuilt
host still means re-doing it by hand until the proxmox-iac layer exists.

That's not a reason to skip this -- it's the same gap every other homelab
config has. But it does mean: **commit each deploy as a
`services/<component>/README.md` with idempotent install steps**, the way
the existing services do, so the next box doesn't depend on this session's
memory.

Recommended capture scheme for this proposal:
* `services/observability/README.md` -- the master plan (links to this doc).
* `services/observability/prometheus.yml` -- the evolved scrape config
  (rules + alertmanager refs + blackbox + node target).
* `services/observability/alerts.yml` -- all the prometheus rules.
* `services/observability/grafana/` -- the provisioned datasources.yaml +
  dashboard JSONs (gitignored are the secrets; nothing real is secret here,
  so commit all of it).
* `services/observability/loki/` -- CT 130 setup (loki config, Vector/syslog
  intake config, retention).
* `services/observability/node-exporter-host.sh` -- idempotent install for a
  PVE host (download static binary, unit, enable, verify scrape).
* `services/observability/node-exporter-router.sh` -- same for the GL-MT2500.
* `services/observability/promtail-ct.sh` -- idempotent per-CT promtail
  install (takes a CT vmid).
* `services/observability/tailscale-oauth.md` -- how to mint the
  tailnet-scoped OAuth key for the exporter (stored where the other secrets
  are -- not in this repo).

---

## Recommended order if you say go

1. **Phase 1a+1b+1c+1d in one sitting** (node_exporter on hosts, grafana
   datasource + 2 boards, blackbox + service-health board, alertmanager ->
   ntfy). This is the biggest visibility jump for the least new surface and
   it makes *every later alert* ride the same rail. Skip 1e's hand-rolled
   curls if you want -- they're nice but not blocking.
2. **Phase 3a + 3d next** (tailscale-exporter + tailnet board + PVE-native
   notification targets). Cheap, high signal on the parts you care most
   about (who's on the tailnet, did backups succeed, did HA move a CT).
3. **Phase 2 (Loki) third.** It's the most moving parts and the lowest
   urgency -- you currently lose nothing searchable during an incident
   that you can't `pct exec N -- journalctl` in 30s. Centralized logging is
   a comfort+scales-build, not a fix for a current pain. Do it once the
   metrics+alert rail is solid so you're not debugging Loki *and* an outage
   at the same time.
4. **Phase 3b (router) + 3c (app exporters) last**, opportunistically -- add
   the router the next time you touch it; add app exporters as you
   incidentally open those services.

This ordering front-loads the things that turn *silent failures into phone
pushes* (the actual ask behind "more ntfy notifications") before the
comfort-only logging layer.

---

## Open questions for you

* **OAuth key for tailscale-exporter** -- OK to mint a read-only
  tailnet-scoped OAuth key (we'd store it the way the other ntfy secrets
  live -- not in this repo)? This is the only new secret the whole plan
  needs.
* **CT 130 host placement** -- pve-thermaltake (it's the desktop with free
  RAM and already hosts prometheus-adjacent stuff) is my default;
  pve-framework has lots of free RAM too but is the node that's been least
  stable. Preference?
* **promtail scope** -- agree with the **8 curated CTs** over "all 23"? I'd
  rather add the 15th promtail when there's an incident that would've been
  caught by it than maintain 23 copies now.
* **router monitor transport** -- try the static node_exporter first
  (nicer board, should run on the June-2025 OpenWrt build), fall back to
  snmpd if the binary won't cooperate? Or just go snmp from the start for
  predictability?

---

## Verified current state (probed live 2026-08-30)

Everything in the TL;DR above is from direct probes, not the docs (the docs
in `docs/services.md` are STALE on CT placement -- post-2026-07-30 HA
migrations moved several CTs home). Current live placements:

* pve-thermaltake: 101, 102, 104, 107, 111, 122, 127
* pve-aspiree15: 109, 119, 124
* pve-aspires: 103, 105, 106, 112, 113, 118, 120, 121
* pve-framework: 108, 123, 125, 126, 128
* raspberrypi: (witness only)

**Prometheus (CT 122, pve-thermaltake):** full config inspected. 3 jobs
(prometheus/self, pve x5 nodes, speedtest-tracker) with the pve job using
the standard `__param_target`/instance relabel to
`prometheus-pve-exporter.tail54538d.ts.net:9221`. `/etc/prometheus/` holds
only `prometheus.yml` + two Jul-11 `.bak` files; no `rules/`, no `conf.d/`.
`/api/v1/targets` -> all 7 `health: up`. `/api/v1/rules` ->
`{"groups":[]}`. `alerting.alertmanagers.targets` -> commented out.
`/api/v1/status/tsdb` -> 7,144 series; top metrics `pve_ha_state`,
`pve_lock_state`, `pve_up`, `pve_disk_usage_bytes`, `pve_memory_usage_bytes`,
`pve_uptime_seconds`, `pve_cpu_usage_*`.

**Prometheus-pve-exporter (CT 124, pve-aspiree15):** service `active`.
Scrape `?target=pve-thermaltake...` returns `pve_up`, `pve_ha_state`, etc.
(The `/etc/prometheus-pve-exporter/` dir from the docs does NOT exist on this
CT; the config/credentials live elsewhere -- the service runs regardless.)

**Grafana (CT 123, pve-framework):** Grafana **13.1.0**.
`/etc/grafana/provisioning/` has the stock sample yamls + one real file:
`datasources/prometheus.yml` which is intentionally `datasources: []` with a
comment "already exists in the DB as 'prometheus' (uid afrtfru117lz4c). No
file-based provisioning needed". `grafana.db` is 1.7M; sqlite counts:
`dashboard` 0, `data_source` 1, `alert_rule` 0, `alert_rule_group_v2` 0,
`notification_policy` 0, `contact_point` 0. API `/api/health` ->
`version 13.1.0`. Datasource row: name=prometheus, type=prometheus,
url=`http://prometheus.tail54538d.ts.net:9090`, uid=`afrtfru117lz4c`.
So: working datasource, no dashboards, no alerts.

**ntfy (CT 128, pve-framework):** server active on `127.0.0.1:2586`,
bridge active on `127.0.0.1:2587`; `base-url https://ntfy.tail54538d.ts.net`,
`auth-default-access deny-all`, admin user `nate`. tailscale serve proxies
`/` -> `localhost:2587`. TrueNAS `alertservice.query` -> exactly one service:
`{"name":"ntfy (homelab)","type":"Slack","url":"https://ntfy.tail54538d.ts.net/truenas-f7e57b5f699d3d35","level":"WARNING","enabled":true,"id":3}`.
Cross-host grep of `/etc/cron*` + `/etc/systemd/system/*.service` on all 5
PVE nodes for the string "ntfy" -> NO other publishers found. Only TrueNAS
publishes today.

**Host-level (all 5 PVE nodes):** `systemd-journal-remote` +
`systemd-journal-upload` -> `inactive` on all 5. No `promtail` / `vector` /
`loki` / `node_exporter` / `journal-remote` binaries present. No
`journal-upload.conf` / `journal-remote.conf` configured. `journalctl
--disk-usage`: thermaltake 641M, aspiree15 242M, aspires 656M, framework
1.2G, pi 118M (no retention cap enforced). No ntfy curl in any cron on any
host.

**Per-CT agents:** probed all 23 CTs for `promtail` / `node_exporter` /
`vector` / `loki` binaries -> none present in any CT. Probed app-native
metrics endpoints: forgejo CT 107 `/metrics` -> empty (metrics NOT enabled
in app.ini). jellyfin CT 102 has a listener on `:9079` but `/metrics` returns
nothing -- not a metrics exporter (jellyfin has no native prom exporter).
postgres CT 108 -> no `postgres_exporter`, no `:9187` listener.

**tailscale serve (sampled):** every web CT proxies `/` ->
`http://localhost:<port>` only; NONE expose a separate `/metrics` path.
PVE-exporter (like prometheus itself) is scraped on its RAW tailnet port
(`:9221` for the exporter, `:80` for speedtest) over HTTP -- the precedent
for any future raw-port scrape (node_exporter `:9100`, app exporters).

**Router (GL-MT2500, root@gl-mt2500.tail54538d.ts.net):** kernel
`5.4.211 #0 SMP Tue Jun 24 10:48:30 2025 aarch64` -- a June-2025 build, NOT
the frozen OpenWrt the older docs imply. Interfaces: `eth0` (WAN),
`eth1`/`br-lan`, `wgclient` (a WireGuard client tunnel, separate from
tailscale), `tailscale0`. No `snmpd` / `collectd` / `node_exporter` /
`promtail` installed. No syslog/logd remote-forward configured. tailscale
serve status on the router returns nothing (it's a subnet-router / exit,
not a serve host).

**TrueNAS (nate@truenas):** RESTful API v2.0 reachable. One alertservice
(the ntfy/Slack one above). `cloudsync` tasks 4-8 (the 5 per-leaf B2 tasks
from the 2026-07-30 rearchitect). No grafana/loki app currently installed
(no `app.available` match).

**Repo + dotfiles:** `~/Projects/homelab` git log: 6 commits, none
observability-related besides the existing `services/ntfy/` +
`docs/notifications.md`. No `services/grafana/`, `services/prometheus/`, or
`services/observability/` dir exists yet. `~/dotfiles` migrations: none
observability-related (`rg` for grafana/prometheus/loki/alertmanager/
node_exporter/promtail/tailscale-export across `root/` -> nothing). Confirms
the deploy gap: nothing in either repo provisions any of the proposed
components; it is all live-only today.

**Net correction vs the first draft of this doc:** the original TL;DR said
grafana had "zero provisioned datasources" and was "the stock empty install".
That was wrong -- grafana has a working DB-created Prometheus datasource.
Corrected above. Every other premise (no node_exporter, no centralized
logging, no alert rules, ntfy wired only to TrueNAS) was confirmed by direct
probe.