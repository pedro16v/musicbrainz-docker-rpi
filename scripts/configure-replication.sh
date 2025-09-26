#!/bin/bash

# Configuration script for MusicBrainz replication
# This script generates DBDefs.pm from template using environment variables

set -e

# Default values
export POSTGRES_DB="${POSTGRES_DB:-musicbrainz_db}"
export POSTGRES_USER="${POSTGRES_USER:-musicbrainz}"
export POSTGRES_PASSWORD="${POSTGRES_PASSWORD:-musicbrainz}"
export POSTGRES_HOST="${POSTGRES_HOST:-db}"
export POSTGRES_PORT="${POSTGRES_PORT:-5432}"
export REPLICATION_TYPE="${REPLICATION_TYPE:-RT_MIRROR}"
export REPLICATION_ACCESS_TOKEN="${REPLICATION_ACCESS_TOKEN:-}"
export REDIS_SERVER="${REDIS_SERVER:-redis}"
export REDIS_PORT="${REDIS_PORT:-6379}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Validate required environment variables
validate_env() {
    if [ -z "$REPLICATION_ACCESS_TOKEN" ]; then
        log_error "REPLICATION_ACCESS_TOKEN is required"
        exit 1
    fi
    
    if [ ${#REPLICATION_ACCESS_TOKEN} -ne 40 ]; then
        log_error "REPLICATION_ACCESS_TOKEN must be exactly 40 characters"
        exit 1
    fi
    
    log_success "Environment validation passed"
}

# Generate configuration from template
generate_config() {
    local template_file="$1"
    local output_file="$2"
    
    if [ ! -f "$template_file" ]; then
        log_error "Template file not found: $template_file"
        exit 1
    fi
    
    log_info "Generating configuration from template..."
    envsubst < "$template_file" > "$output_file"
    log_success "Configuration generated: $output_file"
}

# Main function
main() {
    local template_file="${1:-/musicbrainz-server/lib/DBDefs.pm.template}"
    local output_file="${2:-/musicbrainz-server/lib/DBDefs.pm}"
    
    log_info "Configuring MusicBrainz replication..."
    log_info "Database: $POSTGRES_HOST:$POSTGRES_PORT/$POSTGRES_DB"
    log_info "User: $POSTGRES_USER"
    log_info "Replication Type: $REPLICATION_TYPE"
    
    validate_env
    generate_config "$template_file" "$output_file"
    
    log_success "Configuration complete!"
}

# Run main function if script is executed directly
if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
    main "$@"
fi
