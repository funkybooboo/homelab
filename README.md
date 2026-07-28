# Homelab

Documentation for the current homelab: a 5-node Proxmox cluster on a
[Tailscale](https://tailscale.com) tailnet, backed by a TrueNAS storage box.
All web surfaces are HTTPS over the tailnet -- nothing is exposed to the
public internet.

> This is the live, Proxmox-based homelab (post-2026-07). It supersedes the
> older Docker-on-Pi service configs that used to live in this repo.

## Start here

* [`docs/overview.md`](docs/overview.md) -- nodes, tailnet, services, doc map.
* [`docs/notifications.md`](docs/notifications.md) -- the ntfy push pipeline
  for TrueNAS + homelab-wide alerts.
* [`docs/ntfy-flow.md`](docs/ntfy-flow.md) -- ASCII diagram of request flow
  through the ntfy container.

## Services documented so far

* [`services/ntfy/`](services/ntfy/) -- self-hosted ntfy push server + a tiny
  Slack-to-ntfy bridge so TrueNAS's native Slack alert type can publish to
  ntfy. Includes reproducible deploy steps + the (scrubbed) bridge source.

## Conventions

* No secrets in this repo. Configs that need a secret are committed only as
  `*.example` templates; the real filled-in files (with tokens/passwords)
  live on the hosts they run on and are gitignored.
* Service dirs hold config files, helper scripts, and a per-service `README.md`
  with deploy notes.