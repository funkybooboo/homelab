#!/bin/bash
# scripts/stage-pgdata.sh -- stage the root-owned tier-0 PGDATA
# extract into a nate-readable tarball for the postgres role
# (the role restores it exactly once; local/ is gitignored).
# Run ON DEBBIE with sudo, from the repo root:
#   sudo ./scripts/stage-pgdata.sh
set -euo pipefail
SRC="legacy-extraction/from-dump-108/var/lib/postgresql/17"
OUT="local/staging/pgdata-108.tar.gz"
[ -d "$SRC" ] || { echo "missing $SRC (extraction incomplete?)"; exit 1; }
mkdir -p local/staging
tar -czf "$OUT.tmp" -C "$(dirname "$SRC")" 17
mv "$OUT.tmp" "$OUT"
chown nate:nate "$OUT"
chmod 600 "$OUT"
echo "staged: $OUT ($(du -h "$OUT" | cut -f1)) -- the postgres role will restore it on next converge"
