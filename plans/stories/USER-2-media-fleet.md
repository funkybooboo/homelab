# USER-2: The media fleet

As a household member, I want the media services back on the GPU node
(jellyfin, navidrome, audiobookshelf), so that movies, music, and
audiobooks work again.

**Status**: planned
**Arc**: v3 (scope: [../issues.md](../issues.md) item 6)

## Acceptance criteria

- [ ] All three deployed from guest manifests on `pve-thermaltake`
      (the only GPU; NVIDIA transcode + UVM devnode handling ported
      from `services/nvidia-uvm-devnodes/`)
- [ ] Media libraries mounted from truenas NFS (the old dataset
      layout is in docs/storage.md)
- [ ] Per-service data/metadata extracted from the old rootfs before
      it is archived

## Notes

Firefox sync (syncstorage-rs) is deliberately NOT here -- it is its own
story (USER-5) despite living on the same old node.

REVISED 2026-11-21 (revival): the media CTs revive with the fleet on
thermaltake; the story becomes verify (GPU transcode, the 5 NFS media
mounts, library counts vs the docs/services.md July catalog).

REVISED 2026-11-22 (plan shift final form): the old media CTs were
cleaned out (OPS-20). BUILD FRESH on thermaltake (the only GPU):
jellyfin, navidrome, audiobookshelf, syncstorage as manifests +
roles. The MEDIA DATA never moved (truenas NFS exports, untouched);
only per-service configs/metadata would restore from dumps if wanted
(tier-2, decide at story time).
