# Documentation index

Two tiers of truth here: what describes the fleet as it will be, and
what describes the old fleet as it was (the old CTs are cleaned out,
not revived -- that tier is the as-was reference for the v2 rebuild).
The historical archive of the wind-down era lives in
git history, not the tree.

## Current (describe what exists / what we run against)

- [`overview.md`](./overview.md) -- the one-page picture (node table
  predates the wind-down; re-anchored during v2)
- [`data-to-extract.md`](./data-to-extract.md) -- the LIVE tiered
  extraction inventory (`scripts/extract-legacy.sh` walks it); tier-0
  copy must exist outside the truenas pool before anything
  destructive
- [`backups.md`](./backups.md) -- vzdump + snapshots + B2 (still true;
  PBS lands at OPS-14)
- [`notifications.md`](./notifications.md) + [`ntfy-flow.md`](./ntfy-flow.md)
  -- the ntfy push pipeline
- [`https.md`](./https.md) -- per-node TLS + the per-CT `tailscale
  serve` machinery
- [`ha-recovery.md`](./ha-recovery.md) -- the HA error-state dance (the
  revival evening's runbook for stuck CTs)
- [`laptop-nodes.md`](./laptop-nodes.md) -- lid + screen-off setup
- [`nextjs-behind-tls-proxy.md`](./nextjs-behind-tls-proxy.md) -- the
  INTERNAL_API_URL app trap

## Old-fleet as-built (as-was reference for the v2 rebuild; IPs were
## 192.168.8.x then)

- [`cluster.md`](./cluster.md) -- cluster + HA + the Pi rule
- [`nodes.md`](./nodes.md) -- the 5 nodes + truenas (pre-shutdown
  placements)
- [`services.md`](./services.md) -- the 23-CT July catalog (the final
  state added CTs 130-134)
- [`storage.md`](./storage.md) -- NFS + the jellyfin media mounts
- [`observability.md`](./observability.md) -- the observability stack
  as-built 2026-08-30
