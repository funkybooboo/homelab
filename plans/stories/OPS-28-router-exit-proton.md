# OPS-28: Router tailnet exit node + ProtonVPN egress

As the operator, I want the OPNsense router (.1) to be a tailnet
EXIT NODE, and its egress to ride ProtonVPN, so that away-from-home
devices can travel through the house AND everything leaves via
Proton rather than the ISP.

**Status**: planned
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

## The decision the operator must make: blanket vs split

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
