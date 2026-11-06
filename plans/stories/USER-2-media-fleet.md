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
      layout; see `docs/legacy/`)
- [ ] Per-service data/metadata extracted from the old rootfs before
      it is archived

## Notes

Firefox sync (syncstorage-rs) is deliberately NOT here -- it is its own
story (USER-5) despite living on the same old node.
