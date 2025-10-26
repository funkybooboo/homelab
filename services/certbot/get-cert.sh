#!/bin/bash

# Get SSL certificate for domain(s)

if [ -z "$1" ]; then
    echo "Usage: ./get-cert.sh domain.com [domain2.com ...]"
    echo ""
    echo "Examples:"
    echo "  ./get-cert.sh example.com"
    echo "  ./get-cert.sh example.com www.example.com"
    exit 1
fi

# Build domain arguments
DOMAINS=""
for domain in "$@"; do
    DOMAINS="$DOMAINS -d $domain"
done

echo "Getting certificate for: $@"
echo ""
echo "Make sure nginx is running for validation"
echo "Press Enter to continue..."
read

# Get certificate using webroot (nginx must be running)
docker run --rm \
    -v certbot_certbot_certs:/etc/letsencrypt \
    -v certbot_certbot_www:/var/www/certbot \
    certbot/certbot certonly \
    --webroot \
    --webroot-path=/var/www/certbot \
    --agree-tos \
    --no-eff-email \
    --email your-email@example.com \
    $DOMAINS

echo ""
echo "Done"
echo ""
echo "Certificates saved to: /etc/letsencrypt/live/$1/"
echo ""
echo "Update nginx config to use:"
echo "  ssl_certificate /etc/letsencrypt/live/$1/fullchain.pem;"
echo "  ssl_certificate_key /etc/letsencrypt/live/$1/privkey.pem;"
