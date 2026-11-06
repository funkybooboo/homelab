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
is 28. All recorded with sources in `docs/legacy/README.md`.

## Greenfield arcs (to be written as they ship)

v1 foundations, v2 IaC skeleton + core services, v3 service batches,
v4 automation polish -- each appended above as its stories flip done.
