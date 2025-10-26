# Pi-hole Docker Setup

Network-wide ad blocker and local DNS server.

## Prerequisites

- Docker and Docker Compose installed
- Port 53 (DNS) and 8053 (web UI) available
- Optional: Port 67 (DHCP) if using Pi-hole as DHCP server
- Your server's local IP address

## Quick Start

### 1. Configure Environment Variables

Edit the `.env` file:

```bash
TIMEZONE=America/New_York
WEBPASSWORD=your_secure_admin_password
SERVER_IP=192.168.1.100  # Your server's IP
UPSTREAM_DNS=1.1.1.1;1.0.0.1  # Cloudflare DNS
WEBTHEME=default-dark
```

### 2. Start the Service

```bash
docker compose up -d
```

### 3. Access Pi-hole

Open your browser and navigate to:
```
http://localhost:8053/admin
```

Login with the password from `.env` file.

### 4. Configure Devices to Use Pi-hole

#### Option 1: Configure Each Device
Set DNS to your server's IP (e.g., 192.168.1.100)

#### Option 2: Configure Router (Recommended)
1. Log into your router
2. Find DHCP/DNS settings
3. Set DNS server to your Pi-hole IP
4. Reboot router or renew DHCP leases on clients

#### Option 3: Use Pi-hole as DHCP Server
1. Disable DHCP on your router
2. Enable DHCP in Pi-hole web interface
3. Configure DHCP range and gateway

## Common Commands

### View Logs
```bash
docker compose logs -f
```

### View Real-time Queries
```bash
docker compose exec pihole pihole -t
```

### Update Gravity (Block Lists)
```bash
docker compose exec pihole pihole -g
```

### View Stats
```bash
docker compose exec pihole pihole -c
```

### Restart DNS Service
```bash
docker compose exec pihole pihole restartdns
```

### Stop Service
```bash
docker compose down
```

### Update Pi-hole
```bash
docker compose pull
docker compose up -d
```

## Configuration

### Add Custom Block Lists

1. Go to http://localhost:8053/admin
2. Navigate to Adlists
3. Add URLs to block lists
4. Update gravity: `docker compose exec pihole pihole -g`

Popular block lists:
- [Firebog](https://firebog.net/)
- [OISD](https://oisd.nl/)
- [1Hosts](https://o0.pages.dev/)

### Whitelist/Blacklist Domains

```bash
# Whitelist a domain
docker compose exec pihole pihole -w example.com

# Blacklist a domain
docker compose exec pihole pihole -b ads.example.com

# Or use the web interface: Domains → Whitelist/Blacklist
```

### Local DNS Records

Add custom DNS entries in web interface:
1. Go to Local DNS → DNS Records
2. Add domain and IP address
3. Examples:
   - `nas.local` → 192.168.1.50
   - `homelab.local` → 192.168.1.100

### CNAME Records

Add CNAME records in web interface:
1. Go to Local DNS → CNAME Records
2. Map subdomains to domains

## Integration with WireGuard

To use Pi-hole when connected via WireGuard VPN:

1. Ensure WireGuard is configured with:
```env
PEERDNS=10.13.13.100  # Pi-hole's IP in WireGuard network
```

2. Configure Pi-hole to accept queries from WireGuard subnet:
   - Go to Settings → DNS
   - Interface Settings: "Permit all origins"
   - Or add custom `dnsmasq` config

## Monitoring

### Web Dashboard
View statistics at http://localhost:8053/admin

### Query Log
- Real-time: `docker compose exec pihole pihole -t`
- Web interface: Query Log section

### Top Clients and Domains
- CLI: `docker compose exec pihole pihole -c`
- Web interface: Dashboard

## Backup and Restore

### Backup Configuration
```bash
# Via web interface: Settings → Teleporter → Backup

# Or manually backup volumes
docker run --rm -v pihole_pihole_config:/data -v $(pwd):/backup alpine tar czf /backup/pihole_config_backup.tar.gz -C /data .
```

### Restore Configuration
```bash
# Via web interface: Settings → Teleporter → Restore

# Or manually restore volumes
docker run --rm -v pihole_pihole_config:/data -v $(pwd):/backup alpine tar xzf /backup/pihole_config_backup.tar.gz -C /data
```

## Troubleshooting

### DNS Not Resolving
- Check Pi-hole is running: `docker compose ps`
- Verify port 53 is not in use: `sudo ss -tulpn | grep :53`
- Test DNS: `dig @localhost google.com`
- Check logs: `docker compose logs pihole`

### Web Interface Not Loading
- Check port 8053 is accessible
- Try: http://SERVER_IP:8053/admin
- Check logs: `docker compose logs pihole`

### Too Many Ads Being Blocked
- Check whitelist
- Disable Pi-hole temporarily: `docker compose exec pihole pihole disable 5m`
- Review query log for false positives

### Port 53 Already in Use
If systemd-resolved is using port 53:
```bash
# Disable systemd-resolved
sudo systemctl disable systemd-resolved
sudo systemctl stop systemd-resolved

# Remove symlink
sudo rm /etc/resolv.conf

# Create new resolv.conf
echo "nameserver 1.1.1.1" | sudo tee /etc/resolv.conf

# Restart Pi-hole
docker compose restart
```

## Performance Optimization

### Increase Cache Size
Add to environment in docker-compose.yml:
```yaml
- DNSMASQ_CACHE_SIZE=10000
```

### Use Unbound for DNS
For increased privacy, run Unbound as recursive DNS resolver:
1. Add Unbound container
2. Point Pi-hole to Unbound
3. No reliance on upstream DNS providers

## Volumes

This setup creates two persistent volumes:
- `pihole_config`: Pi-hole configuration and databases
- `pihole_dnsmasq`: Dnsmasq configuration files

## Security Recommendations

1. **Strong Password** - Use a strong WEBPASSWORD
2. **Update Regularly** - Keep Pi-hole updated
3. **Monitor Queries** - Review query log for suspicious activity
4. **Limit Access** - Don't expose port 53 to the internet
5. **DNSSEC** - Enable DNSSEC in settings for security
6. **Use HTTPS** - Put behind reverse proxy with SSL

## More Information

- [Pi-hole Documentation](https://docs.pi-hole.net/)
- [Pi-hole GitHub](https://github.com/pi-hole/pi-hole)
- [Docker Pi-hole](https://github.com/pi-hole/docker-pi-hole)
- [Pi-hole Discourse](https://discourse.pi-hole.net/)
