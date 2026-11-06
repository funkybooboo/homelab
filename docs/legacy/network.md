# The old LAN (192.168.8.0/24)

The subnet the whole old fleet hardcoded, and the reason the rebuild
is greenfield. Recorded so nothing ever re-anchors to it, and so the
v1 network plan (OPS-2) knows exactly what moved where.

## Router

- **GL-MT2500** (OpenWrt 21.02, GL.iNet "Beryl") at `192.168.8.1` --
  the DHCP server, DNS forwarder, and internet gateway. Dead
  (retired 2026-10-28, unrecoverable). Its successor: the Protectli
  V1210 running OPNsense 25.7 at `192.168.1.1` on the NEW
  192.168.1.0/24 LAN.
- Transfer quirk: the GL-MT2500 had no `sftp-server` -- file pushes
  used `cat | ssh root@router 'cat > file'`. OPNsense (FreeBSD) is not
  so constrained.

## Static / reserved hosts (the whole table)

| host | MAC | IP | mechanism |
|------|-----|----|-----------|
| `truenas` | `6c:bf:b5:04:d9:97` | 192.168.8.100 | static at OS via midclt (enp1s0, `ipv4_dhcp=false`, alias `/24`) + router reservation |
| `pve-thermaltake` | `4c:ed:fb:bf:ab:7d` | 192.168.8.117 | DHCP reservation only |
| `pve-aspiree15` | `54:ab:3a:9b:e9:4c` | 192.168.8.102 | DHCP reservation only |
| `pve-aspires` | `00:e0:4c:68:a4:fa` | 192.168.8.103 | DHCP reservation only |
| `pve-framework` | `9c:bf:0d:01:4c:d6` | 192.168.8.129 | DHCP reservation only |
| `raspberrypi` | `d8:3a:dd:45:d3:7e` | 192.168.8.243 | DHCP reservation only |

Note the node IPs carry NO pattern (thermaltake .117, framework .129,
Pi .243) -- they pinned whatever DHCP handed out, because PVE nodes
cannot change IP without rewriting `corosync.conf`. The v1 plan fixes
this: static from `ips.yaml` on day one (OPS-2).

CTs/VMs got NO reservations -- LAN IPs came from the router's DHCP
pool; the primary access path was always the tailnet name. Known CT
LAN IPs from the final state: 130 loki `192.168.8.130` (static),
131 syncstorage `.190`, 132 navidrome `.230`, 133 audiobookshelf
`.126`, 134 omnivore `.185` -- i.e. the media batch did NOT follow any
scheme either (dhcp leases + one manual static).

## Why the subnet was load-bearing

- `corosync.conf` hardcoded the 5 node LAN IPs (cluster traffic on
  the LAN, never the tailnet).
- truenas NFS exports + every node's fstab hardcoded `.100`.
- Every CT's `nameserver 192.168.8.1` (DNS hardening decision).
- PVE storage defs (`pve-shared`, `pve-backups`) pointed at
  `192.168.8.100`.

When the GL-MT2500 died and the LAN renumbered to 192.168.1.0/24, ALL
of that broke at once; nothing was worth un-breaking piecemeal. That is
the greenfield verdict in one paragraph.

## Tailnet

- Tailnet `tail54538d.ts.net`. Every CT was its own tailscale node
  (its own keys, `/var/lib/tailscale` persisted in rootfs) with
  `tailscale serve` HTTPS fronts. ~35 tailnet nodes total.
- Node consoles + truenas also on the tailnet; debbie, kelsey-laptop,
  MacBook are the surviving member devices (post-wind-down).
- truenas needed a static `/etc/hosts` entry for
  `ntfy.tail54538d.ts.net -> 100.106.74.87` because its tailscale app
  container didn't inject the tailnet resolver the way PVE did.
- Incident: the router once blocked loki's DHCP IP (`.120`) silently
  (stale lease/MAC mismatch) -> loki got a static `.130`. Symptom
  class to remember: router DHCP state can wedge a CT invisibly.

## What carries forward unchanged

- The tailnet + its DNS name (all `*.tail54538d.ts.net` certs remain
  valid; tailscale is the account-level constant).
- truenas's MAC + NFS export paths (renumbered host, same datasets).
- Node MACs (same physical boxes, if they return per issues item 2).
