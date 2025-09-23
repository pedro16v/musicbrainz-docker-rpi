#!/bin/bash

# Test script to verify MusicBrainz container can access dump files
# This script runs a temporary container to check if the volume mapping works

set -e

echo "=== Testing MusicBrainz Container Dump File Access ==="
echo

# Check if Docker is running
if ! docker info >/dev/null 2>&1; then
    echo "❌ Docker daemon is not running!"
    echo "Please start Docker Desktop or Docker daemon first."
    echo "Then run this script again."
    exit 1
fi

echo "✅ Docker daemon is running"
echo

# Test 1: Check if the container can see the dump directory
echo "1. Testing if container can access /media/dbdump directory..."
docker compose run --rm musicbrainz ls -la /media/dbdump

echo
echo "2. Checking for specific dump files..."
docker compose run --rm musicbrainz bash -c "
    echo 'Checking for required dump files:'
    for file in mbdump.tar.bz2 mbdump-cdstubs.tar.bz2 mbdump-cover-art-archive.tar.bz2 mbdump-event-art-archive.tar.bz2 mbdump-derived.tar.bz2 mbdump-stats.tar.bz2 mbdump-wikidocs.tar.bz2; do
        if [ -f \"/media/dbdump/\$file\" ]; then
            echo \"✓ \$file exists\"
            ls -lh \"/media/dbdump/\$file\"
        else
            echo \"✗ \$file missing\"
        fi
    done
"

echo
echo "3. Checking for metadata files..."
docker compose run --rm musicbrainz bash -c "
    echo 'Checking for metadata files:'
    for file in LATEST MD5SUMS .for-non-commercial-use .for-commercial-use; do
        if [ -f \"/media/dbdump/\$file\" ]; then
            echo \"✓ \$file exists\"
            if [ \"\$file\" = \"LATEST\" ]; then
                echo \"  Content: \$(cat /media/dbdump/\$file)\"
            fi
        else
            echo \"✗ \$file missing\"
        fi
    done
"

echo
echo "4. Testing directory permissions..."
docker compose run --rm musicbrainz bash -c "
    echo 'Directory permissions:'
    ls -ld /media/dbdump
    echo 'Can write to directory:'
    touch /media/dbdump/test-write-permission 2>/dev/null && echo '✓ Write permission OK' || echo '✗ No write permission'
    rm -f /media/dbdump/test-write-permission 2>/dev/null
"

echo
echo "5. Testing createdb.sh script recognition..."
docker compose run --rm musicbrainz bash -c "
    echo 'Testing if createdb.sh can find dump files:'
    cd /media/dbdump
    echo 'Files that createdb.sh expects:'
    ls -la *.tar.bz2 *.tar.xz 2>/dev/null || echo 'No tar files found'
    echo 'Total size of dump files:'
    du -sh *.tar.bz2 *.tar.xz 2>/dev/null || echo 'No tar files to measure'
"

echo
echo "=== Test Complete ==="
echo "If you see your dump files listed above, the volume mapping is working correctly!"
echo "You can now run: docker compose run --rm musicbrainz createdb.sh"
