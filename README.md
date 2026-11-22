# Homelab

The declaratively managed self-hosted service fleet: Proxmox nodes +
a TrueNAS storage box on a flat 192.168.1.0/24 LAN behind OPNsense,
every service tailnet-only, and this repo as the source of truth --
`git push` + (from v2) `make converge` *is* the deploy.

> State (2026-11-22): revival shipped -- all 5 nodes + truenas live
> on the new LAN, 5/5 quorate. The old CTs are cleaned out, not
> revived; the fleet is then rebuilt as code (v2) on the bare
> cluster. The router stays untouched for now. See
> [`plans/roadmap.md`](plans/roadmap.md).

## Repo layout

| Path | What it is |
|------|------------|
| [`plans/`](plans/) | The erledigen-style planning system: identity (constitution), roadmap (arcs v0-v5 + someday), stories (one file per work item), design records, history, issues. Start at [`plans/roadmap.md`](plans/roadmap.md). |
| [`ansible/`](ansible/) | The v2 IaC skeleton home: inventory + facts (`inventory/host_vars/*.yml` is THE per-machine registry, `group_vars/all.yml` the LAN plan), pinned collections in `requirements.yml`, playbook static files (`playbooks/files/keys/` = the admin pubkey the bootstrap flow installs). Playbooks + roles land with OPS-7. |
| [`scripts/`](scripts/) | The operator's toolbelt -- bring-up + fleet tools, run from debbie over ssh (by you, or by a directed assistant acting as you). See each header for usage. |
| [`docs/`](docs/) | All documentation, indexed by tier (current / old-fleet as-built) in [`docs/README.md`](docs/README.md). The wind-down-era archive lives in git history, not the tree. |
| [`services/`](services/) | Old-fleet shipped artifacts (TLS renewals, auto-update, observability configs + dashboards, ntfy bridge, remount helpers) -- the as-shipped reference for the v2 rebuild: each piece becomes an ansible role (e.g. OPS-13 auto-update) once the clean-out leaves the cluster bare. |
| [`local/`](local/) | Gitignored credentials (e.g. the router API keypair). Only `*.example` templates are tracked. |
| `Makefile` | `make help` / `converge` / `verify` (converge + verify are honest stubs until the v2 skeleton lands). |

## Working mode

Humans operate this homelab; AI assistants help. The operator (you)
does physical + console work (power, installers, running
`scripts/console-setup-operator.sh` at a node's console), then drives
fleet operations from debbie -- directly, or by directing an AI
assistant to run the same scripts under the same `nate` identity.
One identity, one audit trail, human-controlled. Cluster-level,
storage, and destructive operations stay human-gated forever (the
constitution, [`plans/identity.md`](plans/identity.md)).

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
