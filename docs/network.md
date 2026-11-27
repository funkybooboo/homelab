# The network: LAN, tailnet, Proton egress, boot order

Addresses live in one place: `ansible/inventory/group_vars/all.yml`
(LAN plan) + `host_vars/*.yml` (per-machine registry). This page is
the picture, not the data.

## The LAN

```mermaid
flowchart TB
    ISP((Internet)) --> RT["OPNsense V1210<br/>192.168.1.1<br/>bare-metal router, Proton WG default"]
    RT --- SW["unmanaged switch<br/>192.168.1.0/24 flat, no VLANs"]

    subgraph NODES["PVE cluster, 5/5 quorate"]
        TT["pve-thermaltake .3<br/>GTX 1060; media + infra hub"]
        FW["pve-framework .4<br/>daily-tools tier; USB-NIC self-heal (quirks.md)"]
        A15["pve-aspiree15 .5"]
        ASP["pve-aspires .6"]
        RPI["raspberrypi .11<br/>quorum member, no guests by policy"]
    end

    GUESTS["17 guests: infra .14-.19 + .51-.53<br/>media .55-.57 (thermaltake)<br/>daily tools .61-.65 (framework)"]
    TN["truenas .10 -- NFS to every node + B2"]
    DEB["debbie .120 -- ops workstation"]
    CLIENTS["client devices -- DHCP .100-.249"]

    SW --- TT & FW & A15 & ASP & RPI & TN & DEB & CLIENTS
    NODES --- GUESTS
    TN -. "NFS: rootfs, backups, media" .-> NODES
```

Reserved: `.12` (future PBS), `.13` (optional future subnet-router
guest). The DHCP pool `.100-.249` is for clients only; infra is
static everywhere.

## The tailnet overlay

```mermaid
flowchart LR
    PHONE["operator phone<br/>(away: exit node on)"] --> SR
    LAP["laptops"] --> SR
    subgraph TAILNET["tailnet tail54538d.ts.net"]
        SR["opnsense router<br/>exit node + subnet router<br/>+ serve relay"]
    end
    SR -- "tailscale serve<br/>HTTPS + LE cert" --> PVEUI["https fronts<br/>&lt;name&gt;.tail54538d.ts.net"]
    SR -- "approved route<br/>192.168.1.0/24" --> LAN["the whole LAN: UIs, ssh, services"]
```

The ROUTER owns the tailnet's LAN presence: exit node advertised
(away devices route ALL their traffic through the house, exiting
via the Proton blanket), subnet route 192.168.1.0/24 approved and
primary, and the tailscale serve relay. thermaltake's old subnet
advertisement is decommissioned -- one owner, the right one. Every
guest enrolls in the tailnet at converge; UI-facing guests get an
https serve front from their manifest's `tailnet_serve` port.
Guests talk to each other over LAN IPs, not MagicDNS names (the
tailnet-names-everywhere rework is the v4 opener).

## The Proton blanket (2026-11-28, operator directive)

Every packet in or out of the house rides Proton WireGuard: the
router's default gateway is the WG tunnel (NetShield
ads+trackers variant, US-UT#42), the whole LAN is SNAT'd to the
tunnel address, and the WAN stays armed as automatic failover
(System > Settings > General, "Gateway switching"; election
happens at startup/interface triggers, so flag changes want a
reboot to arm). House egress verified at 74.63.204.212. Local
traffic stays local; LAN-to-LAN never touches the tunnel. The
operator chose blanket over the recommended policy-split (the
split design + the reversal are on record in OPS-28 and
issues.md). Away devices that select the router's exit node
inherit the same Proton exit.

**DNS rides the same posture** (2026-11-28, operator
directive): the router's unbound forwards to Quad9 (9.9.9.9)
over DNS-over-TLS, cert-pinned to dns.quad9.net -- the whole
house resolves through one no-log, malware-filtering party;
the ISP sees only the WireGuard stream, and a WAN failover
keeps the DNS leg TLS-encrypted. Verified by resolver-identity
lookup (whoami.akamai.net returns Quad9 egress).

## Boot order (a law, identity rule 7)

1. **truenas first** -- NFS must exist before guests boot.
2. **then the PVE nodes** -- quorum before workloads.
3. **then the guests** (onboot / converge).

Power-down is the reverse. The router sits before all of this;
the reboot runbook is [scripts/reboot-node.sh](../scripts/reboot-node.sh),
one node at a time.

## Planned

- PBS VM at `.12` (OPS-14, v4).
- Router re-platform onto Proxmox and the Pi's QDevice re-role
  (v5). The router's OPNsense 26.1 upgrade closes v3 (deliberate
  window, config backup first, oxlorg release paired).
- Tailnet names as the fleet's universal addressing (v4 opener,
  operator directive 2026-11-28).
