# Development

Guide for contributing and maintaining code quality.

## Code Quality

### Linting and Formatting

**Local Development:**

Format bash scripts and YAML files:
```bash
./format.sh
```

Lint bash scripts, YAML files, Dockerfiles, and Docker Compose files:
```bash
./lint.sh
```

**CI/CD:**

GitHub Actions automatically runs on push and pull requests:
- ShellCheck - Lints bash scripts for errors and best practices
- shfmt - Checks bash script formatting
- yamllint - Lints YAML files (docker-compose.yml, workflow files)
- hadolint - Lints Dockerfiles (if present)
- docker compose config - Validates Docker Compose syntax

See `.github/workflows/ci.yml`

### Tools

**ShellCheck**
- Catches common bash errors
- Suggests best practices
- Checks portability issues

Install:
```bash
sudo apt-get install shellcheck
```

**shfmt**
- Formats bash scripts consistently
- Uses 4-space indentation
- Binary install (format.sh does this automatically)

Manual install:
```bash
wget -qO /tmp/shfmt https://github.com/mvdan/sh/releases/download/v3.8.0/shfmt_v3.8.0_linux_amd64
chmod +x /tmp/shfmt
sudo mv /tmp/shfmt /usr/local/bin/shfmt
```

**hadolint**
- Lints Dockerfiles
- Checks best practices and security

Install:
```bash
wget -qO /tmp/hadolint https://github.com/hadolint/hadolint/releases/download/v2.12.0/hadolint-Linux-x86_64
chmod +x /tmp/hadolint
sudo mv /tmp/hadolint /usr/local/bin/hadolint
```

**yamllint**
- Lints YAML files
- Checks syntax and formatting
- Validates indentation and line length

Install:
```bash
pip install --user yamllint
```

**prettier**
- Formats YAML files consistently
- Auto-formats to 2-space indentation
- Handles docker-compose.yml and workflow files

Install:
```bash
sudo npm install -g prettier
```

## Style Guide

### Bash Scripts

**Formatting:**
- 4-space indentation
- Use `#!/bin/bash` shebang
- Enable strict mode: `set -e`
- Use lowercase for variables, UPPERCASE for constants
- Quote variables: `"$var"` not `$var`

**Structure:**
```bash
#!/bin/bash

# Script description

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Constants
readonly CONSTANT_VALUE="value"

# Variables
variable_name="value"

# Functions
function_name() {
    local param="$1"
    echo "$param"
}

# Main logic
main() {
    function_name "value"
}

main "$@"
```

**Common Patterns:**

Get script directory:
```bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
```

Check command exists:
```bash
if ! command -v docker &> /dev/null; then
    echo "docker not found"
    exit 1
fi
```

Read user input:
```bash
read -p "Continue? (y/n): " confirm
if [ "$confirm" != "y" ]; then
    exit 0
fi
```

Iterate array:
```bash
services=("n8n" "gitea" "ollama")
for service in "${services[@]}"; do
    echo "$service"
done
```

### Docker Compose

**Formatting:**
- 2-space indentation
- Service name matches container name
- Always use `restart: unless-stopped`
- Use `env_file` over `environment` when possible
- Create dedicated networks

**Structure:**
```yaml
services:
  servicename:
    image: org/image:tag
    container_name: servicename
    restart: unless-stopped
    ports:
      - "8080:8080"
    volumes:
      - ./data:/data
    env_file:
      - .env
    networks:
      - servicename_network

networks:
  servicename_network:
    driver: bridge
```

### Environment Files

**Formatting:**
- UPPERCASE variable names
- Group related variables
- Comment each variable
- Provide sensible defaults in .env.example

**Structure:**
```bash
# Service Configuration
PORT=8080
HOST=0.0.0.0

# Authentication
ADMIN_USER=admin
ADMIN_PASSWORD=changeme

# Database
DB_HOST=postgres
DB_PORT=5432
DB_NAME=mydb
```

## Testing

**Test scripts:**
```bash
# Test syntax
bash -n script.sh

# Test with shellcheck
shellcheck script.sh

# Test execution
bash -x script.sh  # Debug mode
```

**Test services:**
```bash
# Start service
cd services/myservice
./start.sh

# Check logs
docker compose logs -f

# Test endpoints
curl http://localhost:8080

# Stop service
./stop.sh
```

## Git Workflow

**Branches:**
- `main` - Production-ready code, stable releases
- `dev` - Development branch, integration testing
- Feature branches - `feature/name` (merge to dev)
- Bugfix branches - `bugfix/name` (merge to dev)

**Workflow:**
1. Create feature branch from `dev`
2. Make changes and commit
3. Create PR to `dev` branch
4. CI runs automatically on push
5. After testing in `dev`, merge to `main`

**Commits:**
- Use present tense: "Add feature" not "Added feature"
- Keep commits atomic (one logical change)
- Write descriptive messages

**Pull Requests:**
- Target `dev` for new features
- Target `main` for hotfixes (rare)
- CI must pass (shellcheck, shfmt, hadolint)
- Test locally before submitting
- Update documentation if needed

## Troubleshooting

**Format script fails:**
```bash
# Manual format
shfmt -w -i 4 -ci -bn script.sh
```

**Lint errors:**
```bash
# Ignore specific error
# shellcheck disable=SC2034
unused_var="value"
```

**CI fails locally passes:**
- Check shfmt version matches CI (v3.8.0)
- Check shellcheck version
- Run in clean directory
