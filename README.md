# Homelab

The declaratively managed self-hosted service fleet: Proxmox nodes +
a TrueNAS storage box on a flat 192.168.1.0/24 LAN behind OPNsense,
every service tailnet-only, and this repo as the source of truth --
`git push` + (from v2) `make converge` *is* the deploy.

> State (2026-11-21): the old fleet is powered down (staged wind-down
> 2026-09 through 2026-10 after the router died and the LAN renumbered).
> The plan is REVIVAL, not rebuild: the 3 healthy nodes come back in
> place on the new LAN, everything scripted in `scripts/`, the router
> stays untouched for now. See [`plans/roadmap.md`](plans/roadmap.md).

## Repo layout

| Path | What it is |
|------|------------|
| [`plans/`](plans/) | The erledigen-style planning system: identity (constitution), roadmap (arcs v0-v5 + someday), stories (one file per work item), design records, history, issues. Start at [`plans/roadmap.md`](plans/roadmap.md). |
| [`ansible/`](ansible/) | The v2 IaC skeleton home: inventory + facts (`inventory/host_vars/*.yml` is THE per-machine registry, `group_vars/all.yml` the LAN plan), pinned collections in `requirements.yml`. Playbooks + roles land with OPS-7. |
| [`scripts/`](scripts/) | The operator/agent toolbelt -- bring-up + fleet tools, driven from debbie over ssh. See each header for usage. |
| [`docs/`](docs/) | All documentation, indexed by tier (current / old-fleet as-built) in [`docs/README.md`](docs/README.md). The wind-down-era archive lives in git history, not the tree. |
| [`services/`](services/) | Old-fleet shipped artifacts (TLS renewals, auto-update, observability configs + dashboards, ntfy bridge, remount helpers) -- revived with the fleet, then converged into ansible. |
| [`files/keys/`](files/keys/) | Public keys (the admin ssh key the bootstrap/revival flows install). |
| [`local/`](local/) | Gitignored credentials (e.g. the router API keypair). Only `*.example` templates are tracked. |
| `Makefile` | `make help` / `converge` / `verify` (converge + verify are honest stubs until the v2 skeleton lands). |

## Working mode

The operator does physical + console work (power, installers, dropping
the admin public key); the agent drives everything else over ssh from
debbie. Cluster-level, storage, and destructive operations stay
human-gated forever (the constitution, [`plans/identity.md`](plans/identity.md)).

## Conventions

* **No secrets in this repo.** Secrets live in gitignored files under
  `local/` or on the hosts; only `*.example` templates are tracked.
* **The repo is the reproducible backup of state**, not the source of
  truth for live systems until v2's converge loop lands: renewal
  scripts + configs here mirror what runs on the boxes (see each
  service dir README), and the direction flips with OPS-7.
* Every commit references the story it serves; decisions live in
  `plans/issues.md` (answered questions + reasoning), demand lives in
  `plans/stories/`, design rationale lives in `plans/design/`.
