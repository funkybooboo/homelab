# Proxmox cluster & HA

A 5-node Proxmox Virtual Environment cluster on the tailnet, with shared
NFS storage from TrueNAS and a Raspberry Pi as a quorum-witness node.

## Nodes

| node | role | arch | notes |
| --- | --- | --- | --- |
| `pve-thermaltake` | PVE node | x86_64 | desktop |
| `pve-aspiree15` | PVE node | x86_64 | laptop; lid-ignored + screen off (see `docs/laptop-nodes.md`) |
| `pve-aspires` | PVE node | x86_64 | laptop; same |
| `pve-framework` | PVE node | x86_64 | desktop |
| `raspberrypi` | PVE quorum-witness only | arm64 | **no workloads** -- no `pve-lrm`; see below |

Cluster communication uses LAN IPs (corosync 192.168.8.x); tailnet is only for
user-facing HTTPS and cross-host management, not for cluster traffic. `ha-manager`
master is `pve-aspiree15`; all 4 x86 LRMs active; corosync 5/5 quorum.

## The Pi rule (important)

`raspberrypi` is a **quorum-witness only** -- it has NO `pve-lrm.service`
(the Local Resource Manager). Any HA-managed CT placed on the Pi will get
stuck in `freeze` state (no LRM to act on the migrate/restart request).

* Never `ha-manager add` a CT that lives on the Pi.
* Never migrate a running HA CT to the Pi.
* If a CT ends up on the Pi and freezes, recovery is a 3-step dance (shared
  storage makes this cheap, ~1 minute):
  ```sh
  ha-manager remove ct:<vmid>          # remove from HA (frozen + no LRM to migrate)
  pct migrate <vmid> pve-framework     # config-only relocation (shared storage)
  ha-manager add ct:<vmid>            # re-add; node inferred from location
  ```

## Running CT placement (snapshot 2026-07)

- pve-thermaltake: 101,102,104,107,111,122,127 (+templates 100,110,114-117)
- pve-aspiree15: 106,113,121,124
- pve-aspires: 103,118,120,123
- pve-framework: 105,108,109,112,119,125,126 (incl. ntfy = 128)
- raspberrypi: NONE (witness only)

HA can relocate CTs between nodes automatically on failure -- proven live
when pve-aspires briefly lost pve-shared and ha-manager migrated 5 CTs onto
pve-framework while it stayed reachable.

Note that HA is high-availability only -- it never watches load and never
redistributes guests for balance. That gap is filled by `pve-balance`
([`services/pve-balance/`](../services/pve-balance/)): a load-aware
auto-balancer that scores each node relative to its hardware and, when the
within-arch spread exceeds a threshold, live-migrates one guest from the
hottest node to the coolest same-arch receiver. It runs on **`raspberrypi`
only** on a 1h timer -- the arm64 quorum-witness is the neutral arbiter
(zero workloads = no bias toward offloading itself; and if the Pi dies the
cluster loses its 5th corosync vote anyway, so the balancer failing is the
least of the problems). The script still carries cluster-coordination code
(heartbeat lock + shared cooldown on `/etc/pve/`) so it can be flipped back
to multi-node any time by enabling the timer on x86 nodes.

## Storage

Shared storage comes from `truenas` (TrueNAS) over NFS:

| PVE storage id | NFS export | role |
| --- | --- | --- |
| `pve-shared` | `/mnt/volume1/pve/shared` | live container disks (`*.raw`) |
| `pve-backups` | `/mnt/volume1/pve/backups` | vzdump backup target |
| local per-node | `local`, `local-lvm` | templates, ISOs, CT rootfs |

See `docs/storage.md` for the NFS config + the jellyfin-media mount puzzle.

## Per-CT conventions

- Every CT runs its **own Tailscale** (each CT is its own tailnet node). Tailscale
  state persists in `/var/lib/tailscale` -> serve config survives reboot.
- Web CTs exposed via `tailscale serve --bg --https 443 --yes
  http://localhost:<port>` (tailnet-only, LE cert auto-renewed by tailscaled;
  see `docs/https.md`).
- DNS hardening: `pct set <vmid> --nameserver 192.168.8.1
  --searchdomain tail54538d.ts.net` + `tailscale set --accept-dns=false` on
  every CT so `tailscale cert` can reach LE regardless of MagicDNS flakiness
  (see `docs/https.md` "DNS gotcha").
- `onboot:1` only where the CT is NOT HA-managed AND must come up before a
  host-level dependency (jellyfin waits for the NFS media mounts via
  `/etc/systemd/system/start-jellyfin.service` on pve-thermaltake; see
  `docs/storage.md`). HA-managed CTs are restarted by the LRM on boot, so
  leave `onboot` at default for those.
- CTs generally do NOT expose SSH :22 on the tailnet -- use `pct exec
  <vmid> -- <cmd>` via a PVE node instead.