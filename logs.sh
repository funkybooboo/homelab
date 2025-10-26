#!/bin/bash

# View logs for a specific service

if [ -z "$1" ]; then
    echo "Usage: ./logs.sh <service-name>"
    echo ""
    echo "Available services:"
    ls -1 services/
    exit 1
fi

SERVICE="$1"

if [ ! -d "services/$SERVICE" ]; then
    echo "Error: Service '$SERVICE' not found"
    echo ""
    echo "Available services:"
    ls -1 services/
    exit 1
fi

echo "Viewing logs for $SERVICE..."
echo "Press Ctrl+C to exit"
echo ""

cd "services/$SERVICE" || exit
docker compose logs -f
