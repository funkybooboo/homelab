# auto-update -- tiered unattended patching for the homelab

Implements the locked design in `plans/design/auto-update.md` (decisions locked
2026-08; S-variant reboot serialization chosen 2026-09-27).

Three layers by blast radius:

| tier | systems | behavior |
|---|---|---|
| A | CTs (26 running: 25 apt + 1 alpine) | auto-apply FULL updates nightly, needrestart restarts services live, error-only ntfy. No CT ever reboots (no per-CT kernel). |
| B | PVE hosts (5 nodes) | auto-apply FULL updates nightly, NEVER self-reboot; a serialized cluster reboot controller reboots flagged nodes one at a time, quorum-gated, master last. |
| C | TrueNAS, GL router | notify-only. TrueNAS polls daily and pushes ntfy on transition; apply stays manual. Router: see "Router tier" below. |

## Components

* `unattended-50.example` -> `/etc/apt/apt.conf.d/50unattended-upgrades`
  (full-update allowlist: Debian trixie + trixie-updates + trixie-security,
  Proxmox trixie, Ubuntu noble + noble-updates + noble-security;
  `Automatic-Reboot false` everywhere)
* `unattended-20.example` -> `/etc/apt/apt.conf.d/20auto-upgrades`
  (enables the stock apt timers as a backstop)
* `needrestart-auto.example` -> CTs only: needrestart restarts upgraded
  services live (postgres/nginx/jellyfin blip at 03:30 accepted by design).
  Hosts deliberately do NOT get this file: cluster services restart via the
  serialized reboot, never live by needrestart.
* `unattended-upgrade-wrapper.sh` -> runs `unattended-upgrade`, appends to
  `/var/log/unattended-upgrades/unattended-upgrades.log`, pushes ntfy
  URGENT only on failure. Host mode (auto-detected via `/etc/pve/nodes`)
  maintains the cluster-visible `/etc/pve/nodes/<host>/reboot-required`
  pmcfs flag: set when a kernel tree newer than the current boot exists
  (arch-agnostic: works for proxmox-kernel and the Pi kernel variants),
  cleared otherwise.
* `alpine-upgrade-wrapper.sh` -> apk variant for CT 101.
* `auto-update-maint.sh` -> Sunday 04:30 on hosts: `apt-get autoclean` +
  `journalctl --vacuum-time=7d`, ntfy only on errors.
* `pve-cluster-reboot-controller.sh` -> the S-variant choreography (below).
* `truenas-update-check.sh` -> daily TrueNAS poll, urgent ntfy push on
  "update available" transition, state in `/mnt/volume1/.admin/`.
* `install-host.sh` / `install-ct.sh` -> idempotent installers.

## Schedule (all "nightly 03:30 America/Denver", locked decision #4)

* PVE hosts: systemd `auto-update.timer` at 03:30 LOCAL (nodes run
  America/Denver), `Persistent=true` to catch up after downtime.
* CTs: `/etc/cron.d/auto-update` at 30 09 * * * when the CT runs UTC
  (03:30 MDT == 09:30 UTC; the hour is derived from each CT's own timezone
  at install time, so a CT set to Denver gets 03:30 directly). CTs do NOT
  chase DST (accepted: a fixed UTC hour drifts to 02:30 Denver in winter --
  still the middle of the night).
* Reboot controller: hourly on every host via `/etc/cron.d/pve-reboot-
  controller` (randomized minute per node), guarded by the pmcfs heartbeat
  lock.
* TrueNAS poll: daily 09:00 TrueNAS-local (middleware cronjob).
* Sunday maintenance: 04:30 on hosts.

## The reboot controller (S-variant), in one paragraph

Every node's wrapper writes `reboot-required` on pmxcfs when it installed a
kernel newer than the running one. Hourly, one node wins the heartbeat lock
(`/etc/pve/auto-update/lock`, pve-balance pattern: claim, re-read to break
races, holder refreshes each step, peers defer while fresh, TTL 900s
takeover) and reboots flagged nodes ONE AT A TIME in order: raspberrypi
(arm64 witness, hosts no guests) first, non-master x86 nodes, the HA master
last, and itself always last (a self-reboot ends the cycle; the next hourly
pass continues from a peer). Before each reboot it verifies the cluster is
quorate, all nodes online, and all HA services settled; after each reboot
it waits for the node to leave, return, quorum to restore, and every HA
service to recover before moving on (and clears that node's flag). Any
timeout pushes an URGENT ntfy and stops for a human. This is how
"reboot allowed" (locked decision #1) avoids the 5-nodes-at-once corosync
quorum-loss cascade that naive `Automatic-Reboot=true` would cause.

## Install

From this directory (repo = source of truth; deployed by hand like the
other homelab services):

```sh
# PVE hosts (all 5; idempotent, restarts nothing):
for n in pve-framework pve-aspires pve-aspiree15 pve-thermaltake raspberrypi; do
  scp -r services/auto-update "root@$n:/root/" && ssh "root@$n" /root/auto-update/install-host.sh
done

# CTs (run ON the node hosting each CT):
/root/auto-update/install-ct.sh <vmid>     # apt CTs and the alpine CT both

# TrueNAS (script + middleware cronjob):
scp services/auto-update/truenas-update-check.sh root@truenas:/mnt/volume1/.admin/
midclt call cronjob.create '{"user":"root","command":"/mnt/volume1/.admin/truenas-update-check.sh","description":"Auto-update: daily TrueNAS update-available poll (notify-only)","schedule":{"minute":"0","hour":"9","dom":"*","month":"*","dow":"*"},"enabled":true,"stderr":true,"stdout":true}'
```

Verify: `systemctl list-timers auto-update.timer` on hosts;
`cat /etc/cron.d/auto-update` in a CT; run any wrapper by hand once and
watch `/var/log/unattended-upgrades/unattended-upgrades.log`.

## Revert

Hosts: `systemctl disable --now auto-update.timer`, remove
`/etc/cron.d/pve-reboot-controller` + `/etc/cron.d/auto-update-maint`,
restore the stock `/etc/apt/apt.conf.d/50unattended-upgrades` (or
`apt-get purge unattended-upgrades`). CTs: delete `/etc/cron.d/auto-update`
(alpine: remove the crontabs/root line), `apt-get purge unattended-upgrades
needrestart` inside the CT, remove `/usr/local/sbin/unattended-upgrade-
wrapper.sh`, `/usr/local/sbin/ntfy-publish.sh`, `/etc/ntfy-publish.env`.
TrueNAS: `midclt call cronjob.delete <id>`.

## ntfy credentials

The existing `/etc/ntfy-publish.env` (mode 600, topic token) is copied from
the hosting PVE node into each CT by `install-ct.sh` (accepted token reuse
per locked decision #3; worst case if a CT is owned = spam on a
tailnet-only, deny-all ntfy topic).

## Router tier (deliberately NOT automated)

The design says notify-only for the GL-MT2500. Probed live 2026-09-27:
GL's custom 21.02-SNAPSHOT build has NO firmware-check CLI (no `gl_firmware`),
no update-flag file, and the web UI checks GL's cloud API with session auth
we do not own. opkg upgrades on GL's busybox-override build stay manual too
(locked decision #7: notify-only anyway). Until GL exposes a clean signal,
router firmware updates are manual via the GL web UI -- revisit if the
router ever moves to vanilla OpenWrt.

## Known notes

* `unattended-upgrade` exits 0 even on some inner failures; the wrapper
  additionally greps its output for "returned an error" and treats that as
  failure.
* The reboot-required signal is kernel-tree-mtime-vs-boot-time, plus
  `/var/run/reboot-required` if anything ever installs it -- deliberately
  NOT `uname -r` vs newest `/boot/vmlinuz-*`, which mis-sorts the Pi's
  kernel variants (2712 vs v8) and would flag the witness forever.
* HA resources in the parked `freeze` state do not block the controller
  (they are a known deliberate state); `starting`/`stopped` do.