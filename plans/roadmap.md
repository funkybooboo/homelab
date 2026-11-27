# Roadmap

The queue. Arcs are the milestones (each ends with something
running); stories are the work (one file each in
[stories/](./stories/)). The shipped record is
[history.md](./history.md); decisions and their reasoning live in
[issues.md](./issues.md); when something changed is git's job, not
this file's. This file says what is true now and what happens
next.

## Where we stand

- v3 is ACTIVE and its first half is shipped: USER-2 (media
  fleet) and USER-3 (daily tools, container-guest mechanism)
  are live and operator-verified; OPS-28 (Proton blanket + the
  router as tailnet exit node/subnet router) is shipped,
  operator-verified away-from-home, and CLOSED. The secrets
  incident is fully closed (rotate + resolve-as-revoked;
  gitleaks-clean; see history.md).
- The daily-tools CTs live on thermaltake (evacuated there the
  night framework's USB NIC died). Decision: framework re-enters
  guest rotation -- some of the five re-home there, the split
  picked at migration time. That move is the first build action
  after the current docs pass.
- Next by operator directive (2026-11-28), both from scratch:
  USER-5 firefox sync and OPS-24 cronmaster -- their stories are
  rewritten against the current cluster, and
  [design/browser-off-cloud.md](./design/browser-off-cloud.md)
  maps the full get-the-browser-off-the-cloud scope they belong
  to.
- Side stories queued and pull-forwardable: OPS-29 (grafana
  observability) and USER-20 (superset BI).
- Parked items (see [issues.md](./issues.md)): item 16 (the
  codeberg 100-repo cap; 12 un-mirrored targets) and item 8
  (open). The OPS-9 carried notes are RESOLVED: roll-pins now
  handles the gitea-mirror version (and every pinned release +
  container digest) on every `make update`.

## Timeline at a glance

Eras are condition-gated, not calendar-gated: an era ships when its
acceptance criteria are green. Size: S = a session, M = a few
sessions, L = an era's backbone.

| Era | State | Opens when | Size | Ends with |
|-----|-------|------------|------|-----------|
| v3 curation | ACTIVE (USER-2 shipped) | - | L | the curated list running and documented |
| v4 automation polish | queued | v3 close + the opening protocol | L | durability + visibility + automation |
| v5 platform refresh | queued | v4 close, hardware appetite | M/L | router re-platform, QDevice re-role, native balancer |
| Backlog | demand recorded | a named trigger fires | - | nothing queued silently |

The opening protocol below is part of "opens when" for every
queued era.

## The era-opening protocol

Every era after the active one starts with an opening phase, not
with building:

**Phase 0 -- research + Q&A.** Walk the era's stories to a
same-page design; re-read the design records; answer or file open
questions into [issues.md](./issues.md). Scout the current state of
what the era touches -- fleets drift between eras, and docs can
lag. Prove access to every external and internal system the era
needs (APIs, accounts, hardware) before building against it.
Chase the operator-held facts to closure. Walk the quality
lenses (security, visibility, reliability, scalability --
[design/quality-lenses.md](./design/quality-lenses.md)) against
every story; the answers land in acceptance criteria.

**Phase 1 -- docs.** Update and clean the docs the era inherits so
they tell the truth on day one.

**Phase 2 -- build.** The era runs in the order its section states;
every story ends with something running.

An era may compress the phases when nothing is stale and every
access is already proven.

## v3: Curation + media fleet (ACTIVE)

Scope: the curated list (~12-15 services, issues item 6) is
enforced at build time -- nothing stale is built. The media fleet
runs on the GPU node. Old services with recoverable data each get
their own story; the ONCE trio are the first container guests
(official images pinned by digest; the vendor's self-updating
installer is rejected).

Order from here (operator directive 2026-11-28): the
re-homing SHIPPED the same day -- all five daily-tools CTs now
live on framework (the tools tier and the landing zone for the
next builds; pmxcfs moves, tailnet fronts verified, CT-reboot
drill green). Then USER-5 firefox sync and OPS-24 cronmaster -- both
STARTED FROM SCRATCH, their stories re-baselined against the
current cluster -- then the keeps, the ONCE trio, and the
personal-content family in numeric order. The browser-off-cloud
map ([design/browser-off-cloud.md](./design/browser-off-cloud.md))
is the design context for USER-5 and any story that follows it.

- [USER-3 daily tools](./stories/USER-3-daily-tools.md) -- the
  tier-3 browser tools + the curation decision (five container
  guests live 2026-11-27; the container mechanism the ONCE trio
  inherits -- the trio's stories stay as written) 
- The keeps (each a restore from the dump archive, see
  [docs/archive.md](../docs/archive.md)):
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
- The ONCE trio:
  [USER-14 campfire](./stories/USER-14-campfire.md),
  [USER-15 fizzy](./stories/USER-15-fizzy.md),
  [USER-16 writebook](./stories/USER-16-writebook.md)
- The personal-content family (pairs with the media fleet; served
  via tailnet, backed as tier-0 where the corpus is unrecoverable):
  [USER-17 knowledge base](./stories/USER-17-knowledge-base.md),
  [USER-18 books library](./stories/USER-18-books-library.md),
  [USER-19 youtube queue](./stories/USER-19-youtube-queue.md),
  [USER-21 immich](./stories/USER-21-immich.md) (the photo
  library; phone uploads + the Proton Drive photos export),
  [USER-22 offline docs library](./stories/USER-22-offline-docs-library.md),
  [USER-23 paperless](./stories/USER-23-paperless.md)
  (hardware-gated: the operator's scanner)
- Amendments: [USER-5 firefox sync](./stories/USER-5-firefox-sync.md)
  carries the data-loss warning (no dump exists for old CT 131; the
  B2 check is its opening move). Old CTs 110 and 116 are presumed
  stopped templates; resurrect on demand.

Ends with: the curated list running and documented; the uncurated
stay as dumps + extraction notes, cheap to resurrect when a real
need appears. The closing item is the ROUTER UPGRADE TO 26.1
(operator directive 2026-11-28): OPNsense 26.1 ("Witty
Woodpecker") upgrades the router in a deliberate window AFTER
the above lands -- config backup first, the oxlorg collection
release paired to 26.1 verified, migration notes read (26.1
moves the DNAT/rules APIs tonight's work rides), then the
upgrade + full re-verification of the Proton blanket, tailscale
exit node, and subnet routing. Never a button-click on a one-day-old
tier-0 release mid-project.

## v4: Automation polish (queued)

Order: make the loop pleasant, make the fleet visible, then
durable, then self-minding. Every operator-held gating fact is
named; nothing starts blind. The opening protocol's Phase 0
reorders this list with evidence and settles the open picks.

0. [TAILNET NAMES AS THE FLEET'S UNIVERSAL ADDRESSING]
   (operator directive 2026-11-28): every guest, node, machine,
   service, and config speaks tailnet DNS names (MagicDNS), not
   LAN IPs -- resolvers, DSNs, access tables, manifests, and
   scripts all converge on `<name>.tail54538d.ts.net`. Reverses
   the current state (guests resolve via the router and address
   each other by LAN IP; the freshrss DSN had to be repointed to
   192.168.1.14 because MagicDNS did not resolve in-guest).
   Opens with its Phase 0: pick the per-guest resolver strategy
   (each tailscaled guest answering MagicDNS at
   100.100.100.100 vs the router's resolver forwarding the
tailnet zone), then sweep every IP reference in the repo +
   live DSNs. Sized when opened.

1. [OPS-27 mise as the fleet loop front door]
   (./stories/OPS-27-mise-fleet-loop.md) -- mechanical, and every
   later story runs through the loop it improves. Pull-forwardable.
2. [OPS-29 Grafana observability]
   (./stories/OPS-29-grafana-dashboards.md) -- a: close the data
   gaps, b: THE at-a-glance board, c: the low-level set. Design:
   [design/observability-dashboards.md](./design/observability-dashboards.md).
3. The offsite alerting tier
   ([design/offsite-alerting.md](./design/offsite-alerting.md)) --
   detection on the v4 observability stack, delivery + dead-man's
   switch on a ~$5/mo VPS (the first recurring paid service after
   B2). Needs: the VPS account, the
   Gatus-vs-Healthchecks pick (Phase 0).
4. [USER-20 personal-data BI]
   (./stories/USER-20-personal-data-superset.md) -- rides the
   analytics habits OPS-29 builds; clean-API sources first. Needs
   per-source account/API access proven in Phase 0.
5. [OPS-14 PBS backups](./stories/OPS-14-pbs-backups.md) -- vzdump
   covers the fleet today; PBS adds granularity + the quarterly
   restore drill. Needs: storage sizing (Phase 0).
6. [OPS-25 UPS power-loss protection]
   (./stories/OPS-25-ups-power-loss.md) -- hardware-gated: the
   APC BE600M1, battery outlets feeding router + Pi (physical
   wiring, operator). The deliberate standing-rule exception:
   power-loss shutdown is automated.
7. [OPS-28 router exit node + ProtonVPN egress]
   (./stories/OPS-28-router-exit-proton.md) -- operator facts
   gate it (see Where we stand).
8. [USER-4 monero node](./stories/USER-4-monero-node.md)
   (design: [design/monero-node.md](./design/monero-node.md)) --
   the operator is getting into Monero; the node is the wallet's
   private validator. Chain storage sizing is Phase 0.
9. [OPS-12 push-to-apply](./stories/OPS-12-push-to-apply.md),
   [OPS-13 auto-update port](./stories/OPS-13-auto-update-port.md),
   [OPS-15 drift detection](./stories/OPS-15-drift-detection.md),
   [OPS-16 auto-repair via n8n]
   (./stories/OPS-16-homelab-auto-repair.md) --
   the self-minding tier, last on purpose: automation is only safe
   on a fleet that is already visible, durable, and understood.

Ends with: rebuild-a-node and add-a-service are runbook-only.

## v5: Platform refresh (queued)

The router re-platform onto Proxmox (OPS-3), the Pi's QDevice
re-role (OPS-6), the native Dynamic Load Balancer replacing manual
placement, the PVE rolling-upgrade criteria that survived
OPS-17's evaporation, [OPS-19 the NAS re-platform]
(./stories/OPS-19-nas-replatform.md) (TrueNAS becomes a Proxmox
guest -- the operator's confirmed want), and [USER-24 stalwart]
(./stories/USER-24-stalwart-mail.md) (the own-mail experiment).
Only after v3-v4 keep the running fleet boring.

## Backlog (named triggers, not queued)

Nothing here is queued; each entry names the trigger that files
its story.

- **homelab/household VLAN split** (operator directive
  2026-11-28: "I want my homelab to be separate from the rest
  of my house") -- trigger: a managed switch joins the LAN (the
  current unmanaged switch cannot do VLANs; a Zyxel GS1900-24E
  was the candidate under discussion). Design on record:
  additive -- homelab keeps 192.168.1.0/24 (VLAN 10) untouched,
  household devices (wife's computer, TV, other non-homelab
  gear, all currently DHCP .100-.249 on the flat LAN) move to a
  new VLAN 20 (192.168.2.0/24); router firewall blocks
  VLAN 20 -> VLAN 10 except a narrow allow-list for the services
  the household actually uses (day-one question: does the TV
  stream from jellyfin/navidrome/audiobookshelf?). Household
  devices stay together on VLAN 20 so their casting/mDNS keeps
  working; casting into the homelab stops. Operator devices
  (debbie, phones, laptops) stay on VLAN 10. Costs already
  known: switch config is manual web-UI (commit its config
  export to the repo for reproducibility); the OPNsense VLAN
  interface assignment is a UI-only surface = operator click.
  Day-one behavior note for the household: their devices ride
  the Proton blanket + Quad9 today; broken-site reports are
  NetShield/blanket suspects, not their device.
  END-STATE (operator directive 2026-11-28: "level 2 now,
  eventually level 3"): the household VLAN is rung 2 of a
  reserved ladder, so every later rung is additive with zero
  re-addressing -- VLAN 10 stays 192.168.1.0/24 (homelab +
  operator devices); VLAN 20 = 192.168.2.0/24 (household);
  reserved: 30/IoT 192.168.3.0/24 (internet only, trigger:
  the first smart-home device), 40/cameras 192.168.4.0/24
  (no internet at all, NVR access only; pairs with the frigate
  backlog trigger), 50/guest 192.168.5.0/24
  (internet only + client isolation, trigger: visitors want
  Wi-Fi), and an infra-management VLAN when the
  fleet grows devices with admin pages of their own (the
  Zyxel is the first). Level-3 costs already on record: an
  mDNS reflector becomes necessary the first time a casting
  device lands on a different VLAN than the phone casting to
  it; the Atom router carries all inter-VLAN routing, so the
  media path never crosses a rung (same-subnet stays switch
  fabric).
- **truenas REST API retirement** -- trigger: TrueNAS 26.04
  approaches. The extract-legacy scripts and node-side midclt
  calls ride the deprecated REST API (50 uses/day flagged from
  .120 and .3); migrate them to the JSON-RPC 2.0 WebSocket API
  before that release or the tier-0 backup tooling breaks.
- **truenas boot-pool on USB (sdc)** -- trigger: hands on the
  machine. TrueNAS warns the boot pool consumes a USB device;
  move it to a small mirror on real disks at the next hardware
  session (boot-pool failure risk on the tier-0 storage host).
- **frigate** (NVR) -- trigger: the operator buys cameras. Wants
  GPU passthrough first.
- **ollama + openwebui** -- trigger: the operator buys AI-capable
  hardware. The use case: the household's own assistant on the
  LAN.
- **headscale** (self-hosted tailscale control plane) -- trigger:
  the operator decides to migrate off the hosted tailnet. Known
  cost recorded in the backlog design: serve fronts and some
  managed features must be re-validated.
- [design/future-services-backlog.md](./design/future-services-backlog.md)
  -- the reference triage; decided dispositions are recorded
  there; nothing joins a converge without its own story

## Policy

Numeric order: always complete the lowest incomplete arc before
starting anything higher. An arc only starts when its blockers
([issues.md](./issues.md)) are answered. Deferrals are recorded
here, never silent.

Every era after the active one opens with the era-opening protocol
(research + Q&A with access proven, docs, then the build). Within
an era, the section's stated order governs.
