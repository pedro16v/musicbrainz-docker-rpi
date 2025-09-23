#!/bin/bash

# Replication script with proper environment setup
cd /musicbrainz-server

# Ensure logs directory exists
mkdir -p logs

# Set up environment variables for DBDefs.pm
export MUSICBRAINZ_POSTGRES_SERVER=${MUSICBRAINZ_POSTGRES_SERVER:-db}
export MUSICBRAINZ_POSTGRES_PORT=${MUSICBRAINZ_POSTGRES_PORT:-5432}
export MUSICBRAINZ_POSTGRES_DATABASE=${MUSICBRAINZ_POSTGRES_DATABASE:-musicbrainz_db}
export MUSICBRAINZ_POSTGRES_USERNAME=${POSTGRES_USER:-musicbrainz}
export MUSICBRAINZ_POSTGRES_PASSWORD=${POSTGRES_PASSWORD:-musicbrainz}

echo "Starting MusicBrainz replication..."
echo "Database: $MUSICBRAINZ_POSTGRES_SERVER:$MUSICBRAINZ_POSTGRES_PORT/$MUSICBRAINZ_POSTGRES_DATABASE"
echo "User: $MUSICBRAINZ_POSTGRES_USERNAME"

# Call the actual replication script from MusicBrainz
exec ./admin/replication/LoadReplicationChanges --verbose 2>&1 | tee logs/replication.log
