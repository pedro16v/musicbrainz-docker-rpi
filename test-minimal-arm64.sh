#!/bin/bash

# Test script for minimal ARM64 MusicBrainz setup

set -e

echo "Testing minimal ARM64 MusicBrainz setup..."

# Check if we're on the right branch
CURRENT_BRANCH=$(git branch --show-current)
if [ "$CURRENT_BRANCH" != "minimal-arm64-setup" ]; then
    echo "Warning: Not on minimal-arm64-setup branch (current: $CURRENT_BRANCH)"
fi

# Check if compose file exists
if [ ! -f "compose/db-minimal-arm64.yml" ]; then
    echo "Error: compose/db-minimal-arm64.yml not found"
    exit 1
fi

# Check if optimization file exists
if [ ! -f "compose/arm64-optimization.yml" ]; then
    echo "Error: compose/arm64-optimization.yml not found"
    exit 1
fi

# Check if minimal Dockerfile exists
if [ ! -f "build/musicbrainz-minimal/Dockerfile" ]; then
    echo "Error: build/musicbrainz-minimal/Dockerfile not found"
    exit 1
fi

# Check if scripts exist and are executable
SCRIPTS=(
    "build/musicbrainz-minimal/scripts/docker-entrypoint.sh"
    "build/musicbrainz-minimal/scripts/replication.sh"
    "build/musicbrainz-minimal/scripts/createdb.sh"
    "build/musicbrainz-minimal/scripts/fetch-dump.sh"
)

for script in "${SCRIPTS[@]}"; do
    if [ ! -f "$script" ]; then
        echo "Error: $script not found"
        exit 1
    fi
    
    if [ ! -x "$script" ]; then
        echo "Error: $script is not executable"
        exit 1
    fi
done

# Check if host directory exists
if [ ! -d "/mnt/storage/musicbrainz/dbdump" ]; then
    echo "Warning: Host directory /mnt/storage/musicbrainz/dbdump does not exist"
    echo "Please create this directory manually:"
    echo "  sudo mkdir -p /mnt/storage/musicbrainz/dbdump"
    echo "  sudo chown $USER:$USER /mnt/storage/musicbrainz/dbdump"
    echo "Or use a different path by modifying the compose file."
fi

# Test Docker Compose configuration
echo "Testing Docker Compose configuration..."
if ! docker compose -f compose/db-minimal-arm64.yml config > /dev/null 2>&1; then
    echo "Error: Invalid Docker Compose configuration"
    exit 1
fi

# Test with optimization file
echo "Testing with ARM64 optimization..."
if ! docker compose -f compose/db-minimal-arm64.yml -f compose/arm64-optimization.yml config > /dev/null 2>&1; then
    echo "Error: Invalid Docker Compose configuration with optimization"
    exit 1
fi

echo "✅ All tests passed!"
echo ""
echo "Next steps:"
echo "1. Configure the setup: admin/configure add compose/db-minimal-arm64.yml"
echo "2. Add optimization: admin/configure add compose/arm64-optimization.yml"
echo "3. Build images: docker compose build"
echo "4. Test with sample data: docker compose run --rm musicbrainz-minimal createdb.sh -sample -fetch"
echo "5. Start services: docker compose up -d"
echo ""
echo "For full documentation, see README-MINIMAL-ARM64.md"
