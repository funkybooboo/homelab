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


### USER-2 as built: the media fleet

Build design (recorded before code):

(as built; the build log's deviations are appended below)

- IDs per guests/README conventions: jellyfin 205/.55, navidrome
  206/.56, audiobookshelf 207/.57 (.54 skipped -- the dead mirror
  CT's IP, stale DNS confusion risk).
- NFS model per docs/network.md planned diagram: the media exports
  mount on EVERY x86 node at the same path (/mnt/media/*), CTs get
  bind mounts via pct mp entries -- guest mobility, no in-CT NFS.
  Node mounts are fstab + `_netdev,nofail` (boot-order law: truenas
  boots first; nofail keeps a dead truenas from hanging a node).
- Six exports (truenas sharing/nfs, verified live): movies,
  tvshows, Music, Audiobooks, Books, Podcasts. All map to
  /mnt/media/{movies,tvshows,music,audiobooks,books,podcasts}.
- mounts:[] + devnodes were DECLARED in manifests but UNIMPLEMENTED
  in guests.yml (no guest needed them until now) -- this story adds
  the mp/devn application, verify-first style (pct config probe
  before pct set; never trust, always check).
- Roles follow the vaultwarden house pattern: version-gate marker,
  pinned installs, restore-if-absent from legacy-extraction/, systemd
  hardening, serve fronts (8096/4533/13378).
- GPU: dkms nvidia 580.142 was built for kernel 7.0.14-20-pve; the
  nodes now run 7.0.14-30-pve and the driver is GONE (nvidia-smi
  fails, no /dev/nvidia*). Rebuild dkms for the running kernel,
  verify nvidia-smi, then devnode passthrough into CT 205.
- Metadata restore sequence: CTs converge EMPTY first (services
  healthy, libraries absent), then the operator runs
  `scripts/extract-legacy.sh --copy 1` on debbie (needs root; the
  tier-1 list covers jellyfin 102, navidrome 132, audiobookshelf
  133 -- their raw disks verified present on pve-shared), then one
  more converge lands the metadata restore-if-absent. Never-clobber
  both ways: an empty-fresh CT accepts the dump; a live library
  with real state refuses to be overwritten.
- ports: jellyfin 8096, navidrome 4533, audiobookshelf 13378.

As-built deviations:

- **GPU driver = the .run 580.142 branch, not Debian's apt driver.**
  Found live: Debian trixie's nvidia-driver 550 cannot compile
  against PVE kernel 7.0 (dkms fails in nv-mmap.c -- VMA_LOCK_OFFSET
  + mmap_lock API drift), and NVIDIA's CUDA apt repo has rotated
  past the 580 branch entirely (590+ dropped Pascal). The GTX 1060
  has NO apt-managed driver left anywhere; the old fleet's .run
  choice was forced, not a habit. Managed the vaultwarden way now:
  pinned in group_vars, marker-gated in node_glue, --dkms registered,
  CT-side userspace installed --no-kernel-module from the same pin.
  (This re-cleans a trap: the leftover .run residue breaks apt's
  nvidia-installer-cleanup postinst with debconf exit 30 -- the
  uninstaller must run before ANY apt nvidia transaction.)
- **Audiobookshelf installs from the vendor's flat apt repo**
  (advplyr.github.io/audiobookshelf-ppa) -- GitHub release binaries
  no longer exist (checked: zero assets on the last 100 releases);
  the repo is their documented Debian path. Its config layout probe
  handles both old eras (/var/lib/audiobookshelf and /audiobookshelf).
- **Jellyfin's repo key moved**: jellyfin.gpg.key 404s now;
  jellyfin_team.gpg.key is the current name. The trixie suite
  exists (v12.4, live since 2026-11-23).
- **PVE kernel packages renamed**: proxmox-headers-<kernel>
  provides linux-headers-* -- the plain names show no candidates.
- **Extractor tarball naming fixed before first use**:
  multi-path probes (102, 133) overwrote their own tarballs;
  per-path slugs now. The lxc-confs copy never existed (the old
  confs lived in /etc/pve, lost with the old cluster) -- the
  devnode lines were rebuilt from standard LXC practice instead.
- **The NFS-image source is DEAD for the old fleet** (found at the
  operator's --copy 1 run): OPS-20 removed the old disks, and the
  v2 fleet recycled vmids 101-106 -- the probe path now sees the
  NEW guests' rootfs images. The extractor warns + skips recycled
  vmids; docs/data-to-extract.md carries the correction. THE
  SOURCE OF RECORD = the vzdump archive (--copy-from-dump),
  confirmed present for 102 (Sep 26), 132 (Sep 26), 133 (Nov 21).
  All three roles now restore from the from-dump rootfs trees
  (directory copies, never-clobber, marker-gated, ownership
  fixed post-restore).
- **MISDIAGNOSIS CORRECTED 2026-11-26**: the first restore attempt
  appeared to fail because "from-dump-102's jellyfin dirs were
  empty after a reboot-truncated extraction" -- WRONG. The sudo
  extraction left root-owned 750 dirs; the agent's unprivileged
  du/ls read them as empty and led to a false truncation story
  (the ssh-agent drops + /tmp wipes were the only real reboot
  damage). The roles' content-gates (find as nate) correctly
  refused to 'restore' from unreadable sources; the burned markers
  were cleared and the contract tightened: gates now demand
  FILES, and markers are only written inside a real restore.
  Lesson: a 0-byte du on a dir you do not own is a PERMISSION
  reading, not a content reading -- check with the become channel
  (pct exec / root) before declaring source data missing.
- **133's real era-path**: the old CT was a deb-install using the
  vendor defaults (/usr/share/audiobookshelf, 95M: binary 90M +
  metadata 3.5M + config 1.5M); the probe alternates in
  data-to-extract.md were guesses. The role probes all three
  eras.



### OPS-9 as built: the forgejo hub + sync layer

Scope (operator chose the full hub, not the mirror-only letter):
the restored forgejo DB is the whole personal hub (17 users, 347
repos). The repo files live in the Oct-17 vzdump of CT 107: 315 of
347 on disk (8.3G); the 32 DB-only repos are all mirrors and
self-heal by re-pulling. Zero non-mirror data lost.

RESTORE MODEL: extract from the dump tarball (the old live rootfs was
wiped in OPS-20; the dump is the tier-1 archive) ->
legacy-extraction/from-dump-107/ on debbie -> role restores
only-if-absent, like vaultwarden. app.ini restored VERBATIM (all
secrets: INTERNAL_TOKEN, LFS JWT, oauth keys) with the database +
server sections overridden by environment (LAN pg host, the new
role-per-service forgejo role, SSH clone disabled for v1 -- reads
work over https; the class is over).

Old forgejo 15.0.4 (schema 305) -> pinned v17.0.2 (codeberg ships
prebuilt amd64, unlike vaultwarden's upstream); migrations run
forward on first boot.

SYNC LAYER DECISION (operator): the old fleet's GitHub
-> forgejo sync never rode forgejo-native pull mirrors -- the
operator ran RayLabsHQ/gitea-mirror (push-based, auto-discovers new
GitHub repos). The restored DB confirms it: mirror rows frozen
mid-July while push-driven repo activity ran to Oct 19. Native is
dormant here too (the update_mirrors cron fired by admin API was a
silent no-op; 170 mirrors due, zero pulled) -- so the new hub keeps
the same division of labor: forgejo serves, gitea-mirror syncs
(CT 203, guests/gitea-mirror.yaml, bare-metal Bun, secrets
generated only-while-absent because a regenerated ENCRYPTION_SECRET
makes stored tokens unreadable). Native mirror rows are left as
legacy state; the homelab mirror created 2026-11-23 via the migrate
API (funkybooboo/homelab, 8h interval) stays -- it costs nothing
and a native pull is harmless alongside pushes.

TRAPS WORTH KEEPING: forgejo's FORGEJO__ env overrides are IGNORED
by the runtime when --config is passed (proven live); a pgdata-restored
DB is postgres-owned and migrations fail until a per-relkind DO-block
reassigns user objects (REASSIGN OWNED BY postgres is impossible);
forgejo rewrites app.ini post-migration (ReadWritePaths needed in a
hardened unit); apt auto-start crash-loops tailscaled in fresh CTs
and trips systemd's start limit (guest_common drop-in fixes it).


## Greenfield arcs (to be written as they ship)

v4 automation polish, v5 platform refresh -- each appended above
as its stories flip done.

## The extraction ledger

The dump-archive consumption record (the dated table that used to
live in docs/data-to-extract.md; dates = the dump used, not the
restore day):

| CT | Service | Newest dump | Outcome |
| --- | --- | --- | --- |
| 106 | n8n | 2026-11-21 | extracted (tier 0) |
| 107 | forgejo hub | 2026-11-21 | restored (OPS-9) |
| 108 | postgres | 2026-11-21 | restored (OPS-10) |
| 109 | vaultwarden | 2026-11-21 | restored (USER-1) |
| 102 | jellyfin | 2026-09-26 | restored (USER-2) |
| 132 | navidrome | 2026-09-26 | restored (USER-2) |
| 133 | audiobookshelf | 2026-11-21 | restored (USER-2) |

Re-extraction stays possible for every row; the live archive
inventory is [docs/archive.md](../docs/archive.md).

## Incidents (pre-v3, carried from the debugging runbook)

- framework vanish x3 (Jul/Sep/Nov 2026): USB NIC same-second
  disconnect + re-enumerate; node up, network dead, no corosync
  leave. Mitigated with the udev self-heal in node_glue; permanent
  fix is a PCIe NIC.
- The old fleet's hourly pve-reboot-controller was found armed with
  live flags and a fresh lock; unattended serialized cluster reboots
  were minutes away. Decommissioned; the standing rule since:
  cluster-level actions stay human-gated.
- Service crash-loops on fresh CTs traced to packages shipping
  without data dirs and without journal-group membership
  (grafana family), plus fs.protected_regular making stale
  root-owned files poison O_CREAT. Fixed structurally in
  guest_common.
- Jinja '\1' regex backrefs in string literals are octal escapes
  and silently corrupt generated configs; the prometheus target
  template was rewritten in for-loop form.

Detail carried from the roadmap's v2 record (the roadmap is
forward-looking now; this is the last of the shipped narrative):

- Build order inside v2: observability first (every guest born
  with journald->loki, node_exporter, the five-family watcher +
  daily heartbeat), then the services.
- OPS-9 shipped as the operator's Option B: 17 users + 349 repos on
  the new forgejo (CT 202), sync rebuilt as the old fleet ran it:
  two gitea-mirror instances (CT 203 github->hub, CT 204
  github->codeberg; one shared role, base URLs hostname-derived).
  Nightly schedules; self-owned repos sync green; the
  phantom-import class (pre-existing collaborator repos) stayed
  stale-but-present by operator policy, with the exclude list as
  follow-up. In-app forgejo metrics scraped.
- The completeness audit: every old-fleet service accounted as
  live, planned (USER-6..13, OPS-24, the ONCE trio), or
  consciously deferred (USER-5 with its data warning).

## The secrets incident (2026-11-28)

Two scanner findings on the public repo, both closed same-day:

- The searxng settings secret_key was committed in the manifest
  (6f50292, an operator tool flagged it): real, exposed, low
  impact (tailnet-only service, limiter off). ROTATED the same
  hour; manifests now carry a placeholder token the
  container_guest role replaces from local/searxng-secret.env
  at deploy time (fail-loud when absent). The exposed value is
  dead.
- GitHub secret-scanning alert 1 (tailscale_api_key): the
  `tskey-paste-token-here` placeholder in the old example
  template's history -- never a real key, resolved as
  false-positive via the API.
- Standing observation, RESOLVED 2026-11-28: docs/access.md carried
  the forgejo web password in cleartext (and it matched the
  operator's broader identity naming). The password was ROTATED
  via the forgejo admin CLI (console channel; the old string was
  public in the repo's history and is now dead, verified: web
  login 303 with the new, 200-rejection with the old) and the doc
  now points at the Proton Pass vault. The grafana row also no
  longer states the stale default credential.

## 2026-11-28: the network era's close (v3 first half done)

- USER-3 daily tools CLOSED (operator-verified: freshrss reads
  208 feeds / 32k entries; excalidraw live). Five container
  guests, the mechanism the ONCE trio inherits; searxng tuned to
  a daily-usable engine spread.
- OPS-28 CLOSED: the house rides Proton end to end (blanket
  directive, issues #17), the router is the tailnet's exit node +
  subnet router (issues #18), WAN auto-failover armed. Operator
  verified in-house and away-from-home.
- The secrets incident is fully closed: searxng key rotated,
  forgejo web password rotated + vaulted, gitleaks full-history
  clean, GitHub alert resolved as false-positive. Doctrine
  recorded: rotate + resolve-as-revoked beats history rewrite;
  anything the converge renders gets the same tracked/untracked
  decision as any other artifact.
- framework's USB-NIC outage closed with a postmortem + a
  self-heal package (MAC-matched udev rule, udevd reload, and the
  one-minute watchdog ladder), proven by a live drill: NIC killed
  on purpose, node back in 3.5 minutes with zero human action.
  Hardware stays as-is (operator decision); no PCIe and no
  firmware path exist on this board, so the watchdog IS the fix.
- The five daily-tools CTs ride on thermaltake pending re-homing;
  framework re-enters guest rotation (docs updated, migration is
  the next build action).
- Docs + plans re-baselined to the present (this pass): roadmap,
  network picture, issues ledger, the two next-build stories
  rewritten from scratch (USER-5, OPS-24), and the
  browser-off-cloud map filed as their design context.

## 2026-11-28 (later): the tools tier lands + Quad9

- RE-HOMING SHIPPED: all five daily-tools CTs (.61-.65, vmids
  211-215) moved thermaltake -> framework (pmxcfs conf moves,
  disks already on pve-shared). Framework is the tools tier and
  the landing zone for USER-5 + OPS-24; thermaltake keeps the
  media fleet + the infra hub. Tailnet fronts verified
  (200/302), CT-reboot drill green (it-tools back unattended in
  40 s), fleet converge changed=0 after the manifest updates.
  One transient: thermaltake's template check timed out under
  post-migration load; re-run clean.
- DNS: the house resolver (router unbound) now forwards to
  Quad9 over DoT (9.9.9.9, verify=dns.quad9.net) per operator
  directive -- no-log upstream, malware-filtered, encrypted end
  to end, riding the Proton tunnel; ISP sees only WireGuard.
  Before this the router recursed from the root servers (also
  ISP-blind; the directive trades query-spread for one
  accountable no-log party).

- USER-5 server side shipped: firefox sync from scratch.
  syncstorage-rs (bundled tokenserver, image verified from the
  registry, not recall) as CT 216 on framework .58 behind the
  tailnet serve front; mysql 8.0.46 as the shared DB guest CT 107
  on thermaltake .20 (decision #20: postgres impossible upstream,
  in-guest rejected by the operator; sibling to postgres 101).
  Verified: https front heartbeat 200 / tokenserver 401-unauthed,
  schemas migrated, dump drill 44 tables, reboot drill 20 s.
  Build traps, now in quirks.md: the env-token guard caught my own
  off-by-one ("env:" is 4 chars, slice [4:] not [5:]); the merged
  syncserver's config sections are syncstorage/tokenserver so the
  storage URL is SYNC_SYNCSTORAGE__DATABASE_URL (compiled default
  is mysql://root@127.0.0.1/syncstorage -- wrong names fail as
  connection-refused to localhost); the binary binds
  container-loopback unless SYNC_HOST=0.0.0.0 (docker-proxy RST).

- USER-5 CLOSED end to end: firefox sync paired and verified.
  The operator's LibreWolf (user.js pref via the 000326 channel)
  signed in, and the first sync landed 4501 client-encrypted
  records / 2.1 MB in syncstorage.bso -- Mozilla no longer holds
  a copy of the household's bookmarks, history, forms, logins,
  or tabs. The pairing arc surfaced three server bugs, all
  fixed live and now in quirks.md: the bundled tokenserver ships
  with PLACEHOLDER FxA oauth creds (every exchange 401
  invalid-credentials, which Firefox surfaces as a sign-in that
  doesn't stick -- configure the public oldsync pair);
  run_migrations defaults OFF (schema never created; the 500
  said Table 'tokenserver.services' doesn't exist); and the
  migration famously does NOT seed the sync-1.5 service row +
  node (its own integration-test TODO says so) -- now a
  converge-owned idempotent tokenserver_seed block in the mysql
  manifest. Diagnostics lesson: the syncserver logs nothing at
  default level, so empty docker logs never meant no traffic --
  the client's weave/logs error files were the real evidence
  every time.
