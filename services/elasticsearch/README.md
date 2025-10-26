# Elasticsearch

Search and analytics engine.

## Quick Start

```bash
nano .env      # Set password
./start.sh     # Start Elasticsearch
```

Access: `http://localhost:9200`

## Test Connection

```bash
# Check status
curl -u elastic:password http://localhost:9200

# Health check
curl -u elastic:password http://localhost:9200/_cluster/health
```

## Create Index

```bash
# Create index
curl -X PUT -u elastic:password \
  http://localhost:9200/myindex

# Add document
curl -X POST -u elastic:password \
  -H "Content-Type: application/json" \
  http://localhost:9200/myindex/_doc \
  -d '{"name": "test", "value": 123}'
```

## Search

```bash
# Search all
curl -u elastic:password \
  http://localhost:9200/myindex/_search

# Search with query
curl -u elastic:password \
  -H "Content-Type: application/json" \
  http://localhost:9200/myindex/_search \
  -d '{"query": {"match": {"name": "test"}}}'
```

## Backup

```bash
# Backup to snapshot
curl -X PUT -u elastic:password \
  http://localhost:9200/_snapshot/my_backup/snapshot_1?wait_for_completion=true
```

## Configuration

Default: 512MB heap size (`ES_JAVA_OPTS=-Xms512m -Xmx512m`)

For production, increase in docker-compose.yml:
```yaml
environment:
  - "ES_JAVA_OPTS=-Xms2g -Xmx2g"
```

## Connection

From apps:
```
http://elastic:password@localhost:9200
```

From Docker containers:
```
http://elastic:password@elasticsearch:9200
```

## Kibana (Optional)

To add visualization, create `services/kibana`:
```yaml
services:
  kibana:
    image: docker.elastic.co/kibana/kibana:8.11.0
    ports:
      - "5601:5601"
    environment:
      - ELASTICSEARCH_HOSTS=http://elasticsearch:9200
      - ELASTICSEARCH_USERNAME=elastic
      - ELASTICSEARCH_PASSWORD=yourpass
```

## More Info

[Elasticsearch Documentation](https://www.elastic.co/guide/)
