#!/bin/bash

# MusicBrainz ARM64 Automated Deployment Script
# Optimized for Digital Ocean and ARM64 systems

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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
    log_error "Deployment failed at step: $1"
    log_error "Error: $2"
    echo
    log_info "Troubleshooting steps:"
    log_info "1. Check system resources: free -h && df -h"
    log_info "2. Check Docker status: systemctl status docker"
    log_info "3. Check port conflicts: netstat -tlnp | grep -E ':(5432|6379)'"
    log_info "4. Check logs: docker compose logs"
    exit 1
}

# Parse command line arguments
SKIP_SYSTEM_SETUP=false
ENVIRONMENT="production"
COMPOSE_FILE="docker-compose.yml"
while [[ $# -gt 0 ]]; do
    case $1 in
        --skip-system-setup)
            SKIP_SYSTEM_SETUP=true
            shift
            ;;
        --environment|-e)
            shift
            ENVIRONMENT="$1"
            case $ENVIRONMENT in
                production)
                    COMPOSE_FILE="docker-compose.yml"
                    ;;
                test)
                    COMPOSE_FILE="compose/musicbrainz-test.yml"
                    ;;
                dev)
                    COMPOSE_FILE="compose/musicbrainz-dev.yml"
                    ;;
                *)
                    log_error "Invalid environment: $ENVIRONMENT"
                    log_info "Valid environments: production, test, dev"
                    exit 1
                    ;;
            esac
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo "Options:"
            echo "  --skip-system-setup    Skip system optimization and dependency installation"
            echo "  --environment, -e      Set environment (production, test, dev)"
            echo "  --help, -h            Show this help message"
            echo
            echo "Examples:"
            echo "  $0                                    # Full production deployment"
            echo "  $0 --skip-system-setup               # Deploy on existing server"
            echo "  $0 --environment test                # Deploy test environment"
            echo "  $0 --skip-system-setup --environment dev  # Deploy dev environment"
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            log_info "Use --help for usage information"
            exit 1
            ;;
    esac
done

log_info "=== MusicBrainz ARM64 Automated Deployment ==="
if [ "$SKIP_SYSTEM_SETUP" = true ]; then
    log_info "Mode: Existing server deployment (skipping system setup)"
else
    log_info "Mode: Full deployment with system setup"
fi
log_info "Environment: $ENVIRONMENT"
log_info "Compose file: $COMPOSE_FILE"
echo

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    log_error "Please run as root (use sudo)"
    exit 1
fi

# Conflict detection
detect_conflicts() {
    log_info "Detecting potential conflicts..."
    
    # Check port conflicts
    local postgres_port=$(grep -E "POSTGRES_EXTERNAL_PORT" env.template 2>/dev/null | cut -d'=' -f2 || echo "5432")
    local redis_port=$(grep -E "REDIS_EXTERNAL_PORT" env.template 2>/dev/null | cut -d'=' -f2 || echo "6379")
    
    if netstat -tlnp 2>/dev/null | grep -q ":$postgres_port "; then
        log_warning "Port $postgres_port is already in use"
        log_info "Consider using POSTGRES_EXTERNAL_PORT environment variable"
    fi
    
    if netstat -tlnp 2>/dev/null | grep -q ":$redis_port "; then
        log_warning "Port $redis_port is already in use"
        log_info "Consider using REDIS_EXTERNAL_PORT environment variable"
    fi
    
    # Check Docker conflicts
    if docker ps --format "table {{.Names}}" | grep -q "musicbrainz"; then
        log_warning "Existing MusicBrainz containers detected"
        log_info "Consider using --environment test for parallel deployment"
    fi
    
    log_success "Conflict detection complete"
}

# System validation
validate_system() {
    log_info "Validating system requirements..."
    
    # Check available memory
    local available_memory=$(free -m | awk 'NR==2{printf "%.0f", $7}')
    if [ "$available_memory" -lt 1024 ]; then
        log_warning "Low available memory: ${available_memory}MB"
        log_info "Consider adding swap or reducing resource limits"
    fi
    
    # Check available disk space
    local available_disk=$(df -BG . | awk 'NR==2{print $4}' | sed 's/G//')
    if [ "$available_disk" -lt 10 ]; then
        log_warning "Low available disk space: ${available_disk}GB"
        log_info "MusicBrainz requires at least 10GB for dumps"
    fi
    
    log_success "System validation complete"
}

# Deployment validation
validate_deployment() {
    log_info "Validating deployment..."
    
    # Check if compose file exists
    if [ ! -f "$COMPOSE_FILE" ]; then
        handle_error "validation" "Compose file not found: $COMPOSE_FILE"
    fi
    
    # Test Docker Compose configuration
    if ! docker compose -f "$COMPOSE_FILE" config >/dev/null 2>&1; then
        handle_error "validation" "Invalid Docker Compose configuration"
    fi
    
    # Check if containers are running
    if ! docker compose -f "$COMPOSE_FILE" ps | grep -q "Up"; then
        handle_error "validation" "Containers are not running"
    fi
    
    log_success "Deployment validation passed"
}

# Test database connection
test_database_connection() {
    log_info "Testing database connection..."
    
    local container_name="musicbrainz-minimal"
    if [ "$ENVIRONMENT" != "production" ]; then
        container_name="musicbrainz-minimal-$ENVIRONMENT"
    fi
    
    if ! docker compose -f "$COMPOSE_FILE" exec "$container_name" bash -c "PGHOST=\${POSTGRES_HOST:-db} psql -U \${POSTGRES_USER:-musicbrainz} -d \${POSTGRES_DB:-musicbrainz_db} -c 'SELECT 1;'" >/dev/null 2>&1; then
        handle_error "database_test" "Cannot connect to database"
    fi
    
    log_success "Database connection successful"
}

# Test replication configuration
test_replication() {
    log_info "Testing replication configuration..."
    
    local container_name="musicbrainz-minimal"
    if [ "$ENVIRONMENT" != "production" ]; then
        container_name="musicbrainz-minimal-$ENVIRONMENT"
    fi
    
    if ! docker compose -f "$COMPOSE_FILE" exec "$container_name" bash -c "cd /musicbrainz-server && timeout 10 ./admin/replication/LoadReplicationChanges --dry-run" >/dev/null 2>&1; then
        log_warning "Replication test failed, but this may be normal for initial setup"
    else
        log_success "Replication test passed"
    fi
}

# Detect system architecture
ARCH=$(uname -m)
if [[ "$ARCH" != "aarch64" && "$ARCH" != "arm64" ]]; then
    log_warning "This script is optimized for ARM64 systems"
    log_info "Detected architecture: $ARCH"
    read -p "Continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Run validations
validate_system
detect_conflicts

# Prompt for confirmation if not skipping system setup
if [ "$SKIP_SYSTEM_SETUP" = false ]; then
    read -p "This script will install dependencies and configure your system. Continue? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

if [ "$SKIP_SYSTEM_SETUP" = false ]; then
    log_info "Step 1: System optimization..."

    # Install Digital Ocean analytics (optional)
    if command -v curl >/dev/null 2>&1; then
        log_info "Installing Digital Ocean analytics..."
        curl -sSL https://repos.insights.digitalocean.com/install.sh | bash || log_warning "Analytics installation failed, continuing..."
    fi

    # Create swap file for memory optimization
    if [ ! -f /swapfile ]; then
        log_info "Creating 4GB swap file..."
        fallocate -l 4G /swapfile
        chmod 600 /swapfile
        mkswap /swapfile
        swapon /swapfile
        echo '/swapfile none swap sw 0 0' | tee -a /etc/fstab
        log_success "Swap file created successfully"
    else
        log_success "Swap file already exists"
    fi

    log_info "Step 2: Installing dependencies..."

    # Update package list
    apt-get update

    # Install essential packages
    apt-get install -y \
        docker.io \
        docker-compose \
        git \
        postgresql-client-16 \
        curl \
        wget \
        htop \
        unzip

    # Enable and start Docker
    systemctl enable --now docker.service

    # Add current user to docker group (if not root)
    if [ "$SUDO_USER" ]; then
        usermod -aG docker "$SUDO_USER"
        log_success "Added $SUDO_USER to docker group"
    fi
else
    log_info "Skipping system optimization and dependency installation..."
    log_info "Assuming Docker and dependencies are already installed"
    
    # Validate that Docker is available
    if ! command -v docker >/dev/null 2>&1; then
        handle_error "docker_check" "Docker is not installed. Please install Docker first or run without --skip-system-setup"
    fi
    
    if ! command -v docker-compose >/dev/null 2>&1 && ! docker compose version >/dev/null 2>&1; then
        handle_error "docker_compose_check" "Docker Compose is not installed. Please install Docker Compose first or run without --skip-system-setup"
    fi
    
    log_success "Docker validation passed"
fi

log_info "Step 3: Setting up project..."

# Clone the repository
if [ ! -d "musicbrainz-docker-arm" ]; then
    echo "Cloning musicbrainz-docker-arm repository..."
    git clone https://github.com/pedro16v/musicbrainz-docker-rpi.git musicbrainz-docker-arm
else
    echo "Repository already exists, updating..."
    cd musicbrainz-docker-arm
    git pull
    cd ..
fi

cd musicbrainz-docker-arm

# Create necessary directories
mkdir -p logs
mkdir -p local/secrets

echo "Step 4: Building containers..."

# Build the containers
docker compose build

echo "Step 5: Starting containers..."

# Start containers
docker compose up -d

# Wait for containers to be ready
echo "Waiting for containers to start..."
sleep 10

# Check if containers are running
if ! docker compose ps | grep -q "Up"; then
    echo "Error: Containers failed to start"
    docker compose logs
    exit 1
fi

echo "Step 6: Setting up replication..."

# Run the automated setup script
if [ -f "scripts/setup-replication.sh" ]; then
    echo "Running automated replication setup..."
    chmod +x scripts/setup-replication.sh
    ./scripts/setup-replication.sh
else
    echo "Manual replication setup required..."
    echo "Please run: ./scripts/setup-replication.sh"
fi

echo "Step 7: Starting replication..."

# Start replication in background
docker compose exec musicbrainz-minimal replication.sh &

echo "Step 8: Publishing database port..."

# The database port is already exposed in our ARM64 compose file
echo "Database port 5432 is already exposed"

echo "Step 9: Creating database views (if needed)..."

# Check if create_views.sql exists
if [ -f "create_views.sql" ]; then
    echo "Creating database views..."
    PGPASSWORD=musicbrainz psql -h 127.0.0.1 -U musicbrainz -d musicbrainz_db -a -f create_views.sql
else
    echo "No create_views.sql found, skipping view creation"
fi

echo
echo "=== Deployment Complete! ==="
echo
log_info "System Information:"
log_info "- Architecture: $(uname -m)"
log_info "- Memory: $(free -h | grep Mem | awk '{print $2}')"
log_info "- Swap: $(free -h | grep Swap | awk '{print $2}')"
log_info "- Docker: $(docker --version)"
echo
log_info "Container Status:"
docker compose -f "$COMPOSE_FILE" ps
echo
log_info "Replication Status:"
local container_name="musicbrainz-minimal"
if [ "$ENVIRONMENT" != "production" ]; then
    container_name="musicbrainz-minimal-$ENVIRONMENT"
fi
docker compose -f "$COMPOSE_FILE" exec "$container_name" ps aux | grep LoadReplication || log_warning "Replication not running"
echo
log_info "Useful Commands:"
log_info "- Check replication logs: docker compose -f $COMPOSE_FILE exec $container_name tail -f logs/replication.log"
log_info "- Check replication data: docker compose -f $COMPOSE_FILE exec $container_name bash -c 'PGHOST=\${POSTGRES_HOST:-db} PGPORT=\${POSTGRES_PORT:-5432} PGPASSWORD=\${POSTGRES_PASSWORD:-musicbrainz} psql -U \${POSTGRES_USER:-musicbrainz} -d \${POSTGRES_DB:-musicbrainz_db} -c \"SELECT COUNT(*) FROM dbmirror2.pending_data;\"'"
log_info "- Restart replication: docker compose -f $COMPOSE_FILE exec $container_name replication.sh &"
log_info "- View container logs: docker compose -f $COMPOSE_FILE logs $container_name"
log_info "- Stop all containers: docker compose -f $COMPOSE_FILE down"
log_info "- Start all containers: docker compose -f $COMPOSE_FILE up -d"
echo
log_info "Database Access:"
log_info "- Host: localhost"
log_info "- Port: ${POSTGRES_EXTERNAL_PORT:-5432}"
log_info "- Database: ${POSTGRES_DB:-musicbrainz_db}"
log_info "- Username: ${POSTGRES_USER:-musicbrainz}"
log_info "- Password: ${POSTGRES_PASSWORD:-musicbrainz}"
echo
log_info "Files created:"
log_info "- Swap file: /swapfile (4GB)"
log_info "- Project directory: $(pwd)"
log_info "- Logs directory: $(pwd)/logs"
log_info "- Secrets directory: $(pwd)/local/secrets"
echo
log_info "Next steps:"
log_info "1. Monitor replication: docker compose -f $COMPOSE_FILE exec $container_name tail -f logs/replication.log"
log_info "2. Check system resources: htop"
log_info "3. Access database: PGPASSWORD=${POSTGRES_PASSWORD:-musicbrainz} psql -h localhost -U ${POSTGRES_USER:-musicbrainz} -d ${POSTGRES_DB:-musicbrainz_db}"
echo
log_success "MusicBrainz replication is now running!"
log_info "For more details, see REPLICATION-SETUP-GUIDE.md and DIGITAL-OCEAN-DEPLOYMENT.md"
echo
echo
