# Observability design: Grafana dashboards + the BI layer

Operator request 2026-11-26, filed before v3 continues. Companion
stories: OPS-29 (Grafana observability), USER-20 (Superset BI).

## The split rule (decide by data shape, not by tool preference)

**Grafana** owns anything that is a *time-stamped measurement of a
running system*, sampled continuously, needed at a glance, and
alertable: "is the fleet healthy, and what is it doing right now."
Prometheus/loki are the stores; grafana is the face.

**Superset** owns anything that is a *record you will JOIN with
other records*: spend data, learning progress, repo activity,
personal usage stats. Prometheus is a terrible BI store (no joins,
short retention, no ad-hoc dimensions); postgres is a great one.
Superset's sources = the per-service databases (docs/data.md's
centralize-for-analytics goal) + daily-pulled external data.

Overlap zone: a metric worth BOTH (e.g. media library growth over
months) lives in prometheus for the "now" view; if it needs joins,
a periodic puller also lands a row in postgres for superset.

## Current state (what we already collect)

- prometheus: node_exporter on 5 nodes + all 12 guests (:9100),
  postgres-exporter (.14:9187), forgejo in-app metrics (.52:3000).
- loki: promtail ships journald from every host (labels: host, unit).
- grafana: datasources provisioned, ZERO dashboards (built-in-UI
  only so far; docs/data.md commits dashboards-as-provisioning).

## GAPS -- what we do not collect yet

| Gap | Idiomatic fix | Notes |
| --- | --- | --- |
| Proxmox-level metrics (CT usage, vzdump jobs, storage pools) | prometheus-pve-exporter against the homelab-ops API token | one process on the monitoring CT; also gets vzdump task states |
| Truenas (datasets, ARC, scrub, B2 sync lag, pool health) | SNMP exporter (native to TrueNAS) or truenas API exporter | SNMP is the appliance-native read-only channel |
| OPNsense (per-interface traffic, states, CPU) | SNMP exporter (OPNsense ships SNMP) | also unblocks a "network speed" panel |
| GPU (temp, VRAM, transcode sessions) | DCGM exporter (NVIDIA's own) or dcgm-lite | host-level; devnodes already passthrough-adjacent |
| UPS load / power draw | nut-exporter (pairs with OPS-25) | power panels wait for the UPS story's hardware step |
| Packages + updates per host | node_exporter TEXTFILE collector scripts (updates-available, reboot-required, last-converge) | the canonical trick for "no exporter exists" cases |
| Services up (ports/fronts) | blackbox exporter (ping/http probes) | pairs with the v4 offsite-alerting design (design/offsite-alerting.md) |
| Tailscale (device count, key expiry, serve fronts) | textfile collector via the tailscale API (keys route works) | device routes are console-only (recorded trap) |
| Alert counts/types | alertmanager metrics (when the v4 alerting tier lands) | the "alerts" dashboard is empty until then |
| sshd auth events (usage, failures) | already IN loki (journald) -- just needs dashboards | promtail already ships sshd units |
| systemd restarts | node_exporter systemd collector flag + loki unit-restart events | one flag + queries |
| Vaultwarden/media/DB row counts | textfile collectors querying each service's own DB nightly | e.g. items count, 715-movie count, navidrome tracks |
| Cost-of-running estimate | textfile collector: static watts-per-host table (measured once with a meter) x up/running + local utility rate | external APIs only for the utility rate if we want it live; a one-time meter reading beats an API guess |

Textfile collectors are scheduled jobs: cronmaster owns them once
it is live (see [cronmaster-scheduled-jobs.md](./cronmaster-scheduled-jobs.md));
systemd timers are a temporary measure until then.

## The dashboards (one high, many low)

### 1. THE dashboard: "Homelab -- at a glance"

Rows, top to bottom:
1. Fleet health strip (stat panels): hosts up x/17, guests up x/12,
   quorum 5/5, scrape success %, fronts-200 count, alerts firing.
2. The board: one row of per-host status "panels" (green/red at a
   glance, click-through to the node's low-level dashboard).
3. Cluster + guests: aggregate CPU / memory / load heatmap (nodes vs
   guests, one panel each).
4. Storage: truenas pool usage, per-node disk fullness (bars), B2
   last-sync age, vzdump last-success age.
5. Network: LAN throughput in/out (per node interface), top talkers.
6. Events (loki): restarts, ssh auth failures, unattended-update
   installs -- last 24h, count + sparkline.

Everything on this dashboard is a recording rule (pre-aggregated) so
the front page renders in one pass.

### Low-level dashboards (one per concern, linked from the top)

| Dashboard | Contents | Sources |
| --- | --- | --- |
| Node detail (per host) | cores, mem, disk IO, net, temps, uptime, updates pending, GPU (thermaltake only) | node_exporter + textfiles + DCGM |
| PVE cluster | CT cpu/mem per guest, vzdump job history, storage pools, task errors | pve-exporter |
| Truenas | pool health, ARC hit, dataset usage, B2 sync age, scrub | SNMP/API exporter |
| Router / network | per-interface traffic, states, DHCP pool usage, top flows | SNMP |
| Postgres | connections, db sizes, slow queries (when enabled), per-db row counts | postgres-exporter + textfiles |
| Forgejo hub | in-app metrics (users, repos, sync queues) + push-mirror lag | forgejo metrics + textfile |
| Logs (loki) | error rate by unit, ssh auth events, restarts, journal volume | loki |
| Storage + backups | vzdump ages, B2 lag, snapshot ages, disk growth trends | pve-exporter + truenas exporter |
| Media | library counts (movies/music/books), transcode sessions, GPU state | textfile + DCGM |
| Power + cost | watts estimate per host, monthly cost estimate, UPS load (post-OPS-25) | textfile + nut-exporter |
| Tailnet | device count, key expiry ages, front status | textfile + blackbox |
| Security | ssh failures by host, sudo use, password-access attempts, alert history | loki + alertmanager |

## Dashboards-as-code

All of it provisions from the grafana role (JSON in
playbooks/roles/grafana/): datasources already land this way;
dashboards + recording rules follow. A dashboard built by hand in
the UI is unmanaged state (docs/data.md's rule: the repo is the
backup for grafana). Recording rules land as a prometheus role rule
file; alert rules wait for the v4 alerting tier.

## Superset BI -- the personal-data layer (USER-20)

Sources, grouped by how they are pulled:

| Group | Sources | Pull method |
| --- | --- | --- |
| Code hosting | github, codeberg | REST APIs (both first-class; codeberg = our own push chain) |
| Learning | leetcode, neetcode, exercism, codecrafters, pluralsight, udemy | mixed: official APIs where they exist (exercism, codecrafters), export files where APIs refuse (udemy usage reports) |
| Spend | privacy.com, cloaked.com, amazon order history | privacy.com + cloaked have APIs; amazon = order-history export CSV |
| AI/tools | ollama.com, opencode.com | usage APIs/logs |
| Media | youtube, odysee | takeout (youtube watch history) + LBRY API |
| Local usage | debbie app-time, usage time | ActivityWatch self-hosted (the idiomatic personal-time tracker; logs to its own DB; superset reads it) |

The pull layer lands rows in a per-source schema of a dedicated
"analytics" database in the shared postgres (data.md: one database +
role per service). Pull jobs run as systemd timers / n8n flows (the
n8n keep exists; OPS-24 cronmaster is the general job runner) --
NOT unattended agentless magic; each pull is code. Superset then
reads: analytics schemas + per-service DBs (forgejo, navidrome,
vaultwarden read-only) + anything else the split rule routes there.

Honesty notes: leetcode/neetcode scraping terms may forbid API pulls
(neetcode has an API for progress; leetcode has a graphql endpoint
used by many community tools -- verify at story time); youtube data
is takeout-batch-shaped, not live; pluralsight/udemy APIs are
weak-to-absent -- expect manual export + upload for those two.
Anything that cannot be pulled cleanly gets an export-dropbox
directory in the analytics schema instead of a scraper we would
have to defend.

## Sequencing recommendation

1. OPS-29a: exporters + gaps closed (pve, SNMP truenas+opnsense,
   DCGM, textfile collectors, blackbox) -- the DATA must exist
   before dashboards can draw it.
2. OPS-29b: the high-level dashboard (recording rules + provisioned
   JSON), acceptance = one URL answers "is my homelab healthy".
3. OPS-29c: low-level dashboards, one story each or batched by
   theme (nodes, storage, network first -- they carry the most
   "I want to understand my homelab" weight).
4. USER-20 (superset): after OPS-29 lands the analytics habits;
   starts with the sources that have clean APIs (github, codeberg,
   privacy.com, cloaked, exercism, codecrafters) and the local
   postgres sources; takeout/export-shaped sources come last.

Cost/complexity guard: every new exporter is one more thing to
patch and one more scrape target -- the gap table is a MENU, not a
mandate; each item earns its place in a story review.
