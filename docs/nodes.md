# Nodes

The 5 PVE cluster nodes + the TrueNAS storage box. Cluster quorum is 5/5;
the Raspberry Pi is a quorum-witness only (no workloads, no `pve-lrm`).

Cluster traffic uses LAN IPs (corosync 192.168.8.x); the tailnet
(`tail54538d.ts.net`) is for user-facing HTTPS + cross-host management only.
See [`cluster.md`](./cluster.md) for HA + the Pi rule, [`https.md`](./https.md)
for the per-node TLS renewal, and [`services.md`](./services.md) for the
CTs each node hosts.

## node summary

| node | role | arch | LAN IP | tailnet IP | has GPU? | CTs hosted | notes |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `pve-thermaltake` | PVE node | x86_64 | 192.168.8.101? | (ts) | **yes (NVIDIA)** | 101,102,104,107,111,122,127 (+templates 100,110,114,115,116,117) | desktop; drives jellyfin GPU transcode |
| `pve-aspiree15` | PVE node | x86_64 | 192.168.8.103 | (ts) | no | 105,106,109,113,119,121,124 | laptop; lid-ignored + screen-off ([`laptop-nodes.md`](./laptop-nodes.md)); HA master |
| `pve-aspires` | PVE node | x86_64 | 192.168.8.102 | (ts) | no | 103,108,112,118,120,123 | laptop; lid-ignored + screen-off |
| `pve-framework` | PVE node | x86_64 | 192.168.8.104? | (ts) | no | 125,126,128 | desktop; hosts ntfy (128) + bichon + protonmail-bridge. Was offline Jul 18-26 once -- verify long-term stability |
| `raspberrypi` | PVE quorum-witness | arm64 | 192.168.8.105? | (ts) | no | NONE | **no pve-lrm**; never host HA CTs here (see [`cluster.md`](./cluster.md) "Pi rule") |
| `truenas` | storage | x86_64 | 192.168.8.100 | 100.81.7.16 | no | -- (not PVE) | TrueNAS 25.10; NFS for `pve-shared` + `pve-backups`; HTTPS UI + cert re-import cron ([`services/truenas-tls/`](../services/truenas-tls/)) |

(LAN IPs marked `?` are approximate -- re-check with `ip a` on the node if it
matters. Cluster uses LAN for corosync + NFS; tailnet IPs are in
[`services.md`](./services.md) per CT.)

## pve-thermaltake (desktop, the GPU node)

The only node with a discrete GPU, which is why **jellyfin (102) lives here
permanently** -- it has the NVIDIA passthrough entries for hardware
transcoding. Don't migrate 102 off this node without losing GPU accel.

Hosts the bulk of the "tools" CTs (media, rss, git, prometheus) and **all
the VM + LXC templates** (100, 110, 114, 115, 116, 117). Templates live on
`pve-shared` so they're cluster-visible but are stored via this node's
`local`/`local-lvm` for the VM ones.

 specifics:
* jellyfin 102: GPU passthrough (nvidia0/nvidiactl/nvidia-modeset/nvidia-uvm/nvidia-uvm-tools), 5 NFS media mounts, `onboot:0` + `start-jellyfin.service` boot-race fix (see [`storage.md`](./storage.md)).
* the renewal cron `renew-pve-tls.sh` + `/etc/cron.d/renew-pve-tls` lives here like on every node (see [`services/pve-tls/`](../services/pve-tls/)).

## pve-aspiree15 (laptop, HA master)

`ha-manager` master is this node. Lid-ignored + screen-off at boot (see
[`laptop-nodes.md`](./laptop-nodes.md)) so closing the lid doesn't trip HA.
Hosts a broad service set: forgejo-mirror, n8n, vaultwarden, opengist,
searxng, drawio, prometheus-pve-exporter.

## pve-aspires (laptop)

The other laptop node -- lid-ignored + screen-off. Hosts speedtest-tracker,
postgresql, linkwarden, jupyternotebook, excalidraw, grafana.

## pve-framework (desktop)

Was offline Jul 18-26 once (cause not fully diagnosed). Hosts bichon (125),
protonmail-bridge (126), and ntfy (128, on `local-lvm` so it stays here).
Plenty of free RAM (~28G). Verify long-term stability since 5 CTs depend on
it; HA will migrate them to another node if it drops.

## raspberrypi (Pi, quorum-witness only)

Arm64 Pxvirt/PVE port. **Does NOT run `pve-lrm.service`** -- it's a
quorum-witness, not a workload node. Consequences:

* Never `ha-manager add` a CT that lives here (it'll freeze; the bichon
  incident is the canonical example).
* Never migrate a running HA CT here.
* Recovery if one ends up here: `ha-manager remove ct:<v>` ->
  `pct migrate <v> <x86-node>` -> `ha-manager add ct:<v>`.

No CTs hosted, by policy. The `renew-pve-tls.sh` cron still runs here like on
every node (its pveproxy :8006 serves an LE cert too).

## truenas (storage, not part of the PVE cluster)

TrueNAS 25.10.5, root FS read-only (-- writable: `/root`, `/var/tmp`,
`/mnt/volume1`, `/mnt/.ix-apps`). Hosts:

* NFS: `volume1/pve/shared` -> PVE `pve-shared` (live container disks);
  `volume1/pve/backups` -> PVE `pve-backups` (vzdump target).
* The 4 periodic snapshot tasks + the B2 cloud-sync task + the TLS renewal
  cron job id=1 (see [`backups.md`](./backups.md) and
  [`services/truenas-tls/`](../services/truenas-tls/)).
* Tailscale app container `ix-tailscale-tailscale-1` (the cert-issuance
  source for `renew-truenas-tls.py`).

The TrueNAS **host itself** is on the tailnet via `tailscale0`
(100.81.7.16) and reaches `https://ntfy.tail54538d.ts.net` directly -- that's
why the TrueNAS alertservice can POST to the ntfy bridge over the real
tailnet (see [`notifications.md`](./notifications.md)).

---

## Per-node admin commands

```sh
# from a tailnet box (e.g. debbie) via the Pi:
ssh nate@raspberrypi "sudo ssh root@<node> '<cmd>'"

# rotate / inspect the node's pveproxy cert:
sudo ssh root@<node> '/usr/local/sbin/renew-pve-tls.sh'        # idempotent no-op if fresh
sudo ssh root@<node> 'openssl x509 -in /etc/pve/local/pveproxy-ssl.pem -noout -dates'

# list this node's running CTs:
sudo ssh root@<node> 'pct list'

# exec into a CT (only works from the CT's owning node):
sudo ssh root@<owning-node> 'pct exec <vmid> -- bash'
```

## Persistence gap (all 5 nodes)

None of the 5 PVE nodes are managed by `~/dotfiles/migrate.sh` (no PVE-node
deploy mechanism). The per-node files (`renew-pve-tls.sh`, its cron, the
laptop drop-ins, `start-jellyfin.service`, the `/etc/fstab` NFS media mounts)
live only on the node they're on. Reproduce from the per-service READMEs in
this repo if a node is rebuilt.