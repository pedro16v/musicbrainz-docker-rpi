# MusicBrainz Minimal ARM64 Deployment Guide

This guide provides step-by-step instructions for deploying the minimal ARM64 MusicBrainz setup on any ARM device.

## Prerequisites

### Hardware Requirements
- ARM64 device (Raspberry Pi 4+ recommended)
- At least 2GB RAM (4GB+ recommended)
- At least 8GB free disk space
- Network connectivity for downloading data dumps

### Software Requirements
- Docker and Docker Compose installed
- Git installed
- User with sudo privileges

## Quick Deployment

### 1. Clone the Repository
```bash
git clone https://github.com/pedro16v/musicbrainz-docker-rpi.git musicbrainz-docker-arm
cd musicbrainz-docker-arm
git checkout minimal-arm64-setup
```

### 2. Configure Environment
```bash
echo 'COMPOSE_FILE=compose/db-minimal-arm64.yml:compose/arm64-optimization.yml' > .env
```

### 3. Create Host Directory for Data Dumps
```bash
sudo mkdir -p /mnt/storage/musicbrainz/dbdump
sudo chown $USER:$USER /mnt/storage/musicbrainz/dbdump
```

### 4. Build and Start Containers
```bash
docker compose build
docker compose up -d
```

### 5. Import Sample Data
```bash
docker compose run --rm -e PGPASSWORD=musicbrainz -e PGHOST=db musicbrainz-minimal createdb.sh -sample
```

## What's Included

### Services
- **PostgreSQL Database** (port 5432) - Core MusicBrainz database
- **Redis** (port 6379) - Essential caching layer
- **MusicBrainz-minimal** - Container for replication scripts only

### What's NOT Included
- Solr (full-text search) - Not needed for direct database queries
- RabbitMQ (message queue) - Only needed for live indexing
- MusicBrainz Web Server - Not needed for database-only usage
- Search Index Rebuilder - Not needed without Solr

## Database Access

### Connection Details
- **Host**: localhost
- **Port**: 5432
- **Database**: musicbrainz_db
- **Username**: musicbrainz
- **Password**: musicbrainz

### Example Queries
```sql
-- Count artists
SELECT COUNT(*) FROM artist;

-- Search for artists
SELECT name FROM artist WHERE name LIKE '%Beatles%' LIMIT 5;

-- Count releases
SELECT COUNT(*) FROM release;
```

## Data Management

### Sample Data
The sample data includes:
- 273,925 artists
- 38,902 releases
- 2,928,269 recordings
- 277,756 works
- Total: 26+ million rows across 237 tables

### Full Data Import
To import full data instead of sample data:
```bash
docker compose run --rm -e PGPASSWORD=musicbrainz -e PGHOST=db musicbrainz-minimal createdb.sh -fetch
```

### Data Dumps Location
Data dumps are stored in: `/mnt/storage/musicbrainz/dbdump`

## Troubleshooting

### Common Issues

#### 1. Port Conflicts
If port 5432 is already in use:
```bash
sudo systemctl stop postgresql
```

#### 2. Permission Issues
Ensure the data dump directory has correct permissions:
```bash
sudo chown -R $USER:$USER /mnt/storage/musicbrainz/dbdump
```

#### 3. Memory Issues
If running out of memory, reduce resource limits in `compose/arm64-optimization.yml`:
```yaml
services:
  db:
    deploy:
      resources:
        limits:
          memory: 256MB  # Reduce from 512MB
```

### Logs
Check container logs:
```bash
docker compose logs db
docker compose logs redis
docker compose logs musicbrainz-minimal
```

### Container Status
```bash
docker compose ps
```

## Maintenance

### Updating Data
To update with latest data dumps:
```bash
docker compose run --rm -e PGPASSWORD=musicbrainz -e PGHOST=db musicbrainz-minimal fetch-dump.sh replica
```

### Backup Database
```bash
docker compose exec db pg_dump -U musicbrainz musicbrainz_db > backup.sql
```

### Restore Database
```bash
docker compose exec -T db psql -U musicbrainz musicbrainz_db < backup.sql
```

## Resource Usage

### Typical Resource Consumption
- **PostgreSQL**: ~256-512MB RAM
- **Redis**: ~32-64MB RAM
- **MusicBrainz-minimal**: ~64-128MB RAM
- **Total**: ~400-700MB RAM

### Disk Usage
- **Sample Data**: ~2-3GB
- **Full Data**: ~50-100GB
- **Container Images**: ~1-2GB

## Security Notes

- Default passwords are used for simplicity
- For production use, change all default passwords
- Consider using Docker secrets for sensitive data
- Ensure proper firewall configuration

## Support

For issues or questions:
1. Check the troubleshooting section above
2. Review container logs
3. Ensure all prerequisites are met
4. Verify ARM64 compatibility

## Version Information

- **MusicBrainz Server**: v-2025-08-11.0
- **PostgreSQL**: 16-bookworm
- **Redis**: 3-alpine
- **Base Image**: Ubuntu 22.04
