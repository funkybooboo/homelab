#!/bin/bash

# Homelab Initial Setup Script
# Creates .env files from examples and installs Docker if needed

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "Homelab Setup"
echo "============="
echo ""

# Check for Docker
if ! command -v docker &>/dev/null; then
    echo "Docker not found"
    echo ""
    read -p "Install Docker? (y/n): " install_docker

    if [ "$install_docker" = "y" ]; then
        echo "Installing Docker..."

        # Update packages
        sudo apt-get update

        # Install prerequisites
        sudo apt-get install -y ca-certificates curl gnupg

        # Add Docker GPG key
        sudo install -m 0755 -d /etc/apt/keyrings
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
        sudo chmod a+r /etc/apt/keyrings/docker.gpg

        # Add Docker repository
        echo \
            "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
          $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
            | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null

        # Install Docker
        sudo apt-get update
        sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

        # Add user to docker group
        sudo usermod -aG docker $USER

        echo ""
        echo "[+] Docker installed"
        echo ""
        echo "IMPORTANT: Log out and back in for docker group to take effect"
        echo "Then run ./setup.sh again"
        exit 0
    else
        echo "Docker is required. Install it first:"
        echo "  https://docs.docker.com/engine/install/"
        exit 1
    fi
else
    echo "[+] Docker found"
fi

# Check for Docker Compose
if ! docker compose version &>/dev/null; then
    echo "[-] Docker Compose not found"
    echo "Install Docker Compose plugin:"
    echo "  sudo apt-get install docker-compose-plugin"
    exit 1
else
    echo "[+] Docker Compose found"
fi

echo ""

# Create root .env
if [ ! -f .env ]; then
    cp .env.example .env
    echo "[+] Created .env"
else
    echo "[=] .env exists"
fi

# Create service .env files
created=0
for service_dir in services/*/; do
    service=$(basename "$service_dir")
    if [ -f "services/$service/.env.example" ] && [ ! -f "services/$service/.env" ]; then
        cp "services/$service/.env.example" "services/$service/.env"
        created=$((created + 1))
    fi
done

if [ $created -gt 0 ]; then
    echo "[+] Created $created service config files"
else
    echo "[=] All service configs exist"
fi

echo ""
echo "Next:"
echo "  1. nano .env              # Enable services"
echo "  2. nano services/*/.env   # Configure services"
echo "  3. ./start.sh             # Start everything"
echo ""
echo "See README.md for service-specific setup"
