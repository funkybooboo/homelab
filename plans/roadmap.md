# Roadmap

The queue. Arcs are the milestones (each ends with something running);
stories are the work (one file each in [stories/](./stories/)); the
constitution is [identity.md](./identity.md); the shipped record is
[history.md](./history.md). Every change serves one of the three roles.

## Where we stand (2026-11-22)

- v1 SHIPPED: all 5 nodes + truenas live on the new LAN, 5/5
  quorate (thermaltake .3, framework .4, aspiree15 .5, aspires .6,
  Pi .11 witness-only). Nothing was reinstalled: nodes renumbered in
  place ([history.md](./history.md) v1), the cluster turned out to
  already run PVE 9.2 (OPS-17's upgrade evaporated), the GPU is live
  on thermaltake, and the access model is complete end-to-end:
  `nate@pam` + the homelab-ops API token, router + truenas APIs
  under the nate identity, B2 verified.
- The plan shifted ON the revival evening (operator directive,
  recorded as issues item 8's second revision): the old CTs are
  cleaned out, NOT revived -- curation happens at build time (v2/v3)
  on a bare cluster.
- v1.5 SHIPPED 2026-11-22: the clean-out + access layer + hardening
  (OPS-20/21/22) -- the cluster is BARE and verified, the tailnet is
  THE access layer (subnet router + serve fronts + API token),
  good-ssh everywhere, TOTP on both PVE UI identities, and the
  tier-0 extraction insurance sits on debbie. See
  [history.md](./history.md).
- OPS-7 SHIPPED same day (the skeleton): manifest -> CT -> running
  service proven, idempotent, `make converge`/`make verify` real.
  A post-skeleton readiness pass swept the last old-fleet residue
  (55 /tmp debug scripts, 5 stale CT templates, the promtail
  shipper whose endpoint died with the old loki serve-front) and
  later a root-owned /home/tom/sources pve-cd-builder checkout
  from the May-2026 era (no account ever existed; swept
  2026-11-23 on the operator's word), plus de-staling six story
  notes + issues item 8 for the build-fresh reality. A full hygiene
  audit 2026-11-23 then decommissioned the old fleet's LIVE
  auto-update machinery from all 4 nodes (the hourly
  pve-reboot-controller WAS ARMED with live pmxcfs flags + a fresh
  lock -- unattended serialized cluster reboots were minutes away;
  auto-update.service/timer, the maint + ha-state-watch +
  renew-pve-tls crons, start-jellyfin + router-syslog-relay units,
  php packages on the framework node all swept; the new
  OPS-23 model is the only update system now). KEPT as verified
  live: the thermaltake GPU stack, laptop screen-off, the NFS
  self-healing glue (pve-shared-remount + nfs-check), vzdump, and
  the system disk-hygiene timers. Entering the
  service stories, the cluster carries
  exactly: 1 manifest-managed test CT, 1 base template, node glue
  (proxmoxer), and nothing else.
- NEXT: v3 -- the media fleet (USER-2) first, then the daily tools and
  the restored keeps. v2 SHIPPED 2026-11-25 (see the v2 section);
  carry-forwards are recorded there, not lost.
- Standing tooling: `docs/` (the live data-to-extract inventory),
  `ansible/inventory/` (LAN plan, host facts),
  `scripts/revive-node.sh` + the parked future-node tooling
  (`bootstrap`, `deploy-node-glue`, `setup-qdevice`).

## v0: Legacy archive -- SHIPPED 2026-11-06

[OPS-1 the legacy archive](./stories/OPS-1-legacy-archive.md) --
done: the old-fleet archive (guest catalog, old LAN, quirks +
incidents, extraction inventory) + `scripts/extract-legacy.sh`.
2026-11-21: per the operator's git-is-the-archive call, the
pure-history archive files were retired to git history;
`docs/data-to-extract.md` survives as the live inventory. The script
RUNS at the first hardware touch, after the truenas move (OPS-4).

## v1: Revival -- SHIPPED 2026-11-21/22

[OPS-2 the network plan](./stories/OPS-2-network-plan.md) (done),
[OPS-4 the truenas network move](./stories/OPS-4-truenas-network-move.md)
(done), [OPS-18 node revival](./stories/OPS-18-node-revival.md)
(done; supersedes OPS-5). OPS-3 (router) + OPS-6 (QDevice) stay
deferred to v5.

Shipped as built: truenas moved to .10 (the interface fail-safe
trap documented in the script), all 5 nodes renumbered in place via
`revive-node.sh` (framework needed no hardware fix; the Pi rejoined
as a 5th member + witness per operator directive), storage + host
DNS fixed, the GPU live on thermaltake, and the access model
completed 2026-11-22 (nate@pam + the homelab-ops API token,
verified live). The as-built record is [history.md](./history.md).

Ends with: the platform alive on the new LAN, nothing reinstalled,
and every step that did it is a script in the repo. The old CTs do
NOT come back (the plan shift) -- their remains are v1.5's first
story.

## v1.5: Clean-out + access layer -- SHIPPED 2026-11-22

The plan shift made the close-out its own arc: the old fleet's
remains went, the access layer finished, the hardening landed -- all
BEFORE anything was built, so v2 starts on a truthful platform.

[OPS-20 the cluster clean-out](./stories/OPS-20-cluster-clean-out.md)
(done -- gated by the tier-0 extraction landing outside the truenas
pool),
[OPS-21 the tailnet access layer](./stories/OPS-21-tailnet-access-layer.md)
(done -- subnet router + LE-cert serve fronts + API token),
[OPS-22 node hardening + LAN tails](./stories/OPS-22-node-hardening-lan-tails.md)
(done).

Ended with: a bare cluster (zero guests, zero orphans, zero stale
addresses), HTTPS-everywhere access from the tailnet, the good-ssh
state on every node, and second factors on both PVE UI identities.

## v2: IaC skeleton -- SHIPPED 2026-11-25

REVISED 2026-11-22 (the plan shift's final form): the old CTs are
cleaned out (v1.5), not revived, so v2 BUILDS the critical five
fresh -- the skeleton (OPS-7) creates guests via the PVE API and
each service restores its data from the extraction tarballs + the
`services/` as-was references. Curated resurrection, one story per
service; `make converge`/`make verify` become real.

SHIPPED AS BUILT: the observability foundation first (every guest
born with journald->loki, node_exporter, the five-family watcher +
daily heartbeat), then USER-1 vaultwarden (source build, vault
restored, operator-verified), OPS-9 the full hub restore -- the
operator's Option B: 17 users + 349 repos on the new forgejo
(CT 202), with the sync layer rebuilt as the old fleet ran it:
TWO gitea-mirror instances (CT 203 github->forgejo hub leg,
CT 204 github->codeberg leg; one shared role, base URLs
hostname-derived). Nightly schedules set; self-owned repos sync
green; the phantom-import class (pre-existing collaborator repos)
is kept STALE-BUT-PRESENT by operator policy, with the exclude
list as the follow-up. In-app forgejo metrics scraped (the only
service-internal exporter that exists in this tier). Plus the
completeness audit: every old-fleet service is now live, planned
(USER-6..13, OPS-24 + the ONCE trio USER-14..16), or consciously
deferred (USER-5 with its data warning).

Carried into v3 (recorded, not lost): the app exclude list for the
phantom class; the 32 DB-only repos (failed = broken page, not
stale); gitea-mirror ntfy wiring (the operator holds the URL);
the gitea-mirror upstream pin bump (3.54.0 -> 3.56.1 available).

[OPS-7 the IaC skeleton](./stories/OPS-7-iac-skeleton.md)
(done -- shipped 2026-11-22: manifest -> CT -> running service,
idempotent re-run proven),
[OPS-8 ntfy alerting](./stories/OPS-8-ntfy-alerting.md)
(infra live; alert wiring lands with the service stories),
[OPS-9 the forgejo mirror](./stories/OPS-9-forgejo-mirror.md),
[OPS-10 postgresql](./stories/OPS-10-postgresql.md)
(done -- the infra batch 2026-11-22: postgres + adminer, the old
fleet's forgejo + freshrss databases restored + live),
[OPS-11 the monitoring pair](./stories/OPS-11-monitoring-pair.md)
(infra live: prometheus + grafana + loki; dashboards/alerts land as
used),
[OPS-23 the update + maintenance model](./stories/OPS-23-update-model.md)
(done -- every guest born patchable, make update real),
[USER-1 vaultwarden restore](./stories/USER-1-vaultwarden-restore.md).

Ended with: the infra layer (postgres/adminer/ntfy/prometheus/
grafana/loki) built fresh from manifests with https bookmarks per
service (model B, issues item 4 revision), one service = one YAML +
one role, and the update/maintenance model in
[docs/maintenance.md](../docs/maintenance.md) + the data policy in
[docs/data.md](../docs/data.md).

## v3: Curation + media fleet

REVISED 2026-11-22 (the plan shift's final form): nothing stale is
stopped because nothing stale is built -- the curated list
(~12-15, issues item 6) is enforced at BUILD TIME. v3 adds the rest
of the curated services and the media fleet, verified on its GPU
node (thermaltake, CPU-decode fallback per the guest-mobility
design).

REVISED 2026-11-23 (operator directive, the completeness audit): a
two-hour old-fleet inventory (data-to-extract table + the 187
surviving vzdumps) found nine old services with recoverable data
and NO story. The operator kept ALL of them -- one story each now
(they outgrow USER-3's umbrella, which stays for the tier-3
browser tools + the curation decision):

[USER-2 the media fleet](./stories/USER-2-media-fleet.md),
[USER-3 daily tools](./stories/USER-3-daily-tools.md),
[USER-6 n8n](./stories/USER-6-n8n-restore.md),
[USER-7 linkwarden](./stories/USER-7-linkwarden-restore.md),
[USER-8 omnivore](./stories/USER-8-omnivore-restore.md)
(upstream dead; frozen-pin caveat accepted),
[USER-9 opengist](./stories/USER-9-opengist-restore.md),
[USER-10 jupyter](./stories/USER-10-jupyter-notebooks.md),
[USER-11 bichon mail archive](./stories/USER-11-bichon-mail-archive.md),
[USER-12 protonmail-bridge](./stories/USER-12-protonmail-bridge.md)
(pairs with bichon),
[USER-13 speedtest-tracker](./stories/USER-13-speedtest-tracker.md),
[OPS-24 cronmaster port](./stories/OPS-24-cronmaster-port.md)
(job dispositions, not the tool).

ADDED 2026-11-23 (operator request): the ONCE trio -- new builds,
not restores, and the fleet's first container guests:
[USER-14 campfire](./stories/USER-14-campfire.md),
[USER-15 fizzy](./stories/USER-15-fizzy.md),
[USER-16 writebook](./stories/USER-16-writebook.md)
(Basecamp ONCE: chat / kanban / book-publishing; official Docker
images pinned by digest, `docker compose` in nested CTs -- the
vendor's `once` installer is rejected because it self-updates
against the OPS-23 pin model).

Also amended: [USER-5 firefox sync](./stories/USER-5-firefox-sync.md)
carries the data-loss warning (old CT 131 has no dump and was never
extracted; B2 check is its opening move) per the operator's
keep-but-future directive. The two unidentified old CTs (110, 116,
Sept-26 dumps only) are presumed stopped templates; resurrect on
demand if the operator remembers otherwise.

Ends with: the curated list running and documented; the uncurated
stay as dumps + extraction notes, cheap to resurrect when a real
need appears.

ADDED 2026-11-25 (operator requests, the personal-content family):
[OPS-26 Proton Pass secrets home](./stories/OPS-26-pass-cli-secrets.md)
(vault items + tracked templates + a secrets-restore script -- the
repo becomes clone-and-restore portable; the audit's answer to
"what if debbie dies"), plus
[USER-17 the knowledge base](./stories/USER-17-knowledge-base.md)
(md corpus hosted -- writebook considered, forgejo+mdbook is the
fleet-native option; tier-0),
[USER-18 the books library](./stories/USER-18-books-library.md)
(omnivore considered; calibre-web is the library-shaped answer;
tier-0), and
[USER-19 the YouTube queue](./stories/USER-19-youtube-queue.md)
(metube for hand-picked videos -> jellyfin; Tube Archivist only
if it grows into channel archiving; cronmaster only for scheduled
sync). All three pair with the media fleet and land on the
personal-content tier: served via tailnet, backed as tier-0
wherever the corpus is unrecoverable.

## v4: Automation polish

[OPS-12 push-to-apply](./stories/OPS-12-push-to-apply.md),
[OPS-13 the auto-update port](./stories/OPS-13-auto-update-port.md),
[OPS-14 PBS backups](./stories/OPS-14-pbs-backups.md),
[OPS-15 drift detection](./stories/OPS-15-drift-detection.md),
[OPS-25 UPS power-loss protection](./stories/OPS-25-ups-power-loss.md)
(the operator's APC BE600M1 -- NUT on the Pi, grace timer, staged
clean shutdown; the deliberate standing-rule exception: power-loss
shutdown is automated, unlike update reboots), and
[OPS-27 mise as the fleet loop front door](./stories/OPS-27-mise-fleet-loop.md)
(operator request: converge/update/verify as mise tasks, ansible
pinned via mise.toml [tools], Makefile deleted; mechanical port
+ the doc sweep that keeps the docs honest; small enough to pull
forward into v3 whenever the operator wants), and
[OPS-28 router tailnet exit node + ProtonVPN egress]
(./stories/OPS-28-router-exit-proton.md)
(operator request 2026-11-26: os-tailscale exit-node role on the
OPNsense box + Proton WireGuard gateway, with the blanket-vs-split
egress decision recorded in-story; router surgery, operator-held
facts: Proton plan tier + WG config),
[OPS-29 Grafana observability -- the dashboard layer]
(./stories/OPS-29-grafana-dashboards.md)
(operator request 2026-11-26, full design in
[design/observability-dashboards.md](./design/observability-dashboards.md):
THE at-a-glance dashboard + a low-level set per domain, the
current-collection gap table (pve exporter, SNMP for truenas +
opnsense, DCGM, blackbox, textfile collectors), dashboards as
code, and the grafana-vs-superset split rule; pull-forwardable
into v3 right after USER-2 if the operator wants the fleet
visible before more services land), and
[USER-20 personal-data BI -- the Superset layer]
(./stories/USER-20-personal-data-superset.md)
(the docs/data.md goal state made concrete: github/codeberg,
leetcode/neetcode/exercism/codecrafters/pluralsight/udemy,
privacy.com/cloaked/amazon spend, ollama/opencode, youtube/odysee,
ActivityWatch local usage; per-source schemas in the analytics
postgres, pulls as code, export-shaped sources via drop-box).

Ends with: rebuild-a-node and add-a-service are runbook-only.

Alerting for this era carries the
[off-site design](./design/offsite-alerting.md) (detection in the
lab, delivery + dead-man's switch on a VPS).

## v5: Platform refresh

The Pi's QDevice re-role, pve-balance's replacement by the native
Dynamic Load Balancer, and the deferred router re-platform (OPS-3,
OPS-6). OPS-17's rolling 8->9 upgrade EVAPORATED at the revival --
the cluster already ran PVE 9.2 (the story carries the supersede
note; its remaining criteria ARE the v5 work). Only after v2-v4
keep the running fleet boring.

## Someday (demand recorded, not queued)

- [OPS-19 NAS re-platform](./stories/OPS-19-nas-replatform.md) -- Proxmox on the NAS hardware, storage as a guest (raised during the revival evening; needs v2 proven first)

- [USER-4 the Monero node](./stories/USER-4-monero-node.md)
  (design: [design/monero-node.md](./design/monero-node.md))
- [USER-5 Firefox sync](./stories/USER-5-firefox-sync.md)
  (design: [design/firefox-sync-server.md](./design/firefox-sync-server.md))
- [LEARN-1 distributed llama.cpp inference](./stories/LEARN-1-llama-rpc.md)
  (design: [design/llama-rpc-inference.md](./design/llama-rpc-inference.md))
- [OPS-16 homelab auto-repair](./stories/OPS-16-homelab-auto-repair.md)
  (design: [design/homelab-auto-repair.md](./design/homelab-auto-repair.md))

ADDED 2026-11-25 (operator-supplied designs + the community-scripts
survey): [design/offsite-alerting.md](./design/offsite-alerting.md)
(the v4 alerting tier -- detection in the lab, delivery + dead-man's
switch on a $5 VPS; supersedes the bare-alertmanager note),
[design/offline-docs-library.md](./design/offline-docs-library.md)
(DevDocs-first private reference library), and
[design/future-services-backlog.md](./design/future-services-backlog.md)
(the 42-service triage: 9 already on the board, new candidates filed
with era suggestions, 3 honest overlaps marked skip). Nothing joins
a converge without its own story first.

## Policy

Numeric order: always complete the lowest incomplete arc before
starting anything higher. An arc only starts when its blockers
([issues.md](./issues.md)) are answered. Deferrals are recorded here,
never silent.
