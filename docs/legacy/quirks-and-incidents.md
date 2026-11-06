# Quirks, traps, and incidents (the old fleet's lessons)

What the old cluster taught the hard way. The greenfield design
records which of these each decision retires; this file is the
complete list so nothing gets relearned.

## Architecture-level quirks

- **The Pi rule**: `raspberrypi` (arm64) is a quorum-witness only -- no
  `pve-lrm`. HA CTs placed on it freeze (no LRM to act); recovery =
  `ha-manager remove` -> `pct migrate` -> `ha-manager add`. It also
  stranded amd64 packages, so pve-balance moved guests only within
  per-arch families. Retired by: Pi becomes a QDevice (OPS-6) and
  never hosts anything.
- **HA placement drift was constant**: failovers + pve-balance moved
  CTs between nodes routinely -- docs/services.md (July) and the final
  state disagree on most placements. Never trust a static "CT X lives
  on node Y" note from this era; the per-CT record is the config, not
  the doc.
- **pve-balance** (retired): scored nodes by `0.7*load15/cores +
  0.3*memused/memtotal`, one migration/hour max, 3h per-guest cooldown,
  ran on the Pi as neutral arbiter, with dormant multi-node
  coordination code. `EXCLUDE_NODES=["pve-framework"]` after its NIC
  went flaky. PVE 9.2's native Dynamic Load Balancer replaces it.
- **Local-lvm CTs do not migrate**: 128 ntfy (framework) + 130 loki
  (thermaltake) had rootfs on local-lvm for reliability -- if the host
  died, HA showed a phantom "started" on the failover target while the
  disk sat on the dead node. Deliberate trade (NFS flakiness > host
  SPOF for those two).
- **HA error-state dance**: NFS gone + a stopped CT = `error` state
  that refuses plain `pct start` (exit 255). Fix: `ha-manager set
  ct:N --state disabled` -> wait 15s (LRM watchdog drain) -> fix
  storage -> `pct start` -> `--state started`. Full write-up:
  [../ha-recovery.md](../ha-recovery.md).
- **emergency_ro rootfs**: a CT running through an NFS suspension could
  flip rootfs to read-only (`emergency_ro` mount flag) -- freshrss
  showed it first with "Read-only file system" in its installer lib.
  Fix: `pct reboot N` + verify `mount | grep ' / '`.

## Incidents, in order

1. **truenas DHCP IP loss cascade** (the motivating incident for
   services/network/): DHCP renewal handed truenas a different lease
   -> NFS pve-shared offline for every node -> running CTs kept cached
   pages, stopped CTs unstartable, HA services stuck in `error`.
   Fix-layer: truenas static via midclt + all node/router
   reservations. Greenfield fix-layer: no host is ever DHCP (OPS-2).
2. **bichon stranded on the Pi**: HA CT living on the Pi froze
   (the canonical Pi-rule incident). Migrated off with the 3-step
   dance.
3. **pve-aspires lost pve-shared** (2026-07): HA live-migrated 5 CTs
   onto pve-framework while it stayed reachable -- the one time HA
   worked exactly as designed, mid-incident.
4. **pve-framework offline 2026-07-18..26**: cause never diagnosed.
   Its USB 2.5GbE NIC was suspected flaky from then on; pve-balance
   excluded the node permanently.
5. **GL-MT2500 blocked loki's lease** (.120) silently -- stale
   lease/MAC mismatch; loki moved to static .130.
6. **vzdump notify was silent** (mail-to-root, no relay) -- backup
   failures invisible until the ntfy bridge existed. Fixed by
   services/auto-update era wiring; v4's OPS-14 makes restore drills
   the check, not notifications.
7. **B2 storage-cap 403 aborts** (backups.md): the old cloud-sync
   attempted live `*.raw` disks (crash-inconsistent + the bulk of the
   bytes) -> hit the application-key cap. Fix recorded: sync only
   vzdump artifacts + user data, never live disks. The current 5-leaf
   snapshot task tree (post-fix, B2, never stopped) is the surviving
   part.
8. **2026-09-27 framework vanished** mid-reboot-controller cycle (the
   flaky USB NIC's final act) and never returned -- first box of the
   wind-down, one month before the rest.

## Per-node glue (lived only on the nodes -- reproduce from repo)

Nothing on the PVE nodes was dotfiles-managed (the "persistence gap").
Everything below was hand-placed; OPS-5's bootstrap role codifies it:

- All 5 nodes: `renew-pve-tls.sh` + `/etc/cron.d/renew-pve-tls`
  (services/pve-tls/) -- LE certs for pveproxy :8006 via the tailnet.
- Laptops (aspiree15, aspires): `logind.conf.d/no-lid-suspend.conf` +
  screen-off-at-boot unit (docs/laptop-nodes.md).
- pve-thermaltake: `/etc/fstab` 5-line NFS media block +
  `start-jellyfin.service` (boot-race fix) + nvidia-uvm-devnodes hook
  (services/nvidia-uvm-devnodes/).
- All nodes: pve-shared-nfs-remount helper (services/pve-shared-nfs-remount/)
  for stuck mounts after truenas reboots.
- pve-framework: ntfy CT's local-lvm disk + bridge config
  (services/ntfy/ holds the reproducible config).

## Application traps worth remembering

- **Next.js behind `tailscale serve`**: `INTERNAL_API_URL` must be
  `http://localhost:<port>` or login succeeds then every page bounces
  to `/login`. Hit in cronmaster (127); linkwarden + excalidraw
  never audited (docs/nextjs-behind-tls-proxy.md).
- **Jellyfin `/media/media` double-nest**: CT saw
  `/mnt/media/media/<sub>` because each host mountpoint nested one
  level; jellyfin library paths in `options.xml` baked it in.
- **FreshRSS**: OPML re-import is manual (no live-subscribe); feed
  daemon can wedge on `Retry-After` state after rootfs incidents
  (services/freshrss/README.md).
- **prometheus scrape vs serve**: raw-HTTP scrape (`:9221/pve`) and
  the serve TLS front (`:443`) coexisted fine -- never scrape through
  `serve`; HTTPS on the exporter breaks the scrape unless config
  matches (the skill's 124 note).
- **Git via tailscale serve**: forgejo SSH clone on :22 needed the
  CT's own tailscale node + `SSH_DOMAIN` set to the tailnet name.
