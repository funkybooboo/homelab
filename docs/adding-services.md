# Adding New Services

Guide for adding services to the homelab.

## Overview

Each service needs:
1. Service directory with Docker config
2. Control scripts (start/stop/restart)
3. Documentation
4. Root .env toggle
5. Integration with main scripts

## Steps

### 1. Create Service Directory

```bash
mkdir -p services/myservice
cd services/myservice
```

### 2. Create docker-compose.yml

```yaml
services:
  myservice:
    image: myservice/myservice:latest
    container_name: myservice
    restart: unless-stopped
    ports:
      - "8080:8080"
    volumes:
      - ./data:/data
    env_file:
      - .env
    networks:
      - myservice_network

networks:
  myservice_network:
    driver: bridge
```

Key points:
- Use `restart: unless-stopped` for automatic restarts
- Use `env_file: .env` for configuration
- Create dedicated network for isolation
- Map volumes for persistent data

### 3. Create .env.example

```bash
# MyService Configuration
PORT=8080
ADMIN_EMAIL=admin@example.com
```

Copy to .env:
```bash
cp .env.example .env
nano .env  # Edit with real values
```

### 4. Create Control Scripts

**start.sh**
```bash
#!/bin/bash
cd "$(dirname "$0")"
docker compose up -d
```

**stop.sh**
```bash
#!/bin/bash
cd "$(dirname "$0")"
docker compose down
```

**restart.sh**
```bash
#!/bin/bash
cd "$(dirname "$0")"
docker compose restart
```

Make executable:
```bash
chmod +x start.sh stop.sh restart.sh
```

### 5. Create README.md

```markdown
# MyService

Brief description of what the service does.

## Access

- Web UI: http://localhost:8080
- Default login: admin / admin

## Configuration

Edit `.env` before starting:

\`\`\`bash
PORT=8080              # Web interface port
ADMIN_EMAIL=user@example.com
\`\`\`

## Usage

\`\`\`bash
./start.sh    # Start service
./stop.sh     # Stop service
./restart.sh  # Restart service
\`\`\`

## Data

Data stored in `./data/`

## Additional Setup

See `docs/` for:
- `router-setup.md` - Port forwarding configuration
- `advanced-config.md` - Advanced options

## Documentation

Official docs: https://myservice.com/docs
```

### 6. Create Additional Documentation (Optional)

For complex setup (router config, advanced options), create service docs:

```bash
mkdir -p docs
```

Example `docs/router-setup.md`:
```markdown
# Router Configuration for MyService

## Port Forwarding

Forward these ports to your server:

| Port | Protocol | Purpose |
|------|----------|---------|
| 8080 | TCP | Web interface |
| 9090 | UDP | P2P connections |

## Router Setup Steps

**Generic Router:**
1. Log into router (usually 192.168.1.1)
2. Navigate to Port Forwarding
3. Add rule: External 8080 -> Internal SERVER_IP:8080
4. Save and reboot router

**Specific Routers:**

**Netgear:**
- Advanced > Advanced Setup > Port Forwarding
- Add Custom Service

**TP-Link:**
- Advanced > NAT Forwarding > Virtual Servers

**pfSense:**
- Firewall > NAT > Port Forward
- Add rule for WAN interface

## Testing

Test external access:
\`\`\`bash
curl http://YOUR_PUBLIC_IP:8080
\`\`\`

## Troubleshooting

**Can't access externally:**
- Check router firewall rules
- Verify port forwarding is enabled
- Confirm service is running: `docker ps`
- Test locally first: `curl http://localhost:8080`
```

Reference in README.md:
```markdown
## Additional Setup

- `docs/router-setup.md` - Port forwarding configuration
```

### 7. Add to Root .env

Edit `/home/nate/projects/homelab/.env.example`:

```bash
# Add your service in the appropriate category, disabled by default
ENABLE_MYSERVICE=false
```

Then update your `.env` to enable it:
```bash
echo "ENABLE_MYSERVICE=true" >> .env
```

Note: All services are disabled by default in .env.example. Users enable only what they need.

### 8. Update Main Scripts

**start.sh** - Add to services array (line ~10):
```bash
declare -A services=(
    # ... existing services ...
    ["myservice"]="$ENABLE_MYSERVICE"
)
```

**stop.sh** - Add to reverse order list (line ~10):
```bash
for service in watchtower nginx ... myservice ...; do
```

Place it logically:
- Infrastructure services (nginx, watchtower) at end
- Databases (postgres) early
- Apps in the middle

**restart.sh** - Same as start.sh

### 9. Update Firewall (Optional)

If service needs external access, edit `setup-firewall.sh`:

```bash
declare -A ports=(
    # ... existing services ...
    ["myservice"]="8080/tcp:MyService Web"
)
```

### 10. Test Service

**Check container is running:**
```bash
docker ps | grep myservice
```

Expected output shows container running:
```
myservice   Up 2 minutes   0.0.0.0:8080->8080/tcp
```

**Check logs for errors:**
```bash
./logs.sh myservice
# or
cd services/myservice && docker compose logs
```

Look for:
- Service started successfully
- No error messages
- Listening on port messages

**Test port connectivity:**
```bash
curl http://localhost:8080
# or
wget -qO- http://localhost:8080
# or
nc -zv localhost 8080
```

**Test web interface:**
```bash
# In browser or with curl
curl -I http://localhost:8080
```

Expected: HTTP 200 OK response

**Test from another machine (if external access):**
```bash
curl http://SERVER_IP:8080
```

**Verify data persistence:**
```bash
# Create test data in service
# Restart service
./restart.sh
# Verify data still exists
```

**Test service stops cleanly:**
```bash
./stop.sh
docker ps | grep myservice  # Should show nothing
```

**Test via main scripts:**
```bash
cd /home/nate/projects/homelab
./start.sh
./logs.sh myservice
./restart.sh
./stop.sh
```

**Common test commands:**
```bash
# View running containers
docker ps

# View all containers (including stopped)
docker ps -a

# Check container health
docker inspect myservice | grep -A 10 Health

# Check network connectivity
docker exec myservice ping -c 3 google.com

# Check disk usage
docker exec myservice df -h

# Check process list
docker exec myservice ps aux
```

## Templates

### Minimal docker-compose.yml

```yaml
services:
  myservice:
    image: myservice:latest
    container_name: myservice
    restart: unless-stopped
    env_file:
      - .env
    networks:
      - myservice_network

networks:
  myservice_network:
    driver: bridge
```

### With Database Dependency

```yaml
services:
  myservice:
    image: myservice:latest
    container_name: myservice
    restart: unless-stopped
    depends_on:
      postgres:
        condition: service_healthy
    env_file:
      - .env
    networks:
      - myservice_network
      - postgres_network

networks:
  myservice_network:
    driver: bridge
  postgres_network:
    external: true
    name: postgres_postgres_network
```

### With Shared Volumes

```yaml
services:
  myservice:
    image: myservice:latest
    volumes:
      - shared_data:/data

volumes:
  shared_data:
    external: true
    name: other_service_data
```

## Common Patterns

### Port Mapping

```yaml
ports:
  - "8080:8080"        # HTTP
  - "8443:8443"        # HTTPS
  - "127.0.0.1:5432:5432"  # Localhost only
```

### Volume Mounting

```yaml
volumes:
  - ./config:/config              # Local directory
  - ./data:/data                  # Persistent data
  - /host/path:/container/path    # Absolute path
  - named_volume:/data            # Docker volume
```

### Environment Variables

```yaml
environment:
  - TZ=America/New_York
  - PUID=1000
  - PGID=1000
```

Or use env_file:
```yaml
env_file:
  - .env
```

### Network Connection

```yaml
networks:
  - myservice_network    # Own network
  - postgres_network     # Connect to postgres
```

## Checklist

- [ ] Created services/myservice/
- [ ] Created docker-compose.yml
- [ ] Created .env.example and .env
- [ ] Created start.sh, stop.sh, restart.sh
- [ ] Made scripts executable (chmod +x)
- [ ] Created README.md
- [ ] Added ENABLE_MYSERVICE=false to root .env.example
- [ ] Added ENABLE_MYSERVICE=true to root .env (for testing)
- [ ] Updated start.sh services array
- [ ] Updated stop.sh service list
- [ ] Updated restart.sh services array
- [ ] Updated setup-firewall.sh (if needed)
- [ ] Tested service starts correctly
- [ ] Tested service stops correctly
- [ ] Verified logs.sh works
- [ ] Verified data persists after restart

## Troubleshooting

**Service won't start**
```bash
cd services/myservice
docker compose logs
```

**Port already in use**
Change PORT in .env, update docker-compose.yml ports mapping

**Permission denied**
```bash
sudo chown -R $USER:$USER services/myservice/data
```

**Service not enabled**
Check root .env has `ENABLE_MYSERVICE=true`

**Script not executable**
```bash
chmod +x services/myservice/*.sh
```
