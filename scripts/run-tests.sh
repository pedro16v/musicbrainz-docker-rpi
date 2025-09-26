#!/bin/bash

# MusicBrainz ARM64 Comprehensive Test Suite
# This script runs all tests and validations

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

# Test suite results
SUITE_RESULTS=()
TOTAL_PASSED=0
TOTAL_FAILED=0
TOTAL_WARNINGS=0

# Add suite result
add_suite_result() {
    local status="$1"
    local message="$2"
    SUITE_RESULTS+=("$status:$message")
    
    case $status in
        "PASS")
            ((TOTAL_PASSED++))
            log_success "$message"
            ;;
        "FAIL")
            ((TOTAL_FAILED++))
            log_error "$message"
            ;;
        "WARN")
            ((TOTAL_WARNINGS++))
            log_warning "$message"
            ;;
    esac
}

# Run validation script
run_validation() {
    log_info "Running deployment validation..."
    
    if [ -f "scripts/validate-deployment.sh" ]; then
        if ./scripts/validate-deployment.sh; then
            add_suite_result "PASS" "Deployment validation passed"
        else
            add_suite_result "FAIL" "Deployment validation failed"
        fi
    else
        add_suite_result "FAIL" "Validation script not found"
    fi
}

# Run replication tests
run_replication_tests() {
    log_info "Running replication tests..."
    
    if [ -f "scripts/test-replication.sh" ]; then
        if ./scripts/test-replication.sh; then
            add_suite_result "PASS" "Replication tests passed"
        else
            add_suite_result "FAIL" "Replication tests failed"
        fi
    else
        add_suite_result "FAIL" "Replication test script not found"
    fi
}

# Test environment-specific deployments
test_environment_deployments() {
    log_info "Testing environment-specific deployments..."
    
    local environments=("production" "test" "dev")
    
    for env in "${environments[@]}"; do
        local compose_file="compose/musicbrainz-$env.yml"
        
        if [ -f "$compose_file" ]; then
            add_suite_result "PASS" "Compose file for $env environment exists"
            
            # Test compose file syntax
            if docker compose -f "$compose_file" config >/dev/null 2>&1; then
                add_suite_result "PASS" "Compose file for $env environment is valid"
            else
                add_suite_result "FAIL" "Compose file for $env environment has syntax errors"
            fi
        else
            add_suite_result "FAIL" "Compose file for $env environment not found"
        fi
    done
}

# Test configuration templates
test_configuration_templates() {
    log_info "Testing configuration templates..."
    
    if [ -f "build/musicbrainz-minimal/scripts/DBDefs.pm.template" ]; then
        add_suite_result "PASS" "DBDefs.pm template exists"
        
        # Test template syntax
        if grep -q "REPLICATION_TYPE" build/musicbrainz-minimal/scripts/DBDefs.pm.template; then
            add_suite_result "PASS" "DBDefs.pm template contains REPLICATION_TYPE"
        else
            add_suite_result "FAIL" "DBDefs.pm template missing REPLICATION_TYPE"
        fi
        
        if grep -q "REPLICATION_ACCESS_TOKEN" build/musicbrainz-minimal/scripts/DBDefs.pm.template; then
            add_suite_result "PASS" "DBDefs.pm template contains REPLICATION_ACCESS_TOKEN"
        else
            add_suite_result "FAIL" "DBDefs.pm template missing REPLICATION_ACCESS_TOKEN"
        fi
    else
        add_suite_result "FAIL" "DBDefs.pm template not found"
    fi
    
    if [ -f "env.template" ]; then
        add_suite_result "PASS" "Environment template exists"
    else
        add_suite_result "FAIL" "Environment template not found"
    fi
}

# Test scripts
test_scripts() {
    log_info "Testing scripts..."
    
    local scripts=("setup-replication.sh" "configure-replication.sh" "validate-deployment.sh" "test-replication.sh" "deploy-arm64.sh")
    
    for script in "${scripts[@]}"; do
        if [ -f "scripts/$script" ]; then
            add_suite_result "PASS" "Script $script exists"
            
            if [ -x "scripts/$script" ]; then
                add_suite_result "PASS" "Script $script is executable"
            else
                add_suite_result "FAIL" "Script $script is not executable"
            fi
        else
            add_suite_result "FAIL" "Script $script not found"
        fi
    done
}

# Test documentation
test_documentation() {
    log_info "Testing documentation..."
    
    local docs=("README.md" "TROUBLESHOOTING.md" "REPLICATION-SETUP-GUIDE.md" "QUICK-REFERENCE.md" "DIGITAL-OCEAN-DEPLOYMENT.md")
    
    for doc in "${docs[@]}"; do
        if [ -f "$doc" ]; then
            add_suite_result "PASS" "Documentation $doc exists"
        else
            add_suite_result "FAIL" "Documentation $doc not found"
        fi
    done
}

# Test Docker images
test_docker_images() {
    log_info "Testing Docker images..."
    
    # Test if images can be built
    if docker compose build --no-cache >/dev/null 2>&1; then
        add_suite_result "PASS" "Docker images can be built"
    else
        add_suite_result "FAIL" "Docker images failed to build"
    fi
}

# Test container health
test_container_health() {
    log_info "Testing container health..."
    
    if ! docker compose ps | grep -q "Up"; then
        add_suite_result "FAIL" "No containers are running"
        return 1
    fi
    
    # Test container health
    local containers=("db" "redis" "musicbrainz-minimal")
    
    for container in "${containers[@]}"; do
        if docker compose ps | grep -q "$container.*Up"; then
            add_suite_result "PASS" "Container $container is running"
        else
            add_suite_result "FAIL" "Container $container is not running"
        fi
    done
}

# Generate comprehensive report
generate_comprehensive_report() {
    echo
    log_info "=== Comprehensive Test Suite Report ==="
    echo
    
    log_info "Overall Summary:"
    log_info "- Passed: $TOTAL_PASSED"
    log_info "- Failed: $TOTAL_FAILED"
    log_info "- Warnings: $TOTAL_WARNINGS"
    echo
    
    if [ $TOTAL_FAILED -eq 0 ]; then
        log_success "All critical tests passed!"
        if [ $TOTAL_WARNINGS -gt 0 ]; then
            log_warning "Please review the warnings above"
        fi
    else
        log_error "Some critical tests failed. Please fix the issues above."
    fi
    
    echo
    log_info "Detailed Results:"
    for result in "${SUITE_RESULTS[@]}"; do
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
    if [ $TOTAL_FAILED -gt 0 ]; then
        log_info "For help resolving issues, see TROUBLESHOOTING.md"
    fi
    
    echo
    log_info "Test Suite completed at $(date)"
}

# Main function
main() {
    echo "=== MusicBrainz ARM64 Comprehensive Test Suite ==="
    echo "Started at $(date)"
    echo
    
    # Check if we're in the right directory
    if [ ! -f "docker-compose.yml" ]; then
        log_error "Not in musicbrainz-docker project directory"
        exit 1
    fi
    
    # Run all tests
    test_scripts
    test_configuration_templates
    test_environment_deployments
    test_documentation
    test_docker_images
    test_container_health
    run_validation
    run_replication_tests
    
    generate_comprehensive_report
    
    if [ $TOTAL_FAILED -gt 0 ]; then
        exit 1
    fi
}

# Run main function if script is executed directly
if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
    main "$@"
fi
