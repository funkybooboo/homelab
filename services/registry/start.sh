#!/bin/bash
cd "$(dirname "$0")" || exit
echo "Starting $(basename "$(pwd)")..."
docker compose up -d
