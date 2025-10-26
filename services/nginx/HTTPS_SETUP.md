# HTTPS Setup

Enable HTTPS on your domain with Certbot.

## Prerequisites

- Domain pointing to your server
- Ports 80 and 443 open

## Steps

1. Start nginx:
```bash
./start.sh
```

2. Get certificate:
```bash
cd ../certbot
./get-cert.sh yourdomain.com
cd ../nginx
```

3. Create site config:
```bash
cp sites/https-example.conf.disabled sites/yourdomain.conf
nano sites/yourdomain.conf
```

Change `example.com` to your domain.

4. Reload nginx:
```bash
./restart.sh
```

5. Start certbot for auto-renewal:
```bash
cd ../certbot
./start.sh
```

Done.
