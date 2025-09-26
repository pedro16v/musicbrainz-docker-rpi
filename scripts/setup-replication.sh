#!/bin/bash

# MusicBrainz Replication Setup Script for ARM64
# This script sets up replication for MusicBrainz on ARM64 systems

set -e

echo "=== MusicBrainz Replication Setup for ARM64 ==="
echo

# Check if we're in the right directory
if [ ! -f "docker-compose.yml" ]; then
    echo "Error: Please run this script from the musicbrainz-docker-arm directory"
    exit 1
fi

# Check if containers are running
if ! docker compose ps | grep -q "Up"; then
    echo "Error: Containers are not running. Please start them first:"
    echo "  docker compose up -d"
    exit 1
fi

echo "Step 1: Installing missing Perl dependencies..."
docker compose exec --user root musicbrainz-minimal apt update
docker compose exec --user root musicbrainz-minimal apt install -y libgnupg-perl libredis-perl

echo "Step 2: Setting up replication access token..."
if [ ! -f "local/secrets/metabrainz_access_token" ]; then
    echo "Creating secrets directory..."
    mkdir -p local/secrets
    
    echo "Please get your MetaBrainz access token:"
    echo "1. Go to: https://metabrainz.org/account/applications"
    echo "2. Log in with your MetaBrainz account (create one if needed)"
    echo "3. Create a new application or use an existing one"
    echo "4. Copy the 40-character access token"
    echo
    read -p "Enter your MetaBrainz access token: " TOKEN
    
    if [ ${#TOKEN} -ne 40 ]; then
        echo "Error: Token must be exactly 40 characters long"
        exit 1
    fi
    
    echo "$TOKEN" > local/secrets/metabrainz_access_token
    chmod 600 local/secrets/metabrainz_access_token
    echo "Token saved to local/secrets/metabrainz_access_token"
else
    echo "Access token already exists"
fi

echo "Step 3: Configuring replication in container..."
TOKEN=$(cat local/secrets/metabrainz_access_token | tr -d '\n')
docker compose exec musicbrainz-minimal sed -i "s/# sub REPLICATION_ACCESS_TOKEN { 'YOUR_TOKEN_HERE' }/sub REPLICATION_ACCESS_TOKEN { '$TOKEN' }/" /musicbrainz-server/lib/DBDefs.pm

echo "Step 4: Setting up replication database tables..."
docker compose exec musicbrainz-minimal bash -c 'PGHOST=db PGPORT=5432 PGPASSWORD=musicbrainz psql -U musicbrainz -d musicbrainz_db -f /musicbrainz-server/admin/sql/dbmirror2/ReplicationSetup.sql'

echo "Step 5: Testing replication..."
echo "Starting replication test (this may take a few minutes)..."
docker compose exec musicbrainz-minimal bash -c 'cd /musicbrainz-server && PGHOST=db PGPORT=5432 PGPASSWORD=musicbrainz timeout 60 ./admin/replication/LoadReplicationChanges' || true

echo
echo "=== Setup Complete! ==="
echo
echo "To start replication in the background:"
echo "  docker compose exec musicbrainz-minimal replication.sh &"
echo
echo "To check replication status:"
echo "  docker compose exec musicbrainz-minimal tail -f logs/replication.log"
echo
echo "To check replication data:"
echo "  docker compose exec musicbrainz-minimal bash -c 'PGHOST=db PGPORT=5432 PGPASSWORD=musicbrainz psql -U musicbrainz -d musicbrainz_db -c \"SELECT COUNT(*) FROM dbmirror2.pending_data;\"'"
echo
