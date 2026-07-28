# Proxmox Infrastructure as Code (IaC) for the homelab cluster

## Executive Summary

Today the homelab is managed ClickOps-first: containers are created through the
Proxmox web UI, configs hand-edited on each CT, and a lot of operational glue
(renewal crons, tailscale-serve commands, Slack-bridge units) lives only on the
box it was typed on. This document sketches what a real Infrastructure-as-Code
layer would look like for *this specific* cluster -- not a generic cloud
template -- so the next rebuild or the next machine converges from a repo
instead of from my memory log.

---

## 1. Current State

### What actually runs today

- **5 PVE nodes** in one cluster:
  - 4 x86_64: `pve-thermaltake` (desktop), `pve-framework` (desktop),
    `pve-aspiree15` + `pve-aspires` (laptops, lid-ignored + screen-off unit).
  - 1 arm64: `raspberrypi` -- a quorum witness only, no pve-lrm, must never
    host HA CTs.
- **1 storage box**: `truenas` (TrueNAS 25.10) at 192.168.8.100, NFS exports
  consumed by every node as `pve-shared` (live CT disks) and `pve-backups`
  (vzdump target).
- **~19 LXC CTs**, each its own tailscale node, each served over HTTPS via
  `tailscale serve --bg --https 443 --yes http://localhost:<port>`. Jellyfin,
  freshrss, forgejo, vaultwarden, linkwarden, searxng, n8n, grafana,
  prometheus, excalidraw, drawio, adminer, opengist, speedtest-tracker,
  jupyternotebook, cronmaster, bichon, protonmail-bridge, postgresql, ntfy.
- **Everything on a tailnet** (`tail54538d.ts.net`), 1GbE LAN `192.168.8.x`/24,
  nothing exposed to the public internet. All web surfaces already serve
  Let's Encrypt certs.

### Pain (why IaC)

- Each CT was built by hand; no record of what flags, env, or packages beyond
  what's in the per-service `services/<name>/` notes.
- Operational glue lives only on the box it was typed on: `renew-pve-tls.sh`
  + cron on each of the 5 nodes, the ntfy Slack-bridge unit on CT 128,
  `renew-truenas-tls.py` on truenas, DNS/`accept-dns=false` fixes applied live
  per-CT. If a node or CT is rebuilt, these have to be remembered and re-typed.
- Drift is real: CTs were created over time with slightly different templates
  and conventions; nothing enforces "a homelab CT looks like X".
- `~/dotfiles/migrate.sh` covers the Pi and the workstation but has no
  PVE-node or PVE-CT deploy path, so nothing in the cluster converges
  declaratively today.

### Target state

- New CT provisioning defined as code (template, cores/RAM/disk, network,
  tailscale serve, onboot).
- Existing ~19 CTs imported into state, not recreated.
- Per-node glue (renewal crons, lid/screen units) also versioned.
- A re-built node or CT converges from the repo `pi` can run it.

---

## 2. Recommended tool stack (right-sized, not cloud-scale)

### Core

| Tool | Purpose | Why this, for this cluster |
| --- | --- | --- |
| **OpenTofu** (or Terraform) | Proxmox resource provisioning | `bpg/proxmox` provider covers CT/VM/network/storage; Telmate provider is stale. |
| **Ansible** | Post-provision config inside CTs/nodes | Matches what the CTs already are (Debian + a couple of services); one playbook per service. |
| **age + SOPS** (or `git-crypt`) | Secrets in repo, encrypted at rest | Vault is overkill at this scale; one key per machine, files decryptable on the boxes that need them. |

### Dropped vs. the generic template

- **Packer / golden images**: not worth it. CTs here are stock Debian-13 LXC
  templates cloned via `pct`; Packer buys you nothing for LXC and the VM stock
  is one Pi. Skip until there's a real VM image-pipeline need.
- **S3/MinIO + DynamoDB state backend**: no AWS, no MinIO currently running.
  The honest fit is **local state in the repo** (private repo, tailnet-only) or
  a single state file on the TrueNAS NFS share. Locking matters less for a
  one-operator cluster; state encryption-at-rest comes from SOPS if the state
  ever carries secrets (it shouldn't -- keep secrets out of state).
- **Multi-env `production/staging/development`**: there is one cluster and one
  tailnet. Drop the env split; use a single `environments/homelab/` (or no env
  dir at all).
- **Vault, Checkov, cost-center tagging, blue/green**: theater at this size.

### Supporting tools worth keeping

| Tool | Purpose |
| --- | --- |
| `pre-commit` + `tflint`/`tofu fmt` | Code quality hooks |
| A minimal CI on the repo host (or just `pre-commit` + a `tofu plan` wrapper) | Catch regressions before push |

No GitHub Actions / external CI required -- the repo can live on the
tailnet-only forgejo CT.

---

## 3. High-Level architecture

```
┌───────────────────────────────────────────────────────────┐
│  this repo (forgejo CT, tailnet-only)                     │
│  ┌──────────────┐  ┌──────────────┐  ┌─────────────────┐  │
│  │ tofu modules │  │ ansible      │  │ per-service     │  │
│  │ (pct CT,     │  │ playbooks/   │  │ notes (already  │  │
│  │  network,    │  │ roles        │  │ in services/*)   │  │
│  │  storage)    │  │              │  │                 │  │
│  └──────────────┘  └──────────────┘  └─────────────────┘  │
└────────────────────────┬──────────────────────────────────┘
                         │ `tofu apply` / `ansible-playbook`
                         │ (run from Pi or workstation)
   ┌─────────────────────▼──────────────────────┐
   │  Proxmox cluster (192.168.8.x / tailnet)    │
   │  pve-thermaltake  pve-framework             │
   │  pve-aspiree15   pve-aspires   raspberrypi  │
   │                       │                      │
   │                       ▼                      │
   │  truenas NFS: pve-shared + pve-backups       │
   └─────────────────────────────────────────────┘
```

---

## 4. Directory structure (proposed)

```text
homelab/
├── docs/                      # already exists
├── services/                  # already exists (per-service notes/scripts)
├── ideas/                     # this file, idea2.md
├── iac/
│   ├── tofu/
│   │   ├── providers.tf       # bpg/proxmox
│   │   ├── versions.tf
│   │   ├── modules/
│   │   │   ├── ct-base/       # one LXC CT: cores/mem/disk/onboot/tailnet
│   │   │   ├── tailscale-serve/ # if not done in an ansible role
│   │   │   └── node-glue/     # per-PVE-node: renew-pve-tls.sh + cron, lid/screen units
│   │   └── projects/
│   │       └── homelab/       # the actual CTs: import existing 100-128, then add
│   ├── ansible/
│   │   ├── inventory.ini      # generated from tofu output or maintained by hand
│   │   ├── playbooks/
│   │   │   ├── ct-bootstrap.yml   # base Debian: pkg updates, tailscale, dns fix
│   │   │   ├── site.yml
│   │   │   └── renew-tls.yml      # pve + truenas renewal glue
│   │   └── roles/
│   │       ├── tailscale_serve/
│   │       ├── service_<name>/   # one per CT, mirrors services/<name>/
│   │       └── dns_fixed/         # nameserver 192.168.8.1, accept-dns=false
│   └── secrets/
│       └── *.sops.yaml          # encrypted; never plaintext, never the ntfy creds
└── README.md
```

Note: deliberately **not** a parallel `proxmox-iac/` repo. Keep it in this repo;
the per-service `services/<name>/` notes are already here and are the source of
truth for what each CT should become.

---

## 5. Implementation phases

### Phase 0: Decide & scaffold (days, not weeks)
- [ ] Pick OpenTofu vs Terraform and a state location (lean: local in repo).
- [ ] Add `bpg/proxmox` provider skeleton, point at one node's API over the
      tailnet (https://pve-framework.tail54538d.ts.net, token auth).
- [ ] `pre-commit` with `tofu fmt` + `tflint`.

### Phase 1: Per-node glue first (low blast radius, high value)
- [ ] Codify `renew-pve-tls.sh` + `/etc/cron.d/renew-pve-tls` for all 5 nodes.
- [ ] Codify the laptop lid-ignored + `screen-off.service` for aspiree15/aspires.
- [ ] Codify `truenas` `renew-truenas-tls.py` + cron.
**Deliverable:** rebooting or rebuilding any node no longer loses the renewal
glue. This is the most fragile stuff today, so do it first.

### Phase 2: CT module + import
- [ ] `ct-base` module: clone debian-13 template, cores/mem/disk, `onboot`,
      `--nameserver 192.168.8.1 --searchdomain tail54538d.ts.net` (the DNS fix
      already applied per-CT by hand).
- [ ] `tofu import` each existing CT (100..128) into state -- do **not**
      recreate. State now reflects reality.
- [ ] Add `tailscale_serve` role (the `--bg --https 443 --yes ...` pattern).
**Deliverable:** existing cluster described as code, no behavior change.

### Phase 3: Provision a new CT end-to-end
- [ ] Add one brand-new service CT fully via tofu + ansible.
- [ ] Verify it matches what a hand-built one looks like (onboot, dns fixed,
      tailscale serve, HTTPS cert issued).
**Deliverable:** a repeatable "new service" path. From here, migrate the other
services lazily.

### Phase 4: Migrate the per-service config (ongoing)
- [ ] One ansible role per `services/<name>/` that already has notes.
- [ ] As each is codified, delete the equivalent manual glue from the box.
**Deliverable:** configs converge from repo on every run.

### Phase 5: Operations (ongoing)
- [ ] A `tofu plan` wrapper run weekly (cron on the Pi) that diffs live vs
      code and ntfy-publishes drift (reuse the existing ntfy topic).
- [ ] Runbook for rebuild-a-node and rebuild-a-CT from repo only.

---

## 6. Best practices that actually matter here

### Security
1. **No secrets in state.** Proxmox token, SOPS age key, ntfy creds -- all stay
   out of tofu state (read from env / SOPS at apply time). The ntfy creds stay
   on CT 128 + the phone, per the existing rule; do not move them into the repo.
2. **Least-privilege Proxmox API token** scoped to the pool/CTs, not cluster
   admin.
3. **Tailnet-only infra access.** tofu/ansible run from the Pi or workstation
   over the tailnet; the Proxmox API is never exposed publicly.

### Operations
1. **Idempotent** -- re-running apply must be a no-op. This is the whole point
   for the renewal crons and the dns fix.
2. **Import, don't recreate** the existing 19 CTs. Recreation risks data loss
   and downtime for nothing.
3. **One source of truth per service.** `services/<name>/README.md` (human
   notes) + `iac/ansible/roles/service_<name>/` (machine) should agree; the
   notes drive the role.
4. **Drift ntfy-published**, not silently ignored -- the ntfy topic already
   exists for this.

### Development
1. Modular, but not over-abstracted -- this is ~20 CTs, not 200.
2. Keep `services/<name>/` as the human-readable contract; the IaC is the
   executable form of it.

---

## 7. Key configuration patterns (cluster-specific)

### Provider (bpg/proxmox, tailnet-only)

```hcl
terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.60"
    }
  }
}

provider "proxmox" {
  endpoint = "https://pve-framework.tail54538d.ts.net:8006"  # or :443 via tailscale serve
  api_token = var.proxmox_api_token     # from SOPS / env, never in state
  insecure = false
  ssh {
    agent = true
  }
}
```

### State backend (honest pick: local in the private repo)

```hcl
terraform {
  backend "local" {
    path = "state/homelab.tfstate"
  }
}
```

Rationale: one operator, private tailnet-only repo, no S3 to stand up. If a
second operator appears or state grows, move to an encrypted file on the
True NFS share; do not bother with S3+locking at this scale.

### A homelab CT (the ct-base module essence)

```hcl
module "ntfy" {
  source       = "../../modules/ct-base"
  vmid         = 128
  hostname     = "ntfy"
  target_node  = "pve-framework"      # x86 node (never the Pi)
  template     = "debian-13-r1"       # the template already in use
  cores        = 1
  memory       = 512
  disk_gb      = 4
  storage      = "local-lvm"
  onboot       = true
  nameserver   = "192.168.8.1"        # the DNS fix, not MagicDNS
  searchdomain = "tail54538d.ts.net"
  tun_passthrough = true              # ntfy CT needs /dev/net/tun
}
```

---

## 8. Risk mitigation

| Risk | Mitigation |
| --- | --- |
| Drift introduced by my own manual fixes | Weekly plan-diff ntfy-published; codify fixes instead of live-typing |
| State loss | State committed to the private repo (or backed NFS); SOPS for secrets |
| Recreating a live CT by accident | `import` existing CTs first; `prevent_destroy` lifecycle on critical ones |
| Proxmox API token leak | SOPS-encrypted, tailnet-only, least-privilege scope |
| Breaking an existing service during migration | Phase 4 is one CT at a time, lazily; nothing forces a big-bang |

---

## 9. Success metrics (honest for one operator)

- **Rebuild-time to back-in-service**: from "re-type everything from memory" to
  "tofu apply + ansible-playbook".
- **Drift notifications/week**: should trend to 0.
- **Number of CTs whose config lives only on the box**: should trend to 0.

No fake SLO numbers; the goal is "the next machine converges, and the existing
ones stop silently diverging."

---

## 10. Next steps

1. Phase 0 decisions: OpenTofu, local state, `bpg/proxmox`.
2. Phase 1: codify `renew-pve-tls.sh` + crons and the laptop lid/screen units
   first -- they're the most fragile and least captured today.
3. Phase 2: write `ct-base`, import the existing 19 CTs.
4. Phase 3: build one new CT fully from code to prove the loop.

---

## References

- [bpg/proxmox Terraform provider](https://registry.terraform.io/providers/bpg/proxmox)
- [Proxmox API tokens](https://pve.proxmox.com/wiki/User_Management#pveum_tokens)
- [Ansible Proxmox modules](https://docs.ansible.com/ansible/latest/collections/community/general/proxmox_module.html)
- Existing notes in this repo: `docs/overview.md`, `docs/notifications.md`,
  `services/ntfy/`

---

*Document Version: 2.0 -- rewritten for the actual cluster (4 x86 PVE nodes +
Pi arm64 quorum witness, TrueNAS NFS, tailnet-only, ~19 LXC CTs, no AWS, no
GPU). Replaces the generic cloud-template v1.0.*