# Diagrams: the homelab at a glance

The network and the fleet as pictures, all current as of
2026-11-28: five diagrams plus the narrative they compress.
The data behind them lives in
[ansible/inventory/](../ansible/inventory/) and the guest
manifests; addresses live only there. When reality changes,
change this page the same commit.

## 1. The physical network

Five machines, one flat LAN, one router, one switch.

```mermaid
flowchart TB
    ISP((ISP))
    ISP --> RT
    subgraph ROUTER["OPNsense .1 (Protectli V1210)"]
        RT[router: firewall, DHCP, DNS, WireGuard]
    end
    RT --> SW["unmanaged switch 192.168.1.0/24"]
    SW --> TT["pve-thermaltake .3<br/>GTX 1060"]
    SW --> FW["pve-framework .4<br/>laptop board, self-heal NIC"]
    SW --> A15["pve-aspiree15 .5"]
    SW --> ASP["pve-aspires .6"]
    SW --> RPI["raspberrypi .11<br/>quorum only"]
    SW --> TN["truenas .10<br/>NFS + B2 backups"]
    SW --> DEB["debbie .120<br/>ops workstation"]
    SW --> CLIENTS["phones, laptops, etc<br/>DHCP .100-.249"]
```

## 2. Every packet's path (the privacy posture)

The operator directive made real: everything in or out of the
house rides Proton; the ISP sees one encrypted stream.

```mermaid
flowchart LR
    LAN["the house<br/>(5 nodes, 19 guests,<br/>every client)"]
    RT["OPNsense router .1"]
    WG["Proton WireGuard<br/>US-UT#42, NetShield"]
    WWW((the internet))
    QUAD["Quad9 9.9.9.9<br/>DNS over TLS"]

    LAN --> RT
    RT == "default route<br/>(whole house SNAT)" ==> WG
    WG --> WWW
    RT -. "DNS only:<br/>unbound forward, DoT" .-> QUAD
    QUAD -.-> WWW
    WAN["raw WAN<br/>failover only"]
    RT -. "auto, if tunnel dies" .-> WAN
    WAN --> WWW
```

- The ISP sees: one WireGuard stream to Proton. No sites, no
  DNS, no traffic patterns.
- Quad9 sees: the domain queries (no-log, malware-filtering;
  that is the trade on record).
- A tunnel flap slides the house to raw WAN automatically; the
  DNS leg stays TLS-encrypted even then.

## 3. Who runs what (service placement)

Framework is the tools tier; thermaltake is media + the data
hub; the Aspires carry the build/observability layer; the Pi
holds quorum.

```mermaid
flowchart TB
    subgraph TT["pve-thermaltake .3 -- media + data hub"]
        TT1["jellyfin .55"]
        TT2["navidrome .56"]
        TT3["audiobookshelf .57"]
        TT4["postgres .14<br/>(the shared database)"]
        TT45["mysql .20<br/>(the other shared database)"]
        TT5["vaultwarden .51"]
        TT6["loki .19"]
    end
    subgraph FW["pve-framework .4 -- the tools tier"]
        FW1["it-tools .61"]
        FW2["searxng .62"]
        FW3["excalidraw .63"]
        FW4["drawio .64"]
        FW5["freshrss .65"]
        FW6["firefox sync .58<br/>(sync.tail54538d.ts.net)"]
    end
    subgraph A15["pve-aspiree15 .5 -- forge + metrics"]
        A1["forgejo .52"]
        A2["gitea-mirror .53"]
        A3["prometheus .17"]
        A4["adminer .15"]
    end
    subgraph ASP["pve-aspires .6 -- dashboards + alerts"]
        S1["grafana .18"]
        S2["ntfy .16"]
    end
    RPI["raspberrypi .11<br/>quorum member, zero guests"]
```

(All guest rootfs disks live on pve-shared NFS, so any guest can
land on any node; this placement is the current intent, not a
constraint.)

## 4. The tailnet overlay

Away from home, every device reaches every service by name over
WireGuard, exiting through the house.

```mermaid
flowchart LR
    subgraph AWAY["away from home"]
        PHONE["operator phone<br/>exit node ON"]
        LAP["laptops"]
    end
    subgraph TAILNET["tailnet tail54538d.ts.net"]
        SR["OPNsense router<br/>exit node + subnet route<br/>+ serve relay"]
    end
    subgraph HOME["the house (via the approved route)"]
        GUESTS["https fronts<br/>name.tail54538d.ts.net<br/>19 guests + node UIs"]
        LAN["raw LAN access<br/>ssh, appliances, everything"]
    end
    PHONE --> SR
    LAP --> SR
    SR -- "tailscale serve<br/>(HTTPS + LE certs)" --> GUESTS
    SR -- "approved route<br/>192.168.1.0/24" --> LAN
```

- Away traffic that uses the exit node exits via the same Proton
  path as the house.
- Every guest enrolls in the tailnet at converge; UI-facing
  services get a serve front from their manifest.

## 5. Storage + the backup path

```mermaid
flowchart LR
    NODES["the 4 PVE nodes<br/>(guest rootfs on NFS)"]
    TN["truenas .10<br/>volume1"]
    NFS["pve-shared NFS<br/>guest disks + templates"]
    MEDIA["media share<br/>jellyfin / navidrome / ABS"]
    B2(("Backblaze B2<br/>encrypted offsite"))
    GH((GitHub))
    FJ["forgejo hub .52"]
    CB((Codeberg))
    GHP((GitHub mirrors))

    NODES -- "rootfs" --> NFS --> TN
    MEDIA --> TN
    TN == "nightly snapshots<br/>-> cloud sync (encrypted)" ==> B2
    GH -- "pull mirror" --> FJ
    FJ -- "push mirrors" --> CB
    FJ --> GHP
```

- Media files are the tier-0 data; metadata lives in databases
  (derived, restorable).
- The mirror chain: GitHub canonical -> forgejo hub on-cluster ->
  two external mirrors.

## The narrative behind the pictures

**The Proton blanket (operator directive, 2026-11-28).** Every
packet in or out of the house rides Proton WireGuard: the
router's default gateway is the tunnel (NetShield
ads+trackers variant, US-UT#42), the whole LAN is SNAT'd to the
tunnel address, and the WAN stays armed as automatic failover
("Gateway switching"; the election happens at startup/interface
triggers, so flag changes want a reboot to arm). Local traffic
stays local. The operator chose blanket over the recommended
policy-split -- the reversal is on record in OPS-28 and
issues.md. Away devices selecting the router's exit node
inherit the same Proton exit.

**DNS rides the same posture.** The router's unbound forwards to
Quad9 (9.9.9.9) over DNS-over-TLS, cert-pinned to
dns.quad9.net -- one no-log, malware-filtering party resolves
for the whole house; the ISP sees only the WireGuard stream,
and a WAN failover keeps the DNS leg TLS-encrypted.

**Boot order (a law, identity rule 7).**

1. **truenas first** -- NFS must exist before guests boot.
2. **then the PVE nodes** -- quorum before workloads.
3. **then the guests** (onboot / converge).

Power-down is the reverse. The router sits before all of this;
the reboot runbook is
[scripts/reboot-node.sh](../scripts/reboot-node.sh), one node
at a time.

**Planned (already drawn as dashed lines where applicable).**

- PBS VM at `.12` (OPS-14, v4).
- The router's OPNsense 26.1 upgrade closes v3 (deliberate
  window, config backup first).
- Tailnet names as the fleet's universal addressing (the v4
  opener) -- guests still address each other by LAN IP today.
- Router re-platform onto Proxmox + the Pi's QDevice re-role
  (v5).

## How to read it

Picture 1 is where things physically are; picture 2 is where
packets go; picture 3 is which machine does which job; picture
4 is how the house is reached from outside; picture 5 is where
the data lives and how it survives a house fire. The narrative
section carries the rules the pictures cannot (boot order,
the directive record). If a change touches more than one
picture, that change is probably one worth a second look.
