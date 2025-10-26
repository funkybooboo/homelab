#!/bin/bash
cd "$(dirname "$0")" || exit
echo "Restarting $(basename "$(pwd)")..."
docker compose restart
