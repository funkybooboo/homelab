# FreshRSS with PostgreSQL Docker Setup

Self-hosted RSS feed aggregator with PostgreSQL database backend.

## Prerequisites

- Docker and Docker Compose installed
- Port 8080 available on your host

## Quick Start

### 1. Configure Environment Variables

Edit the `.env` file and set your values:

```bash
POSTGRES_PASSWORD=your_secure_password_here
TIMEZONE=America/New_York  # Set your timezone
```

### 2. Start the Services

```bash
docker compose up -d
```

This will:
- Create a PostgreSQL database container
- Create a FreshRSS container
- Set up persistent volumes for database and FreshRSS data
- Configure automatic feed updates every 15 minutes

### 3. Access FreshRSS

Open your browser and navigate to:
```
http://localhost:8080
```

On first access, complete the installation wizard:
1. Choose PostgreSQL as database type
2. Database settings:
   - Host: `postgres`
   - Database name: `freshrss` (or your POSTGRES_DB value)
   - Username: `freshrss` (or your POSTGRES_USER value)
   - Password: (your POSTGRES_PASSWORD value)
3. Create your admin account
4. Start adding feeds!

## Common Commands

### View Logs
```bash
# All services
docker compose logs -f

# Only FreshRSS
docker compose logs -f freshrss

# Only PostgreSQL
docker compose logs -f postgres
```

### Manual Feed Update
```bash
docker compose exec freshrss php ./app/actualize_script.php
```

### Stop Services
```bash
docker compose down
```

### Stop and Remove Volumes (⚠️ This deletes all data!)
```bash
docker compose down -v
```

### Update FreshRSS
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
docker compose exec postgres pg_dump -U freshrss freshrss > freshrss_backup.sql
```

### Restore PostgreSQL Database
```bash
docker compose exec -T postgres psql -U freshrss freshrss < freshrss_backup.sql
```

### Backup FreshRSS Data
```bash
docker run --rm -v freshrss_freshrss_data:/data -v $(pwd):/backup alpine tar czf /backup/freshrss_data_backup.tar.gz -C /data .
```

## Configuration

### Change Feed Update Frequency

Edit `docker-compose.yml` and modify the `CRON_MIN` environment variable:

```yaml
environment:
  - CRON_MIN=*/15  # Update every 15 minutes (default)
  # - CRON_MIN=*/30  # Update every 30 minutes
  # - CRON_MIN=0  # Update every hour
```

Then restart: `docker compose up -d`

### Install Extensions

Extensions are stored in the `freshrss_extensions` volume. To install an extension:

1. Download the extension
2. Copy to the extensions volume
3. Enable in FreshRSS settings

## API Access

FreshRSS supports several API protocols:
- Google Reader API (compatible with many mobile apps)
- Fever API
- Greader API

Configure API access in Settings → Authentication.

## Mobile Apps

Compatible mobile apps include:
- **Android**: FeedMe, News+, EasyRSS
- **iOS**: Reeder, NetNewsWire, Unread

Configure with Google Reader API:
- URL: `http://your-server:8080/api/greader.php`
- Username: Your FreshRSS username
- Password: API password (not your login password)

## Troubleshooting

### FreshRSS can't connect to PostgreSQL
- Check that PostgreSQL is healthy: `docker compose ps`
- View PostgreSQL logs: `docker compose logs postgres`
- Verify credentials in `.env` file

### Feeds not updating automatically
- Check logs: `docker compose logs freshrss`
- Manually trigger update to test: `docker compose exec freshrss php ./app/actualize_script.php`
- Verify CRON_MIN environment variable

### Port already in use
- Change port in docker-compose.yml: `"8081:80"` instead of `"8080:80"`

### Reset everything
```bash
docker compose down -v
# Edit .env if needed
docker compose up -d
# Reconfigure FreshRSS in the web interface
```

## Volumes

This setup creates three persistent volumes:
- `postgres_data`: PostgreSQL database files
- `freshrss_data`: FreshRSS feeds, articles, and user data
- `freshrss_extensions`: FreshRSS extensions

To inspect volumes:
```bash
docker volume ls
docker volume inspect freshrss_postgres_data
docker volume inspect freshrss_freshrss_data
```

## Security Recommendations

1. **Use Strong Passwords** - Set strong passwords for PostgreSQL and FreshRSS
2. **Disable Public Registration** - Configure in FreshRSS settings
3. **Use HTTPS** - In production, put behind a reverse proxy with SSL
4. **Backup Regularly** - Backup both database and FreshRSS data
5. **Keep Updated** - Regularly pull the latest images
6. **Use API Passwords** - Generate separate API passwords for mobile apps

## More Information

- [FreshRSS Documentation](https://freshrss.github.io/FreshRSS/en/)
- [FreshRSS GitHub](https://github.com/FreshRSS/FreshRSS)
- [FreshRSS Extensions](https://github.com/FreshRSS/Extensions)
