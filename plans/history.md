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
- 2026-10-19: truenas + every remaining CT (one mass stop).
- 2026-10-28: the last three nodes (`pve-aspires`, `pve-aspiree15`,
  `raspberrypi`) + the GL-MT2500 retired; OPNsense at 192.168.1.1 takes
  the LAN (new subnet: 192.168.1.0/24).
- 2026-11-04: state verified by network forensics -- everything dark,
  the old subnet dead, only debbie + the laptops on the tailnet.

## Greenfield arcs (to be written as they ship)

Each arc's as-built record is appended here when its stories flip to
done: v1 foundations, v2 IaC skeleton + core services, v3 service
batches, v4 automation polish.
