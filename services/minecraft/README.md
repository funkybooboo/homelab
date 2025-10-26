# Minecraft Server

## Quick Start

1. Edit `.env` - configure server settings
2. `docker compose up -d` - start server
3. Connect to `localhost:25565` (or server IP)

## Configuration

Edit `.env` file:
- `SERVER_TYPE`: VANILLA, PAPER, FORGE, FABRIC
- `VERSION`: LATEST or specific version (1.20.1)
- `MEMORY`: RAM allocation (2G, 4G, 8G)
- `ONLINE_MODE`: true requires valid Minecraft accounts

## Common Commands

```bash
# View logs
docker compose logs -f

# Attach to console
docker attach minecraft-minecraft-1

# Execute command
docker compose exec minecraft rcon-cli say "Hello players!"

# Stop server
docker compose down

# Update server
docker compose pull && docker compose up -d
```

## RCON (Remote Console)

```bash
# Install mcrcon
apt install mcrcon

# Connect
mcrcon -H localhost -p 25575 -P your_rcon_password

# Or use in container
docker compose exec minecraft rcon-cli
```

## Backup

```bash
# Backup world data
docker run --rm -v minecraft_minecraft_data:/data -v $(pwd):/backup alpine tar czf /backup/minecraft_backup.tar.gz -C /data .
```

## Port Forwarding

Forward port 25565 on your router to enable external access.

## Server Types

- **VANILLA**: Official Minecraft server
- **PAPER**: Optimized, plugin support
- **FABRIC**: Mod support, lightweight
- **FORGE**: Extensive mod support
- **SPIGOT**: Plugin support

## More Info

[itzg/minecraft-server docs](https://github.com/itzg/docker-minecraft-server)
