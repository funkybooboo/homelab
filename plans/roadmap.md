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
- **All questions answered; the plan was REVISED 2026-11-21 to
  REVIVE-IN-PLACE** (issues.md item 8): the 3 healthy nodes are
  renumbered onto the new LAN without reinstalling (the router stays
  untouched; framework + Pi stay off), so the entire 28-CT service
  fleet comes back the same evening. The platform goals (PVE 9, the
  QDevice re-role, the router re-platform) move to v5; the IaC goals
  converge the RUNNING fleet in v2-v4. Shipped: `docs/legacy/` +
  `infra/` (ips.yaml, node facts, admin key) +
  `scripts/{truenas-network-move,extract-legacy,bootstrap,deploy-node-glue,setup-qdevice}.sh`
  (the last three parked as future-tooling) + `revive-node.sh`.

## v0: Legacy archive -- SHIPPED 2026-11-06

[OPS-1 the legacy archive](./stories/OPS-1-legacy-archive.md) --
done: `docs/legacy/` (guest catalog, old LAN, quirks + incidents,
data-to-extract inventory) + `scripts/extract-legacy.sh`. The script
RUNS at the first hardware touch, after the truenas move (OPS-4).

## v1: Revival -- SHIPPED-PREP as of 2026-11-21

[OPS-2 the network plan](./stories/OPS-2-network-plan.md) (done),
[OPS-4 the truenas network move](./stories/OPS-4-truenas-network-move.md),
[OPS-18 node revival](./stories/OPS-18-node-revival.md) (new;
supersedes OPS-5). OPS-3 (router) + OPS-6 (QDevice) deferred to v5
per operator -- the V1210 keeps routing bare-metal, the Pi stays off
(3 revived nodes = 3-of-5 quorum).

Evening order: truenas move (remote, no console) -> boot 3 nodes ->
operator drops the admin key at each console -> `revive-node.sh
--renumber` per node -> 3rd node = quorum -> `--post-quorum` fixes
(storage.cfg, fstab, CT nameservers) -> HA auto-start + the
documented error-state dance -> `extract-legacy.sh` as a tier-0
backup snapshot.

Ends with: the whole old fleet running on the new LAN, nothing
reinstalled, and every step that did it is a script in the repo.

## v2: IaC skeleton over the RUNNING fleet

REVISED 2026-11-21 (revival): the core services come back alive on
revival night, so these stories become *converge + verify* rather than
*restore*. The skeleton (OPS-7) builds the manifests + roles and
converges what is already running; drift disappears in the first
passes.

[OPS-7 the IaC skeleton](./stories/OPS-7-iac-skeleton.md),
[OPS-8 ntfy alerting](./stories/OPS-8-ntfy-alerting.md),
[OPS-9 the forgejo mirror](./stories/OPS-9-forgejo-mirror.md),
[OPS-10 postgresql](./stories/OPS-10-postgresql.md),
[OPS-11 the monitoring pair](./stories/OPS-11-monitoring-pair.md),
[USER-1 vaultwarden restore](./stories/USER-1-vaultwarden-restore.md).

Ends with: one service = one YAML + one role, the revived fleet
converged under it, and the critical five verified live.

## v3: Curation + media verification

REVISED 2026-11-21 (revival): everything revived, curation now happens
by STOPPING the non-curated CTs (stopping is easy; resurrecting was
the hard direction) and verifying the media fleet on its GPU node.

[USER-2 the media fleet](./stories/USER-2-media-fleet.md),
[USER-3 daily tools](./stories/USER-3-daily-tools.md).

Ends with: the curated list enforced (stopped + documented), the rest
still archived in `docs/legacy/`.

## v4: Automation polish

[OPS-12 push-to-apply](./stories/OPS-12-push-to-apply.md),
[OPS-13 the auto-update port](./stories/OPS-13-auto-update-port.md),
[OPS-14 PBS backups](./stories/OPS-14-pbs-backups.md),
[OPS-15 drift detection](./stories/OPS-15-drift-detection.md).

Ends with: rebuild-a-node and add-a-service are runbook-only.

## v5: Platform refresh

[OPS-17 PVE 9 rolling upgrade + platform refresh](./stories/OPS-17-pve9-rolling-upgrade.md)
-- the rolling 8->9 dist-upgrade, the Pi's QDevice re-role, native
balancer, and the deferred router re-platform (OPS-3, OPS-6 folded
in). Only after v2-v4 keep the running fleet boring.

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
