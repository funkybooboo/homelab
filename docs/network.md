# The network: LAN, tailnet, boot order

Addresses live in one place: `ansible/inventory/group_vars/all.yml`
(LAN plan) + `host_vars/*.yml` (per-machine registry). This page is
the picture, not the data.

## The LAN

```mermaid
flowchart TB
    ISP((Internet)) --> RT["OPNsense V1210<br/>192.168.1.1<br/>bare-metal router"]
    RT --- SW["unmanaged switch<br/>192.168.1.0/24 flat, no VLANs"]

    subgraph NODES["PVE cluster, 5/5 quorate"]
        TT["pve-thermaltake .3<br/>GTX 1060, tailnet subnet router"]
        FW["pve-framework .4"]
        A15["pve-aspiree15 .5"]
        ASP["pve-aspires .6"]
        RPI["raspberrypi .11<br/>quorum member, no guests by policy"]
    end

    GUESTS["12 guests: infra .14-.19 + .51-.53<br/>media .55-.57 (on thermaltake)"]
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
    PHONE["operator phone"] --> SR
    LAP["laptops"] --> SR
    subgraph TAILNET["tailnet tail54538d.ts.net"]
        SR["pve-thermaltake<br/>subnet router + serve"]
    end
    SR -- "tailscale serve<br/>HTTPS + LE cert" --> PVEUI["https fronts<br/>&lt;name&gt;.tail54538d.ts.net"]
    SR -- "approved route<br/>192.168.1.0/24" --> LAN["the whole LAN: UIs, ssh, services"]
```

One subnet router covers the whole LAN; WireGuard end to end, zero
inbound router ports. Every guest enrolls in the tailnet at
converge; UI-facing guests get an https serve front from their
manifest's `tailnet_serve` port. Guests talk to each other over LAN
IPs, not MagicDNS names (userspace tailscaled hooks neither the
guest resolver nor outbound routing).

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
  (v5).
- The tailnet exit node on the router (OPS-28, operator decision
  pending).
