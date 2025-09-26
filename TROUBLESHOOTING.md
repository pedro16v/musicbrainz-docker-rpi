# MusicBrainz ARM64 Troubleshooting Guide

This guide helps you diagnose and fix common issues with MusicBrainz replication on ARM64 systems.

## 🚨 Quick Diagnostics

### Check System Status
```bash
# Check if containers are running
docker compose ps

# Check system resources
free -h && df -h

# Check port conflicts
netstat -tlnp | grep -E ':(5432|6379)'

# Check Docker status
systemctl status docker
```

### Check Replication Status
```bash
# Check if replication is running
docker compose exec musicbrainz-minimal ps aux | grep LoadReplication

# Check replication logs
docker compose exec musicbrainz-minimal tail -f logs/replication.log

# Check replication data
docker compose exec musicbrainz-minimal bash -c 'PGHOST=db PGPORT=5432 PGPASSWORD=musicbrainz psql -U musicbrainz -d musicbrainz_db -c "SELECT COUNT(*) FROM dbmirror2.pending_data;"'
```

## 🔧 Common Issues and Solutions

### 1. Container Startup Issues

#### Problem: Containers fail to start
**Symptoms:**
- `docker compose ps` shows containers as "Exited"
- Error messages about port conflicts or resource limits

**Solutions:**
```bash
# Check logs for specific errors
docker compose logs

# Check port conflicts
netstat -tlnp | grep -E ':(5432|6379)'

# If ports are in use, use different ports
export POSTGRES_EXTERNAL_PORT=5433
export REDIS_EXTERNAL_PORT=6380
docker compose up -d

# Check resource limits
docker stats

# Increase memory limits if needed
# Edit docker-compose.yml and increase memory limits
```

#### Problem: Database connection refused
**Symptoms:**
- `psql: error: connection to server on socket "/var/run/postgresql/.s.PGSQL.5432" failed`
- Database connection errors in logs

**Solutions:**
```bash
# Check if database container is running
docker compose ps db

# Check database logs
docker compose logs db

# Test database connection
docker compose exec musicbrainz-minimal bash -c 'PGHOST=db PGPORT=5432 PGPASSWORD=musicbrainz psql -U musicbrainz -d musicbrainz_db -c "SELECT 1;"'

# Restart database container
docker compose restart db
```

### 2. Replication Issues

#### Problem: "This is not a mirror server!"
**Symptoms:**
- Error message: `This is not a mirror server!`
- Replication fails to start

**Solutions:**
```bash
# Check replication type configuration
docker compose exec musicbrainz-minimal grep -A 2 REPLICATION_TYPE /musicbrainz-server/lib/DBDefs.pm

# Should show: sub REPLICATION_TYPE { RT_MIRROR }
# If not, reconfigure:
./scripts/setup-replication.sh
```

#### Problem: "Invalid or missing REPLICATION_ACCESS_TOKEN"
**Symptoms:**
- Error message: `Invalid or missing REPLICATION_ACCESS_TOKEN in DBDefs.pm`
- Replication fails to authenticate

**Solutions:**
```bash
# Check if token file exists
ls -la local/secrets/metabrainz_access_token

# Check token configuration
docker compose exec musicbrainz-minimal grep -A 2 REPLICATION_ACCESS_TOKEN /musicbrainz-server/lib/DBDefs.pm

# Reconfigure token
./scripts/setup-replication.sh
```

#### Problem: "Can't locate [Module].pm in @INC"
**Symptoms:**
- Error messages like `Can't locate aliased.pm in @INC`
- Perl module not found errors

**Solutions:**
```bash
# Install missing Perl modules
docker compose exec --user root musicbrainz-minimal cpanm aliased GnuPG Redis List::AllUtils

# Or rebuild container with updated Dockerfile
docker compose build musicbrainz-minimal
docker compose up -d
```

### 3. Database Issues

#### Problem: "relation 'dbmirror2.pending_data' does not exist"
**Symptoms:**
- Error message about missing replication tables
- Replication setup fails

**Solutions:**
```bash
# Create replication tables
docker compose exec musicbrainz-minimal bash -c 'PGHOST=db PGPORT=5432 PGPASSWORD=musicbrainz psql -U musicbrainz -d musicbrainz_db -f /musicbrainz-server/admin/sql/dbmirror2/ReplicationSetup.sql'

# Verify tables exist
docker compose exec musicbrainz-minimal bash -c 'PGHOST=db PGPORT=5432 PGPASSWORD=musicbrainz psql -U musicbrainz -d musicbrainz_db -c "\dt dbmirror2.*"'
```

#### Problem: Database connection timeout
**Symptoms:**
- Database connection hangs or times out
- Slow query performance

**Solutions:**
```bash
# Check database resource usage
docker stats db

# Check database configuration
docker compose exec db psql -U musicbrainz -d musicbrainz_db -c "SHOW shared_buffers;"
docker compose exec db psql -U musicbrainz -d musicbrainz_db -c "SHOW max_connections;"

# Increase memory limits if needed
# Edit docker-compose.yml and increase db memory limits
```

### 4. Performance Issues

#### Problem: Slow replication
**Symptoms:**
- Replication takes a long time to process changes
- High CPU/memory usage

**Solutions:**
```bash
# Check system resources
htop
free -h
df -h

# Check container resource usage
docker stats

# Optimize database settings
docker compose exec db psql -U musicbrainz -d musicbrainz_db -c "ALTER SYSTEM SET shared_buffers = '512MB';"
docker compose exec db psql -U musicbrainz -d musicbrainz_db -c "ALTER SYSTEM SET work_mem = '4MB';"
docker compose exec db psql -U musicbrainz -d musicbrainz_db -c "SELECT pg_reload_conf();"

# Restart containers
docker compose restart
```

#### Problem: High memory usage
**Symptoms:**
- System running out of memory
- Containers being killed by OOM killer

**Solutions:**
```bash
# Check memory usage
free -h
docker stats

# Add swap if not present
sudo fallocate -l 4G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile

# Reduce container memory limits
# Edit docker-compose.yml and reduce memory limits
```

### 5. Configuration Issues

#### Problem: Wrong environment configuration
**Symptoms:**
- Containers using wrong database host/port
- Configuration not matching environment

**Solutions:**
```bash
# Check current configuration
docker compose exec musicbrainz-minimal env | grep -E '(POSTGRES|REDIS)'

# Use environment-specific compose file
docker compose -f compose/musicbrainz-test.yml up -d

# Or set environment variables
export POSTGRES_HOST=localhost
export POSTGRES_PORT=5432
docker compose up -d
```

## 🔍 Advanced Troubleshooting

### Debug Mode
```bash
# Enable debug logging
docker compose exec musicbrainz-minimal bash -c 'cd /musicbrainz-server && MUSICBRAINZ_DEBUG=1 ./admin/replication/LoadReplicationChanges'

# Check detailed logs
docker compose logs --tail=100 musicbrainz-minimal
```

### Database Inspection
```bash
# Check database size
docker compose exec musicbrainz-minimal bash -c 'PGHOST=db PGPORT=5432 PGPASSWORD=musicbrainz psql -U musicbrainz -d musicbrainz_db -c "SELECT pg_size_pretty(pg_database_size('\''musicbrainz_db'\''));"'

# Check replication status
docker compose exec musicbrainz-minimal bash -c 'PGHOST=db PGPORT=5432 PGPASSWORD=musicbrainz psql -U musicbrainz -d musicbrainz_db -c "SELECT * FROM musicbrainz.replication_control;"'

# Check pending data
docker compose exec musicbrainz-minimal bash -c 'PGHOST=db PGPORT=5432 PGPASSWORD=musicbrainz psql -U musicbrainz -d musicbrainz_db -c "SELECT COUNT(*) FROM dbmirror2.pending_data;"'
```

### Network Troubleshooting
```bash
# Test network connectivity
docker compose exec musicbrainz-minimal ping db
docker compose exec musicbrainz-minimal ping redis

# Check DNS resolution
docker compose exec musicbrainz-minimal nslookup db
docker compose exec musicbrainz-minimal nslookup redis

# Test port connectivity
docker compose exec musicbrainz-minimal telnet db 5432
docker compose exec musicbrainz-minimal telnet redis 6379
```

## 🚀 Recovery Procedures

### Complete Reset
```bash
# Stop all containers
docker compose down

# Remove volumes (WARNING: This deletes all data)
docker volume prune -f

# Rebuild containers
docker compose build --no-cache

# Start fresh
docker compose up -d

# Run setup
./scripts/setup-replication.sh
```

### Partial Reset
```bash
# Stop replication
docker compose exec musicbrainz-minimal pkill -f LoadReplicationChanges

# Restart containers
docker compose restart

# Reconfigure replication
./scripts/setup-replication.sh

# Restart replication
docker compose exec musicbrainz-minimal replication.sh &
```

### Data Recovery
```bash
# Backup current data
docker compose exec db pg_dump -U musicbrainz musicbrainz_db > backup_$(date +%Y%m%d_%H%M%S).sql

# Restore from backup
docker compose exec -T db psql -U musicbrainz musicbrainz_db < backup_file.sql
```

## 📞 Getting Help

### Log Collection
```bash
# Collect system information
uname -a > system_info.txt
free -h >> system_info.txt
df -h >> system_info.txt
docker --version >> system_info.txt
docker compose version >> system_info.txt

# Collect container logs
docker compose logs > container_logs.txt

# Collect replication logs
docker compose exec musicbrainz-minimal cat logs/replication.log > replication_logs.txt
```

### Common Error Messages

| Error Message | Cause | Solution |
|---------------|-------|----------|
| `This is not a mirror server!` | Wrong replication type | Run `./scripts/setup-replication.sh` |
| `Invalid or missing REPLICATION_ACCESS_TOKEN` | Missing or invalid token | Configure token in setup script |
| `Can't locate [Module].pm in @INC` | Missing Perl module | Install module with `cpanm` |
| `relation 'dbmirror2.pending_data' does not exist` | Missing replication tables | Run ReplicationSetup.sql |
| `connection to server failed` | Database not accessible | Check database container status |
| `Port already in use` | Port conflict | Use different ports or stop conflicting service |

### Support Resources
- [MusicBrainz Documentation](https://musicbrainz.org/doc/MusicBrainz_Database)
- [Docker Compose Documentation](https://docs.docker.com/compose/)
- [PostgreSQL Documentation](https://www.postgresql.org/docs/)
- [GitHub Issues](https://github.com/pedro16v/musicbrainz-docker-rpi/issues)

### Template Processing Issues

**Symptom:** The `DBDefs.pm` file shows placeholder values like `'YOUR_TOKEN_HERE'` or incorrect hostnames like `db` instead of `db-test`.
**Cause:** The template processing system (`envsubst`) didn't properly substitute environment variables.
**Solution:** 
1. **Use the enhanced configuration script:** `./scripts/configure-replication.sh`
2. **Manual fix:** Check that all required environment variables are exported before running `envsubst`
3. **Verify template:** Ensure `DBDefs.pm.template` contains proper `${VARIABLE}` placeholders

**Enhanced Template System:**
The repository now includes an enhanced template processing system that:
- Automatically detects the environment (production, test, dev)
- Sets appropriate database and Redis hostnames
- Validates configuration after processing
- Provides detailed logging and error messages

### Environment-Specific Configuration Issues

**Symptom:** Database connection fails with "could not translate host name" errors.
**Cause:** The container is trying to connect to the wrong database service name.
**Solution:**
- **Test environment:** Should connect to `db-test`, not `db`
- **Dev environment:** Should connect to `db-dev`, not `db`
- **Production environment:** Should connect to `db`

The enhanced configuration script automatically handles these environment-specific settings.

## 🔄 Maintenance

### Regular Checks
```bash
# Weekly system check
./scripts/validate-deployment.sh

# Monthly log rotation
docker compose exec musicbrainz-minimal bash -c 'find logs/ -name "*.log" -mtime +30 -delete'

# Quarterly backup
docker compose exec db pg_dump -U musicbrainz musicbrainz_db > backup_$(date +%Y%m%d).sql
```

### Performance Monitoring
```bash
# Monitor replication progress
watch -n 30 'docker compose exec musicbrainz-minimal bash -c "PGHOST=db PGPORT=5432 PGPASSWORD=musicbrainz psql -U musicbrainz -d musicbrainz_db -c \"SELECT COUNT(*) FROM dbmirror2.pending_data;\""'

# Monitor system resources
watch -n 10 'free -h && df -h'
```

This troubleshooting guide should help you resolve most common issues with MusicBrainz replication on ARM64 systems. If you encounter issues not covered here, please collect the relevant logs and system information before seeking help.