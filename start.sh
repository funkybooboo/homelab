#!/bin/bash

# Homelab Services Startup Script
# Starts all enabled services based on .env configuration

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Load configuration
if [ ! -f .env ]; then
    echo "Error: .env file not found"
    echo "Copy .env.example to .env and configure your services"
    exit 1
fi

source .env

# Color output
GREEN='\033[0;32m'
NC='\033[0m' # No Color

echo "Starting services..."
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

# Start enabled services
for service in "${!services[@]}"; do
    if [ "${services[$service]}" = "true" ]; then
        if [ -f "services/$service/start.sh" ]; then
            echo -e "${GREEN}[+] $service${NC}"
            bash "services/$service/start.sh" >/dev/null 2>&1
        fi
    fi
done

echo ""
echo "Done"
echo ""
echo "View logs: ./logs.sh <service>"
