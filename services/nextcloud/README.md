# Nextcloud Docker Setup

Self-hosted cloud storage and collaboration platform.

## Prerequisites

- Docker and Docker Compose installed
- Port 8888 available
- Sufficient storage space for your files
- PostgreSQL for database
- Redis for caching

## Quick Start

### 1. Configure Environment Variables

Edit the `.env` file:

```bash
POSTGRES_PASSWORD=your_secure_password_here
REDIS_PASSWORD=your_redis_password_here
NEXTCLOUD_ADMIN_USER=admin
NEXTCLOUD_ADMIN_PASSWORD=your_admin_password_here
NEXTCLOUD_TRUSTED_DOMAINS=localhost 192.168.1.100
DATA_PATH=/path/to/nextcloud/data  # Where files are stored
```

### 2. Create Data Directory

```bash
mkdir -p /path/to/nextcloud/data
chmod 777 /path/to/nextcloud/data  # Or set proper ownership
```

### 3. Start the Services

```bash
docker compose up -d
```

First startup may take a few minutes to initialize.

### 4. Access Nextcloud

Open your browser and navigate to:
```
http://localhost:8888
```

Login with the admin credentials from `.env` file.

## Common Commands

### View Logs
```bash
# All services
docker compose logs -f

# Only Nextcloud
docker compose logs -f nextcloud
```

### Run OCC Commands
```bash
# General format
docker compose exec -u www-data nextcloud php occ <command>

# Examples
docker compose exec -u www-data nextcloud php occ status
docker compose exec -u www-data nextcloud php occ app:list
docker compose exec -u www-data nextcloud php occ files:scan --all
docker compose exec -u www-data nextcloud php occ maintenance:mode --on
```

### Stop Services
```bash
docker compose down
```

### Update Nextcloud
```bash
docker compose pull
docker compose up -d

# Run update via web interface or:
docker compose exec -u www-data nextcloud php occ upgrade
```

## Configuration

### Add Trusted Domain

```bash
docker compose exec -u www-data nextcloud php occ config:system:set trusted_domains 2 --value=nextcloud.example.com
```

### Enable Apps

```bash
# List available apps
docker compose exec -u www-data nextcloud php occ app:list

# Enable an app
docker compose exec -u www-data nextcloud php occ app:enable calendar

# Popular apps: calendar, contacts, tasks, notes, deck
```

### Configure Memory and Upload Limits

Create `php.ini` and mount it in docker-compose.yml:

```ini
upload_max_filesize = 16G
post_max_size = 16G
max_execution_time = 3600
memory_limit = 512M
```

### Setup Email

Configure in web interface:
1. Settings → Basic settings
2. Configure SMTP settings for email notifications

## Client Apps

### Desktop
- Windows, macOS, Linux: https://nextcloud.com/install/#install-clients

### Mobile
- iOS: Nextcloud app from App Store
- Android: Nextcloud app from Google Play or F-Droid

### WebDAV Access
URL: `http://localhost:8888/remote.php/dav/files/USERNAME/`

## Recommended Apps

Install from Apps menu in web interface:

- **Calendar**: CalDAV calendar
- **Contacts**: CardDAV contacts
- **Tasks**: Task management
- **Notes**: Note taking
- **Deck**: Kanban board
- **Talk**: Video calls and chat
- **Forms**: Create forms and surveys
- **Memories**: Photo management
- **Music**: Music player

## Backup and Restore

### Backup Database
```bash
docker compose exec postgres pg_dump -U nextcloud nextcloud > nextcloud_db_backup.sql
```

### Backup Data
```bash
# Data directory is already on host at DATA_PATH
tar -czf nextcloud_data_backup.tar.gz /path/to/nextcloud/data

# Backup Nextcloud config
docker run --rm -v nextcloud_nextcloud_data:/data -v $(pwd):/backup alpine tar czf /backup/nextcloud_config_backup.tar.gz -C /data .
```

### Restore Database
```bash
docker compose exec -T postgres psql -U nextcloud nextcloud < nextcloud_db_backup.sql
```

## Maintenance

### Enable Maintenance Mode
```bash
docker compose exec -u www-data nextcloud php occ maintenance:mode --on
```

### Disable Maintenance Mode
```bash
docker compose exec -u www-data nextcloud php occ maintenance:mode --off
```

### Scan Files
```bash
docker compose exec -u www-data nextcloud php occ files:scan --all
```

### Clean Up
```bash
docker compose exec -u www-data nextcloud php occ files:cleanup
```

## Troubleshooting

### Can't Access Web Interface
- Check containers are running: `docker compose ps`
- Check logs: `docker compose logs nextcloud`
- Verify port 8888 is not in use
- Check trusted domains configuration

### Upload Errors
- Check disk space
- Verify DATA_PATH permissions
- Check PHP upload limits
- View logs: `docker compose logs nextcloud`

### Database Connection Error
- Verify PostgreSQL is running: `docker compose ps postgres`
- Check credentials in `.env`
- View database logs: `docker compose logs postgres`

### Performance Issues
- Ensure Redis is running for caching
- Increase PHP memory limit
- Enable APCu and Redis caching
- Run `occ db:add-missing-indices`

### Upgrade Issues
```bash
# Put in maintenance mode
docker compose exec -u www-data nextcloud php occ maintenance:mode --on

# Run upgrade
docker compose exec -u www-data nextcloud php occ upgrade

# Disable maintenance mode
docker compose exec -u www-data nextcloud php occ maintenance:mode --off
```

## Integration with Other Services

### Ollama (AI)
Install Assistant app and configure Ollama endpoint

### Jellyfin
Mount shared media directory (read-only)

### WireGuard
Access Nextcloud securely when away from home

## Volumes

This setup creates two persistent volumes:
- `postgres_data`: PostgreSQL database
- `nextcloud_data`: Nextcloud application and config

Files are stored on the host at `DATA_PATH`.

## Security Recommendations

1. **Use Strong Passwords** - For admin, database, and Redis
2. **Enable HTTPS** - Use reverse proxy with SSL
3. **Two-Factor Authentication** - Enable 2FA for all users
4. **Regular Updates** - Keep Nextcloud updated
5. **Backup Regularly** - Backup database and data directory
6. **File Access Control** - Review sharing settings
7. **Limit Login Attempts** - Enable brute force protection

## More Information

- [Nextcloud Documentation](https://docs.nextcloud.com/)
- [Nextcloud Apps](https://apps.nextcloud.com/)
- [Nextcloud Forums](https://help.nextcloud.com/)
