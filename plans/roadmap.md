# Roadmap

The queue. Arcs are the milestones (each ends with something running);
stories are the work (one file each in [stories/](./stories/)); the
constitution is [identity.md](./identity.md); the shipped record is
[history.md](./history.md). Every change serves one of the three roles.

## Where we stand (2026-11-06)

- Everything is powered down (staged 2026-09-27 through 2026-10-28; see
  [history.md](./history.md)). The old cluster and its 192.168.8.0/24
  subnet are dead; the LAN is now 192.168.1.0/24 behind OPNsense.
- The decision is greenfield: rebuild all Proxmox systems as code, keep
  truenas + its data + B2, re-platform OPNsense as a VM on Proxmox.
  Research done 2026-11-05; the arc-level design record is
  [design/greenfield-rebuild.md](./design/greenfield-rebuild.md).
- **Nothing is built yet. v1 is blocked ONLY on [issues.md](./issues.md)
  item 2** (node roster + framework NIC verdict) -- the router box is
  answered: Protectli V1210, 2x 2.5GbE, OPNsense 25.7 running at .1.
  v0 needs no hardware.

## v0: Legacy archive -- SHIPPED 2026-11-06

[OPS-1 the legacy archive](./stories/OPS-1-legacy-archive.md) --
done: `docs/legacy/` (guest catalog, old LAN, quirks + incidents,
data-to-extract inventory) + `scripts/extract-legacy.sh`. The script
RUNS at the first hardware touch, after the truenas move (OPS-4).

## v1: Foundations

[OPS-2 the network plan](./stories/OPS-2-network-plan.md),
[OPS-3 router on Proxmox](./stories/OPS-3-router-on-proxmox.md),
[OPS-4 the truenas network move](./stories/OPS-4-truenas-network-move.md),
[OPS-5 node bootstrap](./stories/OPS-5-node-bootstrap.md),
[OPS-6 the cluster + QDevice](./stories/OPS-6-cluster-and-qdevice.md).

Ends with: router, storage, and cluster alive -- and every step that
made them is a script or playbook in the repo.

## v2: IaC skeleton + core services

[OPS-7 the IaC skeleton](./stories/OPS-7-iac-skeleton.md),
[OPS-8 ntfy alerting](./stories/OPS-8-ntfy-alerting.md),
[OPS-9 the forgejo mirror](./stories/OPS-9-forgejo-mirror.md),
[OPS-10 postgresql](./stories/OPS-10-postgresql.md),
[OPS-11 the monitoring pair](./stories/OPS-11-monitoring-pair.md),
[USER-1 vaultwarden restore](./stories/USER-1-vaultwarden-restore.md).

Ends with: one new service = one YAML + one role, and the critical five
live (vaultwarden data restored first -- it is the passwords).

## v3: Service batches

[USER-2 the media fleet](./stories/USER-2-media-fleet.md),
[USER-3 daily tools](./stories/USER-3-daily-tools.md).

Ends with: the curated service list live and the old rootfs safe to
archive.

## v4: Automation polish

[OPS-12 push-to-apply](./stories/OPS-12-push-to-apply.md),
[OPS-13 the auto-update port](./stories/OPS-13-auto-update-port.md),
[OPS-14 PBS backups](./stories/OPS-14-pbs-backups.md),
[OPS-15 drift detection](./stories/OPS-15-drift-detection.md).

Ends with: rebuild-a-node and add-a-service are runbook-only.

## Someday (demand recorded, not queued)

- [USER-4 the Monero node](./stories/USER-4-monero-node.md)
  (design: [design/monero-node.md](./design/monero-node.md))
- [USER-5 Firefox sync](./stories/USER-5-firefox-sync.md)
  (design: [design/firefox-sync-server.md](./design/firefox-sync-server.md))
- [LEARN-1 distributed llama.cpp inference](./stories/LEARN-1-llama-rpc.md)
  (design: [design/llama-rpc-inference.md](./design/llama-rpc-inference.md))
- [OPS-16 homelab auto-repair](./stories/OPS-16-homelab-auto-repair.md)
  (design: [design/homelab-auto-repair.md](./design/homelab-auto-repair.md))

## Policy

Numeric order: always complete the lowest incomplete arc before
starting anything higher. An arc only starts when its blockers
([issues.md](./issues.md)) are answered. Deferrals are recorded here,
never silent.
