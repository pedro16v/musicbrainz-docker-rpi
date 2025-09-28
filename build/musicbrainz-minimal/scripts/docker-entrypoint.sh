#!/bin/bash
set -e

# Function to log messages
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Configure DBDefs.pm from template if it exists and environment variables are set
configure_dbdefs() {
    local template_file="/musicbrainz-server/lib/DBDefs.pm.template"
    local target_file="/musicbrainz-server/lib/DBDefs.pm"
    
    if [ -f "$template_file" ]; then
        log "Configuring DBDefs.pm from template..."
        
        # Set default values if not provided
        export POSTGRES_HOST=${POSTGRES_HOST:-db}
        export POSTGRES_PORT=${POSTGRES_PORT:-5432}
        export POSTGRES_DB=${POSTGRES_DB:-musicbrainz_db}
        export POSTGRES_USER=${POSTGRES_USER:-musicbrainz}
        export POSTGRES_PASSWORD=${POSTGRES_PASSWORD:-musicbrainz}
        export REDIS_SERVER=${REDIS_SERVER:-redis}
        export REDIS_PORT=${REDIS_PORT:-6379}
        
        # Check if replication token is provided
        if [ -n "$REPLICATION_ACCESS_TOKEN" ]; then
            log "Replication token found, configuring for replication..."
            export REPLICATION_ACCESS_TOKEN="$REPLICATION_ACCESS_TOKEN"
        else
            log "No replication token provided, using empty token"
            export REPLICATION_ACCESS_TOKEN=""
        fi
        
        # Apply template substitution
        envsubst < "$template_file" > "$target_file"
        
        if [ $? -eq 0 ]; then
            log "DBDefs.pm configured successfully"
            
            # Verify configuration
            if grep -q "REPLICATION_ACCESS_TOKEN" "$target_file"; then
                log "Replication token configuration verified"
            else
                log "Warning: Replication token not found in generated DBDefs.pm"
            fi
        else
            log "Error: Failed to configure DBDefs.pm from template"
            exit 1
        fi
    else
        log "No DBDefs.pm template found, using existing configuration"
    fi
}

# Run configuration on container start
configure_dbdefs

# Execute the main command
log "Starting command: $*"
exec "$@"
