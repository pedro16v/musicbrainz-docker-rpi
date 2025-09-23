#!/bin/bash

# Create a symlink for mirror.log to match the expected filename
cd /musicbrainz-server

# Ensure logs directory exists
mkdir -p logs

# Create the expected mirror.log file (symlink to replication.log)
ln -sf replication.log logs/mirror.log

echo "Mirror log setup complete. Use: docker compose exec musicbrainz /usr/bin/tail -f logs/mirror.log"
