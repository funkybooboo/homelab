# OPS-28: Router tailnet exit node + ProtonVPN egress

As the operator, I want the OPNsense router (.1) to be a tailnet
EXIT NODE, and its egress to ride ProtonVPN, so that away-from-home
devices can travel through the house AND everything leaves via
Proton rather than the ISP.

**Status**: shipped 2026-11-28 (blanket directive -- see below);
the phone away-from-home test is the operator's last click
**Arc**: v3 (network tier; router stays bare-metal until OPS-3)

## Design sketch (2026-11-26, pre-build)

Two layers, one router:

1. **Tailscale on OPNsense** via the community `os-tailscale`
   plugin (exit-node capable). The router enrolls with the existing
   reusable auth key (mint-tailscale-key.sh) and advertises
   `--advertise-exit-node`. Away devices select it per-client
   (the tailnet's model stays consent-based).
   - The subnet-router duty on thermaltake is UNCHANGED (inbound
     LAN access). The exit node is a second, additive role.
2. **ProtonVPN as a WireGuard gateway** on OPNsense: Proton
   generates a WG config (endpoint + keys); OPNsense gets a WG
   interface as a policy-routing gateway.

## Idiomatic refinement (2026-11-28; resolves the split question)

Policy-split by traffic class, fail-closed, one policy point:

- **Proton WG = a gateway object, never the default route.**
- **Policy routing by source alias** (`vpn_services` = the
  service-CT addresses, 192.168.1.51-.65): one rule routes that
  class's outbound via Proton. Anonymizes the WHOLE service class
  (searxng engines, freshrss feed pulls, gitea-mirror github
  fetches, future paperless/immich) -- no per-service proxies.
- **Deliberately raw-WAN**: gaming, streaming, the tailnet itself,
  B2 backups, forgejo mirrors -- latency paths and authenticated
  infrastructure; a Proton flap is never a household outage.
- **Kill switch = the same ruleset**: deny `vpn_services` to WAN
  after the policy route; tunnel down means the class loses
  internet (crons retry), never a silent home-IP leak.
- **Exit node rides the tunnel**: away devices get home LAN +
  Proton egress in one path. tailscaled's own coordination
  (UDP/DERP) is carved OUT of the policy route or a flap cuts
  the remote-access lifeline.
- **DNS fails closed**: the class's :53 redirects to Proton's
  tunnel DNS; the rest of the house keeps unbound.
- **One WG key per purpose** (router key revocable independent
  of phone/laptop Proton apps; Secure Core vs standard config
  for the service class is the one plan-tier decision).

## The blanket-vs-split decision (superseded 2026-11-28)

Resolved by the idiomatic refinement above: neither blanket nor
exit-node-only -- policy-split by source alias, with the service
CT class riding Proton and everything latency-sensitive or
authenticated staying raw-WAN. The original analysis that led
there:

- **Blanket** (their words: "all traffic"): every LAN egress rides
  Proton. Privacy-max; but: kill-switch complexity, streaming
  geolocation breaks, B2/mirror/update paths inherit Proton's
  latency + any WG flap becomes a fleet-wide internet outage, and
  the router must keep working for the tailnet regardless.
- **Split (recommended)**: the EXIT-NODE traffic rides Proton
  (that is the point -- away devices get home + privacy in one
  path), plus optionally chosen LAN hosts; infrastructure egress
  (B2, forgejo mirrors, unattended updates, DNS upstream) stays on
  the WAN direct. Blast radius of a Proton flap = the exit-node
  users only.
- Either way: tailscaled's own coordination/DERP and the tailnet
  interface are carved out of the policy route, or a Proton flap
  collapses the exit node + the LAN's remote access.

## Open facts (operator-held)

- Proton plan: WG configs are a paid-tier feature (Plus+). The
  WireGuard config (server, pubkey, client key) is operator-fetched
  from account.protonvpn.com; the client key becomes a pass-vault
  item (OPS-26 pattern) + local/opnsense env.
- os-tailscale plugin maturity on OPNsense 25.7 -- verified at
  build; fallback: exit node on a PVE node (thermaltake) with
  policy routing there, router untouched.
- ISP uplink speed vs Proton WG throughput through the N5105
  (AES-NI present; WG is cheap) -- measured at build.

## Acceptance criteria

- [ ] Router enrolled + advertising exit node; phone away-from-home
      selects it and reaches both internet and LAN
- [ ] Exit-node egress verified via Proton (exit IP checks)
- [ ] Proton WG flap drill: kill the WG tunnel, confirm what
      survives (the split model bounds the answer)
- [ ] Boot-order drill: router reboot with the UPS battery story in
      mind (router is tier-0 of the boot law; everything depends on
      it, it may never depend on Proton)
- [ ] Secrets in the pass vault; OPNsense changes recorded as
      API/CLI commands in the repo (the router is an appliance --
      its state is commands-of-record, not manifests)

## The blanket directive (2026-11-28, supersedes the split design)

Mid-build the operator chose BLANKET: "all my traffic through
this VPN, in the house or out of the house." The shipped
architecture, as built and verified:

- Proton WG (NetShield ads+trackers variant, US-UT#42) is the
  house DEFAULT gateway (defaultgw flag, priority 1, dpinger
  monitoring 10.2.0.1). Every device -- laptops, nodes, CTs --
  exits via 74.63.204.212 (verified from debbie + CTs).
- WAN auto-failover: "Gateway switching" enabled; the WAN stays
  tier-2 behind Proton. Election triggers on startup/interface
  events (the router reboot that armed this was also the
  boot-order drill: router booted with tunnel + failover + the
  whole house intact).
- Source NAT translates the LAN to the tunnel address.
- The os-tailscale plugin runs on the router: exit node
  ADVERTISED and offered; subnet route 192.168.1.0/24 approved
  and primary (thermaltake's old advertisement decommissioned);
  a tailnet-transit pass rule on the TAILSCALE interface lets
  away devices reach router + LAN + internet. Away traffic
  exits via the router's default = Proton.
- The vpn_services/kill-switch split-mode rules were built first,
  then REMOVED when the blanket directive landed -- the default
  route IS the blanket; the split design stays above as the
  record of what was recommended and superseded.
- The router's own DNS rides the tunnel via the default; the
  NetShield resolver upstream refinement is optional follow-up
  (the router's DNS settings are a UI-only surface).
