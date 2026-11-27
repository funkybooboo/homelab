#!/usr/bin/env bash
# roll-pins.sh -- roll the repo's pinned release versions forward
#
# What: for every role that ships a pinned static release, resolve the
#       upstream latest via its release API and rewrite the pin in the
#       role's defaults/main.yml when upstream moved. The roles' version
#       gates do the rest: the next `make converge` swaps the installed
#       artifact to match the new pin (marker-gated, never blind).
#
# Runs: inside `make update` (before the tier pass) and standalone
#       (`bash scripts/roll-pins.sh`). Non-fatal per pin: an unreachable
#       API keeps the current pin; nothing is edited blind.
#
# Pins tracked here (repo pin -> upstream latest):
#   forgejo_version            codeberg  forgejo/forgejo        v17.x
#   gitea_mirror_version       github    RayLabsHQ/gitea-mirror v3.x
#   gitea_mirror_bun_version   github    oven-sh/bun            bun-v1.x
#   navidrome_version          github    navidrome/navidrome    v0.6x
#   vaultwarden_version        github    dani-garcia/vaultwarden 1.x
#
# The one deliberate exception: nvidia_run_version (group_vars/all.yml)
# is pinned on purpose -- Pascal's terminal 580 branch, locked to the
# host driver; see docs/quirks.md. Never auto-bumped.
#
# After a bump: review the git diff, commit, `make converge`.

set -euo pipefail
cd "$(dirname "$0")/.."

ROLLED=0

# _resolve <api_url>  -> prints the latest tag_name (empty on failure)
_resolve() {
  local url="$1" json
  json="$(mktemp)"
  if command -v gh >/dev/null 2>&1; then
    # gh works for github; codeberg ignores the token harmlessly.
    gh api "${url#https://api.github.com/}" >"$json" 2>/dev/null \
      || curl -fsSL --max-time 15 "$url" -o "$json" 2>/dev/null || true
  else
    curl -fsSL --max-time 15 "$url" -o "$json" 2>/dev/null || true
  fi
  # Comma-split first: payloads arrive pretty-printed or compact, and a
  # version tag never contains a comma. Fails closed on surprises.
  tr ',' '\n' <"$json" | sed -n 's/.*"tag_name":"\([^"]*\)".*/\1/p' | head -1
  rm -f "$json"
}

# _roll <file> <key> <api_url> <transform>
#   transform: how the upstream tag becomes the pin value (e.g. strip v).
#   The CURRENT pin is read from the file at run time (never hardcoded),
#   so re-runs compare against reality, not this script's birth date.
_roll() {
  local file="$1" key="$2" api="$3" tf="$4" tag latest cur
  cur="$(grep -E "^${key}:" "$file" | head -1 | sed -n 's/.*"\([^"]*\)".*/\1/p')"
  if [[ -z "$cur" ]]; then
    echo "  [!] $key: pin not found in $file -- skipping"
    return 0
  fi
  tag="$(_resolve "$api")"
  case "$tf" in
    keep)   latest="$tag" ;;
    stripv) latest="${tag#v}" ;;
    stripbunv) latest="${tag#bun-v}" ;;
  esac
  if [[ -z "$latest" ]]; then
    echo "  [!] $key: latest unresolvable (offline/rate-limit?) -- keeping $cur"
    return 0
  fi
  if [[ "$latest" == "$cur" ]]; then
    echo "  [-] $key $cur (up to date)"
    return 0
  fi
  sed -i "s|^${key}: \"${cur}\"|${key}: \"${latest}\"|" "$file"
  echo "  [+] $key $cur -> $latest"
  ROLLED=$((ROLLED + 1))
}

echo "rolling pinned releases to upstream latest:"

_roll ansible/playbooks/roles/forgejo/defaults/main.yml forgejo_version \
  "https://codeberg.org/api/v1/repos/forgejo/forgejo/releases?limit=1" stripv

_roll ansible/playbooks/roles/gitea_mirror/defaults/main.yml gitea_mirror_version \
  "https://api.github.com/repos/RayLabsHQ/gitea-mirror/releases/latest" keep

_roll ansible/playbooks/roles/gitea_mirror/defaults/main.yml gitea_mirror_bun_version \
  "https://api.github.com/repos/oven-sh/bun/releases/latest" stripbunv

_roll ansible/playbooks/roles/navidrome/defaults/main.yml navidrome_version \
  "https://api.github.com/repos/navidrome/navidrome/releases/latest" stripv

_roll ansible/playbooks/roles/vaultwarden/defaults/main.yml vaultwarden_version \
  "https://api.github.com/repos/dani-garcia/vaultwarden/releases/latest" keep

# The house yaml trap: colon-carrying rewrites are checked before anything
# else touches these files.
for f in forgejo gitea_mirror navidrome vaultwarden; do
  /usr/bin/python3 -c "import yaml,sys; yaml.safe_load(open('ansible/playbooks/roles/$f/defaults/main.yml'))" \
    || { echo "  [!] $f defaults failed yaml parse -- REVERT THE EDIT"; exit 1; }
done

if (( ROLLED > 0 )); then
  echo "pins rolled: $ROLLED. Review the git diff, commit, then make converge."
else
  echo "pins current; nothing to do."
fi
