# MongoDB

NoSQL document database.

## Quick Start

```bash
nano .env      # Set password
./start.sh     # Start MongoDB
```

Access: `localhost:27017`

## Connection

```bash
# Connect with mongosh
docker compose exec mongodb mongosh -u admin -p your_password

# Or from host (if mongosh installed)
mongosh mongodb://admin:password@localhost:27017
```

## Create Database

```javascript
// In mongosh
use myapp
db.createUser({
  user: "myuser",
  pwd: "password",
  roles: [{role: "readWrite", db: "myapp"}]
})
```

## Backup

```bash
# Backup database
docker compose exec mongodb mongodump --username admin --password yourpass --out /data/backup

# Backup to host
docker compose exec mongodb mongodump --username admin --password yourpass --archive | gzip > backup.gz
```

## Restore

```bash
# Restore from host
gunzip -c backup.gz | docker compose exec -T mongodb mongorestore --username admin --password yourpass --archive
```

## Common Operations

```bash
# List databases
docker compose exec mongodb mongosh -u admin -p password --eval "show dbs"

# List collections
docker compose exec mongodb mongosh -u admin -p password mydb --eval "show collections"
```

## Connection String

For apps:
```
mongodb://admin:password@localhost:27017/database?authSource=admin
```

For other Docker containers:
```
mongodb://admin:password@mongodb:27017/database?authSource=admin
```

## More Info

[MongoDB Documentation](https://docs.mongodb.com/)
