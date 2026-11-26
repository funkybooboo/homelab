# Roadmap

The queue. Arcs are the milestones (each ends with something running);
stories are the work (one file each in [stories/](./stories/)); the
constitution is [identity.md](./identity.md); the shipped record is
[history.md](./history.md). Every change serves one of the three roles.

## Where we stand (2026-11-26)

- v1 + v1.5 SHIPPED (nodes live, cluster bare, access layer +
  hardening done; see [history.md](./history.md)).
- v2 SHIPPED 2026-11-25: the IaC skeleton + the critical five +
  both sync legs; converge/update/verify green and idempotent.
- v3 is ACTIVE and mid-flight (its plan is untouched; progress
  lives in the stories): USER-2 the media fleet SHIPPED 2026-11-26
  (three services live on thermaltake, metadata restored, GPU
  transcode proven, converge changed=0 fleet-wide). Next by the
  numeric-order policy: the rest of the curated list (USER-3, the
  keeps, the ONCE trio, the personal-content family).
- v3 also gained two operator-requested side stories, queued but
  pull-forwardable: OPS-29 (grafana observability; design
  [design/observability-dashboards.md](./design/observability-dashboards.md))
  and, with it, USER-20 (superset BI). OPS-28 (router exit node +
  Proton) is filed and waiting on operator-held facts.
- Parked, not lost: issues.md item 16 (codeberg 100-repo cap;
  12 un-mirrored targets), the OPS-9 carried notes (phantom
  exclude list, 32 DB-only rows, mirror ntfy wiring, the
  3.54.0 -> 3.56.1 bump), issues item 8 (open).
- Standing tooling: `docs/` (the live data-to-extract inventory),
  `ansible/inventory/` (LAN plan, host facts),
  `scripts/revive-node.sh` + `reboot-node.sh` + the parked
  future-node tooling (`bootstrap`, `deploy-node-glue`,
  `setup-qdevice`).

## Timeline at a glance

Eras are CONDITION-gated, not calendar-gated -- a homelab ships
when its acceptance criteria are green, not when a date arrives.
The "size" column is honest rough work (S = a session, M = a few
sessions, L = an era's backbone).

| Era | State | Opens when | Size | Closes when (Ends-with) |
|-----|-------|------------|------|------------------------|
| v0 legacy archive | SHIPPED | - | S | archive + extractor |
| v1 revival | SHIPPED | - | L | platform alive on the new LAN |
| v1.5 clean-out | SHIPPED | plan shift (11-22) | M | bare cluster + access layer |
| v2 IaC skeleton | SHIPPED | - | L | critical five + the loop |
| v3 curation | ACTIVE (USER-2 shipped) | v2 close | L | curated list running + documented |
| v4 automation polish | queued | v3 close + OPENING PROTOCOL (below) | L | durability + visibility + automation; runbook-only additions |
| v5 platform refresh | queued | v4 close, hardware appetite | M/L | router re-platform, QDevice re-role, native balancer |
| Someday | demand recorded | a real need appears | - | nothing queued silently |

Within-era ordering is the roadmap's job; each era's section
names its sequence. The OPENING PROTOCOL below is now part of
"opens when" for every era from v4 onward.

## The era-opening protocol (operator directive 2026-11-26)

Every era after the active one STARTS with an opening phase, not
with building. v3's pre-flight audit was the prototype; from v4
this is standing policy:

**Phase 0 -- research + Q&A.** Flesh out the era's design to
the same page: the operator and the assistant walk the era's
stories, every design record re-read, open questions answered or
filed into [issues.md](./issues.md). Scout the CURRENT state of
what the era touches (the fleet drifts between eras; docs lie
quietly). GET ACCESS to everything the era needs -- external
APIs, accounts, hardware, service logins -- and prove each one
works BEFORE the era builds against it (the v3 lesson: the GPU
had no driver, the extraction sources were gone, and both were
found by scouting, not by assuming). Operator-held facts are
named here and chased to closure.

**Phase 1 -- docs update + cleanup.** The era's docs sweep:
make verify on the docs themselves, stale claims fixed, the
standing fleet picture updated. Docs must tell the truth the era
will inherit.

**Phase 2 -- build.** The era runs in its stated story order,
numeric policy inside the era, every story ending with something
running.

An era may not skip the phases; it may compress them when nothing
is stale and every access is already proven. v3 (already active)
is exempt retroactively -- its remaining work proceeds as planned.

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

SEQUENCED 2026-11-26 (roadmap refinement; every era from here
opens with the ERA-OPENING PROTOCOL above -- Phase 0 reorders
this list with evidence, Phase 1 de-stales the docs it inherits):

Order rationale: make the loop pleasant, make the fleet visible,
then make it durable, then make it self-minding. Specific
operator-held facts gate three stories (named below); nothing
starts blind.

1. [OPS-27 mise as the fleet loop front door]
   (./stories/OPS-27-mise-fleet-loop.md) -- first because it is
   mechanical, small, and every later story runs through the
   loop it improves. (Pull-forwardable into v3 at will.)
2. [OPS-29 Grafana observability]
   (./stories/OPS-29-grafana-dashboards.md) -- a: close the data
   gaps, b: THE at-a-glance board, c: the low-level set. The
   fleet becomes VISIBLE; every later v4 story lands on a
   dashboard that proves it. (Pull-forwardable; design already
   filed: [design/observability-dashboards.md].)
3. The offsite alerting tier
   ([design/offsite-alerting.md](./design/offsite-alerting.md))
   -- detection rides the v4 observability stack; delivery +
   dead-man's switch on a ~$5/mo VPS (the first recurring paid
   service after B2; provider pick + Gatus-vs-Healthchecks is
   Phase-0 Q&A). Needs: VPS account + provisioned access.
4. [USER-20 personal-data BI -- the Superset layer]
   (./stories/USER-20-personal-data-superset.md) -- rides the
   analytics habits OPS-29 builds; clean-API sources first.
   Needs: per-source account/API access verified in Phase 0
   (github, codeberg, privacy.com, cloaked, exercism,
   codecrafters, ollama, opencode).
5. [OPS-14 PBS backups](./stories/OPS-14-pbs-backups.md) --
   vzdump already covers the fleet; PBS adds granularity + the
   quarterly restore drill. Needs: PBS storage sized (truenas
   or elsewhere -- Phase-0 decision).
6. [OPS-25 UPS power-loss protection]
   (./stories/OPS-25-ups-power-loss.md) -- hardware-gated: the
   operator's APC BE600M1 + battery outlets feeding router +
   Pi (a physical wiring step, not a software one).
7. [OPS-28 router tailnet exit node + ProtonVPN egress]
   (./stories/OPS-28-router-exit-proton.md) -- operator facts
   gate it: Proton plan tier + the WireGuard config + the
   blanket-vs-split egress decision (recorded in-story).
8. [OPS-12 push-to-apply](./stories/OPS-12-push-to-apply.md),
   [OPS-13 the auto-update port]
   (./stories/OPS-13-auto-update-port.md),
   [OPS-15 drift detection](./stories/OPS-15-drift-detection.md)
   -- the self-minding tier, last on purpose: automation is
   only safe on a fleet that is already visible, durable, and
   understood.

V4's Phase 0 must also verify: the dead-man's-switch VPS choice,
PBS storage sizing, the UPS hardware state, router plugin
maturity on OPNsense 25.7, and the superset source APIs -- each
one proven reachable before its story builds.

Ends with: rebuild-a-node and add-a-service are runbook-only.

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

ADDED 2026-11-26 (operator directive): every era after the active
one opens with the ERA-OPENING PROTOCOL (top of this file) --
research + Q&A and same-page design first, access to every
external/internal system PROVEN before build, then the docs
sweep, and only then the stories. Within an era, sequence follows
its section's stated order; the numeric policy governs arcs, not
sessions.
