# Homelab

The declaratively managed self-hosted service fleet: Proxmox nodes +
a TrueNAS storage box on a flat 192.168.1.0/24 LAN behind OPNsense,
every service tailnet-only, and this repo as the source of truth --
`git push` + `make converge` is the deploy.

> Current state: see [`plans/roadmap.md`](plans/roadmap.md) (the
> queue) and [`plans/history.md`](plans/history.md) (the shipped
> record).

## Repo layout

| Path | What it is |
|------|------------|
| [`plans/`](plans/) | The erledigen-style planning system: identity (constitution), roadmap (arcs v0-v5 + Backlog), stories (one file per work item), design records, history, issues. Start at [`plans/roadmap.md`](plans/roadmap.md). |
| [`ansible/`](ansible/) | The IaC home: inventory + facts (`inventory/host_vars/*.yml` is THE per-machine registry, `group_vars/all.yml` the LAN plan), pinned collections in `requirements.yml`, playbooks + roles (`playbooks/roles/<name>/` -- one role per service guest), playbook static files (`playbooks/files/keys/` = the admin pubkey the bootstrap flow installs). |
| [`guests/`](guests/) | The fleet declaration: one YAML per guest, read by the converge/update/verify loop. This, not the PVE UI, is the list of what should exist. |
| [`scripts/`](scripts/) | The operator's toolbelt -- bring-up + fleet tools, run from debbie over ssh (by you, or by a directed assistant acting as you). See each header for usage. |
| [`docs/`](docs/) | All documentation, indexed in [`docs/README.md`](docs/README.md). |
| [`local/`](local/) | Gitignored credentials + audit evidence; every env file documented by an `.example` sibling (see [`local/README.md`](local/README.md)). |
| `Makefile` | `make help` / `converge` / `update` / `verify` -- the fleet loop (idempotent converge, tier-gated patch pass, read-only drift check). |

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
* **The repo is the source of truth for live state**: `make converge`
  applies `guests/*.yaml` + the roles idempotently; `make verify`
  checks drift read-only. Hand-edits on boxes are expected to be
  overwritten (or flagged, if a manifest has not caught up).
* Every commit references the story it serves; decisions live in
  `plans/issues.md` (answered questions + reasoning), demand lives in
  `plans/stories/`, design rationale lives in `plans/design/`.
