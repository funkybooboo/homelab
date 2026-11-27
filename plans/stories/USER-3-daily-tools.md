# USER-3: Daily tools

As a household member, I want the daily-driver tools back -- freshrss,
searxng, it-tools, and whatever else survives curation -- so that
everyday workflows return.

**Status**: in progress (five container guests live 2026-11-27; the
freshrss data restore waits on one operator extraction)
**Arc**: v3 (scope: [../issues.md](../issues.md) item 6)

## Acceptance criteria

- [x] Curated list decided from the old ~28 (lean: ~12-15 total
      resurrected; the rest stay stopped + documented in the
      curation list)
- [ ] Each service: manifest + role, data extracted from old rootfs,
      verified, THEN old rootfs archived
      (four stateless tools + freshrss built as container guests;
      the freshrss dump extraction is the remaining operator step)
- [x] Postgres-backed services (linkwarden, omnivore if kept) point
      at OPS-10's instance (freshrss keeps its sqlite data dir --
      it was sqlite in the old fleet and restores verbatim)

## The curation list (operator decisions 2026-11-27)

The old fleet, every vmid accounted for (recovered from the
extraction script's probe table):

| Old CT | Service | Disposition |
| --- | --- | --- |
| 102/132/133 | jellyfin, navidrome, audiobookshelf | done (USER-2, live) |
| 107/108/109/106 | forgejo, postgres, vaultwarden, n8n | live (n8n = USER-6) |
| 105 | old forgejo-mirror | superseded by gitea-mirror CT 203 |
| 123 | old grafana | superseded by new grafana; dashboards restorable from dump |
| 112/113/118/125/126/127/103/134 | linkwarden, opengist, jupyter, bichon, protonmail-bridge, cronmaster, speedtest, omnivore | kept -- own stories USER-6..USER-13, OPS-24 |
| 131 | firefox sync | kept -- USER-5 (opens with the B2 check) |
| 101 | it-tools | rebuilt fresh here (stateless) |
| 104 | freshrss | KEPT per operator -- built here (data restore pending) |
| (no CT) | searxng, excalidraw, drawio | rebuilt fresh here (stateless) |
| 110/116 + VM templates | stopped templates | gone (OPS-20); resurrect on demand |

Not resurrected, with reasons: old forgejo-mirror + old grafana
(both superseded by live replacements); the old templates (gone,
resurrect on demand). Nothing else remains uncategorized -- the
whole old fleet is keep / superseded / gone.

Operator decisions: (1) freshrss kept; (2) one guest per service;
(3) node placement pve-aspiree15.

## The container-guest mechanism (shipped here, ONCE trio inherits)

These services are container-native (no apt path), so USER-3 lands
the fleet's container mechanism: one `container_guest` role, a
`container:` block per manifest (image, digest, port, target,
volumes, env), docker + compose inside nesting-enabled CTs,
images pinned by DIGEST, a systemd-managed `compose up --wait`,
stdout to the guest journal (promtail ships it). The digests roll
via `make update` (`roll-pins.sh` resolves each image's latest
digest and rewrites the manifest; the next converge re-pulls and
restarts). Two PVE unlock lines (nesting + apparmor raw) are
applied by play 2 -- see [../docs/quirks.md](../docs/quirks.md).

## Notes

The deliberately-not-resurrected get a one-line reason each in
the table above; that list is what makes lazy resurrection cheap
later -- plus the dump archive
([../docs/archive.md](../docs/archive.md)) keeps it cheaper still.

The remaining operator step (freshrss data):

```sh
sudo ./scripts/extract-legacy.sh --copy-from-dump 104
sudo chown -R nate:nate legacy-extraction
make converge
```

The old feeds list is also in git history if a fresh start is
ever preferred:
`git show 3e67e2b:services/freshrss/feeds.opml`.
