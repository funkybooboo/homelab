# Ecosystem survey: homelab-as-code best practices (2026-11-22)

**Status**: current (research snapshot; supersedes nothing)
**Why**: operator asked for a survey of comparable projects + best
practices to refine the plan, repo structure, and docs before v2
builds on them. Gathered via curl against GitHub's API + raw docs
(no web-browsing tool; sources below are verifiable).

## Sources

- `Minh141120/awesome-homelab` -- "Your homelab, as a Git
  repository": the 11-layer map (00 hardware, 01 infrastructure,
  02 bootstrap, 03 gitops, 04 secrets, 05 network, 06 storage,
  07 observability, 08 identity, 09 automation, 10 apps). The
  canonical layer model home-ops repos organize around.
- `khuedoan/homelab` (9.7k stars) -- the flagship "empty disks to
  running services" repo; IaC + GitOps. Its own intro points at
  the community that renamed itself AWAY from k8s-at-home -- the
  ecosystem's biggest lesson is in its history.
- `davestephens/ansible-nas` (3.8k) -- ansible + docker on a
  single server; per-service roles; CI badges. The scale-twin
  pattern for a no-k8s homelab.
- `mother-of-all-self-hosting/mash-playbook` (1.2k) -- one
  ansible playbook, one vars entry per service, changelog +
  per-service docs.
- `lae/ansible-role-proxmox` (0.7k) -- the canonical PVE IaC
  role (RBAC as code, storage defs, HA groups; PVE 9.x + trixie).
- `bpg/terraform-provider-proxmox` (2.3k) + Telmate (3.0k,
  stale) -- the terraform alternative for guest lifecycle.
- `community-scripts/ProxmoxVE` (30k) -- the tteck lineage:
  helper scripts for LXC creation; a toolbox, not a pattern.
- Mozilla OpenSSH guidelines (infosec.mozilla.org/guidelines/openssh)
  -- the canonical sshd hardening reference.
- Tailscale docs: kb/1019 (subnet routers) + kb/1242 (tailscale
  serve) -- both current, documented patterns; our OPS-21 model
  matches them exactly.

## What the survey CONFIRMS about our design

1. **LXC + ansible, not k8s + gitops.** The k8s-at-home community
   renamed itself away from k8s; the durable non-k8s pattern
   (ansible-nas, MASH, lae role) is exactly our shape: one
   ansible playbook, per-service roles, a plain Makefile. At a
   12-15 service scale, k8s/flux/renovate is the ecosystem's own
   documented overkill trap.
2. **Repo layout.** Our plans/ + ansible/ + scripts/ + docs/ +
   services/ + local/ maps cleanly onto the awesome-homelab
   layer map; the 2026-11-22 cleanup (d17a0f5) already fixed the
   one non-idiomatic piece (top-level files/). Nothing further
   to change.
3. **Tailscale model.** One subnet router + serve fronts with LE
   certs (OPS-21) is Tailscale's documented idiom; no public
   exposure, no inbound ports, HTTPS via serve's own cert
   provisioning.
4. **Identity/RBAC.** lae.proxmox manages PVE RBAC as code --
   validating our nate@pam + scoped-token model as the
   idiomatic target state for v2's converge loop.
5. **SSH.** Our harden-ssh.sh covers Mozilla's headline items
   (password auth off, root key-only for PVE inter-node ops).
   One gap taken (below).

## Refinements applied

- `harden-ssh.sh`: added `LogLevel VERBOSE` (Mozilla: logs key
  fingerprints on login -- the audit trail for our one-identity
  model). Modern Debian trixie OpenSSH defaults already pin
  ed25519/curve25519/chacha20/aes-gcm, so their KEX/cipher lists
  are unnecessary at our version.

## Decision items raised (recorded as issues 11-14)

- **11 -- Secrets in git (SOPS/age) vs gitignored local/.** The
  ecosystem standard encrypts secrets INTO the repo; our
  local/ keeps them out entirely (identity rule: repo = the
  reproducible backup of state -- secrets being outside means
  bare-metal rebuilds need manual secret re-entry).
- **12 -- Guest lifecycle: ansible-only vs terraform.** bpg
  provider is the active ecosystem favorite; community.proxmox
  ansible modules do the same job without a second toolchain.
- **13 -- PVE web-UI 2FA (TOTP).** PVE supports it natively;
  LAN+tailnet-only access lowers the urgency but not the value.
- **14 -- SSO/identity layer (authelia/authentik).** The map's
  layer 08; real value starts with household multi-user +
  many web UIs.

## Deliberate non-adoptions

Kubernetes, flux/renovate-style gitops, and per-CT tailscale
nodes: each is documented in the ecosystem for problems we do
not have at this scale; our equivalents (ansible converge,
OPS-13 auto-update, one subnet router) are the same layers with
simpler tools. Revisit triggers are recorded with each issue.
