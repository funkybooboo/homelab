# Future services backlog (community-scripts survey, 2026-11-25)

**Status**: ideas, demand recorded, not queued
**Why**: the operator surveyed the Proxmox VE Community Scripts catalog
and flagged 42 services of interest. This is the triage: what is
already on the roadmap, what fits an existing era, what is genuinely
new, and what overlaps what the fleet already runs.

**Deployment stance** (same as the ONCE trio, USER-14..16): the
community scripts are REFERENCES for what upstream ships, not our
deployment method. When any of these gets a story, it gets a guest
manifest + an ansible role like everything else; container-only apps
take the documented container-exception path.

## Already on the board (no new story needed)

| Service | Where it already lives |
|---|---|
| n8n | USER-6 (restored keeps) |
| searxng | USER-3 (daily tools) |
| audiobookshelf | USER-2 (media fleet) |
| firefox-syncserver | USER-5 -- note: prefer syncstorage-rs (modern server) over the script's legacy syncserver 1.5 |
| opnsense-vm | v5 router re-platform (OPS-3) |
| forgejo-runner | v4 push-to-apply (OPS-12) -- a runner on the hub is the natural CI arm |
| prometheus-alertmanager | v4 alerting tier -- now superseded by the off-site alerting design (see design/offsite-alerting.md) |
| sonarr / seerr / bazarr / configarr | USER-2 extension notes -- the *arr automation layer on top of the media fleet, when curation demands it |
| gpu-passthrough | prerequisite machinery for the frigate / LLM eras below |

## New candidates, with the era they suggest

| Service | One-liner | Suggested home |
|---|---|---|
| paperless-ngx (+gpt/+ai) | document management + OCR + AI tagging | own era; a heavyweight, high-value service -- deserves a USER story |
| immich | photo library + apps (truenas holds the media) | v3 media-adjacent era |
| frigate | NVR / camera detection (wants GPU) | camera era; gpu-passthrough first |
| ollama + openwebui | local LLM serving + web UI | LEARN-1 distributed llama -- same era |
| rustfs | S3-compatible object storage | observability/storage backend option (e.g. loki's store, OPS-14 backups) |
| nextcloud-vm + onlyoffice | files suite + collaborative editing | files era; heavy -- evaluate against truenas' own sharing first |
| stalwart | full mail server (IMAP/SMTP/JMAP) | mail era; big -- evaluate against bichon + protonmail-bridge scope first |
| rustdeskserver | self-hosted remote-desktop relay | daily-tools era |
| headscale | self-hosted tailscale control plane | sovereignty someday; the fleet rides the hosted tailnet by choice (OPS-21) |
| metube | youtube downloader | media era |
| shlink | URL shortener | daily tools |
| languagetool | grammar checking (self-hosted) | daily tools |
| haos-vm | Home Assistant OS (VM, not CT) | smart-home era -- first VM service; needs a VM story |
| homepage | services dashboard | daily tools (low priority; grafana serves today) |
| hermesagent / opengym / paperclip / myip / tor-snowflake / github-runner | small utilities + unknowns | decide at curation time; none blocking |

## Honest overlaps -- suggest SKIP

| Service | Why the fleet already covers it |
|---|---|
| uptimekuma | the debbie watcher (5 families + heartbeat) is this, already alive |
| netdata | prometheus + node_exporter + grafana stack covers metrics |
| traefik | tailscale serve fronts (model B) are the fleet's reverse proxy |

## Policy

Backlog items earn stories when the operator asks for them ("one
story per service" precedent). Nothing here silently joins a converge.
