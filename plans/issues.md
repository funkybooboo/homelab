# Issues

Open questions + self-audit notes. Story input; kept verbatim (moved
from design/greenfield-rebuild.md when `plans/` was created -- the
design record keeps the research + traps, this file keeps what is still
OPEN).

## Questions (answered 2026-11-06, except 8 + 16)

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
4. **Tailscale/TLS** -- ANSWERED 2026-11-06, REVISED 2026-11-22
   (operator): the model is **(B) per-service tailscale + serve
   fronts, as code** -- every service guest enrolls in the tailnet
   (MagicDNS name + tailnet IP) and UI-facing services get an https
   serve front (https://<name>.tail54538d.ts.net, automatic LE
   cert). The old fleet's graveyard failure mode is mitigated by:
   enrollment via a preauthorized reusable auth key minted through
   the tailscale API (local/tailscale-authkey.env, 90-day expiry
   re-checked by make update), stable manifest-driven CT names, and
   tailscaled in userspace-networking mode (no /dev/net/tun, no
   pmxcfs config surgery in unprivileged CTs). The subnet router on
   thermaltake STAYS for node UIs, appliances, tailscale-less boxes;
   LAN access unchanged (fronts only add). Accepted cost: device
   purges stay console-only on this tailnet (per-device API
   endpoints 404), so destroy/recreate cycles leave orphan entries
   until a periodic console purge.
   FOLLOW-UP 2026-11-22 (operator surfaced the docs): an os-tailscale
   community plugin exists since OPNsense v24.711 (GUI-installable,
   System > Firmware > Plugins > community) -- the old "no plugin,
   don't touch the gateway" fact is stale. Viable now: join the
   router to the tailnet for off-LAN gateway management, and
   optionally dual-advertise the 192.168.1.0/24 route (thermaltake
   today) for redundancy. Decision pending the operator.
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
   REVISED A THIRD TIME 2026-11-22 (the plan shift, final): the old
   CTs were cleaned out, NOT revived (OPS-20) -- v2 builds the fleet
   FRESH from manifests (OPS-7 skeleton shipped), data restores from
   the tier-0 extraction + dumps. The revive-in-place text above
   stays as history.

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

10. **Access layer + cloud model** -- ANSWERED 2026-11-21 by
   the operator (secure, idiomatic, HTTPS everywhere): (a) TAILSCALE =
   the recorded item-4 model: ONE subnet router
   (thermaltake already on the tailnet) advertises 192.168.1.0/24 so
   the whole LAN is reachable from outside; `tailscale serve` fronts
   host UIs with LE certs (HTTPS, no HTTP); a Tailscale API token
   (admin console Settings > Keys -> local/tailscale-api.env) comes
   with v2's automation (auth keys for new nodes, device/ACL
   management); the ~28 dead tailnet device entries get purged with
   the cluster clean-out. (b) BACKBLAZE: no repo key -- B2 is owned by
   the truenas middleware (the 5 verified snapshot tasks); a repo key
   only appears if a restic/rclone layer is added at OPS-14. (c) CLOUD
   BURST (linode/digitalocean): DEFERRED until a concrete load exists
   -- no accounts/keys "just in case"; the inventory+bootstrap design
   makes adding a cloud node an hour's work when a real need appears.
   (d) NAS-on-Proxmox: someday story OPS-19. (e) GUEST MOBILITY: all
   shared NAS mounts declared once in group_vars and applied to EVERY
   node at the same path (any guest binds from any node = full
   migration freedom); jellyfin prefers thermaltake via HA affinity
   and falls back to CPU decode when /dev/nvidia* is absent.

11. **Secrets: encrypted-in-git (SOPS/age) vs gitignored `local/`** --
   ANSWERED 2026-11-22 by the operator (raised by the ecosystem
   survey: [design/ecosystem-survey-2026-11-22.md](./design/ecosystem-survey-2026-11-22.md)).
   The ecosystem standard puts secrets IN the repo, encrypted with
   SOPS+age; ours keeps them entirely out via `local/`. Trade-off:
   ours means a bare-metal rebuild re-enters secrets by hand (the
   repo alone never rebuilds the world unattended); SOPS makes the
   repo complete but adds key management + a new failure mode (age
   key loss = secrets loss). DECIDED: keep `local/` for v2 (few
   secrets, operator-owned; B2 offsite + vaultwarden already
   cover recovery); revisit when secret count grows past what the
   operator comfortably re-enters, or when unattended full rebuild
   becomes a real demand.
12. **Guest lifecycle: ansible-only vs +terraform** -- ANSWERED
   2026-11-22 by the operator (same source).
   bpg/terraform-provider-proxmox (2.3k stars, active) is
   the ecosystem favorite for provisioning guests; the alternative
   is ansible's community.proxmox modules doing the same job
   through the same API token. Terraform adds a second toolchain +
   a state file for a 12-15-service fleet. DECIDED: ansible-only
   (one toolchain; the converge loop is already the design);
   revisit if guest churn grows or cloud-burst nodes become real.
13. **PVE web-UI 2FA (TOTP)** -- ANSWERED 2026-11-22 by the
   operator. PVE supports TOTP natively; the UI is LAN + tailnet
   only, which lowers but does not eliminate the value (a stolen
   laptop on the tailnet = UI access). DECIDED: enable on nate@pam
   (QR into vaultwarden); criterion added to OPS-22 -- operator
   action in the UI, no new moving parts.
14. **SSO/identity layer (authelia/authentik)** -- ANSWERED
   2026-11-22 by the operator. The
   awesome-homelab layer-08 pattern for many household web UIs.
   Our fleet is one operator + household; per-service accounts +
   vaultwarden suffice. DECIDED: DEFER (someday) -- recorded as
   demand; revisit when household multi-user web access becomes
   real.

15. **Data architecture** -- ANSWERED 2026-11-22 (operator):
STRUCTURED APP DATA CENTRALIZES in the shared postgres (CT 101) --
one cluster, **database-per-service, role-per-service** (least
privilege, scram, no app superusers). Services with postgres support
land there as their stories run: n8n, freshrss, linkwarden, forgejo,
superset (when queued). DELIBERATE EXCEPTIONS: vaultwarden stays on
SQLite ON PURPOSE (tier-0: its availability must not depend on
shared infra; dumped + B2'd independently); ntfy's cache is transient;
media servers keep embedded DBs (metadata = derived state; the FILES
on NFS are the data); prometheus TSDB + loki have purpose-built
stores. Grafana config stays SQLite with dashboards as provisioning
files in git (the repo is the backup). Apache Superset is the
planned data-viewing layer (own pg metadata db + valkey cache when
queued); it reaches per-service databases as sources for
cross-service dashboards.

16. **Codeberg 100-repo cap** -- OPEN 2026-11-25 (operator:
   leave as-is for now). The push chain mirrors 96/108 repos to
   codeberg; the last 12 targets cannot be created because the
   account is at Codeberg's per-user limit of 100 repositories
   (94 old-fleet pushes + 6 created 2026-11-25 = 100; verified by
   two full API pages). Repo creation returns HTTP 500 with an
   EMPTY message -- which cost a day of "rate limit will reset"
   misdiagnosis before the count was checked. It is a hard cap,
   not a window.

   The 12 un-mirrored targets (push mirrors pre-wired on the hub,
   hub+github-only until slots exist): MCWorld, NLP-Command-Line,
   ChadMcintire-nsegcm, funkybooboo-powerplay, epeterson42-powerplay,
   program-analysis-6715, ryleeeeeeeeeeeee, SpotifyScraper,
   funkybooboo-Trabajador, ucollect,
   funkybooboo-vector-field-analysis,
   EthanDGee-vector-field-analysis. The chain map is
   `local/ops-9-audit/push-chain-built.json`.

   Options when revisited (any one closes this):
   (a) overlap analysis -> drop-list of old codeberg repos verified
   present elsewhere (the no-data-loss directive applies; nothing
   unverifiable gets deleted), then create the 12;
   (b) a support ask to codeberg for a cap raise (mundane next to
   the mirror request they already declined, Community#3313);
   (c) accept 96/108 permanently -- nothing breaks; the 12 stay
   two-legged (hub + github) instead of three-legged.

## Self-audit notes

17. **Blanket Proton over the policy-split** -- DECIDED
   2026-11-28 (operator directive, supersedes the split design):
   "all traffic through this VPN, in the house or out of the
   house." The recommended design was a fail-closed policy-split
   (service-class IPs via Proton, gaming/streaming/tailnet/B2 raw
   WAN, kill-switch) -- the operator chose simplicity of posture
   over the split's blast-radius arguments. What shipped:
   Proton WG IS the default gateway with WAN auto-failover
   (gateway switching), whole-LAN SNAT to the tunnel. Accepted
   costs, on the record: a Proton flap is a household-wide event
   (mitigated by the WAN tier-2 failover + dpinger monitoring),
   and away-from-home exit traffic carries the household exit.
   The split design text survives inside OPS-28 as the
   recommended-not-chosen record; the built reality is in
   [../docs/network.md](../docs/network.md).

18. **Router owns the tailnet** -- DECIDED + SHIPPED 2026-11-28:
   the os-tailscale plugin runs on the router (exit node
   advertised; subnet route 192.168.1.0/24 approved + primary;
   tailscale serve relay); thermaltake's advertisement
   decommissioned. Answers item 4's 2026-11-22 follow-up ("plugin
   viable, decision pending") -- decided, built, verified.

19. **Homelab separated from household devices** -- DECIDED
   2026-11-28 (operator directive, on the VLAN discussion):
   the flat LAN mixes operator-managed infra with
   non-operator-controlled household devices (family computer,
   TV, others) that today reach every management interface
   (flat LAN = zero intra-LAN filtering). The split is additive:
   homelab stays on 192.168.1.0/24, household devices move to a
   new VLAN 20 behind a firewall allow-list. Gated on hardware:
   the current unmanaged switch cannot do VLANs; the trigger and
   full design live in the roadmap Backlog entry (not queued,
   fires when a managed switch arrives). Scope confirmed
   2026-11-28: level 2 first (trusted vs. household), level 3
   eventually (IoT / cameras / guest / infra-mgmt rungs, each
   firing on its own device trigger; ladder + per-rung
   triggers reserved in the Backlog entry so nothing ever
   re-addresses).

- Research traps (oxlorg version pinning, OPNsense ACPI hang, HA-only
  balancing, Telmate dead) live in
  [design/greenfield-rebuild.md](./design/greenfield-rebuild.md) -- they
  are design constraints now, not open issues.
- The 2026-11-04 network-forensics state report is summarized in
  [history.md](./history.md); the raw probe data was ephemeral on
  debbie.
