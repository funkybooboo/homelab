# Watchtower

Automatically updates Docker containers to the latest available image.

## Quick Start

```bash
# Configure schedule in .env
nano .env

# Start Watchtower
./start.sh
```

## Configuration

Edit `.env`:
```bash
# Daily at 4 AM
SCHEDULE=0 0 4 * * *

# Every 6 hours
SCHEDULE=0 0 */6 * * *

# Weekly Sunday at 3 AM
SCHEDULE=0 0 3 * * 0
```

## Cron Schedule Format

```
Second Minute Hour Day Month DayOfWeek
0      0      4    *   *     *
```

## Monitoring

```bash
# View logs to see updates
docker compose logs -f
```

Watchtower will:
- Check for image updates based on schedule
- Pull new images
- Restart containers with new images
- Clean up old images

## Notifications

To receive update notifications, configure in `.env`:

**Slack:**
```bash
NOTIFICATIONS=slack
NOTIFICATION_URL=https://hooks.slack.com/services/xxx/yyy/zzz
```

**Email:**
```bash
NOTIFICATIONS=email
NOTIFICATION_URL=smtp://user:pass@server:port/?from=watchtower@example.com&to=admin@example.com
```

## Exclude Containers

To exclude specific containers from auto-updates, add label to their docker-compose.yml:

```yaml
services:
  myservice:
    image: myimage:latest
    labels:
      - "com.centurylinklabs.watchtower.enable=false"
```

## More Info

[Watchtower Documentation](https://containrrr.dev/watchtower/)
