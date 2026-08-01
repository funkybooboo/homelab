# Self-hosted Firefox Sync Server (syncstorage-rs)

## Executive summary

Run Mozilla's `syncstorage-rs` in a new Proxmox CT so every Firefox instance
in the household (desktop, laptop, mobile) syncs bookmarks / passwords /
history / tabs / addons through *our* homelab instead of Mozilla's cloud.
Native Firefox integration (no browser extension, no XBrowserSync hack) --
the only self-host option that gives that. Data stays on our hardware, sync
metadata (when/how-often/from-where) leaks nowhere, and LAN-resident devices
sync at wire speed.

**Honest caveat up front:** self-hosting does **not** eliminate the Mozilla
Account dependency. Firefox Sync authenticates via OAuth tokens issued by
Mozilla's FxA infrastructure; our tokenserver *validates* those tokens and
issues Hawk credentials for our syncstorage backend, but the FxA login itself
still round-trips Mozilla. The win is **data + metadata sovereignty**, not
"never talk to Mozilla again". If FxA ever changes its terms for self-hosters
(see Risk Assessment) the whole thing unravels -- this is a convenience +
privacy project, not a resilience project.

## Why

* **Privacy / metadata.** Firefox Sync payloads are client-side encrypted
  with keys derived from your FxA password, so Mozilla can't read the blobs
  either way. But Mozilla *does* see sync timings, device counts, collection
  sizes, IPs. Self-hosting zeros that out.
* **No external dependency for keep-alive.** LAN devices keep syncing during
  an internet outage (Firefox still talks to the local server).
* **Custom quotas.** Mozilla caps storage; we don't have to care.
* **It's a real Rust service in the homelab.** Good exposure to a
  production Rust binary, MySQL ops, OAuth/OIDC validation flows -- building
  on the observability + ntfy pipeline we already run.
* **Fits existing infra patterns.** Same shape as every other CT we run:
  debian-13 unprivileged CT, tailscale serve for TLS, Grafana board, ntfy
  alerts on failure, vzdump snapshot Sat 21:00.

## What it is

`syncstorage-rs` is Mozilla's current Rust sync storage backend
(https://github.com/mozilla-services/syncstorage-rs). It replaced the old
Python `syncserver`. Key components:

| component | role | needed? |
|-----------|------|---------|
| **syncstorage-rs** | the storage backend itself; REST API for collections (bookmarks, passwords, ...) | yes |
| **tokenserver** | validates FxA OAuth token, mints Hawk creds for syncstorage | yes (bundled into same binary via `SYNC_TOKENSERVER__ENABLED=true`) |
| **MySQL 8.0** | stores sync blobs + tokenserver state | yes (mysql is better-tested than postgres here) |
| **reverse proxy w/ TLS** | Firefox refuses non-https sync endpoints (with a pref override for LAN POC) | yes for prod, optional for LAN POC |
| **Spanner emulator** | alternative backend | no, skip |

## Where it lives (proposed)

* **CT 131** (next free ID; 122=prometheus, 130=loki) on `pve-thermaltake`.
* **2 cores / 2GB RAM / 25GB local-lvm rootfs** (NOT pve-shared NFS -- same
  reasoning as Loki CT 130: random IO on a DB abhors NFS blips).
* **MySQL:** run *inside* CT 131 for the POC (one less dependency). If it
  earns its keep, Phase 2 splits MySQL out to its own CT (133) and reuses
  the existing Postgres-on-CT-108 backup story as a template for mysqldump +
  binlog PITR. Do NOT reuse CT 108 postgres -- syncstorage's schema is
  mysql-flavoured and the mysql-on-postgres path is unsupported.
* **Network:** tailscale only. `sync.tail54538d.ts.net` via `tailscale serve
  --https 443` -> `localhost:8000`, real LE cert (same pattern as
  grafana/forgejo/prometheus/loki). No public exposure, no port forward.
  LAN devices reach it over tailnet; mobile over tailscale when off-LAN.
* **Backups:** falls under the existing Sat 21:00 `vzdump` job. Add a
  nightly `mysqldump --single-transaction` to `/var/backups/sync` in-CT
  for logical-restore granularity (mirrors the approach we'd want for any
  DB-backed CT).

## Firefox client config

Desktop + mobile:

```
about:config
  identity.sync.tokenserver.uri  ->  https://sync.tail54538d.ts.net/1.0/sync/1.5
```

That's the only client-side knob. The FxA login stays against Mozilla; only
the *tokenserver* URL points at us. Mobile Firefox supports the same pref.

## Phased plan

### Phase 1 -- Proof of concept (weekend, LAN-only)

Goal: two Firefox instances sync a bookmark through our server.

1. Create CT 131 from the debian-13 template, join tailscale
   (`sync.tail54538d.ts.net`), enable `tailscale serve --https 443` ->
   `localhost:8000` (settle 90s before `tailscale cert`, same gotcha as CT 130).
2. Stand up MySQL 8.0 in-CT; create `syncstorage` + `tokenserver` databases
   and a `sync` user.
3. Run syncstorage-rs from the Mozilla container image
   (`ghcr.io/mozilla-services/syncstorage-rs/syncstorage-rs-mysql:latest`)
   via rootless-ish podman/docker in the CT, OR install the binary from the
   release tarball. Start with the container for fast iteration.
4. Generate `SYNC_MASTER_SECRET` + `fxa_metrics_hash_secret` (32+ random
   chars each). Keep in `/etc/sync.env` mode 0600 -- NOT in repo, mirror the
   ntfy-publish.env pattern.
5. `curl https://sync.tail54538d.ts.net/__heartbeat__` -> 200.
6. Set the `identity.sync.tokenserver.uri` pref on desktop+laptop, sign into
   FxA, bookmark a page, verify it lands on the other device within seconds.

Success criteria: two Firefox instances sync through `sync.tail54538d.ts.net`.

### Phase 2 -- Persistent + backed-up (week 2)

1. Split MySQL to its own CT 133, wire binlog + nightly `mysqldump` +
   off-box copy (rsync over tailscale to TrueNAS, mirroring the Loki log
   ship pattern).
2. Replace container with a proper systemd unit running the syncstorage-rs
   binary; config in `/etc/sync/config.toml`, env in `/etc/sync.env`.
3. Health monitoring: add a blackbox_http probe to the existing
   blackbox job on CT 122 (one more row in Network -- Uptime and Certs),
   a heartbeat alert rule feeding alertmanager -> ntfy (same pipeline as
   the other 27 endpoints), and a small "App -- Firefox Sync" Grafana board
   (syncstorage exposes `/metrics`).
4. Secrets: document rotation procedure for `SYNC_MASTER_SECRET` (rotating
   it invalidates all existing client sessions -- expected, not a bug).

### Phase 3 -- Hardening (optional, week 3-4)

1. Network segmentation -- dedicated docker/bridge net if we keep the
   container, or firewall rules restricting the mysql port to CT 131 only.
2. Backup restore drills -- actually restore from a mysqldump into a throwaway
   CT and confirm Firefox still syncs. (We say "tested monthly" for everything
   else; actually do it once here to prove the backup is real.)
3. Off-site backup of the mysqldump (rsync.net or S3 Glacier, ~$5/yr) so a
   house-level disaster doesn't lose years of bookmarks/passwords.
4. Documented recovery: RTO 1h, RPO 24h. (Same targets as our other DB-backed
   services.)

## Open questions

1. **Container vs binary in-CT.** Container is faster to stand up but
   introduces a docker/podman runtime into an otherwise debian-native fleet
   (we run binaries for loki, promtail, grafana, forgejo). Lean toward the
   binary to match house style; decide at Phase 1 kickoff.
2. **MySQL placement.** In-CT for POC is fine; dedicated CT 133 for prod.
   Confirm we don't want to reuse the existing `postgresql` CT 108 --
   answer is almost certainly "don't, syncstorage is mysql-native".
3. **Mobile off-LAN.** tailscale handles this for free, but do we want
   `sync.tail54538d.ts.net` reachable from the WAN via a tailscale Funnel
   for guests / family, or keep it tailnet-only? Default: tailnet-only.
4. **FxA account for the household.** Per-person FxA accounts (each person
   validates against their own FxA login), or one shared household FxA
   account that everyone's Firefox signs into? Affects the tokenserver
   `node_type` + how `fxa_metrics_hash_secret` rows get bucketed. Pick
   before Phase 2.
5. **Browser add-on sync.** Syncstorage covers most collections natively;
   confirm add-on sync works through self-host (it should -- same protocol).

## Threat model

| threat | mitigation |
|--------|------------|
| server compromised | client-side encryption -- attacker gets encrypted blobs only, no keys |
| metadata to third party | eliminated -- we are the only party |
| mitm | TLS via tailscale serve + LE cert; Firefox does cert pinning on the tokenserver URL |
| unauthorized access | tailnet-only, no public port; mysql bound to localhost/CT-internal |
| data loss | nightly mysqldump + Sat vzdump + Phase 3 off-site copy |
| Mozilla kills self-hoster OAuth | low likelihood / high impact; monitor mozilla-services announcements; community fork is the fallback |

## Comparison with alternatives

| option | data control | complexity | FxA required | native FF integration |
|--------|--------------|------------|-------------|----------------------|
| Mozilla cloud sync | low | none | yes | yes |
| **syncstorage-rs (this)** | **high** | **medium** | **yes** | **yes** |
| XBrowserSync | high | low | no | no (extension) |
| Floccus | high | low | no | no (extension, webdav) |
| Syncthing + bookmark files | high | low | no | no |

syncstorage-rs is the **only** option that gives native Firefox integration
with full data control. The FxA dependency is the price of nativeness.

## Cost

* Hardware: $0 (amortized into existing PVE cluster).
* Power: ~3-5W continuous for one small CT.
* Domain: $0 (we use `*.tail54538d.ts.net` for free via tailscale serve).
* Off-site backup: ~$5/yr if we add rsync.net in Phase 3.
* Total: ~$5/yr.

## Success metrics

- [ ] Desktop + laptop sync bookmarks through `sync.tail54538d.ts.net`.
- [ ] Firefox Android syncs against the same server.
- [ ] Sync completes < 5s on LAN.
- [ ] `/__heartbeat__` on the Network -- Uptime and Certs board stays green.
- [ ] Nightly mysqldump runs; one restore test passes.
- [ ] Recover from full CT loss within 1h (recreate CT, restore dump, re-pref
      clients only if the hostname changed -- hostname is stable so clients
      shouldn't even notice).

## Risk assessment

| risk | likelihood | impact | mitigation |
|------|-----------|--------|------------|
| Mozilla deprecates self-hoster OAuth | low | high | watch mozilla-services repo; community fork fallback |
| MySQL corruption | medium | high | nightly dump + Sat vzdump + binlog PITR |
| syncstorage-rs abandonware | medium | medium | it's Mozilla's own prod backend; low real risk of abandonment |
| cert expiry | low | medium | tailscale serve auto-renews LE (already proven on CT 122/130) |
| client-side key loss (FxA password lost) | low | severe | same risk as cloud sync -- not unique to self-hosting |

## References

* Source: https://github.com/mozilla-services/syncstorage-rs
* Docs: https://mozilla-services.github.io/syncstorage-rs/
* Config ref: https://mozilla-services.github.io/syncstorage-rs/config.html
* Container images: https://github.com/mozilla-services/syncstorage-rs/pkgs/container/syncstorage-rs
* Sync protocol: https://mozilla-services.readthedocs.io/en/latest/sync/

## Status

**Phase:** idea -> ready for Phase 1 (POC) when a free weekend lands.
**Estimated effort:** 1 weekend for POC, 2-3 weekends through Phase 2, hardening optional.
**Maintenance:** ~1h/month (image updates, backup-restore drill).
**Prerequisite:** none blocking -- all dependencies (PVE, tailscale serve, LE, Grafana, ntfy, vzdump) are already live.