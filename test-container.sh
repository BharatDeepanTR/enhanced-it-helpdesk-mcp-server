#!/bin/bash
set -euo pipefail

# Test script for DNS Lookup Service container
# Validates that the containerized lambda function works correctly

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Configuration
CONTAINER_NAME="dns-lookup-test-$(date +%s)"
IMAGE_NAME="localhost:5000/dns-lookup-service:latest"
TEST_PORT="8080"
BASE_URL="http://localhost:${TEST_PORT}"

# Test data
TEST_DNS_NAMES=("example.com" "google.com" "github.com")

# Cleanup function
cleanup() {
    log_info "Cleaning up test container..."
    docker stop "${CONTAINER_NAME}" 2>/dev/null || true
    docker rm "${CONTAINER_NAME}" 2>/dev/null || true
}

# Set trap for cleanup
trap cleanup EXIT

# Function to wait for service to be ready
wait_for_service() {
    log_info "Waiting for service to be ready..."
    local max_attempts=30
    local attempt=1
    
    while [[ $attempt -le $max_attempts ]]; do
        if curl -f "${BASE_URL}/health" &>/dev/null; then
            log_success "Service is ready!"
            return 0
        fi
        
        echo -n "."
        sleep 1
        ((attempt++))
    done
    
    log_error "Service failed to become ready after ${max_attempts} seconds"
    return 1
}

# Function to test health endpoint
test_health_endpoint() {
    log_info "Testing health endpoint..."
    
    local response
    response=$(curl -s "${BASE_URL}/health")
    local status=$?
    
    if [[ $status -eq 0 ]]; then
        echo "Response: $response"
        
        # Check if response contains expected fields
        if echo "$response" | jq -e '.status' &>/dev/null; then
            local health_status
            health_status=$(echo "$response" | jq -r '.status')
            
            if [[ "$health_status" == "healthy" ]]; then
                log_success "Health check passed"
                return 0
            else
                log_error "Health check failed: status is $health_status"
                return 1
            fi
        else
            log_error "Health check response missing status field"
            return 1
        fi
    else
        log_error "Health check request failed"
        return 1
    fi
}

# Function to test service info endpoint
test_service_info() {
    log_info "Testing service info endpoint..."
    
    local response
    response=$(curl -s "${BASE_URL}/")
    local status=$?
    
    if [[ $status -eq 0 ]]; then
        echo "Response: $response"
        
        # Check if response contains service information
        if echo "$response" | jq -e '.service' &>/dev/null; then
            log_success "Service info endpoint working"
            return 0
        else
            log_error "Service info response missing service field"
            return 1
        fi
    else
        log_error "Service info request failed"
        return 1
    fi
}

# Function to test DNS lookup with POST
test_dns_lookup_post() {
    local dns_name="$1"
    log_info "Testing DNS lookup (POST) for: $dns_name"
    
    local response
    local status_code
    
    response=$(curl -s -w "HTTPSTATUS:%{http_code}" \
        -X POST "${BASE_URL}/lookup" \
        -H "Content-Type: application/json" \
        -d "{\"dns_name\": \"$dns_name\"}")
    
    status_code=$(echo "$response" | grep -o "HTTPSTATUS:[0-9]*" | cut -d: -f2)
    response=$(echo "$response" | sed 's/HTTPSTATUS:[0-9]*$//')
    
    echo "Status Code: $status_code"
    echo "Response: $response"
    
    # Check status code
    if [[ "$status_code" =~ ^[2-4][0-9][0-9]$ ]]; then
        # Check if response is valid JSON
        if echo "$response" | jq . &>/dev/null; then
            log_success "DNS lookup (POST) test passed for $dns_name"
            return 0
        else
            log_error "Invalid JSON response for $dns_name"
            return 1
        fi
    else
        log_error "Unexpected status code: $status_code for $dns_name"
        return 1
    fi
}

# Function to test DNS lookup with GET
test_dns_lookup_get() {
    local dns_name="$1"
    log_info "Testing DNS lookup (GET) for: $dns_name"
    
    local response
    local status_code
    
    response=$(curl -s -w "HTTPSTATUS:%{http_code}" \
        "${BASE_URL}/lookup?dns_name=${dns_name}")
    
    status_code=$(echo "$response" | grep -o "HTTPSTATUS:[0-9]*" | cut -d: -f2)
    response=$(echo "$response" | sed 's/HTTPSTATUS:[0-9]*$//')
    
    echo "Status Code: $status_code"
    echo "Response: $response"
    
    # Check status code
    if [[ "$status_code" =~ ^[2-4][0-9][0-9]$ ]]; then
        # Check if response is valid JSON
        if echo "$response" | jq . &>/dev/null; then
            log_success "DNS lookup (GET) test passed for $dns_name"
            return 0
        else
            log_error "Invalid JSON response for $dns_name"
            return 1
        fi
    else
        log_error "Unexpected status code: $status_code for $dns_name"
        return 1
    fi
}

# Function to test error handling
test_error_handling() {
    log_info "Testing error handling..."
    
    # Test missing DNS name
    local response
    local status_code
    
    response=$(curl -s -w "HTTPSTATUS:%{http_code}" \
        -X POST "${BASE_URL}/lookup" \
        -H "Content-Type: application/json" \
        -d '{}')
    
    status_code=$(echo "$response" | grep -o "HTTPSTATUS:[0-9]*" | cut -d: -f2)
    response=$(echo "$response" | sed 's/HTTPSTATUS:[0-9]*$//')
    
    echo "Status Code: $status_code"
    echo "Response: $response"
    
    # Should return 400 for missing DNS name
    if [[ "$status_code" == "400" ]]; then
        log_success "Error handling test passed"
        return 0
    else
        log_error "Expected 400 status code, got $status_code"
        return 1
    fi
}

# Function to test CORS
test_cors() {
    log_info "Testing CORS headers..."
    
    local headers
    headers=$(curl -s -I -X OPTIONS "${BASE_URL}/lookup")
    
    if echo "$headers" | grep -i "Access-Control-Allow-Origin" &>/dev/null; then
        log_success "CORS headers present"
        return 0
    else
        log_warning "CORS headers missing (may be expected depending on configuration)"
        return 0
    fi
}

# Function to run security checks
test_security() {
    log_info "Running security checks..."
    
    # Check if container is running as non-root
    local user_id
    user_id=$(docker exec "$CONTAINER_NAME" id -u)
    
    if [[ "$user_id" != "0" ]]; then
        log_success "Container running as non-root user (UID: $user_id)"
    else
        log_error "Container running as root user!"
        return 1
    fi
    
    # Check read-only filesystem (attempt to write to root)
    if docker exec "$CONTAINER_NAME" touch /test_file 2>/dev/null; then
        log_error "Root filesystem is writable!"
        return 1
    else
        log_success "Root filesystem is read-only"
    fi
    
    return 0
}

# Main test function
run_tests() {
    log_info "Starting DNS Lookup Service container tests..."
    
    # Check if image exists
    if ! docker image inspect "$IMAGE_NAME" &>/dev/null; then
        log_error "Image $IMAGE_NAME not found. Please build it first with: ./build-secure.sh"
        exit 1
    fi
    
    # Start the container
    log_info "Starting container: $CONTAINER_NAME"
    docker run -d \
        --name "$CONTAINER_NAME" \
        --platform linux/arm64 \
        -p "${TEST_PORT}:8080" \
        -e ENV=test \
        -e APP_CONFIG_PATH=/config \
        "$IMAGE_NAME"
    
    # Wait for service to be ready
    if ! wait_for_service; then
        log_error "Service failed to start"
        docker logs "$CONTAINER_NAME"
        exit 1
    fi
    
    # Run individual tests
    local tests_passed=0
    local tests_total=0
    
    # Basic endpoint tests
    ((tests_total++))
    test_health_endpoint && ((tests_passed++))
    
    ((tests_total++))
    test_service_info && ((tests_passed++))
    
    # DNS lookup tests
    for dns_name in "${TEST_DNS_NAMES[@]}"; do
        ((tests_total++))
        test_dns_lookup_post "$dns_name" && ((tests_passed++))
        
        ((tests_total++))
        test_dns_lookup_get "$dns_name" && ((tests_passed++))
    done
    
    # Error handling test
    ((tests_total++))
    test_error_handling && ((tests_passed++))
    
    # CORS test
    ((tests_total++))
    test_cors && ((tests_passed++))
    
    # Security tests
    ((tests_total++))
    test_security && ((tests_passed++))
    
    # Summary
    log_info "Test Summary:"
    log_info "Tests passed: $tests_passed/$tests_total"
    
    if [[ $tests_passed -eq $tests_total ]]; then
        log_success "All tests passed! Container is working correctly."
        return 0
    else
        log_error "Some tests failed. Please review the output above."
        return 1
    fi
}

# Show container logs on failure
show_logs_on_failure() {
    if [[ $? -ne 0 ]]; then
        log_info "Showing container logs for debugging:"
        docker logs "$CONTAINER_NAME" 2>&1 | tail -50
    fi
}

# Set trap for showing logs on failure
trap 'show_logs_on_failure' ERR

# Check dependencies
check_dependencies() {
    local missing_deps=()
    
    command -v docker &>/dev/null || missing_deps+=("docker")
    command -v curl &>/dev/null || missing_deps+=("curl")
    command -v jq &>/dev/null || missing_deps+=("jq")
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log_error "Missing dependencies: ${missing_deps[*]}"
        log_info "Please install the missing dependencies and try again."
        exit 1
    fi
}

# Main execution
main() {
    echo "======================================"
    echo "DNS Lookup Service Container Tests"
    echo "======================================"
    
    check_dependencies
    run_tests
    
    log_success "Container testing completed successfully!"
}

# Execute main function if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi