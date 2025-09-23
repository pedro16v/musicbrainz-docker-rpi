# MusicBrainz Docker for Raspberry Pi 4

This is an ARM64-adapted version of the MusicBrainz Docker setup optimized for Raspberry Pi 4.

## Changes Made for ARM64 Compatibility

1. **Fixed Dockerize binary downloads**: Changed from hardcoded `amd64` to dynamic architecture detection
2. **Updated RabbitMQ version**: Upgraded from 3.6.16 to 3.13 for better ARM64 support
3. **Multi-architecture support**: All Dockerfiles now detect and use appropriate architecture binaries

## Prerequisites for Raspberry Pi 4

### Hardware Requirements
- Raspberry Pi 4 with at least 4GB RAM (8GB recommended)
- Fast microSD card (Class 10 or better) or USB 3.0 SSD
- At least 100GB free storage (350GB for full setup with search)

### Software Requirements
- Raspberry Pi OS 64-bit (Bullseye or later)
- Docker and Docker Compose v2 installed
- Git

### Installation on Raspberry Pi

1. **Install Docker and Docker Compose:**
   ```bash
   curl -fsSL https://get.docker.com -o get-docker.sh
   sudo sh get-docker.sh
   sudo usermod -aG docker $USER
   sudo apt-get install docker-compose-plugin
   ```

2. **Logout and login again** to apply docker group membership

3. **Clone this repository:**
   ```bash
   cd /mnt/storage  # or your preferred location
   git clone https://github.com/pedro16v/musicbrainz-docker-rpi.git mbz-docker-rpi
   cd mbz-docker-rpi
   ```

## Quick Start

For a test setup with sample data:

```bash
# Configure for standalone mode
admin/configure add musicbrainz-standalone

# Build images (this will take a while on Pi)
docker compose build

# Create database with sample data
docker compose run --rm musicbrainz createdb.sh -sample -fetch

# Start the services
docker compose up -d
```

## Performance Optimizations for Raspberry Pi

### Memory Settings
Create `local/compose/rpi-memory-settings.yml`:

```yaml
# Description: Raspberry Pi optimized memory settings

services:
  db:
    command: postgres -c "shared_buffers=1GB" -c "shared_preload_libraries=pg_amqp.so"
  search:
    environment:
      - SOLR_HEAP=1g
  musicbrainz:
    environment:
      - MUSICBRAINZ_SERVER_PROCESSES=4
```

Enable the optimization:
```bash
admin/configure add local/compose/rpi-memory-settings.yml
docker compose up -d
```

### Storage Optimization
- Use an external USB 3.0 SSD instead of microSD for better I/O performance
- Mount the SSD at `/mnt/storage` and run the project from there

## Monitoring

Monitor resource usage:
```bash
# Check container resource usage
docker stats

# Monitor Pi temperature
vcgencmd measure_temp

# Monitor memory usage
free -h
```

## Troubleshooting

### Common Issues

1. **Out of memory errors**: Reduce `shared_buffers` and `SOLR_HEAP` values
2. **Slow performance**: Ensure you're using fast storage (SSD recommended)
3. **Architecture errors**: Make sure you're using the ARM64 version of Raspberry Pi OS

### Performance Tips

- Disable swap or use zram for better performance
- Increase GPU memory split: `gpu_mem=16` in `/boot/config.txt`
- Overclock if you have adequate cooling
- Use a high-quality power supply (official Pi adapter recommended)

## Development Workflow

1. Make changes on your development machine
2. Commit and push to GitHub
3. Pull changes on Raspberry Pi
4. Test the changes

```bash
# On development machine
git add .
git commit -m "Updated configuration"
git push rpi main

# On Raspberry Pi
git pull origin main
docker compose up -d --build
```
