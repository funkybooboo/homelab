#!/bin/bash
set -u
M="/mnt/volume1/media/movies"
S="/mnt/volume1/media/tvshows/Looney Tunes Golden Collection"
LOG="/mnt/volume1/media/.jellyfin-looneytunes-move-log-20260731.txt"
: > "$LOG"

mkdir -p "$S"

run_season() {
  local season="$1"; shift
  mkdir -p "$S/$season"
  for base in "$@"; do
    for src in "$M/$base.m4v" "$M/$base.nfo" "$M/$base"-*; do
      [ -e "$src" ] || continue
      dst="$S/$season/$(basename "$src")"
      if mv -- "$src" "$dst" 2>/tmp/mverr; then
        echo "OK $src -> $dst" >> "$LOG"
      else
        echo "FAIL $src : $(cat /tmp/mverr)" >> "$LOG"
      fi
    done
  done
}

run_season "Season 01 - Golden Collection Vol 3" GOLDEN_COLLECTION_VOLUME_3_D2 GOLDEN_COLLECTION_VOLUME_3_D4
run_season "Season 02 - Looney Tunes Golden V4"   LOONEY_TUNES_GOLDEN_V4_D1 LOONEY_TUNES_GOLDEN_V4_D2 LOONEY_TUNES_GOLDEN_V4_D3 LOONEY_TUNES_GOLDEN_V4_D4
run_season "Season 03 - Looney Tunes Golden V5"   LOONEY_TUNES_GOLDEN_V5_D1 LOONEY_TUNES_GOLDEN_V5_D2 LOONEY_TUNES_GOLDEN_V5_D3 LOONEY_TUNES_GOLDEN_V5_D4
run_season "Season 04 - Looney Tunes Golden"      LOONEY_TUNES_GOLDEN_DISC_1 LOONEY_TUNES_GOLDEN_DISC_2 LOONEY_TUNES_GOLDEN_DISC_3 LOONEY_TUNES_GOLDEN_DISC_4 LOONEY_TUNES_GOLDEN_DISC_6 LOONEY_TUNES_GOLDEN_DISC_7 LOONEY_TUNES_GOLDEN_DISC_8 LOONEY_TUNES_GOLDEN_DISK_5
run_season "Season 05 - Looney Tunes Gold Vol 6"  LOONEYTUNES_GOLD_VOLUME6_DISC1 LOONEYTUNES_GOLD_VOLUME6_DISC2 LOONEYTUNES_GOLD_VOLUME6_DISC3 LOONEYTUNES_GOLD_VOLUME6_DISC4
run_season "Season 06 - Porky and the Pigs"       Porky_and_the_Pigs_NA_D3

echo "=== done ==="
ok=$(grep -c "^OK" "$LOG")
fail=$(grep -c "^FAIL" "$LOG")
echo "moved=$ok failed=$fail"