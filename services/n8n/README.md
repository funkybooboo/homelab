# n8n with PostgreSQL Docker Setup

This setup runs n8n with a PostgreSQL database, both in Docker containers.

## Prerequisites

- Docker and Docker Compose installed
- Ports 5678 available on your host

## Quick Start

### 1. Configure Environment Variables

Edit the `.env` file and set your values:

```bash
# Generate a secure encryption key
openssl rand -base64 32

# Or use a simple command
date +%s | sha256sum | base64 | head -c 32
```

**Important:** 
- Set a strong `POSTGRES_PASSWORD`
- Set a unique `N8N_ENCRYPTION_KEY` (minimum 10 characters)
- Optionally enable basic auth by uncommenting those lines

### 2. Start the Services

```bash
docker compose up -d
```

This will:
- Create a PostgreSQL database container
- Create an n8n container
- Set up persistent volumes for both
- Wait for PostgreSQL to be healthy before starting n8n

### 3. Access n8n

Open your browser and navigate to:
```
http://localhost:5678
```

## Common Commands

### View Logs
```bash
# All services
docker compose logs -f

# Only n8n
docker compose logs -f n8n

# Only PostgreSQL
docker compose logs -f postgres
```

### Stop Services
```bash
docker compose down
```

### Stop and Remove Volumes (⚠️ This deletes all data!)
```bash
docker compose down -v
```

### Update n8n
```bash
docker compose pull
docker compose up -d
```

### Restart Services
```bash
docker compose restart
```

## Backup and Restore

### Backup PostgreSQL Database
```bash
docker compose exec postgres pg_dump -U n8n n8n > n8n_backup.sql
```

### Restore PostgreSQL Database
```bash
docker compose exec -T postgres psql -U n8n n8n < n8n_backup.sql
```

### Backup n8n Data Directory
```bash
docker run --rm -v n8n_n8n_data:/data -v $(pwd):/backup alpine tar czf /backup/n8n_data_backup.tar.gz -C /data .
```

## Using with Tunnel (Development Only)

⚠️ **Warning:** Only use tunnel mode for local development and testing!

To enable tunnel mode for webhook testing, modify the n8n service in `docker-compose.yml`:

```yaml
n8n:
  command: n8n start --tunnel
  # ... rest of config
```

Then restart:
```bash
docker compose up -d
```

## Troubleshooting

### n8n can't connect to PostgreSQL
- Check that PostgreSQL is healthy: `docker compose ps`
- View PostgreSQL logs: `docker compose logs postgres`
- Ensure the credentials in `.env` are correct

### Lost encryption key
If you lose your `N8N_ENCRYPTION_KEY`, existing credentials will not work. Always backup your `.env` file!

### Reset everything
```bash
docker compose down -v
# Edit .env if needed
docker compose up -d
```

## Volumes

This setup creates two persistent volumes:
- `postgres_data`: PostgreSQL database files
- `n8n_data`: n8n configuration, credentials, and encryption key

To inspect volumes:
```bash
docker volume ls
docker volume inspect n8n_postgres_data
docker volume inspect n8n_n8n_data
```

## Security Recommendations

1. **Enable Basic Auth** - Uncomment the basic auth variables in `.env`
2. **Use Strong Passwords** - Generate secure passwords for all credentials
3. **Backup Regularly** - Backup both the database and n8n data
4. **Keep Updated** - Regularly pull the latest images
5. **Use HTTPS** - In production, put n8n behind a reverse proxy with SSL

## Production Considerations

For production use, consider:
- Using a reverse proxy (nginx/Traefik) with SSL certificates
- Implementing proper firewall rules
- Using Docker secrets instead of .env files
- Setting up automated backups
- Monitoring and alerting
- Using specific version tags instead of `latest`

## More Information

- [n8n Documentation](https://docs.n8n.io/)
- [n8n Docker Setup](https://docs.n8n.io/hosting/installation/docker/)
- [n8n Hosting Repository](https://github.com/n8n-io/n8n-hosting)
