# Legacy archive (the pre-greenfield homelab)

Everything the old fleet was, frozen at the 2026-10 wind-down: what
ran, where, how it was wired, and what data was worth extracting before
the old rootfs disks go away. The greenfield rebuild (v1+) does not
rebuild from this -- it starts clean on PVE 9.2 -- but USER/OPS stories
that restore data start from THESE records.

Companion: [`scripts/extract-legacy.sh`](../../scripts/extract-legacy.sh)
runs against the live truenas after the v1 network move (OPS-4) to
inventory + pull the data listed in
[`data-to-extract.md`](./data-to-extract.md).

## Contents

| File | What it holds |
|------|---------------|
| [`guest-catalog.md`](./guest-catalog.md) | All 28 running CTs + 6 stopped templates: ids, nodes, storage, HA, ports, restore-story mapping |
| [`network.md`](./network.md) | The 192.168.8.0/24 LAN: router, reservations, node IPs, tailnet layout, corosync |
| [`quirks-and-incidents.md`](./quirks-and-incidents.md) | Every trap + incident the old fleet taught: Pi rule, NFS races, HA dances, per-node glue, failures |
| [`data-to-extract.md`](./data-to-extract.md) | Per-CT data inventory: paths, priority, what each restore needs |

## Provenance + honesty notes

Sources, in order of authority for their date:

- `docs/services.md` -- 2026-07 catalog snapshot (23 running CTs).
  STALE in two ways: it predates CTs 130-134, and node placements
  drifted afterward (HA failovers + pve-balance moved CTs constantly).
- The proxmox agent skill's CT table -- the LAST live inventory
  (2026-10, pre-shutdown). Adds CTs 131-134 (the media batch: syncstorage,
  navidrome, audiobookshelf, omnivore) + reflects final placements.
  One entry is suspect: it places `128 ntfy @ aspires`, but services.md +
  docs/ha-recovery.md + storage.md all record ntfy's rootfs on
  **pve-framework's local-lvm** (which would pin it to framework and make
  it non-migratable). Recorded as framework + flagged, since the
  local-lvm fact (three sources) matters more than the skill's node note.
- `docs/observability.md` -- 2026-08-30 as-built: adds CT 130 `loki`
  (deployed after the July catalog; static LAN .130).

Final running count: 28 CTs + 6 stopped templates = the "~28 LXC CTs"
the 2026-11-04 forensics report counted. vmid 129 was never used; 110 +
116 are LXC templates (skill table only lists the 4 VM templates).

The wind-down timeline lives in
[`../../plans/history.md`](../../plans/history.md) (cross-checked 2026-11-06:
stages 2026-09-27 framework -> 2026-10-01 thermaltake -> 2026-10-19
truenas + CTs -> 2026-10-28 remaining nodes + router).
