# Gitea with PostgreSQL Docker Setup

Self-hosted Git service with a PostgreSQL database backend.

## Prerequisites

- Docker and Docker Compose installed
- Ports 3000 (web) and 2222 (SSH) available on your host

## Quick Start

### 1. Configure Environment Variables

Edit the `.env` file and set a strong PostgreSQL password:

```bash
POSTGRES_PASSWORD=your_secure_password_here
```

### 2. Start the Services

```bash
docker compose up -d
```

This will:
- Create a PostgreSQL database container
- Create a Gitea container
- Set up persistent volumes for both
- Wait for PostgreSQL to be healthy before starting Gitea

### 3. Access Gitea

Open your browser and navigate to:
```
http://localhost:3000
```

On first access, complete the initial configuration:
- Database settings are pre-configured via environment variables
- Create your admin account
- Configure SSH server settings (SSH port is 2222 on host, 22 in container)

## Common Commands

### View Logs
```bash
# All services
docker compose logs -f

# Only Gitea
docker compose logs -f gitea

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

### Update Gitea
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
docker compose exec postgres pg_dump -U gitea gitea > gitea_backup.sql
```

### Restore PostgreSQL Database
```bash
docker compose exec -T postgres psql -U gitea gitea < gitea_backup.sql
```

### Backup Gitea Data Directory
```bash
docker run --rm -v gitea_gitea_data:/data -v $(pwd):/backup alpine tar czf /backup/gitea_data_backup.tar.gz -C /data .
```

## Git Operations

### Clone via HTTP
```bash
git clone http://localhost:3000/username/repository.git
```

### Clone via SSH
```bash
git clone ssh://git@localhost:2222/username/repository.git
```

### Configure Git Remote with Custom SSH Port
```bash
# In your repository
git remote add origin ssh://git@localhost:2222/username/repository.git

# Or modify .git/config to use custom port
```

## Troubleshooting

### Gitea can't connect to PostgreSQL
- Check that PostgreSQL is healthy: `docker compose ps`
- View PostgreSQL logs: `docker compose logs postgres`
- Ensure the credentials in `.env` are correct

### SSH Connection Issues
- Gitea SSH is exposed on port 2222 (not standard 22)
- Use `ssh://git@localhost:2222/` URL format
- Ensure port 2222 is not blocked by firewall

### Reset everything
```bash
docker compose down -v
# Edit .env if needed
docker compose up -d
# Reconfigure Gitea in the web interface
```

## Volumes

This setup creates two persistent volumes:
- `postgres_data`: PostgreSQL database files
- `gitea_data`: Gitea repositories, configuration, and uploads

To inspect volumes:
```bash
docker volume ls
docker volume inspect gitea_postgres_data
docker volume inspect gitea_gitea_data
```

## Security Recommendations

1. **Use Strong Passwords** - Set a strong PostgreSQL password
2. **Disable Public Registration** - Configure in Gitea settings after initial setup
3. **Enable 2FA** - Enable two-factor authentication for admin accounts
4. **Backup Regularly** - Backup both database and Gitea data
5. **Keep Updated** - Regularly pull the latest images
6. **Use HTTPS** - In production, put Gitea behind a reverse proxy with SSL

## Production Considerations

For production use, consider:
- Using a reverse proxy (nginx/Traefik) with SSL certificates
- Configuring custom domain and base URL in Gitea settings
- Setting up automated backups
- Using specific version tags instead of `latest`
- Configuring email for notifications
- Setting appropriate resource limits

## More Information

- [Gitea Documentation](https://docs.gitea.io/)
- [Gitea Configuration Cheat Sheet](https://docs.gitea.io/en-us/config-cheat-sheet/)
