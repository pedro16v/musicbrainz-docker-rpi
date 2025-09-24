# MusicBrainz Minimal ARM64 Setup

This setup provides a minimal MusicBrainz database with replication capabilities, optimized for ARM64 devices (like Raspberry Pi). It includes only the essential services needed for database operations and replication.

## What's Included

- **PostgreSQL Database**: Core MusicBrainz database
- **Redis**: Essential caching layer (required by MusicBrainz)
- **Minimal MusicBrainz Container**: For replication scripts only

## What's NOT Included

- **Solr**: Full-text search engine (not needed for direct database queries)
- **RabbitMQ**: Message queue (only needed for live indexing)
- **MusicBrainz Web Server**: Web application (not needed for database-only usage)
- **Search Index Rebuilder**: Not needed without Solr

## Prerequisites

### Hardware Requirements
- ARM64 device (Raspberry Pi 4+ recommended)
- At least 2GB RAM (4GB+ recommended)
- At least 100GB storage (350GB for full data)
- Fast storage (SSD recommended over microSD)

### Software Requirements
- Docker and Docker Compose v2
- Git
- Host directory `/mnt/storage/musicbrainz/dbdump` for data dumps

## Quick Start

1. **Configure for minimal setup:**
   ```bash
   admin/configure add compose/db-minimal-arm64.yml
   ```

2. **Build images:**
   ```bash
   docker compose build
   ```

3. **Create database with sample data (for testing):**
   ```bash
   docker compose run --rm musicbrainz-minimal createdb.sh -sample -fetch
   ```

4. **Start services:**
   ```bash
   docker compose up -d
   ```

5. **Connect to database:**
   ```bash
   psql -h localhost -p 5432 -U musicbrainz -d musicbrainz_db
   ```

## Full Data Setup

For production use with full MusicBrainz data:

1. **Create database with full data:**
   ```bash
   docker compose run --rm musicbrainz-minimal createdb.sh -fetch
   ```

2. **Set up replication token:**
   ```bash
   admin/set-replication-token
   ```

3. **Run replication once:**
   ```bash
   docker compose exec musicbrainz-minimal replication.sh
   ```

4. **Schedule replication (optional):**
   ```bash
   admin/configure add replication-cron
   docker compose up -d
   ```

## ARM64 Optimizations

For better performance on ARM devices, use the optimization compose file:

```bash
admin/configure add compose/arm64-optimization.yml
docker compose up -d
```

This reduces memory usage and optimizes PostgreSQL settings for ARM64.

## Resource Usage

### Default Setup
- **Total RAM**: ~1GB
- **PostgreSQL**: 512MB-1GB
- **Redis**: 64MB-128MB
- **MusicBrainz-minimal**: 64MB-128MB

### With ARM64 Optimizations
- **Total RAM**: ~512MB
- **PostgreSQL**: 256MB-512MB
- **Redis**: 32MB-64MB
- **MusicBrainz-minimal**: 32MB-64MB

## Volume Mapping

Data dumps are stored on the host at:
- `/mnt/storage/musicbrainz/dbdump` → `/media/dbdump` (in containers)

Make sure this directory exists and has sufficient space:
```bash
sudo mkdir -p /mnt/storage/musicbrainz/dbdump
sudo chown $USER:$USER /mnt/storage/musicbrainz/dbdump
```

## Database Access

### Direct PostgreSQL Access
```bash
# Connect to database
psql -h localhost -p 5432 -U musicbrainz -d musicbrainz_db

# Example queries
SELECT COUNT(*) FROM artist;
SELECT name FROM artist WHERE name ILIKE '%beatles%' LIMIT 5;
```

### Redis Access (if needed)
```bash
# Connect to Redis
redis-cli -h localhost -p 6379

# Check Redis info
redis-cli -h localhost -p 6379 INFO
```

## Replication Management

### Manual Replication
```bash
# Run replication once
docker compose exec musicbrainz-minimal replication.sh

# Check replication logs
docker compose exec musicbrainz-minimal tail -f logs/replication.log
```

### Scheduled Replication
```bash
# Enable scheduled replication (daily at 3 AM UTC)
admin/configure add replication-cron
docker compose up -d

# Check cron status
docker compose exec musicbrainz-minimal crontab -l
```

## Monitoring

### Check Container Status
```bash
docker compose ps
docker compose logs db
docker compose logs redis
docker compose logs musicbrainz-minimal
```

### Resource Usage
```bash
docker stats
```

### Database Size
```bash
docker compose exec db psql -U musicbrainz -d musicbrainz_db -c "SELECT pg_size_pretty(pg_database_size('musicbrainz_db'));"
```

## Troubleshooting

### Out of Memory
- Use ARM64 optimization compose file
- Reduce PostgreSQL shared_buffers
- Ensure sufficient swap space

### Slow Performance
- Use fast storage (SSD recommended)
- Increase PostgreSQL work_mem
- Check for I/O bottlenecks

### Replication Issues
- Verify replication token is set correctly
- Check network connectivity to MusicBrainz servers
- Review replication logs for errors

## Storage Requirements

- **Sample data**: ~1GB
- **Full data**: ~100GB
- **Replication**: Additional space for incremental updates
- **PostgreSQL data**: Additional space for database files

## Security Notes

- Database is exposed on port 5432 - consider firewall rules
- Redis is exposed on port 6379 - consider firewall rules
- Use strong passwords in production
- Consider using Docker secrets for sensitive data

## Performance Tips

1. **Use SSD storage** instead of microSD cards
2. **Increase GPU memory split** on Raspberry Pi: `gpu_mem=16` in `/boot/config.txt`
3. **Disable swap** or use zram for better performance
4. **Use high-quality power supply** (official Pi adapter recommended)
5. **Ensure adequate cooling** if overclocking

## Development

To modify the setup:

1. Edit compose files in `compose/` directory
2. Modify Dockerfiles in `build/musicbrainz-minimal/`
3. Test changes:
   ```bash
   docker compose down
   docker compose build
   docker compose up -d
   ```

## Support

For issues specific to this minimal setup, check:
- Container logs: `docker compose logs [service]`
- Database logs: `docker compose exec db tail -f /var/log/postgresql/postgresql-*.log`
- Replication logs: `docker compose exec musicbrainz-minimal tail -f logs/replication.log`
