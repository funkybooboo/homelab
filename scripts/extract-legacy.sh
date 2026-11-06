#!/usr/bin/env bash
# extract-legacy.sh -- inventory + pull the old fleet's per-CT data off
# the truenas pve-shared NFS export, READ-ONLY.
#
# OPS-1 artifact. docs/legacy/data-to-extract.md is the human table;
# this is the executable version. Run on debbie AFTER the truenas
# network move (OPS-4) so truenas answers at 192.168.1.10.
#
# Usage (needs root for mounts; run it yourself, agent sudo is denied):
#   ./scripts/extract-legacy.sh                     # inventory report only
#   ./scripts/extract-legacy.sh --copy 0            # + copy tiers <= 0
#   ./scripts/extract-legacy.sh --copy 1            # + copy tiers <= 1
#   ./scripts/extract-legacy.sh --copy 2            # + copy tiers <= 2
#   ./scripts/extract-legacy.sh --copy-from-dump 128  # local-lvm CT from vzdump
#
# Safety: every mount is read-only (NFS ro + loop,ro). Nothing ever
# writes to truenas. Copies land in ./legacy-extraction/ with a
# sha256 manifest. Tier-0 data counts as "landed" only when the copy
# exists OUTSIDE the truenas pool (rule 10: extract before wipe).
#
# Env overrides: TRUENAS (default 192.168.1.10), OUT (default
# ./legacy-extraction), TIER_MAX implicit from --copy.

set -euo pipefail

TRUENAS="${TRUENAS:-192.168.1.10}"
SHARED_EXPORT="/mnt/volume1/pve/shared"
BACKUPS_EXPORT="/mnt/volume1/pve/backups"
BASE="/mnt/legacy"
SHARED_MNT="$BASE/shared"
BACKUPS_MNT="$BASE/backups"
CT_MNT_PREFIX="$BASE/ct"
OUT="$(pwd)/legacy-extraction"

COPY_TIER=-1          # -1 = inventory only
DUMP_CTID=""

# Probe table: "ctid:tier:alternates(space-sep):tag"
# Tiers per docs/legacy/data-to-extract.md.
PROBES=(
  "109:0:/var/lib/vaultwarden:vaultwarden-data"
  "108:0:/var/lib/postgresql:pgdata"
  "106:0:/root/.n8n /var/lib/n8n:n8n-data"
  "102:1:/etc/jellyfin /var/lib/jellyfin:jellyfin-config-meta"
  "107:1:/var/lib/forgejo:forgejo-data"
  "132:1:/var/lib/navidrome:navidrome-data"
  "133:1:/var/lib/audiobookshelf /audiobookshelf:audiobookshelf-data"
  "131:1:/var/lib/syncstorage-rs /var/lib/syncstorage:syncstorage-data"
  "104:1:/opt/freshrss/data:freshrss-data"
  "112:1:/opt/linkwarden:linkwarden-app"
  "105:2:/var/lib/forgejo:forgejo-mirror-data"
  "113:2:/var/lib/opengist:opengist-data"
  "118:2:/root:jupyter-root-home"
  "123:2:/var/lib/grafana:grafana-data"
  "125:2:/var/lib/bichon:bichon-archive"
  "126:2:/var/lib/protonmail/bridge:protonmail-bridge"
  "127:2:/opt/cronmaster:cronmaster-app"
  "103:2:/opt/speedtest-tracker:speedtest-app"
  "134:2:/opt/omnivore:omnivore-app"
)

MOUNTED=()
cleanup() {
  local m
  for m in "${MOUNTED[@]:-}"; do
    [ -n "$m" ] && umount "$m" 2>/dev/null || true
  done
  MOUNTED=()
}
trap cleanup EXIT

die() { echo "ERROR: $*" >&2; exit 1; }

# --- preflight ---------------------------------------------------------

if [ "$(id -u)" -ne 0 ]; then
  die "needs root (mounts) -- run with sudo yourself"
fi

while [ $# -gt 0 ]; do
  case "$1" in
    --copy) shift; COPY_TIER="${1:?--copy needs a tier}"; shift ;;
    --copy-from-dump) shift; DUMP_CTID="${1:?--copy-from-dump needs a ctid}"; shift ;;
    *) die "unknown arg: $1" ;;
  esac
done

mkdir -p "$OUT"
MANIFEST="$OUT/manifest.txt"
REPORT="$OUT/inventory.txt"
: > "$MANIFEST"
: > "$REPORT"

echo "== extract-legacy: truenas=$TRUENAS out=$OUT tier_max=$COPY_TIER =="
ping -c1 -W2 "$TRUENAS" >/dev/null 2>&1 || die "truenas ($TRUENAS) not reachable (run OPS-4 network move first, or TRUENAS=<ip>)"

mount_ro() { # mount_ro <what> <where>
  mkdir -p "$2"
  mount -t nfs -o ro "$1" "$2" 2>/dev/null || mount -t nfs -o ro,vers=3 "$1" "$2"
  MOUNTED+=("$2")
}

mount_ro "$TRUENAS:$SHARED_EXPORT" "$SHARED_MNT"
mount_ro "$TRUENAS:$BACKUPS_EXPORT" "$BACKUPS_MNT"

# --- inventory pass ----------------------------------------------------

echo "== pve-shared images (ALL -- settles what really existed at shutdown) ==" | tee -a "$REPORT"
ls -lh "$SHARED_MNT/images/" 2>/dev/null | tee -a "$REPORT" || echo "  (no images dir)" | tee -a "$REPORT"
echo "" | tee -a "$REPORT"

# CT configs: tiny, always copied (encode the old conventions exactly)
if [ -d "$SHARED_MNT/lxc" ]; then
  mkdir -p "$OUT/lxc-confs"
  cp -a "$SHARED_MNT/lxc/." "$OUT/lxc-confs/" 2>/dev/null || true
  echo "== copied CT configs -> $OUT/lxc-confs ==" | tee -a "$REPORT"
fi

ct_volume() { # echo the volume path for a ctid (raw image or subvol dir), or empty
  local id="$1" cand
  for cand in "$SHARED_MNT/images/vm-${id}-disk-0.raw" \
              "$SHARED_MNT/images/vm-${id}-disk-0"; do
    [ -e "$cand" ] && { echo "$cand"; return; }
  done
  echo ""
}

mount_ct() { # mount_ct <ctid> -> echo mountpoint or empty; mounts raw or uses subvol dir
  local id="$1" vol="$2" mnt="$CT_MNT_PREFIX-$id"
  mkdir -p "$mnt"
  if [ -d "$vol" ]; then
    # subvol: bind-mount read-only
    mount --bind "$vol" "$mnt" && mount -o remount,ro,bind "$mnt"
    MOUNTED+=("$mnt")
  else
    mount -o loop,ro "$vol" "$mnt" 2>/dev/null \
      || mount -o loop,ro,offset=1048576 "$vol" "$mnt" 2>/dev/null \
      || mount -o loop,ro,norecovery "$vol" "$mnt" \
      || { rmdir "$mnt" 2>/dev/null || true; return 1; }
    MOUNTED+=("$mnt")
  fi
}

fmt_bytes() { du -sh "$1" 2>/dev/null | cut -f1; }

copy_one() { # copy_one <ctid> <mnt> <path> <tag>
  local id="$1" mnt="$2" path="$3" tag="$4" tarball="$OUT/${id}-${tag}.tar.gz"
  tar -C "$mnt" -czf "$tarball" "$path" 2>/dev/null
  local sum
  sum="$(sha256sum "$tarball" | cut -d' ' -f1)"
  printf '%s\t%s\t%s\t%s\t%s\n' "$id" "$tag" "$path" "$(du -sh "$tarball" | cut -f1)" "$sum" >> "$MANIFEST"
  echo "    copied -> ${tarball} ($(du -sh "$tarball" | cut -f1))" | tee -a "$REPORT"
}

# --- main walk ---------------------------------------------------------

if [ -n "$DUMP_CTID" ]; then
  # local-lvm CT path: pull the newest vzdump of this CT wholesale
  dump="$(ls -1t "$BACKUPS_MNT/dump/vzdump-lxc-${DUMP_CTID}-"*.tar.* 2>/dev/null | head -1 || true)"
  [ -n "$dump" ] || die "no vzdump for CT $DUMP_CTID in pve-backups/dump/"
  dest="$OUT/from-dump-${DUMP_CTID}"
  mkdir -p "$dest"
  echo "== extracting $dump -> $dest ==" | tee -a "$REPORT"
  tar -I zstd -xf "$dump" -C "$dest" 2>/dev/null || tar -xf "$dump" -C "$dest"
  printf '%s\tfrom-dump\t%s\t%s\t%s\n' "$DUMP_CTID" "$dump" "$(du -sh "$dest" | cut -f1)" \
    "$(find "$dest" -type f -exec sha256sum {} + | sha256sum | cut -d' ' -f1)" >> "$MANIFEST"
  exit 0
fi

last_id=""
for entry in "${PROBES[@]}"; do
  IFS=: read -r id tier paths tag <<< "$entry"
  vol="$(ct_volume "$id")"
  if [ -z "$vol" ]; then
    echo "CT $id: NO volume in pve-shared (local-lvm? use --copy-from-dump $id)" | tee -a "$REPORT"
    continue
  fi
  if [ "$id" != "$last_id" ]; then
    [ -n "$last_id" ] && umount "$CT_MNT_PREFIX-$last_id" 2>/dev/null || true
    echo "" | tee -a "$REPORT"
    echo "CT $id ($vol):" | tee -a "$REPORT"
    if ! mount_ct "$id" "$vol"; then
      echo "  mount FAILED (fs dirty? try --copy-from-dump $id)" | tee -a "$REPORT"
      last_id="$id"; continue
    fi
    mnt="$CT_MNT_PREFIX-$id"
    os="$(sed -n 's/^PRETTY_NAME=//p' "$mnt/etc/os-release" 2>/dev/null | tr -d '\"' || echo '?')"
    echo "  os: ${os:-unknown}" | tee -a "$REPORT"
    last_id="$id"
  fi
  mnt="$CT_MNT_PREFIX-$id"
  found=""
  for path in $paths; do
    if [ -e "$mnt/$path" ]; then
      found="$path"
      echo "  [$tier] $path present ($(fmt_bytes "$mnt/$path"))" | tee -a "$REPORT"
      if [ "$tier" -le "$COPY_TIER" ]; then
        copy_one "$id" "$mnt" "$path" "$tag"
      fi
    fi
  done
  [ -z "$found" ] && echo "  [$tier] NONE of: $paths (locate manually if restoring)" | tee -a "$REPORT"
done

# --- closing -----------------------------------------------------------

umount "$CT_MNT_PREFIX-$last_id" 2>/dev/null || true
echo "" | tee -a "$REPORT"
echo "== done. report: $REPORT ; manifest: $MANIFEST ==" | tee -a "$REPORT"
if [ "$COPY_TIER" -ge 0 ]; then
  echo "Verify tier-0 landed: manifest lines for 109/108/106 with a copy OUTSIDE the truenas pool." | tee -a "$REPORT"
fi
