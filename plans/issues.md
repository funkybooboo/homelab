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
   The working list = the revived cluster's CT list itself; final
   yes/no per service happens in USER-3 with the running services in
   front of us. *Unblocks USER-2/USER-3 scope.*
7. **Defaults** -- CONFIRMED 2026-11-06 as written: GitHub stays the
   canonical remote with an on-cluster forgejo mirror; guest IPs
   static at pct level; no PDM; no VLANs.
8. **Renumber the old PVE installs in place vs fresh reinstall** --
   ANSWERED, twice, and the second answer stands. 2026-11-06: fresh
   install (the dark-cluster corosync dance looked expensive).
   REVISED 2026-11-21 per operator + the router deferral: **REVIVE IN
   PLACE.** The re-analysis: (a) the dark-cluster renumber needs no
   old-subnet recreation -- `pvecm expected 1` per node + a
   corosync.conf swap; the third node up forms real 3-of-5 quorum;
   (b) all 28 CTs revive intact on pve-shared the same night
   (vaultwarden, media, everything) -- the per-service v2/v3 restore
   work drops out entirely; (c) rule 1 does not need fresh installs --
   the v2 ansible skeleton CONVERGES a running fleet, drift included.
   Costs accepted: PVE 8 stays until the v5 rolling 8->9 upgrade
   (own story, OPS-17); framework + Pi stay OFF until their fixes
   (3 nodes = quorum); curation happens by STOPPING unwanted CTs
   after revival. Fresh-install tooling (bootstrap.sh,
   deploy-node-glue.sh, setup-qdevice.sh) stays in the repo for future
   new/rebuilt nodes and the Pi re-role. Router stays untouched
   (V1210 keeps routing bare-metal; re-platform = OPS-3 in v5).

9. **Operations identity (least privilege, no root ssh)** --
   ANSWERED 2026-11-21 by the operator, recorded as the standing
   rule. HUMANS OPERATE; assistants help (never a separate
   privileged "agent" caste): (a) PVE nodes = the (A) model as a
   GENERAL OPERATIONS account: the operator's own `nate` account, key-only ssh (the
   operator's key), `sudo NOPASSWD: ALL` -- created by pasting
   scripts/console-setup-operator.sh at each node's PHYSICAL console;
   the operator uses it directly AND an AI assistant runs the same
   commands under it when directed -- one identity, one audit
   trail; (b) TRUENAS = **no root ssh ever** -- the network move
   runs at its console (script fetched via one-shot HTTP from
   debbie's temp alias), then the SSH service gets the good-ssh
   pass (root login + password auth off); (c) nodes: after
   revival, scripts/harden-ssh.sh kills password ssh everywhere --
   root ssh stays KEY-ONLY because PVE itself uses root ssh
   between nodes for migration/cluster operations (the
   load-bearing nuance; the physical console is the break-glass
   path). v2 moves ongoing management to scoped PVE API tokens.
   (d) ROUTER: the already-created `agent` web-UI user gets the
   same treatment -- recreate as `nate` (new keypair,
   scripts/opnsense.sh --import, then delete the `agent` user);
   the API keypair is the credential either way, but the account
   carries the human's name per the convention.

## Self-audit notes

- Research traps (oxlorg version pinning, OPNsense ACPI hang, HA-only
  balancing, Telmate dead) live in
  [design/greenfield-rebuild.md](./design/greenfield-rebuild.md) -- they
  are design constraints now, not open issues.
- The 2026-11-04 network-forensics state report is summarized in
  [history.md](./history.md); the raw probe data was ephemeral on
  debbie.
