#!/bin/bash

# Script to optimize Raspberry Pi memory settings for MusicBrainz import
# This script configures system-level memory management

set -e

echo "Optimizing Raspberry Pi memory settings for MusicBrainz import..."

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root (use sudo)" 
   exit 1
fi

# Backup current sysctl.conf
cp /etc/sysctl.conf /etc/sysctl.conf.backup.$(date +%Y%m%d_%H%M%S)

# Configure memory management parameters
cat >> /etc/sysctl.conf << 'EOF'

# MusicBrainz import optimizations
# Increase swap usage tendency (default is 60, we want more aggressive swapping)
vm.swappiness=60

# Reduce dirty page thresholds to flush to disk more frequently
vm.dirty_ratio=15
vm.dirty_background_ratio=5

# Increase virtual memory overcommit (allows more memory allocation)
vm.overcommit_memory=1

# Optimize for database workloads
vm.dirty_writeback_centisecs=500
vm.dirty_expire_centisecs=3000

# Reduce memory fragmentation
vm.vfs_cache_pressure=50

EOF

# Apply settings immediately
sysctl -p

echo "Memory optimization settings applied:"
echo "- vm.swappiness=60 (more aggressive swap usage)"
echo "- vm.dirty_ratio=15 (flush dirty pages more frequently)"
echo "- vm.dirty_background_ratio=5 (background flush threshold)"
echo "- vm.overcommit_memory=1 (allow memory overcommit)"
echo ""
echo "Settings will persist after reboot."
echo "To revert changes, restore from: /etc/sysctl.conf.backup.*"

# Check current swap status
echo ""
echo "Current swap status:"
swapon --show
echo ""
echo "Memory usage:"
free -h
