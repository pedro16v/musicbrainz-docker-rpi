#!/bin/bash

# MusicBrainz Replication Test Script
# This script tests the replication functionality

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

# Test results
TEST_RESULTS=()
PASSED=0
FAILED=0

# Add test result
add_test_result() {
    local status="$1"
    local message="$2"
    TEST_RESULTS+=("$status:$message")
    
    case $status in
        "PASS")
            ((PASSED++))
            log_success "$message"
            ;;
        "FAIL")
            ((FAILED++))
            log_error "$message"
            ;;
    esac
}

# Test database connection
test_database_connection() {
    log_info "Testing database connection..."
    
    if docker compose exec musicbrainz-minimal bash -c "PGHOST=db PGPORT=5432 PGPASSWORD=musicbrainz psql -U musicbrainz -d musicbrainz_db -c 'SELECT 1;'" >/dev/null 2>&1; then
        add_test_result "PASS" "Database connection successful"
    else
        add_test_result "FAIL" "Database connection failed"
        return 1
    fi
}

# Test replication tables
test_replication_tables() {
    log_info "Testing replication tables..."
    
    local tables=("pending_data" "pending_keys" "pending_ts")
    
    for table in "${tables[@]}"; do
        if docker compose exec musicbrainz-minimal bash -c "PGHOST=db PGPORT=5432 PGPASSWORD=musicbrainz psql -U musicbrainz -d musicbrainz_db -c 'SELECT 1 FROM dbmirror2.$table LIMIT 1;'" >/dev/null 2>&1; then
            add_test_result "PASS" "Replication table $table exists"
        else
            add_test_result "FAIL" "Replication table $table does not exist"
        fi
    done
}

# Test Perl modules
test_perl_modules() {
    log_info "Testing Perl modules..."
    
    local modules=("aliased" "GnuPG" "Redis" "List::AllUtils")
    
    for module in "${modules[@]}"; do
        if docker compose exec musicbrainz-minimal perl -M$module -e 1 2>/dev/null; then
            add_test_result "PASS" "Perl module $module is available"
        else
            add_test_result "FAIL" "Perl module $module is not available"
        fi
    done
}

# Test replication configuration
test_replication_config() {
    log_info "Testing replication configuration..."
    
    # Test replication type
    if docker compose exec musicbrainz-minimal grep -q "sub REPLICATION_TYPE { RT_MIRROR }" /musicbrainz-server/lib/DBDefs.pm; then
        add_test_result "PASS" "Replication type is RT_MIRROR"
    else
        add_test_result "FAIL" "Replication type is not RT_MIRROR"
    fi
    
    # Test access token
    if docker compose exec musicbrainz-minimal grep -q "sub REPLICATION_ACCESS_TOKEN { '[^']*' }" /musicbrainz-server/lib/DBDefs.pm; then
        add_test_result "PASS" "Replication access token is configured"
    else
        add_test_result "FAIL" "Replication access token is not configured"
    fi
    
    # Test database host configuration
    if docker compose exec musicbrainz-minimal grep -q "host.*=>.*'db'" /musicbrainz-server/lib/DBDefs.pm; then
        add_test_result "PASS" "Database host is configured as 'db'"
    else
        add_test_result "FAIL" "Database host is not configured as 'db'"
    fi
}

# Test replication script
test_replication_script() {
    log_info "Testing replication script..."
    
    # Test script exists
    if docker compose exec musicbrainz-minimal test -f /usr/local/bin/replication.sh; then
        add_test_result "PASS" "Replication script exists"
    else
        add_test_result "FAIL" "Replication script does not exist"
        return 1
    fi
    
    # Test script is executable
    if docker compose exec musicbrainz-minimal test -x /usr/local/bin/replication.sh; then
        add_test_result "PASS" "Replication script is executable"
    else
        add_test_result "FAIL" "Replication script is not executable"
    fi
}

# Test LoadReplicationChanges
test_load_replication_changes() {
    log_info "Testing LoadReplicationChanges..."
    
    # Test script exists
    if docker compose exec musicbrainz-minimal test -f /musicbrainz-server/admin/replication/LoadReplicationChanges; then
        add_test_result "PASS" "LoadReplicationChanges script exists"
    else
        add_test_result "FAIL" "LoadReplicationChanges script does not exist"
        return 1
    fi
    
    # Test script is executable
    if docker compose exec musicbrainz-minimal test -x /musicbrainz-server/admin/replication/LoadReplicationChanges; then
        add_test_result "PASS" "LoadReplicationChanges script is executable"
    else
        add_test_result "FAIL" "LoadReplicationChanges script is not executable"
    fi
    
    # Test dry run
    if docker compose exec musicbrainz-minimal bash -c "cd /musicbrainz-server && timeout 30 ./admin/replication/LoadReplicationChanges --dry-run" >/dev/null 2>&1; then
        add_test_result "PASS" "LoadReplicationChanges dry run successful"
    else
        add_test_result "FAIL" "LoadReplicationChanges dry run failed"
    fi
}

# Test replication data
test_replication_data() {
    log_info "Testing replication data..."
    
    # Check if there's any pending data
    local pending_count=$(docker compose exec musicbrainz-minimal bash -c "PGHOST=db PGPORT=5432 PGPASSWORD=musicbrainz psql -U musicbrainz -d musicbrainz_db -t -c 'SELECT COUNT(*) FROM dbmirror2.pending_data;'" 2>/dev/null | tr -d ' \n')
    
    if [ -n "$pending_count" ] && [ "$pending_count" -ge 0 ]; then
        add_test_result "PASS" "Replication data query successful (pending: $pending_count)"
    else
        add_test_result "FAIL" "Replication data query failed"
    fi
}

# Test replication process
test_replication_process() {
    log_info "Testing replication process..."
    
    # Check if replication is running
    if docker compose exec musicbrainz-minimal ps aux | grep -q "LoadReplicationChanges"; then
        add_test_result "PASS" "Replication process is running"
    else
        add_test_result "FAIL" "Replication process is not running"
    fi
}

# Test logs
test_logs() {
    log_info "Testing logs..."
    
    # Check if log directory exists
    if docker compose exec musicbrainz-minimal test -d /musicbrainz-server/logs; then
        add_test_result "PASS" "Log directory exists"
    else
        add_test_result "FAIL" "Log directory does not exist"
    fi
    
    # Check if replication log exists
    if docker compose exec musicbrainz-minimal test -f /musicbrainz-server/logs/replication.log; then
        add_test_result "PASS" "Replication log file exists"
    else
        add_test_result "FAIL" "Replication log file does not exist"
    fi
}

# Generate test report
generate_test_report() {
    echo
    log_info "=== Test Report ==="
    echo
    
    log_info "Summary:"
    log_info "- Passed: $PASSED"
    log_info "- Failed: $FAILED"
    echo
    
    if [ $FAILED -eq 0 ]; then
        log_success "All tests passed!"
    else
        log_error "Some tests failed. Please check the issues above."
    fi
    
    echo
    log_info "Detailed Results:"
    for result in "${TEST_RESULTS[@]}"; do
        local status=$(echo "$result" | cut -d':' -f1)
        local message=$(echo "$result" | cut -d':' -f2-)
        
        case $status in
            "PASS")
                log_success "✓ $message"
                ;;
            "FAIL")
                log_error "✗ $message"
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
    echo "=== MusicBrainz Replication Test Suite ==="
    echo
    
    # Check if containers are running
    if ! docker compose ps | grep -q "Up"; then
        log_error "Containers are not running. Please start them first:"
        log_info "  docker compose up -d"
        exit 1
    fi
    
    test_database_connection || exit 1
    test_replication_tables
    test_perl_modules
    test_replication_config
    test_replication_script
    test_load_replication_changes
    test_replication_data
    test_replication_process
    test_logs
    
    generate_test_report
    
    if [ $FAILED -gt 0 ]; then
        exit 1
    fi
}

# Run main function if script is executed directly
if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
    main "$@"
fi
