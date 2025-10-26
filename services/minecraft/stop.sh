#!/bin/bash
cd "$(dirname "$0")" || exit
echo "Stopping $(basename "$(pwd)")..."
docker compose down
