# MusicBrainz ARM64 Replication - Quick Reference

## Setup Commands

```bash
# Start containers
docker compose up -d

# Automated setup (recommended)
./scripts/setup-replication.sh

# Manual setup
mkdir -p local/secrets
echo 'YOUR_TOKEN' > local/secrets/metabrainz_access_token
chmod 600 local/secrets/metabrainz_access_token
```

## Replication Commands

```bash
# Start replication
docker compose exec musicbrainz-minimal replication.sh &

# Check status
docker compose exec musicbrainz-minimal ps aux | grep LoadReplication

# View logs
docker compose exec musicbrainz-minimal tail -f logs/replication.log
```

## Database Commands

```bash
# Connect to database
docker compose exec musicbrainz-minimal bash -c 'PGHOST=db PGPORT=5432 PGPASSWORD=musicbrainz psql -U musicbrainz -d musicbrainz_db'

# Check replication data
docker compose exec musicbrainz-minimal bash -c 'PGHOST=db PGPORT=5432 PGPASSWORD=musicbrainz psql -U musicbrainz -d musicbrainz_db -c "SELECT COUNT(*) FROM dbmirror2.pending_data;"'

# Check replication tables
docker compose exec musicbrainz-minimal bash -c 'PGHOST=db PGPORT=5432 PGPASSWORD=musicbrainz psql -U musicbrainz -d musicbrainz_db -c "\dt dbmirror2.*"'
```

## Troubleshooting Commands

```bash
# Install missing dependencies
docker compose exec --user root musicbrainz-minimal apt install -y libgnupg-perl libredis-perl

# Setup replication tables
docker compose exec musicbrainz-minimal bash -c 'PGHOST=db PGPORT=5432 PGPASSWORD=musicbrainz psql -U musicbrainz -d musicbrainz_db -f /musicbrainz-server/admin/sql/dbmirror2/ReplicationSetup.sql'

# Test replication
docker compose exec musicbrainz-minimal bash -c 'cd /musicbrainz-server && PGHOST=db PGPORT=5432 PGPASSWORD=musicbrainz timeout 60 ./admin/replication/LoadReplicationChanges'
```

## Container Management

```bash
# Restart containers
docker compose restart

# Stop containers
docker compose down

# View container logs
docker compose logs musicbrainz-minimal
```

## Files to Know

- `docker-compose.yml` - Main ARM64 optimized configuration
- `scripts/setup-replication.sh` - Automated setup script
- `local/secrets/metabrainz_access_token` - Your MetaBrainz token
- `logs/replication.log` - Replication progress logs
- `REPLICATION-SETUP-GUIDE.md` - Detailed documentation
