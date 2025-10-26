#!/bin/bash
cd "$(dirname "$0")"
echo "Restarting $(basename $(pwd))..."
docker compose restart
