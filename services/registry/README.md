# Local Docker Registry Setup

Private Docker registry for storing and distributing container images locally.

## Prerequisites

- Docker and Docker Compose installed
- Ports 5000 (registry) and 5001 (UI) available
- htpasswd utility for creating authentication

## Quick Start

### 1. Create Authentication

Create the auth directory and generate credentials:

```bash
mkdir -p auth

# Create a user (replace 'username' and 'password')
docker run --rm --entrypoint htpasswd httpd:2 -Bbn username password > auth/htpasswd

# Add more users
docker run --rm --entrypoint htpasswd httpd:2 -Bbn anotheruser password >> auth/htpasswd
```

### 2. Start the Services

```bash
docker compose up -d
```

This starts:
- Docker Registry on port 5000
- Web UI on port 5001

### 3. Configure Docker to Use the Registry

For insecure registry (local development), add to `/etc/docker/daemon.json`:

```json
{
  "insecure-registries": ["localhost:5000"]
}
```

Then restart Docker:
```bash
sudo systemctl restart docker
```

### 4. Login to Registry

```bash
docker login localhost:5000
# Enter username and password from step 1
```

## Common Commands

### View Logs
```bash
docker compose logs -f
```

### Push an Image
```bash
# Tag an image
docker tag myimage:latest localhost:5000/myimage:latest

# Push to registry
docker push localhost:5000/myimage:latest
```

### Pull an Image
```bash
docker pull localhost:5000/myimage:latest
```

### List Images via API
```bash
curl -u username:password http://localhost:5000/v2/_catalog
```

### List Tags for an Image
```bash
curl -u username:password http://localhost:5000/v2/myimage/tags/list
```

### Access Web UI
```
http://localhost:5001
```

### Stop Services
```bash
docker compose down
```

### Update Registry
```bash
docker compose pull
docker compose up -d
```

## Using with Other Machines

### Option 1: HTTP (Insecure - Local Network Only)

On each client machine:

1. Add to `/etc/docker/daemon.json`:
```json
{
  "insecure-registries": ["your-server-ip:5000"]
}
```

2. Restart Docker: `sudo systemctl restart docker`

3. Login: `docker login your-server-ip:5000`

### Option 2: HTTPS (Secure - Recommended for Production)

1. Generate SSL certificates
2. Mount certificates in docker-compose.yml
3. Configure registry to use TLS
4. Update nginx/reverse proxy configuration

## Cleanup Old Images

The registry doesn't automatically delete old images. To clean up:

```bash
# Mark images for deletion (via UI or API)
# Then run garbage collection
docker compose exec registry bin/registry garbage-collect /etc/docker/registry/config.yml
```

## Backup and Restore

### Backup Registry Data
```bash
docker run --rm -v registry_registry_data:/data -v $(pwd):/backup alpine tar czf /backup/registry_backup.tar.gz -C /data .
```

### Restore Registry Data
```bash
docker run --rm -v registry_registry_data:/data -v $(pwd):/backup alpine tar xzf /backup/registry_backup.tar.gz -C /data
```

## Storage Estimation

Images can be large. Monitor storage:

```bash
docker system df -v | grep registry
```

## Integration Examples

### With n8n
Use the registry to store custom n8n node images

### With Gitea CI/CD
Push built images to local registry instead of Docker Hub

### With Kubernetes
Configure k8s to pull from local registry:
```yaml
imagePullSecrets:
  - name: regcred
```

## Troubleshooting

### Authentication Failed
- Check auth/htpasswd file exists and is readable
- Verify credentials with: `cat auth/htpasswd`
- Ensure you've logged in: `docker login localhost:5000`

### Cannot Push Images
- Check disk space
- Verify registry is running: `docker compose ps`
- Check logs: `docker compose logs registry`

### Web UI Not Loading
- Ensure registry-ui is running: `docker compose ps`
- Check that port 5001 is not in use
- View logs: `docker compose logs registry-ui`

### Insecure Registry Warning
- Add to Docker daemon.json insecure-registries list
- Or configure HTTPS with valid certificates

## Volumes

This setup creates one persistent volume:
- `registry_data`: Container images and layers

## Security Recommendations

1. **Use Authentication** - Always require login (configured by default)
2. **Use HTTPS** - Configure TLS certificates for production
3. **Network Isolation** - Only expose on trusted networks
4. **Regular Backups** - Backup registry data regularly
5. **Scan Images** - Use tools like Trivy to scan for vulnerabilities
6. **Access Control** - Limit who can push/pull images

## More Information

- [Docker Registry Documentation](https://docs.docker.com/registry/)
- [Registry Configuration](https://docs.docker.com/registry/configuration/)
- [Docker Registry UI](https://github.com/Joxit/docker-registry-ui)
