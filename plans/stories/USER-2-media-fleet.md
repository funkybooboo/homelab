# USER-2: The media fleet

As a household member, I want the media services back on the GPU node
(jellyfin, navidrome, audiobookshelf), so that movies, music, and
audiobooks work again.

**Status**: BUILT 2026-11-26 (converge green + idempotent;
metadata restore awaits the operator's extraction run)
**Arc**: v3 (scope: [../issues.md](../issues.md) item 6)

## Acceptance criteria

- [x] All three deployed from guest manifests on `pve-thermaltake`
      (jellyfin 205/.55, navidrome 206/.56, audiobookshelf 207/.57;
      GPU: nvidia-smi answers from INSIDE the jellyfin CT)
- [x] Media libraries mounted from truenas NFS (6 exports on every
      amd64 node at /mnt/media/*, bind-mounted into the CTs; no
      in-CT NFS)
- [ ] Per-service metadata extracted from the old rootfs and restored
      (operator runs `./scripts/extract-legacy.sh --copy 1` on debbie
      -- needs root; one converge after lands all three restores,
      marker-gated, never-clobber)

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

## Build design (2026-11-26, recorded before code)

(as built; the build log's deviations are appended below)

- IDs per guests/README conventions: jellyfin 205/.55, navidrome
  206/.56, audiobookshelf 207/.57 (.54 skipped -- the dead mirror
  CT's IP, stale DNS confusion risk).
- NFS model per docs/network.md planned diagram: the media exports
  mount on EVERY x86 node at the same path (/mnt/media/*), CTs get
  bind mounts via pct mp entries -- guest mobility, no in-CT NFS.
  Node mounts are fstab + `_netdev,nofail` (boot-order law: truenas
  boots first; nofail keeps a dead truenas from hanging a node).
- Six exports (truenas sharing/nfs, verified live): movies,
  tvshows, Music, Audiobooks, Books, Podcasts. All map to
  /mnt/media/{movies,tvshows,music,audiobooks,books,podcasts}.
- mounts:[] + devnodes were DECLARED in manifests but UNIMPLEMENTED
  in guests.yml (no guest needed them until now) -- this story adds
  the mp/devn application, verify-first style (pct config probe
  before pct set; never trust, always check).
- Roles follow the vaultwarden house pattern: version-gate marker,
  pinned installs, restore-if-absent from legacy-extraction/, systemd
  hardening, serve fronts (8096/4533/13378).
- GPU: dkms nvidia 580.142 was built for kernel 7.0.14-20-pve; the
  nodes now run 7.0.14-30-pve and the driver is GONE (nvidia-smi
  fails, no /dev/nvidia*). Rebuild dkms for the running kernel,
  verify nvidia-smi, then devnode passthrough into CT 205.
- Metadata restore sequence: CTs converge EMPTY first (services
  healthy, libraries absent), then the operator runs
  `scripts/extract-legacy.sh --copy 1` on debbie (needs root; the
  tier-1 list covers jellyfin 102, navidrome 132, audiobookshelf
  133 -- their raw disks verified present on pve-shared), then one
  more converge lands the metadata restore-if-absent. Never-clobber
  both ways: an empty-fresh CT accepts the dump; a live library
  with real state refuses to be overwritten.
- ports: jellyfin 8096, navidrome 4533, audiobookshelf 13378.

## As-built deviations from the design (2026-11-26)

- **GPU driver = the .run 580.142 branch, not Debian's apt driver.**
  Found live: Debian trixie's nvidia-driver 550 cannot compile
  against PVE kernel 7.0 (dkms fails in nv-mmap.c -- VMA_LOCK_OFFSET
  + mmap_lock API drift), and NVIDIA's CUDA apt repo has rotated
  past the 580 branch entirely (590+ dropped Pascal). The GTX 1060
  has NO apt-managed driver left anywhere; the old fleet's .run
  choice was forced, not a habit. Managed the vaultwarden way now:
  pinned in group_vars, marker-gated in node_glue, --dkms registered,
  CT-side userspace installed --no-kernel-module from the same pin.
  (This re-cleans a trap: the leftover .run residue breaks apt's
  nvidia-installer-cleanup postinst with debconf exit 30 -- the
  uninstaller must run before ANY apt nvidia transaction.)
- **Audiobookshelf installs from the vendor's flat apt repo**
  (advplyr.github.io/audiobookshelf-ppa) -- GitHub release binaries
  no longer exist (checked: zero assets on the last 100 releases);
  the repo is their documented Debian path. Its config layout probe
  handles both old eras (/var/lib/audiobookshelf and /audiobookshelf).
- **Jellyfin's repo key moved**: jellyfin.gpg.key 404s now;
  jellyfin_team.gpg.key is the current name. The trixie suite
  exists (v12.4, live since 2026-11-23).
- **PVE kernel packages renamed**: proxmox-headers-<kernel>
  provides linux-headers-* -- the plain names show no candidates.
- **Extractor tarball naming fixed before first use**:
  multi-path probes (102, 133) overwrote their own tarballs;
  per-path slugs now. The lxc-confs copy never existed (the old
  confs lived in /etc/pve, lost with the old cluster) -- the
  devnode lines were rebuilt from standard LXC practice instead.
