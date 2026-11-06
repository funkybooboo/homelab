# Greenfield homelab rebuild: infrastructure as code from scratch

> **STATUS: PROPOSAL** -- research complete 2026-11-05, nothing built yet.
> Reorganized 2026-11-06: the demand + queue now live in
> [`../roadmap.md`](../roadmap.md) and [`../stories/`](../stories/); the open
> questions live in [`../issues.md`](../issues.md). This document stays as the
> arc-level DESIGN RECORD (keep-vs-rebuild, architecture, IP plan, tooling
> decisions, traps, research sources).
> Supersedes [`proxmox-iac.md`](./proxmox-iac.md) (the in-place adoption plan for
> the old 192.168.8.x cluster -- dead: that cluster is powered down and its
> subnet no longer exists). Research sources are listed at the bottom; the raw
> pages are cached in `/tmp/research/` on debbie.

## Honest TL;DR

Every homelab machine is already powered down (staged shutdown 2026-09-27 through
2026-10-28), the new OPNsense router moved the LAN from 192.168.8.0/24 to
192.168.1.0/24, and the old cluster hardcoded the dead subnet everywhere
(corosync, truenas static IP, every CT). Revive-as-was is therefore not cheaper
than rebuild-as-code. The plan:

1. **Document the old homelab** (legacy archive) before anything is wiped.
2. **Keep** truenas (data + NFS + B2 backups; one scripted network move),
   the OPNsense config (LAN stays 192.168.1.1), the tailnet, and the
   `services/<name>/` notes.
3. **Rebuild** all Proxmox systems greenfield on PVE 9.2: fresh installs, fresh
   cluster on 192.168.1.x, OPNsense re-platformed as a VM on its own new PVE node.
4. **Everything declarative from this repo**: Ansible via the
   `community.proxmox` collection, one YAML manifest per guest, router config
   via `oxlorg.opnsense`, `make converge` from the workstation, git push as the
   deployment path -- with cluster-level ops human-gated forever.

## Keep vs rebuild

| Thing | Verdict | Why |
| --- | --- | --- |
| truenas box, datasets, B2 sync | KEEP | Data intact, backups proven. Only its IP/gw moves to 192.168.1.x (2 midclt calls, see `services/network/README.md`) |
| OPNsense config (LAN 192.168.1.1) | KEEP, re-platform | Bare metal -> VM on the new `pve-router` node; config.xml export/import |
| Old CT rootfs on `pve-shared` NFS | KEEP READ-ONLY (temp) | Data-extraction source: vaultwarden db, postgres, n8n workflows, service configs. Wipe last |
| 5 PVE nodes | REBUILD (PVE 9.2) | Fresh installs; cluster re-formed natively on 192.168.1.x -- no renumbering debt |
| `raspberrypi` | RE-ROLE | Full PVE node -> **QDevice** (idiomatic: votes, never hosts guests; fixes the stale-pve-lrm problem class) |
| `pve-balance` service | DELETE | PVE 9.2 ships a native Dynamic Load Balancer |
| Per-CT tailscale + `tailscale serve` | REDESIGN | Subnet router + ACLs (open question 4) |
| vzdump-to-NFS backups | UPGRADE (lean: PBS) | Dedup + verify jobs at this scale (open question 5) |
| HA rules system (old style) | REBUILD SIMPLE | PVE 9.2 arm/disarm + HA rules; fleet-wide HA is open question 3 |
| `services/<name>/` notes | KEEP | They become the human contract each ansible role implements |

## Target architecture

### Network: 192.168.1.0/24 (proposal)

| Range | Use |
| --- | --- |
| `.1` | OPNsense VM (LAN) |
| `.2` - `.9` | PVE nodes (`pve-router` = `.2`, then the rebuilt old names) |
| `.10` | truenas |
| `.11` - `.19` | Infrastructure: QDevice (Pi), PBS VM, subnet-router if a dedicated CT |
| `.50` - `.99` | Guest CTs/VMs: static, declared per-guest in the manifest |
| `.100` - `.249` | DHCP pool (clients; matches the current router behavior) |

- Flat single LAN, no VLANs in v1. The VLAN-aware-bridge upgrade path is
  documented and deferrable.
- The IP plan lives in ONE file (`infra/network/ips.yaml`), consumed by guest
  manifests, node bootstrap, and the oxlorg router playbooks.
- Guests get static IPs at pct level (the old static-at-OS lesson,
  `services/network/README.md`), not DHCP-lease pinning.

### Router on Proxmox: `pve-router`

- PVE 9.2 on the OPNsense box; OPNsense as a VM. Requires 2+ NICs on that box
  (open question 1): WAN bridge (or VLAN on the trunk) + LAN bridge shared with
  any co-located guests.
- virtio NICs; disable CRC/TSO/LRO hardware offload inside OPNsense; start
  order 1 with a generous stop timeout; qemu guest agent enabled.
- OPNsense VM disk on LOCAL storage (never NFS).
- **That node never auto-reboots** (auto-update tier: notify-only) -- an
  OPNsense VM hang on host reboot is a known failure mode.
- Accepted SPOF, stated plainly: while the OPNsense VM is down, the LAN loses
  internet/DNS but corosync + NFS keep working (they are L2). Mitigations
  reduce frequency, not the risk itself.

### Cluster

- x86 nodes run PVE 9.2 fresh installs; the Pi is a QDevice, not a PVE node.
- Storage: truenas NFS for CT rootfs (instant migration, the proven design;
  truenas is an acknowledged SPOF and boots first, on a UPS) + local storage
  for VM disks (router VM, PBS).
- Boot order dependency: truenas -> PVE nodes -> guests.

### Tooling (decided by research, 2026-11-05)

| Layer | Choice | Notes |
| --- | --- | --- |
| Engine | **Ansible only** | `community.proxmox` (~45 modules: cluster create/join, node network, storage, VM/CT lifecycle, disks, pools, HA rules, SDN, IPAM; inventory plugin; `pct`/guest-agent connection plugins run roles inside guests). No state files to corrupt |
| Router | **oxlorg.opnsense** | aliases, firewall rules, routes, gateways, Unbound DNS, WireGuard, cron, `dhcp_reservation`. The "no router provisioner" gap in `services/network/README.md` is closed |
| Secrets | SOPS + age | carried over from `proxmox-iac.md`; no secrets in state, least-privilege PVE API token |
| Terraform | **Not in v1** | If ever wanted: `bpg/proxmox` (PVE 9.x-tested) only; Telmate is dead on PVE 9 |
| Git flow | GitHub canonical (`funkybooboo/homelab`) + optional on-cluster forgejo mirror | Never self-hosted-only: the repo must survive the cluster it controls |
| Apply | `make converge` from the workstation; optional self-hosted runner later, guest config only | Cluster/storage/destructive ops are human-gated forever |

### Repo layout (proposal)

```text
homelab/
  docs/            existing docs + docs/legacy/ (phase 0 archive)
  services/        existing per-service notes (the contract for each role)
  ideas/           design records (this file)
  infra/
    network/       ips.yaml + opnsense playbooks (oxlorg)
    nodes/         per-node facts + bootstrap scripts
  guests/          one YAML per CT/VM: name, vmid, template, resources, IP, mounts
  ansible/         roles + playbooks (data-driven from guests/)
  scripts/         bootstrap, enroll, extract-legacy
  Makefile         bootstrap | converge | verify | extract-legacy
```

Adding a service = one YAML in `guests/` + (usually) one role in `ansible/roles/`.

## Phases (each ends with something running)

### Phase 0 -- Legacy archive (no hardware needed)

- [ ] `docs/legacy/`: full inventory of the old homelab -- CT catalog, IP
      scheme, shutdown timeline (2026-09-27 framework -> 10-01 thermaltake ->
      10-19 truenas + CTs -> 10-28 remaining nodes + old router), HA quirks and
      incidents, per-service state at shutdown. Sources: this repo,
      `ideas/proxmox-iac.md` section 1, network forensics 2026-11-04, truenas
      exports.
- [ ] `scripts/extract-legacy.sh`: mount old `pve-shared` CT rootfs read-only;
      inventory per-service data to extract (vaultwarden db, postgres dumps,
      n8n workflows, forgejo repos, jellyfin metadata, ntfy creds live on the
      phone + old CT only).
- **Done when**: the old homelab is fully described on paper and the old data
  is inventoried.

### Phase 1 -- Foundations

- [ ] IP plan (`infra/network/ips.yaml`); node facts.
- [ ] `pve-router` box: PVE 9.2 install + OPNsense VM (config.xml export from
      the current bare-metal install, import into the VM, LAN = `.1`).
- [ ] truenas network move (scripted midclt: static `.10`, gw `.1`; B2 sync
      continues; NFS exports re-exported on the new subnet).
- [ ] `scripts/bootstrap.sh`: one-command PVE node enrollment (hostname,
      static IP from the plan, ssh key, tailscale, no-subscription repo,
      join cluster via `proxmox_cluster`).
- [ ] Enroll the chosen nodes (open question 2); QDevice on the Pi.
- **Done when**: router, storage, and cluster are alive -- and every step that
  made them is a script or playbook in the repo.

### Phase 2 -- IaC skeleton

- [ ] Debian CT template role; guest manifest format; `make converge`.
- [ ] Core batch, dependency order: **vaultwarden (restore data from legacy
      FIRST -- it is the passwords)**, ntfy (alerting for everything after),
      forgejo (git mirror), postgresql, prometheus + grafana (watch the rebuild).
- **Done when**: a brand-new service is one YAML + one role, applied by make,
  and the critical five are live.

### Phase 3 -- Service migration batches

- [ ] Media batch on thermaltake (the only GPU): jellyfin, navidrome,
      audiobookshelf, syncstorage-rs.
- [ ] Tools batch from the curated list (open question 6): freshrss, searxng,
      linkwarden, n8n, speedtest, and whatever else survives curation.
- [ ] Per service: extract data from old rootfs -> deploy via manifest ->
      verify -> only then may the old rootfs be archived.
- **Done when**: the curated service list is live and `pve-shared` old rootfs
  is safe to archive.

### Phase 4 -- Automation polish

- [ ] Push-to-apply runner for guest config only (webhook -> converge).
- [ ] Auto-update tiers ported into ansible (Tier B hosts never self-reboot;
      `pve-router` is notify-only; HA disarm around host maintenance).
- [ ] PBS verify jobs + one restore drill.
- [ ] Drift detection -> ntfy.
- **Done when**: "rebuild a node" and "add a service" are runbook-only.

## Open questions (blocking, in order)

1. **Router box specs**: NIC count (2+ needed for clean WAN/LAN; 1 NIC blocks
   the re-platform until a NIC is added), CPU/RAM/disk. *Needs answer.*
2. **Node roster**: all 5 old machines back? pve-framework's flaky USB NIC --
   powered hub, PCIe NIC, or retire the box? *Needs answer.*
3. **HA**: (a) HA-manage the guest fleet + let the native PVE 9.2 Dynamic Load
   Balancer do placement -- my lean, because it deletes `pve-balance`, and
   9.2's arm/disarm + HA rules fix the old failure modes; note balancing only
   touches HA-managed guests -- or (b) no HA, ordered autostart only --
   defensible and simpler, at the cost of losing native balancing.
   *Needs decision.*
4. **Tailscale/TLS**: (a) subnet router + `tailscale serve` only on the few
   TLS-worthy hosts -- my lean; or (b) keep the old per-guest tailscale +
   serve-everywhere model (known-good per-service TLS, but research says the
   community moved away; admin-panel chaos, per-guest install effort).
   *Needs decision.*
5. **Backups**: PBS VM with datastore on truenas (my lean: dedup, verify,
   file-level restore; run verify jobs or don't bother) vs vzdump-to-NFS as
   before (simpler, honest for a small fleet). *Needs decision.*
6. **Service list**: full resurrection (~28) vs curated (~12-15) -- my lean is
   curated; the legacy archive makes lazy resurrection cheap later.
   *Needs answer.*
7. Minor, my defaults unless overridden: GitHub stays canonical remote with an
   on-cluster forgejo mirror; guest IPs static at pct level; no PDM, no
   VLANs, revisit later.

## Non-goals (explicit)

- No Kubernetes (wrong tool for a personal 5-box fleet; LXC + a few VMs is
  the idiom).
- No Ceph on this hardware ("gets complex fast" at 3 mixed nodes).
- No VLANs in v1; no multi-env split; no Vault/cost-tagging/blue-green theater.
- No closed-loop push apply of cluster-level ops.
- No gold-plating beyond what a re-run of `make converge` can prove.

## Traps the research surfaced (do not relearn these)

- **oxlorg.opnsense releases are pinned to OPNsense versions** (1-2 releases a
  year): never upgrade OPNsense ahead of the matching collection release.
- **OPNsense VMs hang on ACPI shutdown** (recurring forum reports): guest agent
  on, generous stop timeout, host never auto-reboots.
- **PVE 9.2's native balancer only manages HA-managed guests** -- if open
  question 3 lands on "no HA", there is no native balancing either.
- **Telmate Terraform provider is dead on PVE 9**; Terraform, if ever, = bpg.
- **NFS makes truenas a SPOF for every guest**: truenas boots first, on a UPS,
  every time.
- **The OPNsense VM is an internet/DNS SPOF while down**: corosync + NFS
  survive (L2), tailnet direct connections degrade to relay. Accepted, not
  eliminated.

## Research sources (2026-11-05)

- PVE 9.2 press release -- native Dynamic Load Balancer, HA arm/disarm,
  Debian 13.5 / QEMU 11 / LXC 7 / ZFS 2.4:
  https://www.proxmox.com/en/about/company-details/press-releases/proxmox-virtual-environment-9-2
- `community.proxmox` Ansible collection (docs current 2026-11-04; ~45
  modules incl. `proxmox_cluster`, node network, storage, VM/CT, disks, pools,
  HA rules, SDN, IPAM; inventory + connection plugins):
  https://docs.ansible.com/projects/ansible/latest/collections/community/proxmox/
- bpg Terraform provider (targets PVE 9.x, BPG Labs maintained):
  https://github.com/bpg/terraform-provider-proxmox
- oxlorg.opnsense collection (formerly ansibleguy; module table incl.
  `dhcp_reservation`): https://github.com/O-X-L/ansible-opnsense and
  https://ansible-opnsense.oxl.app
- OPNsense DHCP-API history (gap closed by MVC migration):
  https://forum.opnsense.org/index.php?topic=32558.0
- OPNsense-on-PVE walkthrough (bridges vs passthrough, virtio + offload
  settings, start order 1): https://homenetworkguy.com/how-to/virtualize-opnsense-on-proxmox-as-your-primary-router/
- OPNsense VM ACPI hang reports: https://forum.opnsense.org/index.php?topic=20715.0
- HA honest verdict + watchdog/fencing mechanics:
  https://budgethomelab.com/articles/proxmox-cluster-high-availability/
- NFS homelab patterns (unprivileged LXC bind mounts, tuning):
  https://blog.gntech.me/posts/2026-05-25-nfs-storage-homelab-proxmox-docker/
- Tailscale per-guest vs subnet router:
  https://www.xda-developers.com/i-stopped-running-tailscale-in-every-container/
- PBS vs vzdump: https://vormox.com/blog/vzdump-vs-proxmox-backup-server-which-backup-method-should-you-use-in-proxmox-ve
- GitOps pattern for non-k8s homelabs (cost: another moving part; git revert
  is the rollback): https://yourhomelabguide.com/advanced/gitops-for-homelab/
- QDevice-on-Pi idiom: various proxmox forum threads on 2-node + QDevice.

---

*Document version: 1.0. Written 2026-11-05 after the network-forensics state
report (2026-11-04) and the web research pass (2026-11-05). Predecessor:
[`proxmox-iac.md`](./proxmox-iac.md) (in-place adoption, superseded).*
