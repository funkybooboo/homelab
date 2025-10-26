#!/bin/bash
cd "$(dirname "$0")"
echo "Stopping $(basename $(pwd))..."
docker compose down
