# Nginx

Web server and reverse proxy.

## Quick Start

```bash
./start.sh
```

Access: http://localhost

## Add Site

1. Create config in `sites/`:
```bash
nano sites/mysite.conf
```

2. Add server block:
```nginx
server {
    listen 80;
    server_name mysite.local;
    root /usr/share/nginx/html;
    index index.html;
}
```

3. Reload:
```bash
./restart.sh
```

## Reverse Proxy

Proxy to another service:

```nginx
server {
    listen 80;
    server_name app.local;

    location / {
        proxy_pass http://host.docker.internal:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

## HTTPS

See `HTTPS_SETUP.md` for Certbot integration.

## Commands

```bash
./restart.sh                               # Restart
docker compose exec nginx nginx -s reload  # Reload config
docker compose exec nginx nginx -t         # Test config
```

## Structure

```
nginx/
├── sites/           # Site configs (*.conf)
├── html/            # Static files
└── ssl/             # Manual certificates
```
