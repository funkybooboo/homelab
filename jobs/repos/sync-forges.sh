#!/usr/bin/env bash
set -euo pipefail

# =========================
# CONFIGURATION
# =========================
GITHUB_USER="funkybooboo"
CODEBERG_USER="funkybooboo"
FORGEJO_USER="funkybooboo"

TEA_CODEBERG="codeberg.org"
TEA_FORGEJO="192.168.8.243:3000"

FORGEJO_SSH_PORT="222"
FORGEJO_HOST="192.168.8.243"

WORKDIR="$HOME/projects/repos/_mirror"
mkdir -p "$WORKDIR"
cd "$WORKDIR"

# =========================
# FUNCTIONS
# =========================
log() {
  echo "[`date '+%Y-%m-%d %H:%M:%S'`] $*"
}

ensure_repo_exists() {
  local login="$1"
  local owner="$2"
  local repo="$3"

  log "Switching to login $login"
  tea login use "$login"

  if ! tea repo view "$owner/$repo" >/dev/null 2>&1; then
    log "Creating $owner/$repo on $login"
    # Try to create repo, skip if it fails (user can create manually)
    timeout 5 bash -c "yes '' | tea repo create --name '$repo'" 2>&1 || log "Skipping creation of $repo on $login (create manually if needed)"
  else
    log "Repo $owner/$repo already exists on $login"
  fi
}

sync_repo() {
  local repo="$1"

  log "=== Syncing $repo ==="

  if [ ! -d "$repo.git" ]; then
    log "Cloning GitHub repo $repo"
    gh repo clone "$GITHUB_USER/$repo" "$repo.git" -- --mirror
  fi

  cd "$repo.git"

  git remote set-url origin "git@github.com:$GITHUB_USER/$repo.git" || true

  git remote add codeberg "git@codeberg.org:$CODEBERG_USER/$repo.git" 2>/dev/null || true
  git remote add forgejo \
    "ssh://git@$FORGEJO_HOST:$FORGEJO_SSH_PORT/$FORGEJO_USER/$repo.git" \
    2>/dev/null || true

  log "Fetching all refs for $repo"
  git fetch --all --prune

  log "Pushing $repo to Codeberg"
  git push --mirror codeberg

  log "Pushing $repo to Forgejo"
  git push --mirror forgejo

  cd ..
  log "Finished syncing $repo"
}

# =========================
# MAIN
# =========================
log "Fetching repositories from GitHub…"

REPOS=$(gh repo list "$GITHUB_USER" --limit 1000 --json name -q '.[].name')

for repo in $REPOS; do
  ensure_repo_exists "$TEA_CODEBERG" "$CODEBERG_USER" "$repo"
  ensure_repo_exists "$TEA_FORGEJO" "$FORGEJO_USER" "$repo"
  sync_repo "$repo"
done

log "All repositories synchronized successfully."

