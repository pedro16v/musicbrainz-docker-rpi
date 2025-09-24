#!/bin/bash

# Script to monitor memory usage during MusicBrainz import
# Run this in a separate terminal while importing

set -e

echo "MusicBrainz Import Memory Monitor"
echo "================================="
echo "Press Ctrl+C to stop monitoring"
echo ""

# Function to get memory info
get_memory_info() {
    local mem_info=$(free -h)
    local mem_line=$(echo "$mem_info" | grep '^Mem:')
    local swap_line=$(echo "$mem_info" | grep '^Swap:')
    
    local mem_used=$(echo $mem_line | awk '{print $3}')
    local mem_total=$(echo $mem_line | awk '{print $2}')
    local mem_percent=$(echo $mem_line | awk '{printf "%.1f", $3*100/$2}')
    
    local swap_used=$(echo $swap_line | awk '{print $3}')
    local swap_total=$(echo $swap_line | awk '{print $2}')
    local swap_percent=$(echo $swap_line | awk '{printf "%.1f", $3*100/$2}')
    
    echo "$mem_used/$mem_total ($mem_percent%)"
    echo "$swap_used/$swap_total ($swap_percent%)"
}

# Function to get PostgreSQL memory usage
get_postgres_memory() {
    local pg_pid=$(pgrep -f "postgres.*musicbrainz" | head -1)
    if [[ -n "$pg_pid" ]]; then
        local pg_mem=$(ps -o rss= -p $pg_pid 2>/dev/null | awk '{printf "%.1f MB", $1/1024}')
        echo "$pg_mem"
    else
        echo "N/A"
    fi
}

# Function to get Docker container memory usage
get_docker_memory() {
    local db_mem=$(docker stats --no-stream --format "table {{.Container}}\t{{.MemUsage}}" | grep -E "(db|postgres)" | awk '{print $2}' | head -1)
    echo "${db_mem:-N/A}"
}

# Main monitoring loop
while true; do
    clear
    echo "MusicBrainz Import Memory Monitor - $(date)"
    echo "=============================================="
    echo ""
    
    echo "System Memory Usage:"
    echo "  RAM: $(get_memory_info | head -1)"
    echo "  Swap: $(get_memory_info | tail -1)"
    echo ""
    
    echo "PostgreSQL Memory Usage:"
    echo "  Process: $(get_postgres_memory)"
    echo "  Container: $(get_docker_memory)"
    echo ""
    
    echo "Disk I/O (if iostat available):"
    if command -v iostat >/dev/null 2>&1; then
        iostat -x 1 1 | tail -n +4 | head -5
    else
        echo "  Install sysstat package for I/O monitoring"
    fi
    echo ""
    
    echo "Top Memory Consumers:"
    ps aux --sort=-%mem | head -6 | awk '{printf "  %-20s %6s%% %8s\n", $11, $4, $6}'
    echo ""
    
    echo "Press Ctrl+C to stop monitoring"
    
    sleep 5
done
