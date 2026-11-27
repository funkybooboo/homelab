# Diagrams: the homelab at a glance

The visual atlas. One page, five pictures, all current as of
2026-11-28. The data behind them lives in
[ansible/inventory/](../ansible/inventory/) and the guest
manifests; the narrative lives in
[network.md](./network.md). When reality changes, change these
the same commit.

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
    LAN["the house<br/>(5 nodes, 17 guests,<br/>every client)"]
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
        TT4["postgres .14<br/>(the fleet database)"]
        TT5["vaultwarden .51"]
        TT6["loki .19"]
    end
    subgraph FW["pve-framework .4 -- the tools tier"]
        FW1["it-tools .61"]
        FW2["searxng .62"]
        FW3["excalidraw .63"]
        FW4["drawio .64"]
        FW5["freshrss .65"]
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
        GUESTS["https fronts<br/>name.tail54538d.ts.net<br/>17 guests + node UIs"]
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

## How to read the five together

Picture 1 is where things physically are; picture 2 is where
packets go; picture 3 is which machine does which job; picture
4 is how the house is reached from outside; picture 5 is where
the data lives and how it survives a house fire. If a change
touches more than one picture, that change is probably one worth
a second look.
