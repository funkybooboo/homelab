#!/usr/bin/env bash
# secrets-restore.sh -- materialize every local/*.env from the
# Proton Pass vault (OPS-26).
#
# New-machine story: dotfiles migrate.sh + setup.sh (step 1 is
# `pass-cli login`), clone this repo, then run this script. Every
# local/*.env.example in the repo is an inject template carrying
# pass:// references; this loops `pass-cli inject` over them and
# writes the real env files (mode 600, the inject default).
#
# Rotation note: when a credential is re-minted (e.g. the tailscale
# preauth key via scripts/mint-tailscale-key.sh), update BOTH the
# live local/*.env AND the vault item -- templates are references,
# not values.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

pass-cli info >/dev/null 2>&1 || {
    echo "not logged in -- run 'pass-cli login' first (browser auth)"
    exit 1
}

count=0
for ex in local/*.env.example; do
    base=$(basename "$ex" .env.example)
    pass-cli inject -i "$ex" -o "local/${base}.env" -f
    count=$((count + 1))
done

echo "restored ${count} env files to local/ (mode 600)"
echo "next: make verify   # read-only drift check against the fleet"
