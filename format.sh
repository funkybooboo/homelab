#!/bin/bash

# Format bash scripts and YAML files

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Check if shfmt is installed
if ! command -v shfmt &> /dev/null; then
    echo "shfmt not found. Installing..."
    wget -qO /tmp/shfmt https://github.com/mvdan/sh/releases/download/v3.8.0/shfmt_v3.8.0_linux_amd64
    chmod +x /tmp/shfmt
    sudo mv /tmp/shfmt /usr/local/bin/shfmt
    echo "shfmt installed"
fi

# Check if prettier is installed
if ! command -v prettier &> /dev/null; then
    echo "prettier not found. Installing..."
    sudo npm install -g prettier
    echo "prettier installed"
fi

echo "=== Formatting Shell Scripts ==="
shfmt -w -i 4 -ci -bn .

echo ""
echo "=== Formatting YAML Files ==="
find services -name "docker-compose.yml" -o -name "*.yaml" -o -name "*.yml" | while read -r file; do
    echo "Formatting $file"
    prettier --write --tab-width 2 "$file"
done

find .github -name "*.yml" -o -name "*.yaml" | while read -r file; do
    echo "Formatting $file"
    prettier --write --tab-width 2 "$file"
done

echo ""
echo "Done"
