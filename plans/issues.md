# Issues

Open questions + self-audit notes. Story input; kept verbatim (moved
from design/greenfield-rebuild.md when `plans/` was created -- the
design record keeps the research + traps, this file keeps what is still
OPEN).

## Questions (answered 2026-11-06, except 8)

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
2. **Node roster** -- ANSWERED 2026-11-06: all 5 old machines
   return (thermaltake, aspiree15, aspires, framework, Pi).
   framework's flaky USB-NIC gets FIXED, not retired: powered hub or
   PCIe NIC, chosen with the hardware on hand at enrollment, with a
   stability soak before it hosts HA-managed guests again. The Pi
   stays arm64-cautious: **QDevice only, never hosts guests** (fresh
   Raspberry Pi OS + corosync-qnetd, not the arm64 PVE port).
   *Unblocks OPS-5, OPS-6.*
3. **HA** -- ANSWERED 2026-11-06: **(a)** HA-manage the guest fleet +
   the native PVE 9.2 Dynamic Load Balancer. pve-balance is not
   rebuilt; the arm/disarm maintenance runbook + node-affinity rules
   are OPS-6 deliverables. *Unblocks OPS-6 + every placement behavior
   after.*
4. **Tailscale/TLS** -- ANSWERED 2026-11-06: **(a)** one subnet
   router + `tailscale serve` only on the TLS-worthy hosts. The old
   ~28-node per-guest-tailscale model is not rebuilt. *Unblocks OPS-7
   + every USER story's access path.*
5. **Backups** -- ANSWERED 2026-11-06: **PBS** VM, datastore on
   truenas (operator provisions the truenas access for it). vzdump
   remains the interim baseline until OPS-14's restore drill passes.
   *Unblocks OPS-14.*
6. **Service list** -- ANSWERED 2026-11-06: **curated** (~12-15).
   The per-CT "curate" verdicts in docs/legacy/guest-catalog.md are
   the working list; final yes/no per service happens in USER-3 with
   the extracted data in hand. *Unblocks USER-2/USER-3 scope.*
7. **Defaults** -- CONFIRMED 2026-11-06 as written: GitHub stays the
   canonical remote with an on-cluster forgejo mirror; guest IPs
   static at pct level; no PDM; no VLANs.
8. **Renumber the old PVE installs in place vs fresh reinstall** --
   OPEN (raised by the operator 2026-11-06). Recommendation: fresh
   install. In-place from a DARK cluster means: temporarily recreate
   the 192.168.8.x LAN (OPNsense alias) + boot the whole old cluster
   alive + a live 5-node corosync renumber + a bookworm->trixie
   PVE8->9 dist-upgrade per node -- and it carries the drift the
   greenfield verdict exists to delete, while saving only ~30 min of
   USB-stick time per node. Nothing irreplaceable lives on the nodes
   (rootfs on truenas, tier-0 extracted, ntfy/loki via vzdump).
   Awaiting the operator's call.

## Self-audit notes

- Research traps (oxlorg version pinning, OPNsense ACPI hang, HA-only
  balancing, Telmate dead) live in
  [design/greenfield-rebuild.md](./design/greenfield-rebuild.md) -- they
  are design constraints now, not open issues.
- The 2026-11-04 network-forensics state report is summarized in
  [history.md](./history.md); the raw probe data was ephemeral on
  debbie.
