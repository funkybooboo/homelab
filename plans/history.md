# History

The shipped record. For the homelab a "version" is an era, not a package
release: what ran, as built, and when it ended. The full archive of the
old fleet lands in `docs/legacy/` (OPS-1); this file is the summary and
the timeline.

## The pre-greenfield homelab (wound down 2026-09 through 2026-10)

As shipped (state at the 2026-10 shutdown):

- 5-node PVE 8 cluster, corosync on 192.168.8.0/24: `pve-thermaltake`
  (desktop, the only GPU), `pve-framework` (Zhaoxin desktop, USB 2.5GbE
  NIC), `pve-aspiree15` + `pve-aspires` (laptops), `raspberrypi`
  (arm64 quorum witness, no guests, stale pve-lrm).
- ~28 LXC CTs, rootfs on truenas NFS (`pve-shared`), static LAN IPs
  `192.168.8.<CTID-80>`, each its own tailscale node; per-service HTTPS
  via `tailscale serve` + Let's Encrypt.
- HA with node-affinity rules (amd64-only) + a custom `pve-balance`
  scheduler on the Pi.
- GL-MT2500 (OpenWrt) router at 192.168.8.1 with 6 DHCP reservations.
- truenas 25.10 at 192.168.8.100: NFS `pve-shared` + `pve-backups`, TLS
  re-import cron, Backblaze B2 cloud-sync (5 snapshot leaf tasks).
- Tiered auto-update shipped 2026-09-27 (code:
  `services/auto-update/`; design:
  [design/auto-update.md](./design/auto-update.md)).

## The wind-down + router swap (the era's end)

- 2026-09-27: `pve-framework` last seen online (suspected: the
  reboot-controller's reboot + its flaky USB NIC; it never returned).
- 2026-10-01: `pve-thermaltake`.
- 2026-10-19: truenas + every remaining CT (one mass stop). Same day:
  the Protectli V1210 router box ordered (#10610317, $563.04 -- Intel
  N5105, 2x 2.5GbE, 4GB, 500GB NVMe, OPNsense 25.7 pre-installed).
- 2026-10-28: the last three nodes (`pve-aspires`, `pve-aspiree15`,
  `raspberrypi`) + the GL-MT2500 retired; the V1210's OPNsense takes
  the LAN at 192.168.1.1 (new subnet: 192.168.1.0/24).
- 2026-11-04: state verified by network forensics -- everything dark,
  the old subnet dead, only debbie + the laptops on the tailnet.

- 2026-11-06: v0 ships -- the legacy archive (`docs/legacy/` +
  `scripts/extract-legacy.sh`, OPS-1) records the old fleet before
  anything is wiped.

## v0: Legacy archive (shipped 2026-11-06)

The first greenfield deliverable, no hardware needed. As built:

- `docs/legacy/` -- guest catalog (28 running CTs + 6 templates, final
  placements + provenance for every disputed fact), the old
  192.168.8.0/24 LAN (router, reservations, why the subnet was
  load-bearing), quirks + the full incident list (Pi rule, NFS
  cascade, HA error dance, pve-balance, the framework vanishings),
  and the per-CT data-to-extract inventory with priorities.
- `scripts/extract-legacy.sh` -- read-only NFS mount + per-CT raw-image
  loop-mounts, tiered probe/copy with sha256 manifest, `--copy-from-dump`
  fallback for the two local-lvm CTs. Runs after OPS-4's truenas move;
  tier-0 (vaultwarden, PGDATA, n8n) gates every wipe.

Knowledge corrections made while archiving: the July services.md
snapshot was missing CTs 130-134 (loki + the media batch); ntfy +
loki rootfs live on local-lvm, not pve-shared; the final running count
is 28. All recorded with sources in the v0 notes (the archive files
themselves were retired to git history 2026-11-21 per the operator's
git-is-the-archive call; `docs/data-to-extract.md` survives as the
live extraction inventory).

## v1: Revival (shipped 2026-11-21/22)

Revived in place, nothing reinstalled. The revival evening's plan
shift (operator directive, issues item 8's second revision) reshaped
what "revival" meant mid-arc: the PLATFORM came back, not the old
CT fleet -- the CTs are cleaned out (v1.5), then the services are
rebuilt as code (v2/v3).

As built:

- OPS-4 truenas: moved to 192.168.1.10 stable (the interface
  fail-safe + staged-revert trap documented in the script); NFS
  exports re-scoped to 192.168.1.0/24; API write channel live as
  nate; B2 verified (all 5 cloud-sync snapshot tasks SUCCESS at the
  first post-wind-down schedule, 2026-11-22 00:00).
- OPS-18 nodes: all 5 renumbered in place -- thermaltake .3,
  framework .4 (no hardware fix; a cold boot + USB autosuspend
  hardening queued as insurance), aspiree15 .5, aspires .6, Pi .11
  (rejoined as 5th member + witness per operator directive;
  QDevice re-role stays optional at v5). Mechanism per node: the
  console key-drop (console-setup-operator.sh), then
  revive-node.sh as nate -- pvecm expected 1, pmxcfs local-mode
  corosync.conf swap, detached ifreload + corosync restart, LRM
  disarm/re-arm around the ring change. 5/5 quorate. Storage
  (.100 -> .10) + host DNS (dead router -> .1 + 1.1.1.1) fixed on
  all nodes.
- GPU live on thermaltake: GTX 1060 6GB, dkms nvidia 580.142 built
  for kernel 7.0.14-20-pve, uvm devnodes + boot persistence.
- Access model completed 2026-11-22: PVE user nate@pam
  (Administrator on /) + the homelab-ops API token (privsep 0,
  verified live); router + truenas operated as nate; one token on
  the cluster, nothing root-adjacent. The web UI signs in as
  nate@pam.
- Left for v1.5: the 5 surviving CTs (101 running as an HA
  auto-start artifact, 102/110/116/132 stopped) + 4 VM templates,
  ~24 config-less HA orphan resources, ~28 dead tailnet devices,
  the .8.x temporary aliases, node ssh hardening.

## v1.5: Clean-out + access layer (shipped 2026-11-22)

The era flip: the old fleet's remains went, the access layer landed,
the hardening closed -- v2 builds on a bare, truthful platform.

As built:

- OPS-20 clean-out: the tier-0 extraction landed first (whole-CT
  Nov-21 vzdumps extracted to debbie with a sha256 manifest --
  vaultwarden's vault at /opt/vaultwarden/data, n8n at /.n8n,
  PGDATA 17; the loop-mount path proved unreliable on NFS and the
  dumps are the durable archive, untouched on pve-backups + B2).
  Then the cluster went bare: 5 CTs + 4 VM templates destroyed (the
  NFS chattr holdouts finished by hand), 24 HA resources
  deregistered before destruction, pve-shared images swept empty,
  and the FOSSIL per-node guest configs under
  /etc/pve/nodes/*/lxc/ (the invisible "24 orphans" feeding the
  resource index) discovered + swept. API-verified: zero guests,
  5/5 quorate, LRM armed (framework's found inactive since boot and
  started). The tailnet graveyard (30 devices) purged via the
  console; 9 live devices remain, jellyfin/navidrome hostnames
  freed for v2.
- OPS-21 tailnet access layer: thermaltake = the one subnet router
  (192.168.1.0/24 advertised, operator-approved, forwarding
  persisted); the serve front live with LE certs
  (https://pve-thermaltake.tail54538d.ts.net); tailscale API token
  in local/ for v2 automation. Verified from the operator's phone,
  off-LAN.
- OPS-22 hardening: good-ssh state on all 5 nodes (password auth
  dead, root key-only, VERBOSE audit logging); TOTP on nate@pam AND
  root@pam; truenas found ALREADY compliant (its stale
  "pending hardening" note corrected); debbie swept (four stale
  port-8000 rules gone; the live-only .8.99 alias died with the
  reboot); thermaltake's .8.98 removed; framework's USB NIC
  (RTL8156) keep-awake pinned via udev rule on top of the r8152
  driver behavior. The dead 192.168.8.x subnet verified silent.

## v2: IaC skeleton + the critical five (shipped 2026-11-25)

The OPS-7 skeleton shipped 2026-11-22 (manifest -> CT -> running
service, idempotent re-run proven, make converge/verify real). A
post-skeleton readiness pass swept the last old-fleet residue (55
/tmp debug scripts, 5 stale CT templates, the promtail shipper
whose endpoint died with the old loki serve-front) and a root-owned
/home/tom/sources pve-cd-builder checkout from the May-2026 era
(swept 2026-11-23 on the operator's word), plus de-staled six story
notes + issues item 8. A full hygiene audit 2026-11-23 then
decommissioned the old fleet's LIVE auto-update machinery from all
4 nodes: the hourly pve-reboot-controller WAS ARMED with live
pmxcfs flags + a fresh lock (unattended serialized cluster reboots
were minutes away); auto-update.service/timer, the maint +
ha-state-watch + renew-pve-tls crons, start-jellyfin +
router-syslog-relay units, php packages on the framework node all
went. KEPT as verified live: the thermaltake GPU stack, laptop
screen-off, the NFS self-healing glue, vzdump, the disk-hygiene
timers. The OPS-23 model became the only update system.

Then the critical five, built fresh from manifests: the
observability foundation first (every guest born with journald->
loki, node_exporter, the five-family watcher + heartbeat), USER-1
vaultwarden (source build, vault restored, operator-verified),
OPS-10 postgres + adminer (old forgejo + freshrss databases
restored), OPS-11 prometheus + grafana + loki, OPS-8 ntfy, and
OPS-9 the hub restore (17 users + 349 repos on CT 202, both sync
legs). The idempotence war (forgejo's app.ini blockfile restart
loop) closed 2026-11-25 with verify-first + bootstrap-only +
DDL-gating. OPS-26 made the repo clone-and-restore portable
(Proton Pass vault). CT 204's decommission + the push-chain
codeberg leg closed the arc.

## v3: Curation + media fleet (ACTIVE -- first story shipped)

USER-2 the media fleet SHIPPED 2026-11-26: jellyfin 205/.55,
navidrome 206/.56, audiobookshelf 207/.57 on thermaltake; the
NFS media mounts on every amd64 node; the GPU driver saga (no apt
path for Pascal on kernel 7.x; the .run 580.142, pinned,
dkms-registered, CT userspace from the same pin; nvidia-smi
answers from inside the jellyfin CT); metadata restored from the
vzdump archive after the recycled-vmid + permission-reading
misdiagnoses; converge idempotent fleet-wide. The skeleton gained
manifest mounts + GPU devnode passthrough. Remaining v3 work
proceeds per the roadmap (USER-3, the keeps, the ONCE trio, the
personal-content family; OPS-29/USER-20 pull-forwardable).

## Greenfield arcs (to be written as they ship)

v4 automation polish, v5 platform refresh -- each appended above
as its stories flip done.
