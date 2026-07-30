# network -- static IPs + DHCP reservations for the homelab

Incidences of TrueNAS losing its IP (DHCP renew handed it a different
lease) cascaded into NFS-pve-shared going offline for every PVE node
-> CTs failing to start -> HA services stuck in `error` state
(see [`docs/ha-recovery.md`](../../docs/ha-recovery.md)).

This directory documents the static-IP layer that prevents that class
of incident. **There is no migration in this directory** -- the changes
are live in TrueNAS middleware + the GL-MT2500 router only (dotfiles
has no TrueNAS/router provisioner, same gap as the PVE cert renewal
scripts; see `docs/notifications.md` for the same pattern). This file
is the reproducible spec.

## What has a static / reserved IP, and how

| host            | purpose        | MAC                 | IP             | mechanism
|-----------------|----------------|---------------------|----------------|------------------------------------
| `truenas`       | NFS + B2 sync  | `6c:bf:b5:04:d9:97` | `192.168.8.100`| static at OS via midclt (enp1s0, ipv4_dhcp=false, aliases=192.168.8.100/24) + router reservation
| `pve-framework` | PVE node       | `9c:bf:0d:01:4c:d6` | `192.168.8.129`| DHCP reservation only (pinned current IP -- PVE nodes cannot change IP without rewriting corosync.conf, see WARNING)
| `pve-thermaltake`| PVE node (GPU) | `4c:ed:fb:bf:ab:7d` | `192.168.8.117`| DHCP reservation only
| `pve-aspiree15` | PVE node       | `54:ab:3a:9b:e9:4c` | `192.168.8.102`| DHCP reservation only
| `pve-aspires`   | PVE node       | `00:e0:4c:68:a4:fa` | `192.168.8.103`| DHCP reservation only
| `raspberrypi`   | PVE witness    | `d8:3a:dd:45:d3:7e` | `192.168.8.243`| DHCP reservation only

All reservations PIN the current lease -- nothing actually changes IP
live. Corosync config hardcodes the LAN IPs (see
`/etc/pve/corosync.conf`), so renumbering a PVE node is a ~5-coordinated-
step procedure and risks quorum loss; this deployment deliberately
avoids that.

CTs and VMs are NOT given reservations -- they get their LAN IPs via
the PVE host's DHCP pool, which is fine because their PRIMARY access
path is the tailnet-name (`<ct-name>.tail54538d.ts.net`, 100.x.y.z),
not the LAN IP.

## Repro: TrueNAS static `.100`

SSH to TrueNAS as a user with midclt access (`nate@truenas` works;
for scale 25.x `nate` has passwordless midclt despite not being root):

```sh
midclt call interface.update enp1s0 '{
  "ipv4_dhcp": false,
  "aliases": [{"address": "192.168.8.100", "netmask": 24}]
}'
midclt call interface.commit         # applies the staged change live (idempotent)
```

Verify on the truenas host:

```sh
ip -br addr show enp1s0              # should show 192.168.8.100/24 -- no DHCP
ip route                            # default via 192.168.8.1
```

DNS + the ntfy alerting tailnet endpoint also need to be observed on
TrueNAS -- see `docs/notifications.md` + the truenas network.config
fix (router as nameserver1, 1.1.1.1 as nameserver2, static
`/etc/hosts` entry for `ntfy.tail54538d.ts.net -> 100.106.74.87`
because TrueNAS's tailscale doesn't inject the tailnet local resolver
the way PVE's does).

## Repro: GL-MT2500 router DHCP reservations

Pipe the script to the router (busybox sh -- GL-iNet OpenWrt 21.02):

```sh
cat services/network/set-reservations.sh \
  | ssh root@gl-mt2500.tail54538d.ts.net \
    'cat > /tmp/set-reservations.sh && sh /tmp/set-reservations.sh'
```

The script is idempotent -- it checks for an existing `dhcp.host` section
with the given MAC before adding. Re-running safe.

`uci commit dhcp` + `/etc/init.d/dnsmasq reload` persist + activate. A
host whose lease is already the reserved IP notices nothing; a host on
the wrong IP gets the reserved IP on its next DHCP renewal (or a forced
`dhclient -r && dhclient` inside the host, or a reboot).

## Tool-side note: router has no sftp/scp upload path

The GL-MT2500 OpenWrt Dropbear build doesn't ship `sftp-server`, so
`scp /path/file router:/dest/` fails (`/usr/libexec/sftp-server: not
found`). Use the `cat ... | ssh root@router 'cat > /dest/file'` pattern
for file transfer. The set-reservations.sh script in this directory is
written for exactly that pattern.