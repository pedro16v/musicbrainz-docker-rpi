#!/bin/bash

# MusicBrainz ARM64 Deployment Validation Script
# This script validates the deployment and checks for common issues

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

# Validation results
VALIDATION_RESULTS=()
PASSED=0
FAILED=0
WARNINGS=0

# Add result
add_result() {
    local status="$1"
    local message="$2"
    VALIDATION_RESULTS+=("$status:$message")
    
    case $status in
        "PASS")
            ((PASSED++))
            log_success "$message"
            ;;
        "FAIL")
            ((FAILED++))
            log_error "$message"
            ;;
        "WARN")
            ((WARNINGS++))
            log_warning "$message"
            ;;
    esac
}

# Check if running from correct directory
check_directory() {
    log_info "Checking project directory..."
    
    if [ ! -f "docker-compose.yml" ]; then
        add_result "FAIL" "Not in musicbrainz-docker project directory"
        return 1
    fi
    
    if [ ! -f "scripts/setup-replication.sh" ]; then
        add_result "FAIL" "Missing setup-replication.sh script"
        return 1
    fi
    
    add_result "PASS" "Project directory structure is correct"
}

# Check system requirements
check_system_requirements() {
    log_info "Checking system requirements..."
    
    # Check architecture
    local arch=$(uname -m)
    if [[ "$arch" == "aarch64" || "$arch" == "arm64" ]]; then
        add_result "PASS" "ARM64 architecture detected: $arch"
    else
        add_result "WARN" "Non-ARM64 architecture detected: $arch (may work but not optimized)"
    fi
    
    # Check memory
    local available_memory=$(free -m | awk 'NR==2{printf "%.0f", $7}')
    if [ "$available_memory" -ge 1024 ]; then
        add_result "PASS" "Sufficient memory available: ${available_memory}MB"
    elif [ "$available_memory" -ge 512 ]; then
        add_result "WARN" "Low memory available: ${available_memory}MB (minimum recommended: 1GB)"
    else
        add_result "FAIL" "Insufficient memory: ${available_memory}MB (minimum required: 512MB)"
    fi
    
    # Check disk space
    local available_disk=$(df -BG . | awk 'NR==2{print $4}' | sed 's/G//')
    if [ "$available_disk" -ge 20 ]; then
        add_result "PASS" "Sufficient disk space: ${available_disk}GB"
    elif [ "$available_disk" -ge 10 ]; then
        add_result "WARN" "Low disk space: ${available_disk}GB (recommended: 20GB+)"
    else
        add_result "FAIL" "Insufficient disk space: ${available_disk}GB (minimum required: 10GB)"
    fi
    
    # Check swap
    local swap_size=$(free -h | grep Swap | awk '{print $2}')
    if [ "$swap_size" != "0B" ]; then
        add_result "PASS" "Swap available: $swap_size"
    else
        add_result "WARN" "No swap configured (recommended for ARM64 systems)"
    fi
}

# Check Docker installation
check_docker() {
    log_info "Checking Docker installation..."
    
    if ! command -v docker >/dev/null 2>&1; then
        add_result "FAIL" "Docker is not installed"
        return 1
    fi
    
    if ! docker --version >/dev/null 2>&1; then
        add_result "FAIL" "Docker is not working properly"
        return 1
    fi
    
    add_result "PASS" "Docker is installed and working"
    
    # Check Docker Compose
    if command -v docker-compose >/dev/null 2>&1; then
        add_result "PASS" "Docker Compose is available"
    elif docker compose version >/dev/null 2>&1; then
        add_result "PASS" "Docker Compose (plugin) is available"
    else
        add_result "FAIL" "Docker Compose is not available"
        return 1
    fi
    
    # Check Docker daemon
    if ! docker info >/dev/null 2>&1; then
        add_result "FAIL" "Docker daemon is not running"
        return 1
    fi
    
    add_result "PASS" "Docker daemon is running"
}

# Check port conflicts
check_port_conflicts() {
    log_info "Checking for port conflicts..."
    
    local postgres_port=$(grep -E "POSTGRES_EXTERNAL_PORT" env.template 2>/dev/null | cut -d'=' -f2 || echo "5432")
    local redis_port=$(grep -E "REDIS_EXTERNAL_PORT" env.template 2>/dev/null | cut -d'=' -f2 || echo "6379")
    
    if netstat -tlnp 2>/dev/null | grep -q ":$postgres_port "; then
        add_result "WARN" "Port $postgres_port is already in use"
    else
        add_result "PASS" "Port $postgres_port is available"
    fi
    
    if netstat -tlnp 2>/dev/null | grep -q ":$redis_port "; then
        add_result "WARN" "Port $redis_port is already in use"
    else
        add_result "PASS" "Port $redis_port is available"
    fi
}

# Check container status
check_containers() {
    log_info "Checking container status..."
    
    if ! docker compose ps | grep -q "Up"; then
        add_result "FAIL" "No containers are running"
        return 1
    fi
    
    # Check specific containers
    if docker compose ps | grep -q "db.*Up"; then
        add_result "PASS" "Database container is running"
    else
        add_result "FAIL" "Database container is not running"
    fi
    
    if docker compose ps | grep -q "redis.*Up"; then
        add_result "PASS" "Redis container is running"
    else
        add_result "FAIL" "Redis container is not running"
    fi
    
    if docker compose ps | grep -q "musicbrainz-minimal.*Up"; then
        add_result "PASS" "MusicBrainz container is running"
    else
        add_result "FAIL" "MusicBrainz container is not running"
    fi
}

# Check database connectivity
check_database_connectivity() {
    log_info "Checking database connectivity..."
    
    if ! docker compose exec musicbrainz-minimal bash -c "PGHOST=db PGPORT=5432 PGPASSWORD=musicbrainz psql -U musicbrainz -d musicbrainz_db -c 'SELECT 1;'" >/dev/null 2>&1; then
        add_result "FAIL" "Cannot connect to database"
        return 1
    fi
    
    add_result "PASS" "Database connection successful"
    
    # Check replication tables
    if docker compose exec musicbrainz-minimal bash -c "PGHOST=db PGPORT=5432 PGPASSWORD=musicbrainz psql -U musicbrainz -d musicbrainz_db -c 'SELECT 1 FROM dbmirror2.pending_data LIMIT 1;'" >/dev/null 2>&1; then
        add_result "PASS" "Replication tables exist"
    else
        add_result "FAIL" "Replication tables are missing"
    fi
}

# Check Perl dependencies
check_perl_dependencies() {
    log_info "Checking Perl dependencies..."
    
    local required_modules=("aliased" "GnuPG" "Redis" "List::AllUtils")
    local missing_modules=()
    
    for module in "${required_modules[@]}"; do
        if ! docker compose exec musicbrainz-minimal perl -M$module -e 1 2>/dev/null; then
            missing_modules+=($module)
        fi
    done
    
    if [ ${#missing_modules[@]} -eq 0 ]; then
        add_result "PASS" "All required Perl modules are available"
    else
        add_result "FAIL" "Missing Perl modules: ${missing_modules[*]}"
    fi
}

# Check replication configuration
check_replication_config() {
    log_info "Checking replication configuration..."
    
    # Check replication type
    if docker compose exec musicbrainz-minimal grep -q "sub REPLICATION_TYPE { RT_MIRROR }" /musicbrainz-server/lib/DBDefs.pm; then
        add_result "PASS" "Replication type is configured as RT_MIRROR"
    else
        add_result "FAIL" "Replication type is not configured as RT_MIRROR"
    fi
    
    # Check access token
    if docker compose exec musicbrainz-minimal grep -q "sub REPLICATION_ACCESS_TOKEN { '[^']*' }" /musicbrainz-server/lib/DBDefs.pm; then
        add_result "PASS" "Replication access token is configured"
    else
        add_result "FAIL" "Replication access token is not configured"
    fi
    
    # Check database connections
    if docker compose exec musicbrainz-minimal grep -q "host.*=>.*'" /musicbrainz-server/lib/DBDefs.pm; then
        add_result "PASS" "Database host is configured"
    else
        add_result "FAIL" "Database host is not configured"
    fi
}

# Check replication functionality
check_replication_functionality() {
    log_info "Checking replication functionality..."
    
    # Check if replication is running
    if docker compose exec musicbrainz-minimal ps aux | grep -q "LoadReplicationChanges"; then
        add_result "PASS" "Replication process is running"
    else
        add_result "WARN" "Replication process is not running"
    fi
    
    # Test replication script
    if docker compose exec musicbrainz-minimal bash -c "cd /musicbrainz-server && timeout 10 ./admin/replication/LoadReplicationChanges --dry-run" >/dev/null 2>&1; then
        add_result "PASS" "Replication script test passed"
    else
        add_result "WARN" "Replication script test failed (may be normal for initial setup)"
    fi
}

# Check logs
check_logs() {
    log_info "Checking logs..."
    
    if [ -f "logs/replication.log" ]; then
        add_result "PASS" "Replication log file exists"
        
        # Check for errors in logs
        if grep -q "ERROR\|FATAL" logs/replication.log 2>/dev/null; then
            add_result "WARN" "Errors found in replication logs"
        else
            add_result "PASS" "No errors found in replication logs"
        fi
    else
        add_result "WARN" "Replication log file not found"
    fi
}

# Generate report
generate_report() {
    echo
    log_info "=== Validation Report ==="
    echo
    
    log_info "Summary:"
    log_info "- Passed: $PASSED"
    log_info "- Failed: $FAILED"
    log_info "- Warnings: $WARNINGS"
    echo
    
    if [ $FAILED -eq 0 ]; then
        log_success "All critical checks passed!"
        if [ $WARNINGS -gt 0 ]; then
            log_warning "Please review the warnings above"
        fi
    else
        log_error "Some critical checks failed. Please fix the issues above."
    fi
    
    echo
    log_info "Detailed Results:"
    for result in "${VALIDATION_RESULTS[@]}"; do
        local status=$(echo "$result" | cut -d':' -f1)
        local message=$(echo "$result" | cut -d':' -f2-)
        
        case $status in
            "PASS")
                log_success "✓ $message"
                ;;
            "FAIL")
                log_error "✗ $message"
                ;;
            "WARN")
                log_warning "⚠ $message"
                ;;
        esac
    done
    
    echo
    if [ $FAILED -gt 0 ]; then
        log_info "For help resolving issues, see TROUBLESHOOTING.md"
    fi
}

# Main function
main() {
    echo "=== MusicBrainz ARM64 Deployment Validation ==="
    echo
    
    check_directory || exit 1
    check_system_requirements
    check_docker || exit 1
    check_port_conflicts
    check_containers || exit 1
    check_database_connectivity || exit 1
    check_perl_dependencies
    check_replication_config
    check_replication_functionality
    check_logs
    
    generate_report
    
    if [ $FAILED -gt 0 ]; then
        exit 1
    fi
}

# Run main function if script is executed directly
if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
    main "$@"
fi
