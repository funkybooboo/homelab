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

`Collections` (the 17 auto-generated TMDB boxsets like "James Bond Collection",
"Star Wars Collection") was also removed at the user's request. This required
extra steps because Jellyfin re-creates the `root/default/Collections/`
folder on startup as long as any library config references it:
1. DELETE `/Library/VirtualFolders?name=Collections` (returned 204 both times; a
   single delete was insufficient -- a second attempt was needed).
2. Remove the on-disk `root/default/Collections/` AND the appdata
   `data/collections/` directory before restart (CT root can write its own
   rootfs ext4 -- no NFS squash applies there).
3. While Jellyfin was stopped (for the API-key revoke), delete the orphaned
   BoxSet BaseItems rows: `DELETE FROM BaseItems WHERE Type LIKE '%BoxSet%';`
   and the lingering Collections CollectionFolder row.
4. Remove the empty `root/default/Collections/` stub that Jellyfin recreates
   on each startup (harmless, not registered, but cleaned up).

Verified: user views = Movies + Shows only; virtual folders = Movies + Shows
only; BoxSet count = 0; CollectionFolder rows = Movies + Shows only. DB
backups kept in CT 102: `jellyfin.db.pre-libcleanup-20260731-221435` and
`jellyfin.db.pre-collections-20260731-222214`.

NOTE: Jellyfin will recreate an empty `root/default/Collections/` directory on
startup as long as the system config option `EnableGroupingMoviesIntoCollections`
is enabled (currently false in system.xml). The empty dir is NOT registered as a
library, so it does not reappear as a user view. To prevent even the empty-dir
recreation, the Movies library option `AutomaticallyAddToCollection: true` and
`EnableAutomaticSeriesGrouping: false` could be reviewed.

## Still TODO (separate fixes)

1. **Drop stale BaseItems rows for the 103 deleted NAS files** (the stubs +
   AppleDouble junk removed above). Run Jellyfin Dashboard -> Scheduled Tasks
   -> **Scan Media Library** + **Clean Library**. Could also drive via API
   with a freshly-minted key as above.

2. **Duplicate `.m4v` vs `.m4v.mp4` pairs -- DONE 2026-07-31.** ffprobe'd
   all 202 real movie files (read-only) -> identity table
   [identity-table-20260731.tsv](identity-table-20260731.tsv). Built a
   keep/drop plan ([dup-cleanup-plan-20260731.tsv](dup-cleanup-plan-20260731.tsv)):
   21 dup groups, 22 files to DROP (~20.9 GB freed). Of 20 same-name pairs,
   17 were byte-identical (md5-verified) -- zero quality loss; only 3 were
   real quality decisions (BATMAN_BEGINS keep .m4v 1080p; Monster_House keep
   .mp4 higher bitrate; TOMB_RAIDER keep .m4v.mp4, drop both alternatives);
   plus AVATAR keep full vs AVATAR_small drop. User picked quality-first.
   EXECUTED: the 22 DROP files were `mv`'d to a TrueNAS quarantine folder
   `/mnt/volume1/media/.jellyfin-quarantine-20260731/` (NOT `rm`'d) --
   reversible until ZFS snapshot retention expires. Manifest:
   [quarantine-20260731.txt](quarantine-20260731.txt). Verified: all 22 gone
   from `movies/`, all 21 KEEP counterparts still present. Recovery also via
   `volume1/media/movies@auto-2026-07-31_00-00` ZFS snapshot.

3. **Wrong-title metadata -- DONE 2026-07-31.** Renamed 156 of 180 real
   movie files on TrueNAS to `Title (Year).ext` per the review-approved map
   ([rename-map-20260731.tsv](rename-map-20260731.tsv)). No TMDB/external API
   -- built from filename + ffprobe runtime + user-supplied corrections.
   Execution log: [rename-execution-log-20260731.txt](rename-execution-log-20260731.txt).
   Recovery: TrueNAS ZFS snapshot `volume1/media/movies@auto-2026-07-31_00-00`
   (pre-rename) + the rename log itself (each line: `old -> new`).
   The 23 Looney Tunes / Golden Collection multi-episode discs -- moved
   out of /movies/ into a TV-show tree on 2026-07-31 (see "Looney Tunes
   restructure" section below). The 2 still-uncertain rows (JUSTICE_LEAGUE
   and WORK_AND_THE_GLORY_3 subtitles) were renamed with best-guess names
   + flagged -- user can correct via Jellyfin "Identify" UI.

   Jellyfin library scan POST-RENAME: triggered, running. Re-scraping all
   156 renamed movies (TMDB posters + chapter images). SLOW for two real
   reasons: (a) the on-disk Movies options.xml now has SaveLocalMetadata=false
   + SaveTrickplayWithMedia=false but the LIVE Jellyfin LibraryOptions still
   report MetadataSavers=['Nfo'] + SaveSubtitlesWithMedia=true -- the DB is
   the source of truth and my POST to /Library/VirtualFolders/LibraryOptions
   returns HTTP 400 on JF 10.11.11. User will flip the toggles via web UI:
   Dashboard -> Libraries -> Movies (and Shows) -> Library settings ->
   uncheck 'Save artwork into media folders', 'Save metadata into media
   folders', 'Save trickplay images next to media files', and uncheck NFO
   under Metadata savers -> Save. (UI path sticks reliably.) Metadata
   still saved correctly meanwhile -- JF falls back to
   /var/lib/jellyfin/metadata/library/. (b) /volume1/media/movies dir is
   root:root 0755 so jellyfin (auth as nobody over sec=sys NFS) cannot
   create ANY new file in it -- not a root-squash thing; an ownership+
   mode thing. Sidecars next to the 23 Looney Tunes discs were written
   2026-07-12 by an OLD jellyfin run as GID=netdata; current JF can't
   refresh them. The UI-toggle fix is the durable answer.

## Looney Tunes restructure -> TV show (2026-07-31, IN PROGRESS)

Moving the 23 cartoon compilation discs from /movies/ to
/tvshows/Looney Tunes Golden Collection/ in 6 seasons (one per physical
collection):

  Season 01 - Golden Collection Vol 3   (2 discs: D2, D4)
  Season 02 - Looney Tunes Golden V4   (4 discs: D1-D4)
  Season 03 - Looney Tunes Golden V5   (4 discs: D1-D4)
  Season 04 - Looney Tunes Golden (V1) (8 discs: DISC 1-4, 6-8 + DISK 5)
  Season 05 - Looney Tunes Gold Vol 6   (4 discs: DISC1-4)
  Season 06 - Porky and the Pigs        (1 disc: NA_D3)

Each disc stays as one "episode" file (cartoons stitched as ripped; no
re-encode). Sidecar .nfo + -poster.jpg moved along with each .m4v.
Reversible via the move log + ZFS snapshot. Shows library auto-picks up
the new tree on next scan. mv is slow (cross-dataset ZFS = copy+unlink,
each 2-3GB file takes minutes) AND competes with the in-flight Movies
scan for disk (load avg ~10). Running in background; ~25min to finish.
Move log on TrueNAS: /mnt/volume1/media/.jellyfin-looneytunes-move-log-20260731.txt
Script: services/jellyfin/looneytunes-move.sh

## NFS media dir info (TrueNAS)

Movies:  `/mnt/volume1/media/movies/`  (exported as `192.168.8.100:/mnt/volume1/media/movies`)
TV:     `/mnt/volume1/media/tvshows/`
Music:  `/mnt/volume1/media/music/`
Audiobooks: `/mnt/volume1/media/audiobooks/`
Books:  `/mnt/volume1/media/books/`