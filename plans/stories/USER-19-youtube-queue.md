# USER-19: YouTube download queue for jellyfin

As the operator, I want to paste a YouTube URL into a queue and
have the video land in my jellyfin library so my favorite videos
are part of my media fleet -- watchable on the TV, offline,
permanent.

**Status**: planned (idea recorded 2026-11-25)
**Arc**: v3 (the media fleet's acquisition leg -- pairs with
USER-2)

## Use case shape (drives the pick)

"Add my favorite videos" -- hand-picked, one at a time, into
jellyfin. NOT (yet) channel subscriptions, mass archival, or a
separate player. The queue is a UI; jellyfin stays the player.

## The honest options

1. **metube -- the exact fit for the stated use** -- a minimal
   web UI: paste URL, it downloads via yt-dlp into a folder
   (jellyfin-scanned). One tiny CT, zero opinions, queue-shaped.
   Best first build.
2. **Tube Archivist -- if it grows into archiving** --
   subscriptions, channel sync, its own index/player, sponsor
   block. Heavier (multi-container) and its own player duplicates
   jellyfin's role. The right upgrade IF the use case becomes
   "mirror my channels", not "save this video I like".
3. **cronmaster + yt-dlp (OPS-24)** -- schedule-shaped, not
   queue-shaped: fits "sync this playlist weekly", can't do "grab
   this video right now" from a phone.

Recommendation recorded: start with metube; the story re-opens if
the ambition grows to subscriptions (Tube Archivist) or scheduled
sync (cronmaster leg).

## Notes

- The favorite-videos folder joins the media share on truenas
  (NFS to thermaltake); jellyfin picks it up as a library.
- Best quality is a rabbit hole (yt-dlp defaults are fine; the
  story does not over-engineer).
- Fetched content is re-fetchable in principle -- but favorite
  videos DO vanish from YouTube; treat the library as tier-0 once
  a video lands (it rides the media backup).

## Acceptance criteria

- [ ] Paste URL on phone -> video appears in jellyfin within
      minutes, playable on the TV
- [ ] The downloads folder is part of the media share + backup
- [ ] The queue UI is served via the tailnet (operator-only)
