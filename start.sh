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

# Service list in dependency order (edit as needed)
services_order=(
    postgres
    gitea
    n8n
    ollama
    freshrss
    jellyfin
    registry
    omnivore
    wireguard
    pihole
    nextcloud
    minecraft
    nginx
    watchtower
    openspeedtest
    searxng
    plex
)

# Start enabled services in dependency order
for service in "${services_order[@]}"; do
    # Compose the enable variable name (e.g., ENABLE_POSTGRES)
    enable_var="ENABLE_$(echo "$service" | tr '[:lower:]' '[:upper:]')"
    if [ "${!enable_var}" = "true" ]; then
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
