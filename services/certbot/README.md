# Certbot - SSL Certificates

Automatic SSL with Let's Encrypt. Works with nginx.

## Quick Setup

```bash
# 1. Start nginx
cd ../nginx && ./start.sh

# 2. Get certificate
cd ../certbot
./get-cert.sh yourdomain.com

# 3. Add HTTPS config to nginx
# See nginx/sites/https-example.conf.disabled

# 4. Reload nginx
cd ../nginx && ./restart.sh

# 5. Start certbot for auto-renewal
cd ../certbot && ./start.sh
```

## Get Certificate

```bash
# Make sure nginx is running first!
cd ../nginx && ./start.sh

# Then get cert
cd ../certbot
./get-cert.sh example.com

# Multiple domains
./get-cert.sh example.com www.example.com
```

## How It Works

1. Certbot uses nginx's webroot for validation
2. Let's Encrypt validates via `/.well-known/acme-challenge/`
3. Certificates saved to shared volume
4. Nginx reads certs from `/etc/letsencrypt/`
5. Auto-renewal runs twice daily

## Auto-Renewal

Certbot checks for renewal twice daily and renews certs expiring in 30 days.

After renewal, reload nginx:
```bash
docker compose exec nginx nginx -s reload
```

Or add to certbot post-renewal hook.

## Manual Operations

```bash
# List certificates
docker run --rm -v certbot_certbot_certs:/etc/letsencrypt certbot/certbot certificates

# Revoke certificate
docker run --rm -v certbot_certbot_certs:/etc/letsencrypt certbot/certbot revoke --cert-path /etc/letsencrypt/live/example.com/cert.pem

# Delete certificate
docker run --rm -v certbot_certbot_certs:/etc/letsencrypt certbot/certbot delete --cert-name example.com
```

## Troubleshooting

**Port 80 required**: Let's Encrypt validates via HTTP. Ensure port 80 is open and nginx is serving `/.well-known/acme-challenge/`.

**DNS for wildcard**: Wildcard certificates require DNS validation. Use `--manual` flag.

**Rate limits**: Let's Encrypt has rate limits. Test with `--staging` flag first.

## More Info

[Certbot Documentation](https://eff-certbot.readthedocs.io/)
[Let's Encrypt](https://letsencrypt.org/)
