# USER-2: The media fleet

As a household member, I want the media services back on the GPU node
(jellyfin, navidrome, audiobookshelf), so that movies, music, and
audiobooks work again.

**Status**: SHIPPED 2026-11-26 (build + metadata restore complete;
converge idempotent end-to-end; services live on their serve fronts)
**Arc**: v3 (scope: [../issues.md](../issues.md) item 6)

## Acceptance criteria

- [x] All three deployed from guest manifests on `pve-thermaltake`
      (jellyfin 205/.55, navidrome 206/.56, audiobookshelf 207/.57;
      GPU: nvidia-smi answers from INSIDE the jellyfin CT)
- [x] Media libraries mounted from truenas NFS (6 exports on every
      amd64 node at /mnt/media/*, bind-mounted into the CTs; no
      in-CT NFS)
- [x] Per-service metadata extracted and restored (vzdump archive
      via --copy-from-dump: jellyfin 2.1G data + 18.4MB library db
      from 102 Sep 26; navidrome 21M db from 132 Sep 26;
      audiobookshelf 3.8M metadata + config from 133 Nov 21 --
      marker-gated, never-clobber, markers only written on a real
      restore; final converge changed=0 across the whole fleet)

## Notes

Firefox sync (syncstorage-rs) is deliberately NOT here -- it is its own
story (USER-5) despite living on the same old node.

Built fresh on thermaltake (the only GPU): the media data never
moved (truenas NFS exports, untouched); per-service metadata
restores from the dump archive
([../docs/data-to-extract.md](../docs/data-to-extract.md)).

The build design, the as-built deviations (the GPU driver
situation, the installer-source finds, the restore saga), and the
shipped record are in [../history.md](../history.md) (v3). The
gotchas this build surfaced are in
[../docs/quirks.md](../docs/quirks.md).
