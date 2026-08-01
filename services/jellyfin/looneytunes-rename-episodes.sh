#!/bin/bash
set -u
S="/mnt/volume1/media/tvshows/Looney Tunes Golden Collection"
SHOW="Looney Tunes Golden Collection"
LOG="/mnt/volume1/media/.jellyfin-looneytunes-episode-rename-log-20260731.txt"
: > "$LOG"

# For each season dir, order the .m4v files by their natural sort, rename as S0X E0Y
for d in "$S"/Season\ *; do
  [ -d "$d" ] || continue
  season_num=$(basename "$d" | sed -n 's/^Season \([0-9]\+\) -.*/\1/p')
  [ -z "$season_num" ] && continue
  ep=0
  # list .m4v files with sort, capture full path
  while IFS= read -r -d '' f; do
    ep=$((ep+1))
    ep_pad=$(printf "%02d" "$ep")
    sn_pad=$(printf "%02d" "$season_num")
    base=$(basename "$f")
    # strip ".m4v" suffix for the descriptive part
    desc="${base%.m4v}"
    dst="$d/${SHOW} S${sn_pad}E${ep_pad} - ${desc}.m4v"
    if [ "$f" = "$dst" ] || [ -e "$dst" ]; then
      echo "SKIP already-renamed: $base -> $(basename "$dst")" >> "$LOG"
      continue
    fi
    if mv -- "$f" "$dst"; then
      echo "OK $f -> $dst" >> "$LOG"
    else
      echo "FAIL $f" >> "$LOG"
    fi
  done < <(find "$d" -maxdepth 1 -name "*.m4v" -print0 | sort -z)
done
echo "done. ok=$(grep -c '^OK' "$LOG") fail=$(grep -c '^FAIL' "$LOG") skip=$(grep -c '^SKIP' "$LOG")"