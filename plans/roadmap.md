# Roadmap

The queue. Arcs are the milestones (each ends with something running);
stories are the work (one file each in [stories/](./stories/)); the
constitution is [identity.md](./identity.md); the shipped record is
[history.md](./history.md). Every change serves one of the three roles.

## Where we stand (2026-11-22)

- v1 SHIPPED: all 5 nodes + truenas live on the new LAN, 5/5
  quorate (thermaltake .3, framework .4, aspiree15 .5, aspires .6,
  Pi .11 witness-only). Nothing was reinstalled: nodes renumbered in
  place ([history.md](./history.md) v1), the cluster turned out to
  already run PVE 9.2 (OPS-17's upgrade evaporated), the GPU is live
  on thermaltake, and the access model is complete end-to-end:
  `nate@pam` + the homelab-ops API token, router + truenas APIs
  under the nate identity, B2 verified.
- The plan shifted ON the revival evening (operator directive,
  recorded as issues item 8's second revision): the old CTs are
  cleaned out, NOT revived -- curation happens at build time (v2/v3)
  on a bare cluster.
- v1.5 is queued NOW: clean-out + access layer + hardening
  (OPS-20/21/22 below), gated by the tier-0 extraction
  (`scripts/extract-legacy.sh --copy 1` on debbie). The router
  stays untouched (V1210 bare-metal) until v5.
- Standing tooling: `docs/` (the live data-to-extract inventory),
  `ansible/inventory/` (LAN plan, host facts),
  `scripts/revive-node.sh` + the parked future-node tooling
  (`bootstrap`, `deploy-node-glue`, `setup-qdevice`).

## v0: Legacy archive -- SHIPPED 2026-11-06

[OPS-1 the legacy archive](./stories/OPS-1-legacy-archive.md) --
done: the old-fleet archive (guest catalog, old LAN, quirks +
incidents, extraction inventory) + `scripts/extract-legacy.sh`.
2026-11-21: per the operator's git-is-the-archive call, the
pure-history archive files were retired to git history;
`docs/data-to-extract.md` survives as the live inventory. The script
RUNS at the first hardware touch, after the truenas move (OPS-4).

## v1: Revival -- SHIPPED 2026-11-21/22

[OPS-2 the network plan](./stories/OPS-2-network-plan.md) (done),
[OPS-4 the truenas network move](./stories/OPS-4-truenas-network-move.md)
(done), [OPS-18 node revival](./stories/OPS-18-node-revival.md)
(done; supersedes OPS-5). OPS-3 (router) + OPS-6 (QDevice) stay
deferred to v5.

Shipped as built: truenas moved to .10 (the interface fail-safe
trap documented in the script), all 5 nodes renumbered in place via
`revive-node.sh` (framework needed no hardware fix; the Pi rejoined
as a 5th member + witness per operator directive), storage + host
DNS fixed, the GPU live on thermaltake, and the access model
completed 2026-11-22 (nate@pam + the homelab-ops API token,
verified live). The as-built record is [history.md](./history.md).

Ends with: the platform alive on the new LAN, nothing reinstalled,
and every step that did it is a script in the repo. The old CTs do
NOT come back (the plan shift) -- their remains are v1.5's first
story.

## v1.5: Clean-out + access layer -- QUEUED (the current arc)

The plan shift made the close-out its own arc: the old fleet's
remains go, the access layer finishes, the hardening lands -- all
BEFORE anything is built, so v2 starts on a truthful platform.

[OPS-20 the cluster clean-out](./stories/OPS-20-cluster-clean-out.md)
(gated by the tier-0 extraction landing outside the truenas pool),
[OPS-21 the tailnet access layer](./stories/OPS-21-tailnet-access-layer.md)
(done -- subnet router + LE-cert serve fronts + API token),
[OPS-22 node hardening + LAN tails](./stories/OPS-22-node-hardening-lan-tails.md).

Ends with: a bare cluster (zero guests, zero orphans, zero stale
addresses), HTTPS-everywhere access from the tailnet, and the
good-ssh state on every node.

## v2: IaC skeleton -- BUILD FRESH on the bare cluster

REVISED 2026-11-22 (the plan shift's final form): the old CTs are
cleaned out (v1.5), not revived, so v2 BUILDS the critical five
fresh -- the skeleton (OPS-7) creates guests via the PVE API and
each service restores its data from the extraction tarballs + the
`services/` as-was references. Curated resurrection, one story per
service; `make converge`/`make verify` become real.

[OPS-7 the IaC skeleton](./stories/OPS-7-iac-skeleton.md),
[OPS-8 ntfy alerting](./stories/OPS-8-ntfy-alerting.md),
[OPS-9 the forgejo mirror](./stories/OPS-9-forgejo-mirror.md),
[OPS-10 postgresql](./stories/OPS-10-postgresql.md),
[OPS-11 the monitoring pair](./stories/OPS-11-monitoring-pair.md),
[USER-1 vaultwarden restore](./stories/USER-1-vaultwarden-restore.md).

Ends with: one service = one YAML + one role, the critical five
built fresh and verified live.

## v3: Curation + media fleet

REVISED 2026-11-22 (the plan shift's final form): nothing stale is
stopped because nothing stale is built -- the curated list
(~12-15, issues item 6) is enforced at BUILD TIME. v3 adds the rest
of the curated services (USER-3) and the media fleet (USER-2),
verified on its GPU node (thermaltake, CPU-decode fallback per the
guest-mobility design).

[USER-2 the media fleet](./stories/USER-2-media-fleet.md),
[USER-3 daily tools](./stories/USER-3-daily-tools.md).

Ends with: the curated list running and documented; the uncurated
stay as extraction tarballs + `services/` references, cheap to
resurrect when a real need appears.

## v4: Automation polish

[OPS-12 push-to-apply](./stories/OPS-12-push-to-apply.md),
[OPS-13 the auto-update port](./stories/OPS-13-auto-update-port.md),
[OPS-14 PBS backups](./stories/OPS-14-pbs-backups.md),
[OPS-15 drift detection](./stories/OPS-15-drift-detection.md).

Ends with: rebuild-a-node and add-a-service are runbook-only.

## v5: Platform refresh

The Pi's QDevice re-role, pve-balance's replacement by the native
Dynamic Load Balancer, and the deferred router re-platform (OPS-3,
OPS-6). OPS-17's rolling 8->9 upgrade EVAPORATED at the revival --
the cluster already ran PVE 9.2 (the story carries the supersede
note; its remaining criteria ARE the v5 work). Only after v2-v4
keep the running fleet boring.

## Someday (demand recorded, not queued)

- [OPS-19 NAS re-platform](./stories/OPS-19-nas-replatform.md) -- Proxmox on the NAS hardware, storage as a guest (raised during the revival evening; needs v2 proven first)

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
