# Homelab overview

A 5-node Proxmox cluster on a tailnet, backed by a single TrueNAS box for
shared storage + backups. All web surfaces are HTTPS over the tailnet with
Let's Encrypt certificates; nothing is exposed to the public internet.

> This repo documents the current (post-2026-07) Proxmox-based homelab. It
> supersedes the older Docker-on-Pi layout that lived here previously.

## Nodes

| node | role | arch | notes |
| --- | --- | --- | --- |
| `pve-thermaltake` | PVE node | x86_64 | desktop |
| `pve-aspiree15` | PVE node | x86_64 | laptop -- lid-ignored, screen off at boot |
| `pve-aspires` | PVE node | x86_64 | laptop -- lid-ignored, screen off at boot |
| `pve-framework` | PVE node | x86_64 | desktop |
| `raspberrypi` | PVE quorum witness | arm64 | no workloads (no pve-lrm); never host HA CTs here |
| `truenas` | storage | x86_64 | TrueNAS 25.10; NFS for shared storage + vzdump backups |

Shared storage: TrueNAS exports an NFS pool consumed by all PVE nodes as
`pve-shared` (live container disks) and `pve-backups` (vzdump target).

## Tailnet

Everything speaks Tailscale. Tailnet name: `tail54538d.ts.net`. Every web
service (CTs and the PVE node consoles) is exposed as
`https://<host>.tail54538d.ts.net` (Let's Encrypt via either `tailscale serve`
or native cert import), reachable only from machines on the tailnet.

## Services (running CTs)

~19 LXC containers, each its own tailnet node, each served over HTTPS via
`tailscale serve --bg --https 443 --yes http://localhost:<port>`. Examples:
jellyfin, freshrss, forgejo, vaultwarden, linkwarden, searxng, n8n, grafana,
prometheus, excalidraw, drawio, adminer, opengist, speedtest-tracker,
jupyternotebook, cronmaster, bichon, protonmail-bridge, postgresql.

Notifications live in their own CT: see
[`docs/notifications.md`](./notifications.md) and
[`services/ntfy/`](../services/ntfy/).

## Documentation map

* [`overview.md`](./overview.md) -- this file.
* [`notifications.md`](./notifications.md) -- the ntfy push pipeline.
* `services/<name>/` -- per-service config (config files, scripts, deploy notes).