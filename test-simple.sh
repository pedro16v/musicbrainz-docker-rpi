#!/bin/bash

# Simple test to check if the container can see your dump files
# Run this when Docker is available

echo "Testing if MusicBrainz container can see your dump files..."
echo

# Quick test - just list the dump directory
docker compose run --rm musicbrainz ls -la /media/dbdump

echo
echo "If you see your dump files (mbdump*.tar.bz2) listed above, the volume mapping is working!"
echo "You can now run: docker compose run --rm musicbrainz createdb.sh"
