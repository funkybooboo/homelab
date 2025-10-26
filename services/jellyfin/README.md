# Jellyfin Docker Setup

Self-hosted media server for movies, TV shows, music, and more.

## Prerequisites

- Docker and Docker Compose installed
- Port 8096 available on your host
- Media files stored on your host system
- Optional: GPU for hardware transcoding

## Quick Start

### 1. Configure Environment Variables

Edit the `.env` file and set your media path:

```bash
TIMEZONE=America/New_York
MEDIA_PATH=/path/to/your/media  # e.g., /mnt/media or /home/user/media
```

Organize your media like this:
```
/path/to/your/media/
├── movies/
├── tv/
├── music/
└── photos/
```

### 2. Start the Service

```bash
docker compose up -d
```

### 3. Access Jellyfin

Open your browser and navigate to:
```
http://localhost:8096
```

Complete the initial setup wizard:
1. Set preferred language
2. Create admin user
3. Add media libraries pointing to `/media/movies`, `/media/tv`, etc.
4. Configure metadata providers
5. Set up remote access (optional)

## Common Commands

### View Logs
```bash
docker compose logs -f
```

### Stop Service
```bash
docker compose down
```

### Stop and Remove Volumes (⚠️ This deletes config and cache!)
```bash
docker compose down -v
```

### Update Jellyfin
```bash
docker compose pull
docker compose up -d
```

### Restart Service
```bash
docker compose restart
```

## Hardware Transcoding

### Intel QuickSync (recommended for Intel CPUs)

1. Ensure `/dev/dri` exists on your host
2. Find the `render` group ID: `getent group render | cut -d: -f3`
3. Uncomment the `devices` and `group_add` sections in `docker-compose.yml`
4. Update the group ID if different from 109
5. Restart: `docker compose up -d`
6. Enable in Jellyfin: Dashboard → Playback → Hardware Acceleration

### NVIDIA GPU

1. Install NVIDIA Container Toolkit
2. Modify `docker-compose.yml`:
```yaml
deploy:
  resources:
    reservations:
      devices:
        - driver: nvidia
          count: all
          capabilities: [gpu, compute, video]
```
3. Restart: `docker compose up -d`

## Media Organization

Jellyfin works best with organized media:

### Movies
```
/media/movies/
├── Movie Name (2020)/
│   └── Movie Name (2020).mkv
└── Another Movie (2021)/
    └── Another Movie (2021).mp4
```

### TV Shows
```
/media/tv/
└── Show Name/
    ├── Season 01/
    │   ├── Show Name S01E01.mkv
    │   └── Show Name S01E02.mkv
    └── Season 02/
        ├── Show Name S02E01.mkv
        └── Show Name S02E02.mkv
```

## Client Apps

Jellyfin has apps for:
- **Web**: Any browser at http://localhost:8096
- **Android**: Jellyfin app from Google Play
- **iOS**: Jellyfin app from App Store
- **Android TV**: Jellyfin app
- **Roku**: Jellyfin app
- **Desktop**: Jellyfin Media Player

## Plugins

Install plugins from Dashboard → Plugins:
- **Trakt**: Scrobbling and recommendations
- **TMDb Box Sets**: Automatic collection creation
- **Skin Manager**: Custom themes
- **Playback Reporting**: Watch statistics

## Backup and Restore

### Backup Config
```bash
docker run --rm -v jellyfin_jellyfin_config:/data -v $(pwd):/backup alpine tar czf /backup/jellyfin_config_backup.tar.gz -C /data .
```

### Restore Config
```bash
docker run --rm -v jellyfin_jellyfin_config:/data -v $(pwd):/backup alpine tar xzf /backup/jellyfin_config_backup.tar.gz -C /data
```

## Troubleshooting

### Can't see media files
- Check that MEDIA_PATH in `.env` points to correct directory
- Verify permissions on media directory
- Ensure media is mounted and accessible

### Transcoding not working
- Check hardware transcoding settings
- View logs for errors: `docker compose logs -f`
- Try software transcoding first to isolate issue

### Slow performance
- Enable hardware transcoding if available
- Check network bandwidth
- Optimize video files (consider pre-transcoding large files)
- Increase cache size

### Port already in use
- Change port in docker-compose.yml: `"8097:8096"` instead of `"8096:8096"`

## Volumes

This setup creates two persistent volumes:
- `jellyfin_config`: Configuration, metadata, and user data
- `jellyfin_cache`: Transcoding cache

Your media files remain on the host at the path specified in MEDIA_PATH.

## Security Recommendations

1. **Use Strong Passwords** - Set strong passwords for all users
2. **Enable HTTPS** - Configure SSL in settings or use reverse proxy
3. **Limit Remote Access** - Only enable if needed
4. **Regular Updates** - Keep Jellyfin updated
5. **User Permissions** - Configure appropriate user access levels
6. **Network Segmentation** - Consider using a VPN for remote access

## More Information

- [Jellyfin Documentation](https://jellyfin.org/docs/)
- [Jellyfin GitHub](https://github.com/jellyfin/jellyfin)
- [Jellyfin Forum](https://forum.jellyfin.org/)
