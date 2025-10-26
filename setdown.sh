#!/bin/bash

# Homelab Teardown Script
# Stops all services, removes volumes, and removes configuration files

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Colors
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "Homelab Teardown"
echo "================"
echo ""
echo "WARNING: This will permanently delete:"
echo "  - All containers"
echo "  - All volumes (databases, files, etc)"
echo "  - All .env configuration files"
echo ""
read -p "Type 'DELETE' to continue: " confirm

if [ "$confirm" != "DELETE" ]; then
    echo "Cancelled"
    exit 0
fi

echo ""
echo "Removing services..."

# Stop and remove all services with volumes
for service_dir in services/*/; do
    service=$(basename "$service_dir")
    if [ -f "services/$service/docker-compose.yml" ]; then
        cd "services/$service"
        docker compose down -v 2>/dev/null || true
        cd "$SCRIPT_DIR"
    fi
done

echo "Removing configs..."

# Remove all .env files
rm -f .env
rm -f services/*/.env
rm -f services/registry/auth/htpasswd

echo "Cleaning Docker..."
docker system prune -f -a

echo ""
echo "Done. Everything removed."
echo "To start over: ./setup.sh"
