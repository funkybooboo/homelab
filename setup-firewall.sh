#!/bin/bash

# UFW Firewall Setup for Homelab Services
# Opens necessary ports based on enabled services

set -e

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root or with sudo"
    exit 1
fi

# Colors
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "Firewall Setup"
echo "=============="
echo ""

# Install UFW if not present
if ! command -v ufw &> /dev/null; then
    echo "Installing UFW..."
    apt-get update
    apt-get install -y ufw
fi

# Load configuration
if [ ! -f .env ]; then
    echo "Error: .env file not found"
    exit 1
fi

source .env

echo "Configuring firewall..."
echo ""

# Reset UFW (optional - comment out if you want to keep existing rules)
# ufw --force reset

# Default policies
ufw default deny incoming
ufw default allow outgoing

# Allow SSH (important!)
echo "[+] SSH (22)"
ufw allow 22/tcp comment 'SSH' > /dev/null 2>&1

# Service ports based on enabled services
declare -A ports=(
    # Format: "SERVICE:PORT/PROTOCOL:DESCRIPTION"
    ["n8n"]="5678/tcp:n8n"
    ["gitea"]="3000/tcp:Gitea Web,2222/tcp:Gitea SSH"
    ["ollama"]="11434/tcp:Ollama"
    ["freshrss"]="8080/tcp:FreshRSS"
    ["jellyfin"]="8096/tcp:Jellyfin Web,8920/tcp:Jellyfin HTTPS,7359/udp:Jellyfin Discovery,1900/udp:Jellyfin DLNA"
    ["registry"]="5000/tcp:Docker Registry,5001/tcp:Registry UI"
    ["omnivore"]="3002/tcp:Omnivore Web,4000/tcp:Omnivore API"
    ["wireguard"]="51820/udp:WireGuard VPN"
    ["pihole"]="53/tcp:Pi-hole DNS TCP,53/udp:Pi-hole DNS UDP,67/udp:Pi-hole DHCP,8053/tcp:Pi-hole Web"
    ["nextcloud"]="8888/tcp:Nextcloud"
    ["minecraft"]="25565/tcp:Minecraft,25575/tcp:Minecraft RCON"
    ["nginx"]="80/tcp:HTTP,443/tcp:HTTPS"
    ["openspeedtest"]="3001/tcp:OpenSpeedTest"
    ["searxng"]="8888/tcp:SearXNG"
    ["postgres"]="5432/tcp:PostgreSQL"
    ["plex"]="32400/tcp:Plex Web,3005/tcp:Plex Companion,8324/tcp:Plex Roku,32469/tcp:Plex DLNA,1900/udp:Plex DLNA Discovery,32410/udp:Plex Discovery,32412/udp:Plex Discovery,32413/udp:Plex Discovery,32414/udp:Plex Discovery"
    ["mongodb"]="27017/tcp:MongoDB"
    ["elasticsearch"]="9200/tcp:Elasticsearch HTTP,9300/tcp:Elasticsearch Transport"
)

# Open ports for enabled services
for service in "${!ports[@]}"; do
    var_name="ENABLE_${service^^}"
    if [ "${!var_name}" = "true" ]; then
        IFS=',' read -ra port_list <<< "${ports[$service]}"
        for port_rule in "${port_list[@]}"; do
            IFS=':' read -r port desc <<< "$port_rule"
            echo "[+] $desc ($port)"
            ufw allow $port comment "$desc" > /dev/null 2>&1
        done
    fi
done

# Enable UFW
echo ""
echo "Enabling firewall..."
ufw --force enable > /dev/null 2>&1

echo ""
echo "Done"
echo ""
echo "Important: SSH (port 22) is allowed"
echo ""
echo "View status: sudo ufw status"
