# Idea: Homelab Auto-Repair System

> A self-healing layer for this homelab: deterministic playbooks triggered by
> ntfy alerts, with optional human-in-the-loop approval via ntfy action
> buttons. LLM diagnosis is a non-load-bearing assistant, never the
> decision-maker on dangerous surfaces.

---

## Origin

This doc began as an external pitch ("HAL") -- ntfy alerts -> n8n workflow
-> LLM diagnosis -> scripted fix -> verify -> report. Captured verbatim
first, then pressure-tested against THIS homelab's live stack (probed
2026-08: 5-node Proxmox cluster, 23 LXC CTs, TrueNAS, GL-MT2500 router, no
Docker, no Uptime Kuma, alertmanager+ntfy already live). The pitch assumed
a different homelab (Docker swarm, Plex/\*arr, Uptime Kuma). The honest
read below records what survived, what didn't, and what's worth building.

---

## Problem (still real)

Homelabs break silently and often. Disks fill, CTs crash, certs expire,
services hang, NFS blips drop HA CTs into `error` state. Today this means
manual SSH from the phone at 11 PM. The existing observability stack (Phase
1 done) closed the *detection* gap -- nothing is silent anymore. The next
gap is *response*: every alert still terminates at a phone notification a
human has to act on.

---

## What already exists on this stack (don't rebuild)

The deterministic detection-and-act loop is partly built:

- `pve-shared-remount.sh` (services/pve-shared-nfs-remount/) -- already
  detects dropped NFS storage and auto-remounts before notifying. This IS
  a self-healing playbook with zero AI in it. The pattern to copy.
- `ha-state-watch.sh` -- detects HA state transitions, transitions-only
  push (clean restarts+migrations deliberately not pushed). The
  notification-noise policy to copy.
- alertmanager -> ntfy-slack-bridge -> ntfy -> phone (live, verified) --
  the alert delivery rail already exists. A repair dispatcher just
  subscribes to a repair-topic on the same ntfy server.
- `ideas/auto-update.md` (decisions locked) -- self-healing for the most
  common failure mode (unpatched software). Scoped, deterministic, rollback
  via existing vzdump snapshots. Equivalent to ~half of HAL's playbook
  library done as honest infrastructure.

So: detection rail = done. Several playbooks = done or specified. The
missing piece is a **dispatcher** that routes an ntfy alert-topic to a
named playbook, runs it, verifies, and reports back -- WITHOUT an LLM in
the critical path.

---

## Honest read on the original pitch

### Stack mismatch (inert playbook rows)

Original playbooks assumed Docker: `docker system prune`, `docker compose
restart`, `docker overlay full`, Watchtower. This homelab has no Docker --
workloads are LXC CTs. Those rows translate to:

- disk-fill -> `journalctl --vacuum-time`, `apt-get clean`, clear
  service caches. CT rootfs live on `pve-shared` (NFS) -- disk-fill on a
  CT is really pool-fill on TrueNAS; the fix surface is the TrueNAS box,
  not the CT.
- container-exited -> `pct restart <vmid>` (not `docker compose restart`).
- unhealthy -> `pct restart <vmid>` + health probe via blackbox_exporter's
  existing 27-endpoint probe.
- image-outdated -> covered by `ideas/auto-update.md` (unattended-upgrades).

No Plex/\*arr here. Jellyfin (CT 102) is the media surface; it has no
metric exporter yet (observability Phase 3c). Auto-repair for jellyfin is
premature until jellyfin has metrics to trigger on.

### The LLM-in-the-loop is the weakest layer, not the strongest

1. **Asymmetric cost of a wrong fix.** The dangerous surfaces here are
   `pvecm reboot`, `ha-manager set`, `zpool`, `pvesm`, NFS remounts. One
   wrong auto-fix on the 5-node cluster = a quorum event. An LLM picking
   `ha-manager set ct:N --state started` in the wrong order freezes a CT
   (see docs/ha-recovery.md -- the ordering rule is exact and unforgiving).
   At that point you've encoded the ordering in the playbook anyway and
   the LLM is window dressing.

2. **Confidence numbers from an LLM are not calibrated to risk.** The
   pitch's "auto-execute if confidence >= 85" threshold is a number that
   feels like safety but isn't measured against anything. LLMs are
   overconfident on exactly the ambiguous cases where you'd want
   restraint.

3. **External API dependence breaks the self-hosted model.** Venice
   (cloud LLM) on the alert path = new outbound dependency + new secret
   on a stack deliberately kept tailnet-only. Ollama-local is on-brand but
   the cluster has no GPU pool for it -- only pve-thermaltake has NVIDIA,
   passed through to jellyfin. CPU inference for every alert is slow and
   noisy in a 03:30 window.

4. **The pitch's own exclusion list covers most of the interesting targets.**
   "Never auto-touch: networking, storage pools, backups" -- on a
   Proxmox+TrueNAS homelab that's the router, ZFS, corosync, pve-shared,
   pve-backups. What's left is mostly "restart a single CT", which a
   deterministic script does better, faster, and auditable.

5. **Existing wrappers already beat the AI path on the cases they cover.**
   `pve-shared-remount.sh` doesn't ask an LLM whether to remount -- it
   remounts because the condition is unambiguous. That's the right
   design. Ambiguous conditions should escalate to a human, not to an
   LLM that guesses on a human's behalf.

---

## Revised design -- what I'd actually build

### Tier 1: Deterministic dispatcher (build first, no AI)

A single thin service on CT 128 (ntfy's host) or a new small CT, called
`homelab-dispatcher`:

```
ntfy alert-topic  ->  dispatcher (topic -> playbook map)
                    ->  run named playbook (idempotent bash)
                    ->  verify (blackbox probe / metric query / exit code)
                    ->  publish result to ntfy (low on success, urgent on
                        failure or verification-fail)
```

- **Topic -> playbook map** is a static YAML table, not an LLM. One row
  per alert the user has explicitly approved for auto-action.
  `homelab-disk-fill` -> `playbooks/disk-fill.sh`. No surprises.
- **Playbooks live in the repo** at `services/auto-repair/playbooks/`,
  one file each, idempotent, with a `--dry-run` mode, each carrying a
  header comment matching the renew-pve-tls / ntfy-publish convention.
- **Verification** reuses the existing blackbox_exporter (27 endpoints)
  + prometheus queries -- the same data the alert came from. If the
  probe still fails after the fix, the dispatcher pushes urgent and
  stops (no retry loop).
- **No new CTs/binaries for detection** -- subscribes to the existing
  ntfy server on 127.0.0.1:2586. The only new component is the dispatcher
  process + playbook scripts.

This is `ha-state-watch`'s transitions-only pattern + `pve-shared-remount`'s
act-then-notify pattern, generalized.

### Tier 2: Human-in-the-loop via ntfy action buttons (additive, optional)

For playbooks the user is NOT comfortable auto-running (anything touching
cluster quorum, ZFS, or a CT with stateful data like postgres 108 / forgejo
107), the dispatcher does NOT run them. Instead it publishes an ntfy
message with an **action button**: "Approve restart of CT 108? [Run]
[Snooze 1h]". The user taps; ntfy forwards the tap to a dispatcher webhook;
the playbook runs. This keeps the human on the critical path exactly where
the cost of wrongness is high, and removes them where it isn't.

This is the genuinely useful part of "human-in-the-loop" from the pitch --
ntfy supports action webhooks natively, so it fits the existing rail.

### Tier 3: LLM as optional non-load-bearing assistant (last, if at all)

For alerts with NO approved deterministic playbook, the dispatcher may
(optionally, env-gated) send the alert + a tail of relevant logs to a
local Ollama model and publish the model's *suggestion* to ntfy as a
plain message -- no execution, not even an action button. It's a hint for
the human, not an actor. If the model is wrong, nothing happens. If it's
right, the human turns the suggestion into a committed playbook (Tier 1)
so next time it's deterministic.

Venice/cloud LLM stays out -- breaks the self-hosted model and adds a
secret on the alert path. Ollama-local only, and only if the user wants
it; the dispatcher works fine without it.

### What gets cut from the original pitch

- n8n as the orchestrator. n8n (CT 106) already exists on this stack, but a
  ~50-line Python dispatcher is easier to reason about, version, and audit
  than an n8n workflow JSON blob. n8n's value is visual editing; this
  dispatcher is small enough that a static topic->playbook YAML is cleaner.
  Revisit if the playbook count grows past ~15.
- LLM-driven playbook selection.
- The "confidence >= 85 auto-execute" gate.
- Cloud LLM API.
- Uptime Kuma (not on this stack; prometheus+alertmanager is).
- Docker playbooks (not on this stack).
- The 4-week "share with homelab community" / "month 3: 50% of alerts
  handled without human" targets -- those are product-marketing for a
  SaaS pitch, not goals for a personal homelab. The honest target is:
  "the top 3 repeat incidents stop waking me up."

---

## Candidate playbooks for THIS stack (Tier 1 starter set)

Grounded in incidents this homelab has actually had (per docs/) or
alert rules already firing:

| alert / condition                        | playbook                                | risk   | auto or approval |
| ---------------------------------------- | --------------------------------------- | ------ | ---------------- |
| CT rootfs disk >90% (node fs)            | `disk-fill-ct.sh`: journal vacuum,      | low    | auto             |
|                                          | apt clean, clear /var/cache             |        |                  |
| pve-shared storage gone (`pvesm`)       | already `pve-shared-remount.sh`         | low    | auto (exists)    |
| HA service `error` state                 | `ha-recover-ct.sh`: docs/ha-recovery    | HIGH   | approval         |
|                                          | ordering (disable -> start -> enable)   |        |                  |
| blackbox endpoint down (non-HA CT)       | `restart-ct.sh`: pct restart <vmid> +    | medium | approval         |
|                                          | wait + re-probe                         |        |                  |
| TLS cert <14d (blackbox alert)           | already handled by renew-pve-tls.sh +   | low    | auto (exists)    |
|                                          | renew-truenas-tls wrappers              |        |                  |
| vzdump job-error                         | `vzdump-investigate.sh`: tail job log,  | low    | notify-only (no  |
|                                          | push summary                            |        | auto-run; the    |
|                                          |                                         |        | hook already     |
|                                          |                                         |        | pushes)          |
| postgres 108 unreachable / disk-err     | `pg-safe-restart.sh`: graceful stop +   | HIGH   | approval         |
|                                          | start, NO destructive ops               |        |                  |
| jellyfin transcode stuck (once metrics)  | `jellyfin-restart.sh` (after obs 3c)    | low    | approval         |
| router WAN down                          | NONE -- router is notify-only by policy |        |                  |
| TrueNAS update available                 | NONE -- TrueNAS is notify-only         |        |                  |

The "auto" rows are the win. The "approval" rows are the ntfy-action-button
value. The "notify-only" rows honor the tiered-policy decisions already
locked in `ideas/auto-update.md`.

---

## Safety & guardrails (kept from the pitch, right-sized)

| guardrail            | implementation                                                |
| -------------------- | ------------------------------------------------------------- |
| Static allowlist     | topic->playbook YAML, explicit user-approved, no LLM override |
| Dry-run mode         | every playbook supports `--dry-run` (prints, doesn't act)     |
| Rate limiting        | max N invocations per playbook per hour (per-playbook config) |
| Circuit breaker      | 3 consecutive verify-fails -> disable that playbook + push    |
|                      | urgent "playbook auto-disabled -- needs human"               |
| Exclusion list       | encoded as "playbooks that simply don't exist" -- there is    |
|                      | no row for pvecm reboot / zpool / router / TrueNAS, so the    |
|                      | dispatcher can never call them                                |
| Audit log            | append-only JSONL of every run (topic, playbook, host, exit,  |
|                      | verify-result, timestamp) in /var/lib/homelab-dispatcher/    |
| Snapshot before      | NOT in dispatcher -- user's existing Sat 21:00 vzdump covers  |
| destructive          | rollback; playbooks are non-destructive by design             |

---

## Repo layout (preliminary)

```
services/auto-repair/
  README.md                         -- what + why + install + revert
  dispatcher.py (or dispatcher.sh) -- ntfy subscriber, topic->playbook map
  playbooks/                        -- one bash file per playbook
    disk-fill-ct.sh
    ha-recover-ct.sh
    restart-ct.sh
    pg-safe-restart.sh
    vzdump-investigate.sh
  playbooks-map.example.yaml        -- the static allowlist (no secrets)
  crontab.example                   -- /etc/cron.d for the dispatcher
  ntfy-action-webhook.example       -- the approval-button webhook receiver
```

Follows the existing repo convention: live copy on the host is source of
truth, repo is the reproducible backup, secrets out of repo (none needed
beyond the existing ntfy token).

---

## Open questions

1. Dispatcher language: Python (cleaner ntfy subscribe + webhook) or bash
   (matches renew-pve-tls / ntfy-publish / ha-state-watch style)? Python
   is the slight lean -- it's a long-running subscriber, not a cron one
   shot.
2. Dispatcher placement: co-locate on CT 128 (ntfy host, local-lvm,
   NOT HA-managed -- same fragility caveat as ntfy itself) vs a new small
   HA CT. Ntfy host keeps the subscriber next to the server (no tailnet
   round-trip) but inherits ntfy's single-node-of-failure on pve-framework.
3. Which playbooks are Tier-1 auto vs Tier-2 approval vs notify-only? My
   table above is a proposal -- confirm or adjust per-playbook.
4. Tier 3 (Ollama suggestion-only): build it, or leave it out entirely
   until a specific alert proves an LLM hint would have helped?
5. n8n (CT 106) reuse: keep it for the human-approval webhook receiver
   (visual, easy to edit), or write a tiny Flask/http.server handler?
   n8n is already running; reusing it costs nothing and offloads the
   webhook handling. Slight lean to reuse n8n for approval-flow only,
   dispatcher itself stays python/bash.

---

## One-sentence pitch (revised)

> "Turn the top 3 repeat incidents on this homelab from 11 PM SSH sessions
> into deterministic playbooks the existing ntfy stack runs for you -- and
> keep the dangerous ones behind a one-tap ntfy approval button, not behind
> an LLM that guesses on your behalf."

---

*Status: idea -- grounded in this stack, not started. Build order would be
Tier 1 (deterministic dispatcher + 2-3 auto playbooks) end-to-end before
touching Tier 2 or 3.*