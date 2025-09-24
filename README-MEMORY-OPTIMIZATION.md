# Memory Optimization Guide for Raspberry Pi MusicBrainz Import

This guide provides solutions for handling the memory-intensive full data import on Raspberry Pi with limited RAM and a 16GB swap file on USB 3.0 drive.

## Problem Analysis

The full MusicBrainz data import is memory-intensive and can overwhelm a Raspberry Pi's limited RAM. Even with a 16GB swap file, PostgreSQL may not utilize it effectively due to:

1. **Aggressive memory settings** in default configurations
2. **Large shared_buffers** consuming too much RAM
3. **High work_mem** settings causing memory spikes
4. **System not configured for aggressive swap usage**

## Solutions Implemented

### 1. Memory-Optimized PostgreSQL Configuration

Created `compose/rpi-memory-optimized.yml` with:

- **Reduced shared_buffers**: 256MB (from 1GB)
- **Optimized work_mem**: 8MB (balanced for import operations)
- **Increased maintenance_work_mem**: 128MB (for index creation)
- **System-level swap optimization**: vm.swappiness=60
- **Memory limits**: 1GB container limit with 512MB reservation

### 2. Chunked Import Strategy

Created `build/musicbrainz-minimal/scripts/createdb-chunked.sh`:

- **Configurable chunk size**: Default 1000 rows per chunk
- **Memory monitoring**: Real-time memory usage tracking
- **Progress tracking**: Better visibility into import progress
- **Graceful handling**: Better error recovery

### 3. System-Level Memory Optimization

Created `scripts/optimize-rpi-memory.sh`:

- **Aggressive swap usage**: vm.swappiness=60
- **Frequent disk flushing**: Reduced dirty page thresholds
- **Memory overcommit**: Allows more memory allocation
- **Database-optimized settings**: Tuned for PostgreSQL workloads

### 4. Import Monitoring

Created `scripts/monitor-import.sh`:

- **Real-time memory tracking**: RAM and swap usage
- **PostgreSQL process monitoring**: Database memory consumption
- **Docker container stats**: Container-level memory usage
- **System resource overview**: Top memory consumers

## Usage Instructions

### Step 1: Apply System Optimizations

```bash
# Run as root to optimize system memory settings
sudo ./scripts/optimize-rpi-memory.sh
```

### Step 2: Configure Memory-Optimized Setup

```bash
# Use the memory-optimized configuration
echo 'COMPOSE_FILE=compose/db-minimal-arm64.yml:compose/rpi-memory-optimized.yml' > .env
```

### Step 3: Start Services with Optimized Settings

```bash
# Build and start with memory-optimized settings
docker compose build
docker compose up -d
```

### Step 4: Monitor Import Process

In a separate terminal, start monitoring:

```bash
# Monitor memory usage during import
./scripts/monitor-import.sh
```

### Step 5: Run Chunked Import

```bash
# Import with chunked strategy and monitoring
docker compose run --rm -e PGPASSWORD=musicbrainz -e PGHOST=db musicbrainz-minimal createdb-chunked.sh -fetch -chunk-size 500
```

## Configuration Parameters

### PostgreSQL Memory Settings

| Parameter | Value | Purpose |
|-----------|-------|---------|
| `shared_buffers` | 256MB | Reduced from 1GB to leave more RAM for operations |
| `work_mem` | 8MB | Balanced for import operations without excessive memory usage |
| `maintenance_work_mem` | 128MB | Sufficient for index creation and maintenance |
| `effective_cache_size` | 512MB | Estimated available memory for caching |

### System Memory Settings

| Parameter | Value | Purpose |
|-----------|-------|---------|
| `vm.swappiness` | 60 | More aggressive swap usage |
| `vm.dirty_ratio` | 15 | Flush dirty pages more frequently |
| `vm.dirty_background_ratio` | 5 | Lower threshold for background flushing |
| `vm.overcommit_memory` | 1 | Allow memory overcommit |

### Import Parameters

| Parameter | Default | Purpose |
|-----------|---------|---------|
| `MUSICBRAINZ_IMPORT_CHUNK_SIZE` | 1000 | Rows per import chunk |
| `MUSICBRAINZ_SERVER_PROCESSES` | 1 | Reduced from 4 to save memory |

## Monitoring and Troubleshooting

### Memory Usage Monitoring

```bash
# Check current memory usage
free -h

# Monitor swap usage
swapon --show

# Check PostgreSQL memory usage
docker stats --no-stream db

# Monitor system resources
htop
```

### Common Issues and Solutions

#### Issue: Import Still Fails with Out of Memory

**Solutions:**
1. Reduce chunk size: `-chunk-size 250`
2. Further reduce shared_buffers: `-c "shared_buffers=128MB"`
3. Increase swap file size: `sudo fallocate -l 32G /swapfile`

#### Issue: Very Slow Import Performance

**Solutions:**
1. Check USB 3.0 drive performance: `sudo hdparm -t /dev/sda`
2. Ensure swap is on fast storage (USB 3.0 drive)
3. Monitor I/O wait: `iostat -x 1`

#### Issue: System Becomes Unresponsive

**Solutions:**
1. Reduce vm.swappiness to 30
2. Increase vm.dirty_background_ratio to 10
3. Use smaller chunk sizes

### Performance Optimization Tips

1. **Storage Optimization:**
   - Use USB 3.0 SSD for swap and data
   - Ensure adequate cooling for sustained I/O
   - Monitor drive temperature during import

2. **System Optimization:**
   - Close unnecessary services during import
   - Use `nice -n 19` for import process
   - Consider overclocking if cooling is adequate

3. **Import Strategy:**
   - Start with smaller chunk sizes and increase gradually
   - Monitor memory usage patterns
   - Consider importing during off-peak hours

## Expected Results

With these optimizations, you should see:

- **Better swap utilization**: System actively uses the 16GB swap file
- **Reduced memory pressure**: More stable memory usage patterns
- **Successful import completion**: Full data import without OOM errors
- **Reasonable performance**: Import completes in 6-12 hours depending on storage speed

## Recovery Procedures

### If Import Fails

1. **Clean up partial import:**
   ```bash
   docker compose exec db psql -U musicbrainz -d postgres -c "DROP DATABASE IF EXISTS musicbrainz_db;"
   ```

2. **Adjust settings and retry:**
   ```bash
   # Reduce chunk size and retry
   docker compose run --rm -e PGPASSWORD=musicbrainz -e PGHOST=db musicbrainz-minimal createdb-chunked.sh -chunk-size 250
   ```

### If System Becomes Unresponsive

1. **Reboot and check logs:**
   ```bash
   sudo journalctl -u docker
   docker compose logs db
   ```

2. **Restore original settings:**
   ```bash
   sudo cp /etc/sysctl.conf.backup.* /etc/sysctl.conf
   sudo sysctl -p
   ```

## Support and Further Optimization

For additional optimization:

1. **Monitor import logs** for specific bottlenecks
2. **Adjust chunk sizes** based on memory patterns
3. **Consider hardware upgrades** (8GB RAM, faster storage)
4. **Use incremental imports** for regular updates

This optimization strategy should allow successful full data import on Raspberry Pi with proper swap utilization.
