# Omnivore Docker Setup

Self-hosted read-it-later application for saving articles, newsletters, and documents.

## Prerequisites

- Docker and Docker Compose installed
- Ports 3002 (web) and 4000 (API) available

## Quick Start

### 1. Configure Environment Variables

Edit the `.env` file:

```bash
POSTGRES_PASSWORD=your_secure_password_here

# Generate JWT secret
JWT_SECRET=$(openssl rand -base64 32)
```

### 2. Start the Services

```bash
docker compose up -d
```

### 3. Access Omnivore

Open your browser and navigate to:
```
http://localhost:3002
```

Create your account and start saving articles!

## Common Commands

### View Logs
```bash
# All services
docker compose logs -f

# Specific service
docker compose logs -f omnivore-web
docker compose logs -f omnivore-api
```

### Stop Services
```bash
docker compose down
```

### Update Omnivore
```bash
docker compose pull
docker compose up -d
```

## Browser Extensions

Install browser extensions to easily save articles:
- Chrome/Edge: Search for "Omnivore" in Chrome Web Store
- Firefox: Search for "Omnivore" in Firefox Add-ons
- Safari: Available in Safari Extensions

## Mobile Apps

- iOS: Available on App Store
- Android: Available on Google Play

Configure with:
- Server URL: `http://your-server-ip:3002`
- Login with your credentials

## Features

- Save articles, PDFs, and newsletters
- Read offline
- Highlights and notes
- Full-text search
- Labels and filters
- Email newsletter integration
- RSS feed support
- Keyboard shortcuts

## Backup and Restore

### Backup PostgreSQL Database
```bash
docker compose exec postgres pg_dump -U omnivore omnivore > omnivore_backup.sql
```

### Restore PostgreSQL Database
```bash
docker compose exec -T postgres psql -U omnivore omnivore < omnivore_backup.sql
```

## Troubleshooting

### Can't Connect to API
- Check that all services are running: `docker compose ps`
- Verify ports are not in use
- Check logs: `docker compose logs omnivore-api`

### Login Issues
- Verify JWT_SECRET is set correctly
- Check database connection
- Clear browser cache and cookies

## More Information

- [Omnivore GitHub](https://github.com/omnivore-app/omnivore)
- [Omnivore Documentation](https://docs.omnivore.app/)
