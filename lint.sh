#!/bin/bash

# Lint bash scripts, YAML files, and Docker files

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Check if shellcheck is installed
if ! command -v shellcheck &>/dev/null; then
    echo "shellcheck not found. Installing..."
    sudo apt-get update
    sudo apt-get install -y shellcheck
    echo "shellcheck installed"
fi

# Check if yamllint is installed
if ! command -v yamllint &>/dev/null; then
    echo "yamllint not found. Installing..."
    pip install --user yamllint
    echo "yamllint installed"
fi

# Check if hadolint is installed
if ! command -v hadolint &>/dev/null; then
    echo "hadolint not found. Installing..."
    wget -qO /tmp/hadolint https://github.com/hadolint/hadolint/releases/download/v2.12.0/hadolint-Linux-x86_64
    chmod +x /tmp/hadolint
    sudo mv /tmp/hadolint /usr/local/bin/hadolint
    echo "hadolint installed"
fi

echo "=== Linting Shell Scripts ==="
echo ""
find . -name "*.sh" -not -path "./.git/*" | while read -r script; do
    echo "Checking $script"
    shellcheck "$script" || true
done

echo ""
echo "=== Linting YAML Files ==="
echo ""
cat >.yamllint <<EOF
extends: default
rules:
  line-length:
    max: 120
  indentation:
    spaces: 2
  comments:
    min-spaces-from-content: 1
EOF

find services -name "docker-compose.yml" | while read -r file; do
    echo "Checking $file"
    yamllint "$file" || true
done

yamllint .github/ 2>/dev/null || true

echo ""
echo "=== Linting Dockerfiles ==="
echo ""
if find services -name "Dockerfile" -o -name "Dockerfile.*" | grep -q .; then
    find services -name "Dockerfile" -o -name "Dockerfile.*" | while read -r file; do
        echo "Checking $file"
        hadolint "$file" || true
    done
else
    echo "No Dockerfiles found"
fi

echo ""
echo "=== Validating Docker Compose ==="
echo ""
find services -name "docker-compose.yml" | while read -r file; do
    dir=$(dirname "$file")
    echo "Validating $file"
    cd "$dir"
    docker compose config --quiet || echo "  Error in $file"
    cd "$SCRIPT_DIR"
done

rm -f .yamllint
echo ""
echo "Done"
