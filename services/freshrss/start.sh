#!/bin/bash
cd "$(dirname "$0")"
echo "Starting $(basename $(pwd))..."
docker compose up -d
