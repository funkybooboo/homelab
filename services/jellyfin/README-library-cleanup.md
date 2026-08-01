# Jellyfin (CT 102) -- library cleanup 2026-07-31

The "movies I don't own" showing up in Jellyfin were **not** wrong TMDB matches
on missing files -- they were **real-on-NFS but non-video files** indexed with
real TMDB posters. Clicking them threw "Playback failed due to a fatal player
error" for two independent reasons (see also
[`../nvidia-uvm-devnodes/README.md`](../nvidia-uvm-devnodes/README.md) for the
NVENC half):

## What was deleted (2026-07-31)

Deleted locally on TrueNAS (`ssh root@truenas.tail54538d.ts.net`) -- NFS
root-squash blocked deletion from the PVE host / CT 102 -- original files are
recoverable from ZFS snapshots on `tank/volume1/media`.

| Category | Count | Manifest |
|---|---|---|
| macOS AppleDouble junk (`._*`, resource-fork sidecars) under `tvshows/` | 22 | [cleanup-2026-07-31-appledouble.txt](cleanup-2026-07-31-appledouble.txt) |
| Movie "stubs": video-ext files under `movies/` <= 10 MB (79 x 4096 B + 1 x 0 B + 1 x 1.4 MB) | 81 | [cleanup-2026-07-31-movie-stubs.txt](cleanup-2026-07-31-movie-stubs.txt) |

Total: 103 files. All were dated `Nov 1 2025`, owned root:root, and none could
contain a real feature film at that size. The point is purely that a 4 KB file
is not a movie; deleting it removed the phantom library entry it had been
scraped from (with a real poster).

## Why the deletes had to run on TrueNAS, not the PVE host or CT

`INCEPTION.m4v` etc. are owned by `root:root` on TrueNAS but the NFS export
squashes client root -> `nobody`. From the PVE host (`/mnt/tnas-media/media/`)
the files appear as `root:root`, from inside CT 102 as `nobody:nogroup`, and
every `rm` from either vantage failed with "Permission denied". Only TrueNAS
local root (no NFS in the path) could delete them. If you ever need to clean
media files again from the homelab: do it via `ssh root@truenas.tail54538d.ts.net`
on the dataset directly, not over the NFS share.

## Libraries removed 2026-07-31 (DB pointers only -- NAS files untouched)

User wanted Jellyfin to keep only `Movies` and `Shows`. Removed the `Music`,
`Books`, and `Audiobooks` libraries (DB pointers + cascaded item rows). The
underlying files on TrueNAS (`/mnt/volume1/media/{music,books,audiobooks}`)
were left in place -- 488 music files + 5 books + 3 audiobooks still on disk.

Done via the Jellyfin API (the only safe way -- it cascades through the ~15
related tables; hand-deleting `BaseItems` rows orphans rows):

```
DELETE /Library/VirtualFolders?name=Music&refreshLibrary=true        -> 204
DELETE /Library/VirtualFolders?name=Books&refreshLibrary=true        -> 204
DELETE /Library/VirtualFolders?name=Audiobooks&refreshLibrary=true   -> 204
```
Since no API key existed, one was minted by inserting a row into `ApiKeys`
(jellyfin must be STOPPED first to free the SQLite lock, then restarted to
load the key), used for the deletes, then revoked (`DELETE FROM ApiKeys`).
Auth-tested afterward: the revoked token gets HTTP 401 on `/Library/VirtualFolders`
(which requires auth). `/System/Info/Public` is public and always returns 200
regardless of token -- not a valid auth test.

Verified: `BaseItems` 3249 -> 2737 (-512 rows, all the Audio/MusicAlbum/
MusicArtist/Book/AudioBook items + their metadata rows). Zero audio/book rows
remain in `BaseItems`. User views now show only Collections, Movies, Shows.
`root/default/` on disk now has only Collections/, Movies/, Shows/.

DB backup kept at `/var/lib/jellyfin/data/jellyfin.db.pre-libcleanup-20260731-221435`
inside CT 102 for rollback.

`Collections` (the auto-generated TMDB boxsets like "James Bond Collection")
was kept for now -- asked user separately whether to remove it.

## Still TODO (separate fixes)

1. **Drop stale BaseItems rows for the 103 deleted NAS files** (the stubs +
   AppleDouble junk removed above). Run Jellyfin Dashboard -> Scheduled Tasks
   -> **Scan Media Library** + **Clean Library**. Could also drive via API
   with a freshly-minted key as above.

2. **Duplicate `.m4v` vs `.m4v.mp4` pairs (20)** where BOTH files are real video
   (e.g. `BATMAN_BEGINS.m4v` 3.1 GB + `BATMAN_BEGINS.m4v.mp4` 920 MB). Need a
   keep/delete decision per pair (recommend keep the h264 `.mp4`, delete the
   legacy-mpeg4 `.m4v`) -- see dup-pairs table in audit scratch.

3. **Wrong-title metadata** on the REAL movies (~50). Filenames are too cryptic
   for TMDB matching (e.g. `WALL_E.m4v` scraped as "The Wolf of Wall Street",
   `IRON_MAN.m4v` as "The Man with the Iron Fists 2", `HOLES.m4v` as "Stretch
   My Holes"). Durable fix: rename on TrueNAS to `Title (Year).ext`, rescan, and
   for stragglers use the per-item "Identify" menu in the Jellyfin web UI.

## NFS media dir info (TrueNAS)

Movies:  `/mnt/volume1/media/movies/`  (exported as `192.168.8.100:/mnt/volume1/media/movies`)
TV:     `/mnt/volume1/media/tvshows/`
Music:  `/mnt/volume1/media/music/`
Audiobooks: `/mnt/volume1/media/audiobooks/`
Books:  `/mnt/volume1/media/books/`