# Plex Media Server

Media server with streaming, transcoding, and apps for all platforms.

## Quick Start

```bash
# Get claim token from https://www.plex.tv/claim/
# Add to .env

nano .env

# Start service
./start.sh
```

Access: http://localhost:32400/web

## Initial Setup

1. Get claim token: https://www.plex.tv/claim/
2. Add token to `.env` as `PLEX_CLAIM`
3. Start Plex: `./start.sh`
4. Complete setup in web interface
5. Remove claim token from `.env` (no longer needed)

## Configuration

Edit `.env`:
```bash
TIMEZONE=America/New_York
PLEX_CLAIM=claim-xxxxxx  # Only for first setup
MEDIA_PATH=/path/to/media
```

## Media Organization

```
/media/
  Movies/
    Movie Name (2020)/
      Movie Name (2020).mkv
  TV Shows/
    Show Name/
      Season 01/
        Show Name S01E01.mkv
  Music/
  Photos/
```

## Hardware Transcoding

For Intel QuickSync, uncomment in docker-compose.yml:
```yaml
devices:
  - /dev/dri:/dev/dri
```

Enable in Plex settings under Transcoder.

## Client Apps

- Web: http://localhost:32400/web
- Windows/Mac/Linux: https://www.plex.tv/downloads/
- iOS/Android: Available in app stores
- Smart TVs: Search for Plex app

## Remote Access

Configure in Settings > Remote Access.
Plex can set up automatic port forwarding or use Plex Relay.

## Backup

```bash
# Backup config
docker run --rm -v plex_plex_config:/data -v $(pwd):/backup alpine tar czf /backup/plex_backup.tar.gz -C /data .
```

## Plex Pass

Premium features include:
- Hardware transcoding
- Mobile sync
- Live TV & DVR
- Premium music features

## More Info

[Plex Documentation](https://support.plex.tv/)
