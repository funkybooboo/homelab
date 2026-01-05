# Homelab

Personal homelab configuration for self-hosted services running on Raspberry Pi.

## Overview

This repository contains Docker Compose configurations for self-hosted services and automation scripts. All services are containerized and can be deployed anywhere with Docker and Docker Compose.

## Services

### Infrastructure

- **Caddy** - Modern reverse proxy and web server with automatic HTTPS
  - Ports: 80 (HTTP), 443 (HTTPS)
  - Location: `caddy/`

### Applications

- **Vaultwarden** - Lightweight Bitwarden-compatible password manager
  - Proxied via Caddy at `https://vaultwarden.lan`
  - Location: `vaultwarden/`

- **Forgejo** - Self-hosted Git service (Gitea fork)
  - Ports: 3000 (Web), 222 (SSH)
  - Location: `forgejo/`

- **Gitea** - Lightweight Git service
  - Location: `gitea/`

- **FreshRSS** - RSS feed aggregator
  - Port: 8080
  - Location: `freshrss/`

- **n8n** - Workflow automation tool
  - Port: 5678
  - Location: `n8n/`

- **Omnivore** - Read-it-later application
  - Multi-container setup with PostgreSQL, Redis, MinIO
  - Location: `omnivore/`

- **Uptime Kuma** - Uptime monitoring tool
  - Port: 3002
  - Location: `kuma/`

- **Code Server** - VS Code in the browser
  - Port: 8443
  - Location: `code-server/`

### Jobs & Automation

- **jobs/** - Automated tasks and scripts
  - `repos/sync-forges.sh` - Syncs GitHub repositories to Codeberg and Forgejo
  - `repos/_mirror/` - Mirrored repositories (gitignored)
  - Runs daily at 2:00 AM via crontab

## Directory Structure

```
homelab/
├── caddy/              # Reverse proxy
├── code-server/        # Browser-based IDE
├── forgejo/            # Git forge
├── freshrss/           # RSS reader
├── gitea/              # Git service
├── jobs/               # Automation scripts
│   └── repos/
│       ├── sync-forges.sh
│       └── _mirror/    # Mirrored repos (ignored)
├── kuma/               # Uptime monitoring
├── n8n/                # Workflow automation
├── omnivore/           # Read-it-later
├── vaultwarden/        # Password manager
└── .gitignore          # Excludes data, configs, secrets
```

## Prerequisites

- Docker
- Docker Compose
- Git

## Usage

### Starting Services

Each service has its own `docker-compose.yml` file. To start a service:

```bash
cd <service-directory>
docker compose up -d
```

### Stopping Services

```bash
cd <service-directory>
docker compose down
```

### Viewing Logs

```bash
cd <service-directory>
docker compose logs -f
```

### Starting All Services

```bash
# Start all services
for dir in caddy code-server forgejo freshrss gitea kuma n8n omnivore vaultwarden; do
    cd $dir && docker compose up -d && cd ..
done
```

## Network Configuration

- **Caddy Network**: External network named `web` for reverse proxy
- Create the network if it doesn't exist:
  ```bash
  docker network create web
  ```

## Automated Tasks

### Repository Sync (sync-forges.sh)

Automatically syncs all GitHub repositories to Codeberg and Forgejo:

- **Schedule**: Daily at 2:00 AM (crontab)
- **Location**: `jobs/repos/sync-forges.sh`
- **Log**: `jobs/repos/sync-forges.log`
- **Mirrors**: Stored in `jobs/repos/_mirror/` (gitignored)

Manual run:
```bash
/mnt/data/jobs/repos/sync-forges.sh
```

## Configuration

### Data Persistence

All service data is stored in local volumes or bind mounts:
- Configuration files: `*/config/`
- Data directories: `*/data/`
- Certificates: `*/certs/` or `*/*-certs/`

**Note**: All data directories are gitignored to prevent committing sensitive information.

### Environment Variables

Services may use environment variables defined in their `docker-compose.yml` files. For security:
- Never commit `.env` files
- Use `.env.example` templates where needed
- Sensitive data (passwords, tokens) should be set at runtime

## Security

- All passwords and secrets are stored locally (gitignored)
- Caddy provides automatic HTTPS with internal TLS
- Database files (`.db`, `.sqlite`) are gitignored
- SSH keys and certificates are gitignored

## Deployment

### On Raspberry Pi

1. Clone the repository:
   ```bash
   cd /mnt/data
   git clone git@github.com:funkybooboo/homelab.git
   ```

2. Create the Caddy network:
   ```bash
   docker network create web
   ```

3. Start services as needed (see Usage section)

### On Other Servers

The same configurations can be used on any server with Docker:

1. Clone the repository
2. Create necessary Docker networks
3. Adjust any host-specific settings (ports, domains, paths)
4. Start services

## Maintenance

### Updating Services

```bash
cd <service-directory>
docker compose pull
docker compose up -d
```

### Backing Up Data

Data directories are in each service folder:
```bash
# Example: Backup Vaultwarden data
tar -czf vaultwarden-backup-$(date +%Y%m%d).tar.gz vaultwarden/vw-data/
```

## Troubleshooting

### Check Service Status
```bash
docker ps
```

### View Service Logs
```bash
docker compose logs -f <service-name>
```

### Restart a Service
```bash
cd <service-directory>
docker compose restart
```

### Network Issues
Ensure the `web` network exists:
```bash
docker network ls
docker network create web  # if missing
```

## License

Personal homelab configuration. Use at your own discretion.
