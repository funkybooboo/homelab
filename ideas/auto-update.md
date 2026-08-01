# Automated updates for the homelab

## Executive summary

Patch every host in the homelab automatically, but tiered by blast radius:

* **CTs** (23 running) -- auto-apply security + distro updates via
  `unattended-upgrades`, low risk. Most are stateless web apps. Pushes a
  per-run summary to ntfy.
* **PVE hosts** (5 nodes) -- auto-apply security-only updates, NEVER
  auto-reboot. Cluster reboot choreography stays human-driven; the script
  just surfaces "reboot required" loudly so it can't be forgotten.
* **Router** (GL-MT2500) -- **notify-only**. GL.iNet runs a custom OpenWrt
  21.02-SNAPSHOT build; firmware updates come from GL.iNet's own updater and
  must be applied manually. opkg-upgrade of runtime packages is also risky
  on GL's `busybox override` build, so we just poll for available updates
  + push a weekly digest.
* **TrueNAS** (storage) -- **notify-only**. ZFS host -- never auto-patch.
  A wrapper polls `midclt call update.*` (or the equivalent API call) and
  surfaces "update available" to ntfy. Apply is manual via the UI.
* **VMs** -- 0 running today. Four VM templates exist (100, 114, 115, 117)
  but they are all STOPPED. Templates will be picked up automatically when
  they get cloned+started (Phase 1 design treats them like any other apt
  host). Nothing to schedule while they're stopped.

Three-layer risk model: **auto-apply where a single-CT outage is the worst
case** (CTs) ; **auto-apply-but-don't-reboot where cluster coordination is
needed** (PVE hosts) ; **notify-only where an unattended update could brick
or destabilize the box** (router, TrueNAS, ZFS pools).

All notification rides the EXISTING ntfy pipeline (the `ntfy_publish` helper
is already deployed to all 5 PVE hosts + TrueNAS, the homelab topic token is
already minted). No new secrets are introduced unless we decide to push from
CTs directly (see open question 3).

## Verified current state (probed live 2026-08)

### PVE nodes (5)

| node | arch | OS | PVE | repomode | unattended-upgrades? | pending | notes |
| --- | --- | --- | --- | --- | --- | --- | --- |
| pve-thermaltake | x86_64 | Debian trixie | 9.2.4 | pve-no-subscription (enterprise disabled) | NOT installed | 72 | desktop, has GPU |
| pve-aspiree15 | x86_64 | Debian trixie | 9.2.4 | pve-no-subscription | NOT installed | 65 | laptop, lid-ignored, HA master |
| pve-aspires | x86_64 | Debian trixie | 9.2.4 | pve-no-subscription | NOT installed | 65 | laptop, lid-ignored |
| pve-framework | x86_64 | Debian trixie | 9.2.4 | pve-no-subscription | NOT installed | 39 | was offline Jul 18-26 once -- watch |
| raspberrypi | arm64 | Debian trixie | 9.0.10 | pve-no-subscription likely | NOT installed | 35 | quorum-witness only, no CTs |

All five have `apt-daily.timer` (refresh indices) and `apt-daily-upgrade.timer`
enabled, but the `apt-daily-upgrade.service` unit is **static** and points at
`unattended-upgrade`, which is not installed -- so the enabled timer does
nothing. Effectively nothing auto-updates on any node today. Ceph + enterprise
repos are present but disabled (`Enabled: false`); enabled repos are
`pve-no-subscription`, `tailscale`, `debian trixie`, `debian-security`.

### CTs (23 running)

Pull (`pct exec <vmid> -- apt-get -s upgrade | grep -c ^Inst`):

| CT | os | package mgr | pending | notes |
| --- | --- | --- | --- | --- |
| 101 alpine-it-tools | Alpine 3.24 | apk | 0 | only apk host |
| 102 jellyfin | Ubuntu 24.04 | apt | 0 | GPU passthrough |
| 104 freshrss | Deb trixie | apt | 1 | |
| 107 forgejo | Deb trixie | apt | 0 | big state |
| 108 postgresql | Deb trixie | apt | 0 | only database CT |
| 103/105/106/109/111/113/118/119/120/121/122/123/124/125/126/127 | Deb trixie | apt | 0 | mostly recent |
| 112/118 | Ubuntu 24.04 | apt | 0 | linkwarden, jupyternotebook |
| 128 ntfy | Deb trixie | apt | 64 | NOT on the periodic upgrade path -- drift |
| 130 (loki) | Deb trixie | apt | 65 | NEW (observability Phase 2); not yet on upgrade path |

`unattended-upgrades` is NOT installed on any CT (probed 5 representative
CTs: 102, 104, 112, 128, 130 -- all `NOT_INSTALLED`, no
`/etc/apt/apt.conf.d/50unattended-upgrades`). The default trixie image ships
the `20auto-upgrades`/`50unattended-upgrades` snippets dropped only when
`unattended-upgrades` gets installed. So today: zero auto-patching on CTs.

### VMs

`qm list` across all 5 nodes: only four STOPPED templates
(100 ubuntu, 114 debian, 115 almalinux, 117 arch -- all on pve-thermaltake).
**No running VMs.** Templates get maintained on demand: start -> update ->
snapshot -> stop.

### Router (GL-MT2500)

```
DISTRIB_ID='OpenWrt'  DISTRIB_RELEASE='21.02-SNAPSHOT'
DISTRIB_TARGET='mediatek/mt7981'  DISTRIB_ARCH='aarch64_cortex-a53'
DISTRIB_TAINTS='busybox override'    <-- GL.iNet custom build
435 installed pkgs, no auc/autoupgrade, no /etc/crontabs/root, no sysupgrade conf
```

This is a GL.iNet firmware, not vanilla OpenWrt. Kernel build date June 2025
(recent) but the OpenWrt base is 21.02-SNAPSHOT (old). Two update paths exist:

* **GL.iNet firmware**: GL's own updater (`gl-fi --version`, `/etc/init.d/glfi`
  if installed) -- apply via GL web UI. Manual only.
* **opkg packages**: `opkg update && opkg upgrade <pkgs>`. Risky on GL's
  `busybox override` taint -- an opkg upgrade of busybox could wedge the
  router. Most homelab guides say: keep GL.iNet routers on GL firmware,
  don't opkg-upgrade the base.

Recommendation: **notify-only**. Monitor GL's "firmware update available"
flag from inside the router (or from a tailnet host polling GL's API) and
push to ntfy. Leave opkg alone.

### TrueNAS

```
version: 25.10.5  (Electric Eel)
base OS: Debian 12 bookworm  <-- NOT the same tree as PVE hosts (trixie)
root FS: read-only (writable: /root, /var/tmp, /mnt/volume1)
```

TrueNAS does NOT use apt for system updates -- it has its own "update train"
system. `apt-get upgrade` on TrueNAS is unsupported (will diverge the
middleware). Update is applied via the UI, or via `midclt call update.update`
(TBD on exact call -- needs a quick live probe during the build, not before).
We will **notify-only**: poll for an available update + push to ntfy when it
appears.

### Existing rails (why this is cheap)

* ntfy is deployed (CT 128), `ntfy_publish` helper is on all 5 hosts +
  TrueNAS, the homelab topic + token are minted (`/etc/ntfy-publish.env`
  mode 0600 root-only). Reusing the existing TrueNAS-bridge token works.
* The 5 Phase-1e wrappers (renew-pve-tls, renew-truenas-tls,
  pve-shared-remount, vzdump hook, ha-state-watch) already established the
  "bash script -> curl-to-ntfy" pattern; one more on-host cron per host is a
  drop in the bucket.
* `~/dotfiles/migrate.sh` has NO PVE/CT deploy path (same gap every homelab
  service rubs against). So this is hand-deployed like the others
  (`services/<name>/` in-repo + individuals deployed via SSH). Repo = the
  reproducible backup.

## Target state

### Tier A -- CTs (auto-apply per-CT, error-only ntfy) -- Design A, USER CHOICE

Each apt CT runs `unattended-upgrades` INDEPENDENTLY. Full-update allowlist
(security + regular `trixie-updates`). No per-host orchestrator.

Per apt CT:
* Install `unattended-upgrades` package.
* Drop `/etc/apt/apt.conf.d/50unattended-upgrades` (full-update allowlist)
  + `20auto-upgrades` (enable).
* A systemd timer or `/etc/cron.d` entry runs ~03:30 America/Denver. A
  wrapper (`unattended-upgrade-wrapper.sh`) calls `unattended-upgrade`,
  then inspects exit code + tail of `/var/log/unattended-upgrades/
  unattended-upgrades.log`; on non-zero / error tail it calls
  `ntfy_publish` urgent `rotating_light` with the failing CT name + log
  tail. **Silent on a clean run** (user: push-on-errors-only).
* `ntfy-publish.sh` + `/etc/ntfy-publish.env` deployed INTO each CT
  (reuses the existing homelab topic token; token scope grows from 6 hosts
  to ~26 reuses -- accepted. Threat model: tailnet-only bearer on a
  deny-all ntfy server, worst case = spam notifications if a CT is owned.)

CTs share the HOST kernel -- a CT "full update" installs userspace only;
`needrestart` restarts affected services LIVE. No CT reboot is needed for
kernel updates (there is no per-CT kernel). Service restarts during the
03:30 window may briefly drop a request (e.g. postgres CT 108) -- accepted
as the nature of nightly auto-update; Debian's postgresql-common handles
graceful restart.

Alpine CT 101 is the one non-apt host -- `apk update && apk upgrade` via a
parallel cron wrapper, same error-only ntfy.

NO pre-patch `pct snapshot` in the scripts -- user already has snapshot
coverage (the Sat 21:00 vzdump job). Don't double-snapshot.

### Tier B -- PVE hosts (full updates, auto-reboot ALLOWED -- SERIALIZED)

**USER CHOICE**: full updates (security + `trixie-updates`) + reboot allowed.
But naive `Automatic-Reboot=true` on all 5 nodes reboots them
near-simultaneously when the same kernel update lands -> corosync quorum
loss -> HA cascade (the exact scenario ha-state-watch + pve-shared-remount
were built to catch). So the install MUST be the serialized variant below
(unless the user explicitly accepts the thundering-herd risk -- see the
one remaining open item at the bottom).

Per node:
* Install `unattended-upgrades` with `Automatic-Reboot "false"` (the
  per-node daemon does NOT reboot by itself).
* `50unattended-upgrades` FULL-update allowlist:
  `o=Debian,a=trixie; o=Debian,a=trixie-updates; o=Debian,a=trixie-security;
  o=Proxmox,a=trixie; o=Ubuntu,a=noble; o=Ubuntu,a=noble-updates;
  o=Ubuntu,a=noble-security` (PVE is trixie; Ubuntu suites there in case
  any Ubuntu PVE host is ever added).
* A 03:30 systemd timer runs `unattended-upgrade`; the wrapper leaves the
  `/var/run/reboot-required` state (set by needrestart + kernel updates)
  for the cluster-reboot controller to act on.

Reboot is coordinated by a separate **cluster-reboot controller**
(`pve-cluster-reboot-controller.sh`): one instance, runs on a cron on every
node but guarded by a `/etc/pve/lock-reboot-controller` file (cluster-wide
pmcfs, atomic via `flock`) so only one acts:
1. Scan all 5 nodes for `reboot-required`.
2. Pick ONE node that needs reboot, safest order: quorum-witness Pi first,
   then non-master x86, HA master (pve-aspiree15) LAST.
3. Verify full quorum + no other node mid-reboot (the pmcfs lock).
4. `pvecm reboot <node>` -- wait for the node to leave `pvecm status`,
   then wait for it to rejoin + corosync quorum restored + any HA
   services that live there recovered (`ha-manager status` all started).
5. ntfy push `arrow_up low` per reboot-completed node; urgent
   `rotating_light` if the node fails to rejoin quorum within a timeout
   (needs-human). Loop to the next reboot-required node.

This honors "reboot allowed" without the 5-at-once quorum-loss cascade.

### Tier C -- Router + TrueNAS (notify-only)

* Router: a tiny `router-update-check.sh` runs on the router (or on a PVE
  host polling via SSH/tailnet). If GL's firmware-update flag is set, push
  ntfy `arrow_up` urgent. Push only on TRANSITION (available -> not), no
  recurring digest -- matches the ha-state-watch transitions-only pattern.
* TrueNAS: one wrapper on the TrueNAS box (`truenas-update-check.sh`)
  using `midclt` (TBD exact call -- quick live probe at build time, not
  now) -- already has the ntfy helper + token. Push urgent `arrow_up`
  on transition (update train newly available). Default poll cadence:
  daily 09:00. (User said "notify only"; cadence not explicitly picked --
  defaulting to daily poll, push-on-transition.)

No new CTs. No new binaries beyond `unattended-upgrades` (Debian pkg) and
a few bash wrappers. No new secrets (reuses the existing ntfy topic token).

## Repo layout (preliminary)

```
services/auto-update/
  README.md                       -- what + why + per-CT/per-node install + revert
  unattended-50.example           -- /etc/apt/apt.conf.d/50unattended-upgrades
                                    (full-update allowlist, Automatic-Reboot=false)
  unattended-20.example           -- /etc/apt/apt.conf.d/20auto-upgrades
  unattended-upgrade-wrapper.sh   -- per-CT + per-node run wrapper (error-only ntfy)
  alpine-upgrade-wrapper.sh       -- apk variant for CT 101
  install-ct.sh                   -- idempotent: install u-u + drop configs + wrapper
                                    + ntfy-publish.sh + ntfy-publish.env into one CT
  install-host.sh                 -- idempotent: same for a PVE node (no reboot by u-u)
  pve-cluster-reboot-controller.sh -- serialized, quorum-gated reboot orchestrator
  router-update-check.sh          -- notify-only, GL firmware transition
  truenas-update-check.sh         -- notify-only, TrueNAS update train transition
  crontab.example                 -- /etc/cron.d entries (one per schedule)
  ntfy-publish.env.example        -- already exists in services/observability/ (reuse)
```

All scripts committed here; live deployed to each host per the README's
install section (mirrors renew-pve-tls / ntfy-publish / pve-shared-remount).

## Schedule

* Nightly 03:30 America/Denver: `unattended-upgrade-wrapper.sh` runs in
  every apt CT via its own `/etc/cron.d` or systemd timer (Design A).
* Nightly 03:30 America/Denver: the same wrapper runs on each PVE node.
* Hourly (or on a short timer): `pve-cluster-reboot-controller.sh` checks
  for `reboot-required` across the cluster and serializes reboots (Tier B
  S-variant). Paired with: Sundays `apt autoclean` + `journalctl
  --vacuum-time=7d` (separate cron, no ntfy unless it errors).
* Daily 09:00: `truenas-update-check.sh` (push on transition only).
* Router check: hourly passive, push on firmware-update transition.

## Risks + how we contain them

| risk | containment |
| --- | --- |
| apt auto-upgrade breaks a stateful service (postgres 108, forgejo 107) | existing Sat 21:00 vzdump snapshots; `pct rollback $v` is the revert |
| unattended commits a PVE kernel/qemu/corosync bump | full-update allowlist INCLUDES these by user choice; the serialized reboot controller handles the reboot safely |
| 5 nodes reboot at once -> corosync quorum loss + HA cascade | serialized reboot controller reboots one node at a time gated on full quorum + HA recovery (S-variant). Literal L-variant skips this -- user's explicit acceptance |
| CT migrates between hosts mid-update -> double-apply | per-CT `unattended-upgrade` is idempotent; a migrating CT just runs on its new owner next cycle |
| router opkg-upgrade wedges busybox on GL custom build | router is notify-only; never auto-apply firmware OR packages |
| TrueNAS update destabilizes ZFS pool / app stack | TrueNAS is notify-only; manual UI apply only |
| ntfy outage during a run -> silent patching | ntfy push is best-effort (helper returns 0 on publish failure per its own code); patching still happens. We could enqueue a model answering "did I push?" but that's overkill -- low risk |

## Decisions locked (user, 2026-08)

1. PVE hosts: FULL updates, reboot ALLOWED.
2. Allowlist: full updates (security + regular) for hosts AND CTs.
3. Design A -- per-CT `unattended-upgrades` (each CT self-updates). Accepted
   cost: ntfy token + ntfy-publish.sh deployed into ~20 CTs.
4. Schedule: nightly 03:30 America/Denver.
5. No pre-patch snapshots (existing Sat 21:00 vzdump covers it).
6. ntfy: push on ERRORS only. Silent on clean runs.
7. Router: notify-only.
8. TrueNAS: notify-only (daily poll, push-on-transition -- default).

## Open item -- needs one more user call

**Reboot serialization for the 5 PVE hosts.** Naive unattended-upgrades
`Automatic-Reboot=true` on all 5 nodes reboots them near-simultaneously
(they all hit 03:30, install the same new pve-kernel, all set
reboot-required, all reboot within minutes). In a 5-node corosync cluster
that risks: (a) quorum loss during the overlap window if 3+ are down at
once, (b) HA service cascade (fence/restart churn) when nodes return,
(c) the very failure mode `ha-state-watch` + `pve-shared-remount` were
built to detect. This is THE documented Proxmox auto-reboot footgun -- it's
why enterprise deployments disable unattended-upgrades entirely.

Two implementations of "reboot allowed" -- pick one:

* **(S) Serialized (recommended)**: `Automatic-Reboot=false` per node;
  a cluster-reboot controller reboots ONE node at a time, gated on full
  quorum + HA recovery, HA master last. Honors your "reboot allowed"
  decision with zero quorum-loss risk. One extra script + a pmcfs lock.
* **(L) Literal / every-node-for-itself (your "reboot allowed" as-typed)**:
  `Automatic-Reboot=true` on all 5 nodes; they reboot when they want.
  Simpler (no controller) but the thundering-herd risk above is real. On a
  5-node cluster it USUALLY survives because corosync can keep quorum with
  3 up, but a bad stagger window takes the whole cluster down.

I recommend (S). Your call -- no code will be written until this is picked.