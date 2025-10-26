#!/bin/bash

# Homelab Services Stop Script
# Stops all enabled services based on .env configuration

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Load configuration
if [ ! -f .env ]; then
    echo "Error: .env file not found"
    exit 1
fi

source .env

# Color output
RED='\033[0;31m'
NC='\033[0m' # No Color

echo "Stopping services..."
echo ""

# Service mapping
declare -A services=(
    ["postgres"]="$ENABLE_POSTGRES"
    ["n8n"]="$ENABLE_N8N"
    ["gitea"]="$ENABLE_GITEA"
    ["ollama"]="$ENABLE_OLLAMA"
    ["freshrss"]="$ENABLE_FRESHRSS"
    ["jellyfin"]="$ENABLE_JELLYFIN"
    ["registry"]="$ENABLE_REGISTRY"
    ["omnivore"]="$ENABLE_OMNIVORE"
    ["wireguard"]="$ENABLE_WIREGUARD"
    ["pihole"]="$ENABLE_PIHOLE"
    ["nextcloud"]="$ENABLE_NEXTCLOUD"
    ["minecraft"]="$ENABLE_MINECRAFT"
    ["nginx"]="$ENABLE_NGINX"
    ["watchtower"]="$ENABLE_WATCHTOWER"
    ["openspeedtest"]="$ENABLE_OPENSPEEDTEST"
    ["searxng"]="$ENABLE_SEARXNG"
    ["plex"]="$ENABLE_PLEX"
)

# Stop enabled services (in reverse order)
for service in watchtower nginx plex minecraft nextcloud pihole wireguard omnivore registry jellyfin freshrss ollama searxng openspeedtest gitea n8n postgres; do
    if [ "${services[$service]}" = "true" ]; then
        if [ -f "services/$service/stop.sh" ]; then
            echo -e "${RED}[-] $service${NC}"
            bash "services/$service/stop.sh" >/dev/null 2>&1
        fi
    fi
done

echo ""
echo "Done"
