# MusicBrainz Replication Setup Guide for ARM64

This guide provides step-by-step instructions for setting up MusicBrainz replication on ARM64 systems (Raspberry Pi, ARM servers, etc.).

## Prerequisites

- Docker and Docker Compose installed
- ARM64 compatible system
- MetaBrainz account (free registration at https://metabrainz.org)
- At least 2GB RAM (4GB+ recommended)
- At least 10GB free disk space

## Quick Start

1. **Clone and setup the repository:**
   ```bash
   git clone <repository-url>
   cd musicbrainz-docker-arm
   ```

2. **Start the containers:**
   ```bash
   docker compose up -d
   ```

3. **Run the automated setup script:**
   ```bash
   ./scripts/setup-replication.sh
   ```

4. **Start replication:**
   ```bash
   docker compose exec musicbrainz-minimal replication.sh &
   ```

## Manual Setup (Alternative)

If you prefer to set up replication manually or need to troubleshoot:

### Step 1: Get MetaBrainz Access Token

1. Go to https://metabrainz.org/account/applications
2. Log in with your MetaBrainz account (create one if needed)
3. Create a new application or use an existing one
4. Copy the 40-character access token

### Step 2: Create Token File

```bash
mkdir -p local/secrets
echo 'YOUR_40_CHARACTER_TOKEN_HERE' > local/secrets/metabrainz_access_token
chmod 600 local/secrets/metabrainz_access_token
```

### Step 3: Install Missing Dependencies

```bash
docker compose exec --user root musicbrainz-minimal apt update
docker compose exec --user root musicbrainz-minimal apt install -y libgnupg-perl libredis-perl
```

### Step 4: Configure Replication

```bash
# Set replication type to MIRROR
docker compose exec musicbrainz-minimal sed -i "s/# sub REPLICATION_TYPE { RT_STANDALONE }/sub REPLICATION_TYPE { RT_MIRROR }/" /musicbrainz-server/lib/DBDefs.pm

# Set access token
TOKEN=$(cat local/secrets/metabrainz_access_token | tr -d '\n')
docker compose exec musicbrainz-minimal sed -i "s/# sub REPLICATION_ACCESS_TOKEN { '' }/sub REPLICATION_ACCESS_TOKEN { '$TOKEN' }/" /musicbrainz-server/lib/DBDefs.pm
```

### Step 5: Setup Database Tables

```bash
docker compose exec musicbrainz-minimal bash -c 'PGHOST=db PGPORT=5432 PGPASSWORD=musicbrainz psql -U musicbrainz -d musicbrainz_db -f /musicbrainz-server/admin/sql/dbmirror2/ReplicationSetup.sql'
```

### Step 6: Start Replication

```bash
docker compose exec musicbrainz-minimal replication.sh &
```

## Monitoring Replication

### Check Replication Status

```bash
# View replication logs
docker compose exec musicbrainz-minimal tail -f logs/replication.log

# Check if replication process is running
docker compose exec musicbrainz-minimal ps aux | grep LoadReplication

# Check replication data
docker compose exec musicbrainz-minimal bash -c 'PGHOST=db PGPORT=5432 PGPASSWORD=musicbrainz psql -U musicbrainz -d musicbrainz_db -c "SELECT COUNT(*) FROM dbmirror2.pending_data;"'
```

### Check Database Status

```bash
# Connect to database
docker compose exec musicbrainz-minimal bash -c 'PGHOST=db PGPORT=5432 PGPASSWORD=musicbrainz psql -U musicbrainz -d musicbrainz_db'

# Check replication tables
\dt dbmirror2.*

# Check replication sequence
SELECT * FROM dbmirror2.pending_ts ORDER BY ts DESC LIMIT 5;
```

## Troubleshooting

### Common Issues

1. **"This is not a mirror server!"**
   - Ensure `REPLICATION_TYPE` is set to `RT_MIRROR` in DBDefs.pm
   - Check that the access token is properly configured

2. **"Invalid or missing REPLICATION_ACCESS_TOKEN"**
   - Verify the token is exactly 40 characters
   - Check that the token is properly set in DBDefs.pm

3. **"Can't locate GnuPG.pm"**
   - Install missing Perl modules:
     ```bash
     docker compose exec --user root musicbrainz-minimal apt install -y libgnupg-perl libredis-perl
     ```

4. **Database connection issues**
   - Ensure PostgreSQL environment variables are set:
     ```bash
     export PGHOST=db PGPORT=5432 PGPASSWORD=musicbrainz
     ```

5. **"relation dbmirror2.pending_data does not exist"**
   - Run the replication setup SQL:
     ```bash
     docker compose exec musicbrainz-minimal bash -c 'PGHOST=db PGPORT=5432 PGPASSWORD=musicbrainz psql -U musicbrainz -d musicbrainz_db -f /musicbrainz-server/admin/sql/dbmirror2/ReplicationSetup.sql'
     ```

### Log Files

- Replication logs: `logs/replication.log` (inside container)
- Container logs: `docker compose logs musicbrainz-minimal`

### Performance Optimization

For Raspberry Pi or low-memory systems:

1. **Memory optimization:**
   ```bash
   # Use memory-optimized compose file
   docker compose -f compose/rpi-memory-optimized.yml up -d
   ```

2. **Database tuning:**
   - Reduce `shared_buffers` in PostgreSQL configuration
   - Limit `max_connections` to reduce memory usage

## Configuration Files

### Key Files Modified

- `build/musicbrainz-minimal/Dockerfile` - Added required Perl dependencies
- `build/musicbrainz-minimal/scripts/replication.sh` - Fixed environment variables
- `build/musicbrainz-minimal/scripts/DBDefs.pm` - Configured for replication
- `compose/db-minimal-arm64.yml` - ARM64 optimized configuration

### Environment Variables

- `MUSICBRAINZ_POSTGRES_SERVER=db`
- `MUSICBRAINZ_POSTGRES_PORT=5432`
- `MUSICBRAINZ_POSTGRES_DATABASE=musicbrainz_db`
- `POSTGRES_USER=musicbrainz`
- `POSTGRES_PASSWORD=musicbrainz`

## Security Notes

- Keep your MetaBrainz access token secure
- The token file has restricted permissions (600)
- Never commit the token to version control
- Rotate the token periodically for security

## Support

For issues specific to this ARM64 setup:
- Check the troubleshooting section above
- Review container logs for error messages
- Ensure all dependencies are properly installed

For MusicBrainz replication issues:
- Consult the official MusicBrainz documentation
- Check MetaBrainz community forums
- Review the replication logs for specific error messages
