# Digital Ocean ARM64 Deployment Guide

This guide provides step-by-step instructions for deploying MusicBrainz replication on Digital Ocean ARM64 droplets.

## Prerequisites

- Digital Ocean account
- ARM64 droplet (recommended: 4GB RAM, 2 vCPUs)
- Root access to the droplet
- Basic knowledge of Linux command line

## Quick Deployment

### Option 1: One-Command Deployment

```bash
# Download and run the automated deployment script
curl -sSL https://raw.githubusercontent.com/pedro16v/musicbrainz-docker-rpi/main/scripts/deploy-arm64.sh | sudo bash
```

### Option 2: Manual Deployment

1. **Connect to your droplet:**
   ```bash
   ssh root@your-droplet-ip
   ```

2. **Run the deployment script:**
   ```bash
   # Clone the repository
   git clone https://github.com/pedro16v/musicbrainz-docker-rpi.git musicbrainz-docker-arm
   cd musicbrainz-docker-arm
   
   # Run deployment script
   sudo ./scripts/deploy-arm64.sh
   ```

## What the Deployment Script Does

### System Optimization
- ✅ **Installs Digital Ocean analytics** for monitoring
- ✅ **Creates 4GB swap file** for memory optimization
- ✅ **Updates system packages** and installs dependencies
- ✅ **Installs Docker and Docker Compose**

### Project Setup
- ✅ **Clones the repository** with ARM64 optimizations
- ✅ **Builds Docker containers** with proper dependencies
- ✅ **Starts all services** (PostgreSQL, Redis, MusicBrainz)
- ✅ **Sets up replication** with automated configuration
- ✅ **Starts replication process** in background
- ✅ **Creates database views** for monitoring

### Security & Access
- ✅ **Exposes database port** (5432) for external access
- ✅ **Creates proper user permissions** for Docker
- ✅ **Sets up secure token storage** for MetaBrainz access

## Post-Deployment Verification

### Check System Status
```bash
# Check container status
docker compose ps

# Check system resources
htop

# Check swap usage
free -h
```

### Verify Replication
```bash
# Check replication logs
docker compose exec musicbrainz-minimal tail -f logs/replication.log

# Check replication data
docker compose exec musicbrainz-minimal bash -c 'PGHOST=db PGPORT=5432 PGPASSWORD=musicbrainz psql -U musicbrainz -d musicbrainz_db -c "SELECT COUNT(*) FROM dbmirror2.pending_data;"'

# Check replication views
PGPASSWORD=musicbrainz psql -h localhost -U musicbrainz -d musicbrainz_db -c "SELECT * FROM replication_status;"
```

## Digital Ocean Specific Optimizations

### Droplet Recommendations

**Minimum Configuration:**
- **RAM**: 2GB (4GB recommended)
- **vCPUs**: 1-2 ARM64 cores
- **Storage**: 25GB SSD
- **Network**: 1TB transfer

**Recommended Configuration:**
- **RAM**: 4GB
- **vCPUs**: 2 ARM64 cores  
- **Storage**: 50GB SSD
- **Network**: 2TB transfer

### Performance Tuning

The deployment script automatically:
- Creates swap file for memory optimization
- Configures PostgreSQL with ARM64-optimized settings
- Sets memory limits for containers
- Enables Digital Ocean monitoring

### Monitoring Setup

```bash
# Install additional monitoring tools
apt-get install -y htop iotop nethogs

# Monitor replication progress
watch -n 30 'docker compose exec musicbrainz-minimal bash -c "PGHOST=db PGPORT=5432 PGPASSWORD=musicbrainz psql -U musicbrainz -d musicbrainz_db -c \"SELECT COUNT(*) FROM dbmirror2.pending_data;\""'
```

## Database Access

### Local Access
```bash
# Connect from droplet
PGPASSWORD=musicbrainz psql -h localhost -U musicbrainz -d musicbrainz_db
```

### Remote Access
```bash
# Connect from external machine
PGPASSWORD=musicbrainz psql -h your-droplet-ip -U musicbrainz -d musicbrainz_db
```

### Useful Queries
```sql
-- Check replication status
SELECT * FROM replication_status;

-- Check table sizes
SELECT * FROM database_size;

-- Check recent replication activity
SELECT * FROM dbmirror2.pending_ts ORDER BY ts DESC LIMIT 10;
```

## Troubleshooting

### Common Issues

1. **Out of Memory**
   ```bash
   # Check memory usage
   free -h
   
   # Increase swap if needed
   fallocate -l 8G /swapfile2
   chmod 600 /swapfile2
   mkswap /swapfile2
   swapon /swapfile2
   ```

2. **Container Won't Start**
   ```bash
   # Check container logs
   docker compose logs musicbrainz-minimal
   
   # Restart containers
   docker compose restart
   ```

3. **Replication Not Working**
   ```bash
   # Check replication logs
   docker compose exec musicbrainz-minimal tail -f logs/replication.log
   
   # Restart replication
   docker compose exec musicbrainz-minimal replication.sh &
   ```

### Performance Issues

```bash
# Monitor system resources
htop

# Check disk usage
df -h

# Check Docker resource usage
docker stats

# Check PostgreSQL performance
PGPASSWORD=musicbrainz psql -h localhost -U musicbrainz -d musicbrainz_db -c "SELECT * FROM pg_stat_activity;"
```

## Maintenance

### Regular Tasks

```bash
# Update system packages
apt-get update && apt-get upgrade -y

# Update Docker images
docker compose pull
docker compose up -d

# Clean up Docker resources
docker system prune -f

# Check replication health
docker compose exec musicbrainz-minimal bash -c 'PGHOST=db PGPORT=5432 PGPASSWORD=musicbrainz psql -U musicbrainz -d musicbrainz_db -c "SELECT * FROM replication_status;"'
```

### Backup Strategy

```bash
# Create database backup
PGPASSWORD=musicbrainz pg_dump -h localhost -U musicbrainz musicbrainz_db > musicbrainz_backup_$(date +%Y%m%d).sql

# Backup configuration
tar -czf musicbrainz_config_$(date +%Y%m%d).tar.gz local/secrets/ logs/ docker-compose.yml
```

## Cost Optimization

### Resource Monitoring
- Monitor CPU and memory usage in Digital Ocean dashboard
- Use Digital Ocean monitoring alerts
- Consider downgrading droplet if resources are underutilized

### Storage Optimization
- Regularly clean up old logs
- Monitor disk usage with `df -h`
- Consider upgrading storage if needed

## Support

For Digital Ocean specific issues:
- Check Digital Ocean status page
- Review droplet metrics in dashboard
- Contact Digital Ocean support if needed

For MusicBrainz replication issues:
- Check the troubleshooting section in `REPLICATION-SETUP-GUIDE.md`
- Review container logs for specific errors
- Monitor replication progress in logs
