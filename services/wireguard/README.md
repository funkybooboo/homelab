# WireGuard VPN Docker Setup

Self-hosted VPN server for secure remote access to your homelab.

## Prerequisites

- Docker and Docker Compose installed
- Port 51820/udp available and forwarded on your router
- Public IP or dynamic DNS domain
- Kernel support for WireGuard (included in Linux kernel 5.6+)

## Quick Start

### 1. Configure Environment Variables

Edit the `.env` file:

```bash
TIMEZONE=America/New_York
SERVERURL=your-public-ip-or-domain.com  # Your public IP or DDNS domain
SERVERPORT=51820
PEERS=phone,laptop,tablet  # Or just a number: PEERS=3
PEERDNS=auto  # Or use Pi-hole: 10.13.13.100
INTERNAL_SUBNET=10.13.13.0
ALLOWEDIPS=0.0.0.0/0  # Route all traffic through VPN
```

### 2. Configure Router Port Forwarding

Forward UDP port 51820 to your server's local IP address.

### 3. Start the Service

```bash
docker compose up -d
```

The first start will generate peer configurations.

### 4. Get Peer Configurations

View the logs to see QR codes for mobile devices:

```bash
docker compose logs wireguard
```

Or retrieve config files:

```bash
# List generated configs
docker compose exec wireguard ls -la /config

# View a specific peer config
docker compose exec wireguard cat /config/peer_phone/peer_phone.conf

# Get QR code for mobile
docker compose exec wireguard /app/show-peer phone
```

## Common Commands

### View Logs (Shows QR Codes)
```bash
docker compose logs -f
```

### Show QR Code for Peer
```bash
docker compose exec wireguard /app/show-peer peer_name
```

### Add More Peers

1. Edit `.env` and update `PEERS` value
2. Restart: `docker compose up -d`
3. View new QR codes: `docker compose logs wireguard`

### Remove a Peer

1. Remove peer from `PEERS` in `.env`
2. Restart: `docker compose up -d`
3. Manually delete config: `docker compose exec wireguard rm -rf /config/peer_name`

### Check VPN Status
```bash
docker compose exec wireguard wg show
```

### Stop Service
```bash
docker compose down
```

### Update WireGuard
```bash
docker compose pull
docker compose up -d
```

## Client Setup

### Mobile (iOS/Android)

1. Install WireGuard app from App Store or Google Play
2. View QR code: `docker compose logs wireguard`
3. Scan QR code in the app
4. Enable the tunnel

### Desktop (Windows/Mac/Linux)

1. Install WireGuard from [wireguard.com](https://www.wireguard.com/install/)
2. Get config file:
```bash
docker compose exec wireguard cat /config/peer_laptop/peer_laptop.conf
```
3. Save as `laptop.conf` and import into WireGuard client
4. Activate the tunnel

## Routing Options

### Route All Traffic (Full VPN)
```env
ALLOWEDIPS=0.0.0.0/0
```
All client traffic goes through the VPN.

### Route Only Homelab Traffic (Split Tunnel)
```env
ALLOWEDIPS=192.168.1.0/24,10.0.0.0/8
```
Only traffic to your local networks goes through VPN.

## Integration with Pi-hole

To use Pi-hole as DNS for VPN clients:

1. Ensure Pi-hole is running
2. Set in `.env`:
```env
PEERDNS=10.13.13.100
```
3. Restart WireGuard
4. Configure Pi-hole to allow queries from WireGuard subnet (10.13.13.0/24)

## Troubleshooting

### Can't Connect to VPN
- Verify port 51820/udp is forwarded on router
- Check SERVERURL matches your public IP/domain
- Verify WireGuard is running: `docker compose ps`
- Check logs: `docker compose logs wireguard`

### VPN Connects but No Internet
- Check ALLOWEDIPS setting
- Verify IP forwarding is enabled on host:
```bash
echo "net.ipv4.ip_forward=1" | sudo tee -a /etc/sysctl.conf
sudo sysctl -p
```

### DNS Not Working
- Check PEERDNS setting
- If using Pi-hole, verify it's configured to accept queries from VPN subnet
- Test with: `nslookup google.com`

### Kernel Module Error
- Verify kernel supports WireGuard (5.6+): `uname -r`
- Install WireGuard tools if needed: `sudo apt install wireguard-tools`

## Security Recommendations

1. **Use Strong Server URL** - Use DDNS if you have dynamic IP
2. **Limit Peers** - Only create necessary peer configurations
3. **Rotate Keys** - Periodically regenerate peer configs
4. **Monitor Connections** - Check `wg show` for active connections
5. **Firewall Rules** - Only allow necessary ports
6. **Regular Updates** - Keep WireGuard updated

## Backup and Restore

### Backup Configs
```bash
docker run --rm -v wireguard_wireguard_config:/data -v $(pwd):/backup alpine tar czf /backup/wireguard_backup.tar.gz -C /data .
```

### Restore Configs
```bash
docker run --rm -v wireguard_wireguard_config:/data -v $(pwd):/backup alpine tar xzf /backup/wireguard_backup.tar.gz -C /data
```

## Volumes

This setup creates one persistent volume:
- `wireguard_config`: Server and peer configurations

## More Information

- [WireGuard Documentation](https://www.wireguard.com/)
- [LinuxServer.io WireGuard](https://docs.linuxserver.io/images/docker-wireguard)
