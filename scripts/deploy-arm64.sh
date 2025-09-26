#!/bin/bash

# MusicBrainz ARM64 Automated Deployment Script
# Optimized for Digital Ocean and ARM64 systems

set -e

echo "=== MusicBrainz ARM64 Automated Deployment ==="
echo

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root (use sudo)"
    exit 1
fi

# Detect system architecture
ARCH=$(uname -m)
if [[ "$ARCH" != "aarch64" && "$ARCH" != "arm64" ]]; then
    echo "Warning: This script is optimized for ARM64 systems"
    echo "Detected architecture: $ARCH"
    read -p "Continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

echo "Step 1: System optimization..."

# Install Digital Ocean analytics (optional)
if command -v curl >/dev/null 2>&1; then
    echo "Installing Digital Ocean analytics..."
    curl -sSL https://repos.insights.digitalocean.com/install.sh | bash || echo "Analytics installation failed, continuing..."
fi

# Create swap file for memory optimization
if [ ! -f /swapfile ]; then
    echo "Creating 4GB swap file..."
    fallocate -l 4G /swapfile
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile
    echo '/swapfile none swap sw 0 0' | tee -a /etc/fstab
    echo "Swap file created successfully"
else
    echo "Swap file already exists"
fi

echo "Step 2: Installing dependencies..."

# Update package list
apt-get update

# Install essential packages
apt-get install -y \
    docker.io \
    docker-compose \
    git \
    postgresql-client-16 \
    curl \
    wget \
    htop \
    unzip

# Enable and start Docker
systemctl enable --now docker.service

# Add current user to docker group (if not root)
if [ "$SUDO_USER" ]; then
    usermod -aG docker "$SUDO_USER"
    echo "Added $SUDO_USER to docker group"
fi

echo "Step 3: Setting up project..."

# Clone the repository
if [ ! -d "musicbrainz-docker-arm" ]; then
    echo "Cloning musicbrainz-docker-arm repository..."
    git clone https://github.com/pedro16v/musicbrainz-docker-rpi.git musicbrainz-docker-arm
else
    echo "Repository already exists, updating..."
    cd musicbrainz-docker-arm
    git pull
    cd ..
fi

cd musicbrainz-docker-arm

# Create necessary directories
mkdir -p logs
mkdir -p local/secrets

echo "Step 4: Building containers..."

# Build the containers
docker compose build

echo "Step 5: Starting containers..."

# Start containers
docker compose up -d

# Wait for containers to be ready
echo "Waiting for containers to start..."
sleep 10

# Check if containers are running
if ! docker compose ps | grep -q "Up"; then
    echo "Error: Containers failed to start"
    docker compose logs
    exit 1
fi

echo "Step 6: Setting up replication..."

# Run the automated setup script
if [ -f "scripts/setup-replication.sh" ]; then
    echo "Running automated replication setup..."
    chmod +x scripts/setup-replication.sh
    ./scripts/setup-replication.sh
else
    echo "Manual replication setup required..."
    echo "Please run: ./scripts/setup-replication.sh"
fi

echo "Step 7: Starting replication..."

# Start replication in background
docker compose exec musicbrainz-minimal replication.sh &

echo "Step 8: Publishing database port..."

# The database port is already exposed in our ARM64 compose file
echo "Database port 5432 is already exposed"

echo "Step 9: Creating database views (if needed)..."

# Check if create_views.sql exists
if [ -f "create_views.sql" ]; then
    echo "Creating database views..."
    PGPASSWORD=musicbrainz psql -h 127.0.0.1 -U musicbrainz -d musicbrainz_db -a -f create_views.sql
else
    echo "No create_views.sql found, skipping view creation"
fi

echo
echo "=== Deployment Complete! ==="
echo
echo "System Information:"
echo "- Architecture: $(uname -m)"
echo "- Memory: $(free -h | grep Mem | awk '{print $2}')"
echo "- Swap: $(free -h | grep Swap | awk '{print $2}')"
echo "- Docker: $(docker --version)"
echo
echo "Container Status:"
docker compose ps
echo
echo "Replication Status:"
docker compose exec musicbrainz-minimal ps aux | grep LoadReplication || echo "Replication not running"
echo
echo "Useful Commands:"
echo "- Check replication logs: docker compose exec musicbrainz-minimal tail -f logs/replication.log"
echo "- Check replication data: docker compose exec musicbrainz-minimal bash -c 'PGHOST=db PGPORT=5432 PGPASSWORD=musicbrainz psql -U musicbrainz -d musicbrainz_db -c \"SELECT COUNT(*) FROM dbmirror2.pending_data;\"'"
echo "- Restart replication: docker compose exec musicbrainz-minimal replication.sh &"
echo "- View container logs: docker compose logs musicbrainz-minimal"
echo "- Stop all containers: docker compose down"
echo "- Start all containers: docker compose up -d"
echo
echo "Database Access:"
echo "- Host: localhost"
echo "- Port: 5432"
echo "- Database: musicbrainz_db"
echo "- Username: musicbrainz"
echo "- Password: musicbrainz"
echo
echo "Files created:"
echo "- Swap file: /swapfile (4GB)"
echo "- Project directory: $(pwd)"
echo "- Logs directory: $(pwd)/logs"
echo "- Secrets directory: $(pwd)/local/secrets"
echo
echo "Next steps:"
echo "1. Monitor replication: docker compose exec musicbrainz-minimal tail -f logs/replication.log"
echo "2. Check system resources: htop"
echo "3. Access database: PGPASSWORD=musicbrainz psql -h localhost -U musicbrainz -d musicbrainz_db"
echo
