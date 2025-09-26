#!/bin/bash

# Script to configure DBDefs.pm from template using environment variables
# This script handles different environments (production, test, dev) automatically

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to detect environment based on container name or compose file
detect_environment() {
    local compose_file=""
    local container_name=""
    
    # Check if we're using a specific compose file
    if [ -f "compose/musicbrainz-test.yml" ] && docker compose -f compose/musicbrainz-test.yml ps | grep -q "Up"; then
        compose_file="compose/musicbrainz-test.yml"
        container_name="musicbrainz-minimal-test"
        echo "test"
    elif [ -f "compose/musicbrainz-dev.yml" ] && docker compose -f compose/musicbrainz-dev.yml ps | grep -q "Up"; then
        compose_file="compose/musicbrainz-dev.yml"
        container_name="musicbrainz-minimal-dev"
        echo "dev"
    else
        compose_file="docker-compose.yml"
        container_name="musicbrainz-minimal"
        echo "production"
    fi
}

# Function to get database host based on environment
get_database_host() {
    local env="$1"
    case "$env" in
        test)
            echo "db-test"
            ;;
        dev)
            echo "db-dev"
            ;;
        *)
            echo "db"
            ;;
    esac
}

# Function to get Redis host based on environment
get_redis_host() {
    local env="$1"
    case "$env" in
        test)
            echo "redis-test"
            ;;
        dev)
            echo "redis-dev"
            ;;
        *)
            echo "redis"
            ;;
    esac
}

# Main configuration function
configure_replication() {
    local environment="$1"
    local compose_file="$2"
    local container_name="$3"
    local token="$4"
    
    log_info "Configuring replication for $environment environment..."
    
    # Set environment-specific defaults
    local db_host=$(get_database_host "$environment")
    local redis_host=$(get_redis_host "$environment")
    
    # Export all environment variables
    export REPLICATION_ACCESS_TOKEN="$token"
    export POSTGRES_HOST="${POSTGRES_HOST:-$db_host}"
    export POSTGRES_PORT="${POSTGRES_PORT:-5432}"
    export POSTGRES_DB="${POSTGRES_DB:-musicbrainz_db}"
    export POSTGRES_USER="${POSTGRES_USER:-musicbrainz}"
    export POSTGRES_PASSWORD="${POSTGRES_PASSWORD:-musicbrainz}"
    export REDIS_SERVER="${REDIS_SERVER:-$redis_host}"
    export REDIS_PORT="${REDIS_PORT:-6379}"
    
    log_info "Using database host: $POSTGRES_HOST"
    log_info "Using Redis host: $REDIS_SERVER"
    
    # Apply template using envsubst
    if docker compose -f "$compose_file" exec "$container_name" bash -c "
        export REPLICATION_ACCESS_TOKEN='$REPLICATION_ACCESS_TOKEN'
        export POSTGRES_HOST='$POSTGRES_HOST'
        export POSTGRES_PORT='$POSTGRES_PORT'
        export POSTGRES_DB='$POSTGRES_DB'
        export POSTGRES_USER='$POSTGRES_USER'
        export POSTGRES_PASSWORD='$POSTGRES_PASSWORD'
        export REDIS_SERVER='$REDIS_SERVER'
        export REDIS_PORT='$REDIS_PORT'
        envsubst < /musicbrainz-server/lib/DBDefs.pm.template > /musicbrainz-server/lib/DBDefs.pm
    "; then
        log_success "Template applied successfully"
        
        # Verify the configuration
        if docker compose -f "$compose_file" exec "$container_name" bash -c "
            grep -q 'sub REPLICATION_TYPE { RT_MIRROR }' /musicbrainz-server/lib/DBDefs.pm &&
            grep -q 'sub REPLICATION_ACCESS_TOKEN' /musicbrainz-server/lib/DBDefs.pm &&
            grep -q 'host.*=>.*$POSTGRES_HOST' /musicbrainz-server/lib/DBDefs.pm
        "; then
            log_success "Configuration validation passed"
            return 0
        else
            log_error "Configuration validation failed"
            return 1
        fi
    else
        log_error "Failed to apply template"
        return 1
    fi
}

# Main execution
main() {
    log_info "=== MusicBrainz Replication Configuration ==="
    
    # Detect environment
    local environment=$(detect_environment)
    log_info "Detected environment: $environment"
    
    # Determine compose file and container name
    local compose_file=""
    local container_name=""
    
    case "$environment" in
        test)
            compose_file="compose/musicbrainz-test.yml"
            container_name="musicbrainz-minimal-test"
            ;;
        dev)
            compose_file="compose/musicbrainz-dev.yml"
            container_name="musicbrainz-minimal-dev"
            ;;
        *)
            compose_file="docker-compose.yml"
            container_name="musicbrainz-minimal"
            ;;
    esac
    
    # Check if token file exists
    if [ ! -f "local/secrets/metabrainz_access_token" ]; then
        log_error "Access token file not found: local/secrets/metabrainz_access_token"
        log_info "Please run ./scripts/setup-replication.sh first"
        exit 1
    fi
    
    # Read token
    local token=$(cat local/secrets/metabrainz_access_token | tr -d '\n')
    if [ ${#token} -ne 40 ]; then
        log_error "Invalid token length: ${#token} (expected 40 characters)"
        exit 1
    fi
    
    # Configure replication
    if configure_replication "$environment" "$compose_file" "$container_name" "$token"; then
        log_success "Replication configuration completed successfully!"
        log_info "Environment: $environment"
        log_info "Compose file: $compose_file"
        log_info "Container: $container_name"
    else
        log_error "Replication configuration failed"
        exit 1
    fi
}

# Run main function
main "$@"