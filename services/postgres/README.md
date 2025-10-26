# PostgreSQL Database

Standalone PostgreSQL database server for use with other applications.

## Quick Start

```bash
# Configure credentials
nano .env

# Start database
./start.sh
```

Access: `localhost:5432`

## Connection

```bash
# Connect with psql
docker compose exec postgres psql -U postgres

# Or from host (if psql installed)
psql -h localhost -U postgres -d postgres
```

## Create Databases

### Via psql
```sql
CREATE DATABASE myapp;
CREATE USER myuser WITH PASSWORD 'password';
GRANT ALL PRIVILEGES ON DATABASE myapp TO myuser;
```

### Via init scripts
Place `.sql` or `.sh` files in `init/` directory. They run on first startup.

Example `init/01-create-db.sql`:
```sql
CREATE DATABASE myapp;
```

## Backup

```bash
# Backup single database
docker compose exec postgres pg_dump -U postgres mydb > backup.sql

# Backup all databases
docker compose exec postgres pg_dumpall -U postgres > backup-all.sql
```

## Restore

```bash
# Restore database
docker compose exec -T postgres psql -U postgres mydb < backup.sql

# Restore all
docker compose exec -T postgres psql -U postgres < backup-all.sql
```

## Common Operations

```bash
# List databases
docker compose exec postgres psql -U postgres -c "\l"

# List tables in database
docker compose exec postgres psql -U postgres -d mydb -c "\dt"

# Execute SQL
docker compose exec postgres psql -U postgres -c "SELECT version();"
```

## Connection from Other Services

Use these connection details in other apps:

- **Host**: `postgres` (or `localhost` from host)
- **Port**: `5432`
- **User**: From `.env` POSTGRES_USER
- **Password**: From `.env` POSTGRES_PASSWORD
- **Database**: Your database name

## Performance Tuning

For production use, consider tuning in docker-compose.yml:

```yaml
command:
  - "postgres"
  - "-c"
  - "max_connections=200"
  - "-c"
  - "shared_buffers=256MB"
```

## More Info

[PostgreSQL Documentation](https://www.postgresql.org/docs/)
