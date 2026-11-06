# Issues

Open questions + self-audit notes. Story input; kept verbatim (moved
from design/greenfield-rebuild.md when `plans/` was created -- the
design record keeps the research + traps, this file keeps what is still
OPEN).

## Open questions (blockers first)

1. **Router box specs** -- ANSWERED 2026-11-06 (order #10610317,
   ordered 2026-10-19, $563.04): **Protectli Vault V1210**, 2-port Intel
   N5105 (Jasper Lake quad-core; 2x Intel 2.5GbE per Protectli spec --
   `lspci` on install re-verifies), 4GB LPDDR4 (soldered: the node stays
   router-only), 500GB Kingston NV3 NVMe, coreboot BIOS, **OPNsense 25.7
   pre-installed** (= the box currently running at 192.168.1.1). Two
   NICs = clean WAN + LAN; blocker lifted. Follow-up: pin the
   oxlorg.opnsense release matching OPNsense 25.7 before any
   router-as-code playbook runs.
   *Unblocks OPS-3.*
2. **Node roster** -- all 5 old machines back? pve-framework's flaky
   USB NIC: powered hub, PCIe NIC, or retire? *Blocks v1 (OPS-5,
   OPS-6).*
3. **HA** -- (a) HA-manage the guest fleet + let the native PVE 9.2
   Dynamic Load Balancer do placement (lean: deletes pve-balance; 9.2's
   arm/disarm + HA rules fix the old failure modes; note balancing only
   touches HA-managed guests) or (b) no HA, ordered autostart only
   (simpler; loses native balancing). *Gates the cluster design (OPS-6)
   + every placement behavior after.*
4. **Tailscale/TLS** -- (a) one subnet router + `tailscale serve` on
   the few TLS-worthy hosts (lean) or (b) the old per-guest tailscale +
   serve-everywhere model (known-good per-service TLS, but heavy).
   *Gates OPS-7 + every USER story's access path.*
5. **Backups** -- PBS VM with its datastore on truenas (lean: dedup,
   scheduled verify, file-level restore) vs vzdump-to-NFS as before.
   *Gates OPS-14.*
6. **Service list** -- full resurrection (~28) vs curated (~12-15);
   lean is curated. *Gates USER-2/USER-3 scope.*
7. Minor defaults unless overridden: GitHub stays the canonical remote
   with an on-cluster forgejo mirror; guest IPs static at pct level; no
   PDM; no VLANs.

## Self-audit notes

- Research traps (oxlorg version pinning, OPNsense ACPI hang, HA-only
  balancing, Telmate dead) live in
  [design/greenfield-rebuild.md](./design/greenfield-rebuild.md) -- they
  are design constraints now, not open issues.
- The 2026-11-04 network-forensics state report is summarized in
  [history.md](./history.md); the raw probe data was ephemeral on
  debbie.
