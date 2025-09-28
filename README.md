# MusicBrainz ARM64 Replication Setup

A minimal Docker setup for running MusicBrainz database replication on ARM64 devices (Raspberry Pi, ARM servers, etc.).

## What This Does

This setup provides:
- **PostgreSQL database** with MusicBrainz data
- **Live replication** from MusicBrainz servers
- **Minimal resource usage** optimized for ARM64
- **Direct database access** for queries and applications

**What's NOT included:** Web interface, search engine, or full MusicBrainz server (database access only).

## Requirements

- ARM64 device (Raspberry Pi 4+ recommended)
- 2GB+ RAM (4GB+ recommended)
- 10GB+ free storage
- Docker and Docker Compose
- MetaBrainz account (free at https://metabrainz.org)

## Quick Start

### 1. Clone and Setup
```bash
git clone <this-repository>
cd musicbrainz-docker
```

### 2. Get MetaBrainz Token
1. Go to https://metabrainz.org/account/applications
2. Create an application and copy the 40-character token

### 3. Configure Environment
```bash
cp env.example .env
nano .env  # Set your REPLICATION_ACCESS_TOKEN
```

### 4. Launch
```bash
# Start containers
docker compose up -d

# Run setup (creates database and starts replication)
./scripts/setup-replication.sh
```

### 5. Verify
```bash
# Check replication status
docker compose exec musicbrainz-minimal tail -f logs/replication.log

# Test database access
docker compose exec db psql -U musicbrainz -d musicbrainz_db -c "SELECT COUNT(*) FROM artist;"
```

## Usage

### Database Access
- **Host:** localhost
- **Port:** 5432
- **Database:** musicbrainz_db
- **User:** musicbrainz
- **Password:** musicbrainz

### Common Commands
```bash
# View logs
docker compose logs -f

# Stop services
docker compose down

# Restart replication
docker compose exec musicbrainz-minimal replication.sh &

# Check system status
docker compose ps
```

## Storage Paths

Data is stored in:
- **Database:** `/mnt/storage/musicbrainz-docker-arm/postgres-data`
- **Dumps:** `/mnt/storage/musicbrainz/dbdump`
- **Logs:** `./logs`

## Troubleshooting

### Container won't start
```bash
# Check logs
docker compose logs

# Check system resources
free -h && df -h
```

### Replication issues
```bash
# Check replication log
docker compose exec musicbrainz-minimal tail -f logs/replication.log

# Restart replication
docker compose restart musicbrainz-replication
```

### Database connection issues
```bash
# Test connection
docker compose exec db psql -U musicbrainz -d musicbrainz_db -c "SELECT 1;"
```

## Components

- **PostgreSQL 16** - Database server
- **Redis 3** - Caching layer
- **MusicBrainz Minimal** - Replication scripts only

## Configuration Options

You can customize the setup using Docker Compose overrides in the `compose/` directory:

- **`arm64-optimization.yml`** - ARM64 specific memory optimizations
- **`rpi-memory-optimized.yml`** - Ultra-low memory settings for Raspberry Pi
- **`replication-cron.yml`** - Automated replication scheduling
- **`replication-token.yml`** - Token-based authentication for replication
- **`publishing-db-port.yml`** - Expose database port for external access

Example usage:
```bash
# Use memory optimization for low-RAM systems
echo "COMPOSE_FILE=docker-compose.yml:compose/rpi-memory-optimized.yml" > .env

# Enable automated replication scheduling
echo "COMPOSE_FILE=docker-compose.yml:compose/replication-cron.yml" > .env
```

## Performance Notes

- Optimized for ARM64 with reduced memory usage
- Database uses 512MB shared buffers
- Containers have memory limits to prevent system overload
- Replication runs continuously in background

For detailed troubleshooting, see `TROUBLESHOOTING.md`.