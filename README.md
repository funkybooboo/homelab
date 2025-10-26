# Homelab

20 self-hosted services. Pick what you need.

## Quick Start

```bash
./setup.sh    # Install Docker + create configs
nano .env     # Enable services
./start.sh    # Start everything
```

## Commands

```bash
./start.sh               # Start all enabled services
./stop.sh                # Stop all services
./restart.sh             # Restart all services
./logs.sh <service>      # View service logs
./setdown.sh             # Remove everything (requires "DELETE")
sudo ./setup-firewall.sh # Configure firewall
./format.sh              # Format all bash scripts
./lint.sh                # Lint all bash scripts
```

## Services

**Apps**
- **n8n** (5678) - Workflow automation. Connect APIs, databases, and services together
- **Gitea** (3000) - Self-hosted Git service. Like GitHub but yours
- **Nextcloud** (8888) - Cloud storage and file sharing. Your own Dropbox
- **Jellyfin** (8096) - Media server. Stream your movies and TV shows
- **Plex** (32400) - Alternative media server. Stream with better client apps
- **Minecraft** (25565) - Minecraft server for you and friends
- **FreshRSS** (8080) - RSS feed reader. Stay updated on websites/blogs
- **Omnivore** (3002) - Save articles and read later. Open source Pocket
- **SearXNG** (8888) - Private search engine. Aggregates results without tracking

**Infrastructure**
- **Nginx** (80/443) - Web server and reverse proxy. Serves sites and forwards traffic
- **Certbot** - Auto-renews SSL certificates from Let's Encrypt. Works with Nginx
- **WireGuard** (51820) - VPN server. Secure access to your network from anywhere
- **Pi-hole** (53) - Network-wide ad blocker. Blocks ads for all devices on network
- **Watchtower** - Automatically updates Docker containers to latest versions
- **Registry** (5000) - Private Docker image registry. Store your own containers

**Databases**
- **PostgreSQL** (5432) - Relational database. Used by many services
- **MongoDB** (27017) - NoSQL document database. For unstructured data
- **Elasticsearch** (9200) - Search and analytics engine. Full-text search

**Other**
- **Ollama** (11434) - Run large language models locally. Like ChatGPT but private
- **OpenSpeedTest** (3001) - Test your network speed. Self-hosted speedtest.net

## Configuration

All services are disabled by default. Enable what you need in `.env`:
```bash
# Enable services you want
ENABLE_NGINX=true
ENABLE_GITEA=true
ENABLE_POSTGRES=true

# Others remain false
ENABLE_PLEX=false
```

Configure each service in `services/<name>/.env`

## Setup Notes

**Docker Registry** - Create auth:
```bash
cd services/registry && mkdir -p auth
docker run --rm --entrypoint htpasswd httpd:2 -Bbn user pass > auth/htpasswd
```

**Media (Jellyfin/Plex)** - Set media path in `.env`:
```bash
MEDIA_PATH=/path/to/movies
```

**Nextcloud** - Set data path in `.env`:
```bash
DATA_PATH=/path/to/data
```

**WireGuard** - Set public IP in `.env`:
```bash
SERVERURL=your-domain.com
```

**HTTPS** - See `services/nginx/HTTPS_SETUP.md`

## Documentation

- Adding services: `docs/adding-services.md`
- Development: `docs/development.md`
- Each service: `services/<name>/README.md`

## License

GPL-3.0
