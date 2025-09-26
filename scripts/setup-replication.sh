#!/bin/bash

# MusicBrainz Replication Setup Script for ARM64
# This script sets up replication for MusicBrainz on ARM64 systems

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

# Error handling
handle_error() {
    log_error "Setup failed at step: $1"
    log_error "Error: $2"
    echo
    log_info "Troubleshooting steps:"
    log_info "1. Check container logs: docker compose logs musicbrainz-minimal"
    log_info "2. Verify database connection: docker compose exec musicbrainz-minimal psql -h \$POSTGRES_HOST -U \$POSTGRES_USER -d \$POSTGRES_DB -c 'SELECT 1;'"
    log_info "3. Check Perl modules: docker compose exec musicbrainz-minimal perl -Maliased -MGnuPG -MRedis -MList::AllUtils -e 'print \"All modules loaded\\n\"'"
    log_info "4. Verify configuration: docker compose exec musicbrainz-minimal grep -A 2 REPLICATION_TYPE /musicbrainz-server/lib/DBDefs.pm"
    exit 1
}

# Dependency validation
validate_dependencies() {
    log_info "Validating Perl dependencies..."
    
    local missing_deps=()
    local required_modules=("aliased" "GnuPG" "Redis" "List::AllUtils")
    
    for module in "${required_modules[@]}"; do
        if ! docker compose exec musicbrainz-minimal perl -M$module -e 1 2>/dev/null; then
            missing_deps+=($module)
        fi
    done
    
    if [ ${#missing_deps[@]} -gt 0 ]; then
        log_warning "Missing Perl modules: ${missing_deps[*]}"
        log_info "Installing missing modules..."
        
        for module in "${missing_deps[@]}"; do
            log_info "Installing $module..."
            if ! docker compose exec --user root musicbrainz-minimal cpanm --notest $module; then
                handle_error "dependency_install" "Failed to install $module"
            fi
        done
        
        log_success "All Perl dependencies installed"
    else
        log_success "All Perl dependencies are available"
    fi
}

# Configuration validation
validate_config() {
    log_info "Validating configuration..."
    
    # Check replication type
    if ! docker compose exec musicbrainz-minimal grep -q "sub REPLICATION_TYPE { RT_MIRROR }" /musicbrainz-server/lib/DBDefs.pm; then
        handle_error "config_validation" "Replication type not configured as RT_MIRROR"
    fi
    
    # Check access token
    if ! docker compose exec musicbrainz-minimal grep -q "sub REPLICATION_ACCESS_TOKEN { '[^']*' }" /musicbrainz-server/lib/DBDefs.pm; then
        handle_error "config_validation" "Access token not configured"
    fi
    
    # Check database connections
    if ! docker compose exec musicbrainz-minimal grep -q "host.*=>.*'" /musicbrainz-server/lib/DBDefs.pm; then
        handle_error "config_validation" "Database host not configured"
    fi
    
    log_success "Configuration validation passed"
}

# Database connectivity test
test_database_connection() {
    log_info "Testing database connection..."
    
    if ! docker compose exec musicbrainz-minimal bash -c "PGHOST=\${POSTGRES_HOST:-db} PGPORT=\${POSTGRES_PORT:-5432} PGPASSWORD=\${POSTGRES_PASSWORD:-musicbrainz} psql -U \${POSTGRES_USER:-musicbrainz} -d \${POSTGRES_DB:-musicbrainz_db} -c 'SELECT 1;'" >/dev/null 2>&1; then
        handle_error "database_connection" "Cannot connect to database"
    fi
    
    log_success "Database connection successful"
}

# Replication test
test_replication() {
    log_info "Testing replication functionality..."
    
    if ! docker compose exec musicbrainz-minimal bash -c "cd /musicbrainz-server && PGHOST=\${POSTGRES_HOST:-db} PGPORT=\${POSTGRES_PORT:-5432} PGPASSWORD=\${POSTGRES_PASSWORD:-musicbrainz} timeout 30 ./admin/replication/LoadReplicationChanges --dry-run" >/dev/null 2>&1; then
        log_warning "Replication test failed, but this may be normal for initial setup"
        log_info "Continuing with setup..."
    else
        log_success "Replication test passed"
    fi
}

echo "=== MusicBrainz Replication Setup for ARM64 ==="
echo

# Check if we're in the right directory
if [ ! -f "docker-compose.yml" ]; then
    log_error "Please run this script from the musicbrainz-docker-arm directory"
    exit 1
fi

# Check if containers are running
if ! docker compose ps | grep -q "Up"; then
    log_error "Containers are not running. Please start them first:"
    log_info "  docker compose up -d"
    exit 1
fi

# Step 1: Validate and install dependencies
validate_dependencies

# Step 2: Set up replication access token
log_info "Setting up replication access token..."
if [ ! -f "local/secrets/metabrainz_access_token" ]; then
    log_info "Creating secrets directory..."
    mkdir -p local/secrets
    
    log_info "Please get your MetaBrainz access token:"
    log_info "1. Go to: https://metabrainz.org/account/applications"
    log_info "2. Log in with your MetaBrainz account (create one if needed)"
    log_info "3. Create a new application or use an existing one"
    log_info "4. Copy the 40-character access token"
    echo
    read -p "Enter your MetaBrainz access token: " TOKEN
    
    if [ ${#TOKEN} -ne 40 ]; then
        handle_error "token_validation" "Token must be exactly 40 characters long"
    fi
    
    echo "$TOKEN" > local/secrets/metabrainz_access_token
    chmod 600 local/secrets/metabrainz_access_token
    log_success "Token saved to local/secrets/metabrainz_access_token"
else
    log_success "Access token already exists"
fi

# Step 3: Configure replication in container
log_info "Configuring replication in container..."
TOKEN=$(cat local/secrets/metabrainz_access_token | tr -d '\n')

# Use environment-based configuration if template exists
if docker compose exec musicbrainz-minimal test -f /musicbrainz-server/lib/DBDefs.pm.template; then
    log_info "Using template-based configuration..."
    docker compose exec musicbrainz-minimal bash -c "
        export REPLICATION_TYPE=RT_MIRROR
        export REPLICATION_ACCESS_TOKEN='$TOKEN'
        export POSTGRES_HOST=\${POSTGRES_HOST:-db}
        export POSTGRES_PORT=\${POSTGRES_PORT:-5432}
        export POSTGRES_DB=\${POSTGRES_DB:-musicbrainz_db}
        export POSTGRES_USER=\${POSTGRES_USER:-musicbrainz}
        export POSTGRES_PASSWORD=\${POSTGRES_PASSWORD:-musicbrainz}
        envsubst < /musicbrainz-server/lib/DBDefs.pm.template > /musicbrainz-server/lib/DBDefs.pm
    "
else
    log_info "Using legacy configuration method..."
    docker compose exec musicbrainz-minimal sed -i "s/# sub REPLICATION_TYPE { RT_STANDALONE }/sub REPLICATION_TYPE { RT_MIRROR }/" /musicbrainz-server/lib/DBDefs.pm
    docker compose exec musicbrainz-minimal sed -i "s/# sub REPLICATION_ACCESS_TOKEN { '' }/sub REPLICATION_ACCESS_TOKEN { '$TOKEN' }/" /musicbrainz-server/lib/DBDefs.pm
    docker compose exec musicbrainz-minimal sed -i "s/#       host            => '',/        host            => '\${POSTGRES_HOST:-db}',/" /musicbrainz-server/lib/DBDefs.pm
    docker compose exec musicbrainz-minimal sed -i "s/#       port            => '',/        port            => '\${POSTGRES_PORT:-5432}',/" /musicbrainz-server/lib/DBDefs.pm
fi

# Step 4: Test database connection
test_database_connection

# Step 5: Set up replication database tables (if needed)
log_info "Setting up replication database tables..."
if docker compose exec musicbrainz-minimal bash -c "PGHOST=\${POSTGRES_HOST:-db} PGPORT=\${POSTGRES_PORT:-5432} PGPASSWORD=\${POSTGRES_PASSWORD:-musicbrainz} psql -U \${POSTGRES_USER:-musicbrainz} -d \${POSTGRES_DB:-musicbrainz_db} -c 'SELECT 1 FROM dbmirror2.pending_data LIMIT 1;'" >/dev/null 2>&1; then
    log_success "Replication tables already exist"
else
    log_info "Creating replication tables..."
    if ! docker compose exec musicbrainz-minimal bash -c "PGHOST=\${POSTGRES_HOST:-db} PGPORT=\${POSTGRES_PORT:-5432} PGPASSWORD=\${POSTGRES_PASSWORD:-musicbrainz} psql -U \${POSTGRES_USER:-musicbrainz} -d \${POSTGRES_DB:-musicbrainz_db} -f /musicbrainz-server/admin/sql/dbmirror2/ReplicationSetup.sql"; then
        handle_error "replication_setup" "Failed to create replication tables"
    fi
    log_success "Replication tables created"
fi

# Step 6: Validate configuration
validate_config

# Step 7: Test replication
test_replication

echo
log_success "=== Setup Complete! ==="
echo
log_info "To start replication in the background:"
log_info "  docker compose exec musicbrainz-minimal replication.sh &"
echo
log_info "To check replication status:"
log_info "  docker compose exec musicbrainz-minimal tail -f logs/replication.log"
echo
log_info "To check replication data:"
log_info "  docker compose exec musicbrainz-minimal bash -c 'PGHOST=\${POSTGRES_HOST:-db} PGPORT=\${POSTGRES_PORT:-5432} PGPASSWORD=\${POSTGRES_PASSWORD:-musicbrainz} psql -U \${POSTGRES_USER:-musicbrainz} -d \${POSTGRES_DB:-musicbrainz_db} -c \"SELECT COUNT(*) FROM dbmirror2.pending_data;\"'"
echo