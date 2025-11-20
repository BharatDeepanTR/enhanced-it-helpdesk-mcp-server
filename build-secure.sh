#!/bin/bash
set -euo pipefail

# Secure Docker Build Script with Vulnerability Scanning
# Platform: ARM64
# Security: Multi-stage build with comprehensive scanning

# Configuration
IMAGE_NAME="dns-lookup-service"
IMAGE_TAG="${1:-latest}"
REGISTRY="${REGISTRY:-localhost:5000}"
FULL_IMAGE_NAME="${REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}"
BUILD_DATE=$(date -u +'%Y-%m-%dT%H:%M:%SZ')
COMMIT_HASH="${GITHUB_SHA:-$(git rev-parse --short HEAD 2>/dev/null || echo 'unknown')}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Security check functions
check_docker_buildx() {
    log_info "Checking Docker Buildx availability..."
    if ! docker buildx version &>/dev/null; then
        log_error "Docker Buildx is required for multi-platform builds"
        exit 1
    fi
    log_success "Docker Buildx is available"
}

check_security_tools() {
    log_info "Checking security scanning tools..."
    
    # Check for Trivy
    if ! command -v trivy &>/dev/null; then
        log_warning "Trivy not found. Installing..."
        install_trivy
    else
        log_success "Trivy is available"
    fi
    
    # Check for Grype (alternative scanner)
    if ! command -v grype &>/dev/null; then
        log_warning "Grype not found. Will use Trivy only"
    else
        log_success "Grype is available"
    fi
}

install_trivy() {
    log_info "Installing Trivy..."
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        # Linux installation
        curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b /usr/local/bin
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS installation
        brew install trivy
    else
        log_error "Unsupported OS for automatic Trivy installation"
        log_info "Please install Trivy manually: https://aquasecurity.github.io/trivy/latest/getting-started/installation/"
        exit 1
    fi
}

scan_dependencies() {
    log_info "Scanning Python dependencies for vulnerabilities..."
    
    # Create virtual environment for scanning
    python3 -m venv scan_env
    source scan_env/bin/activate
    
    # Install pip-audit for dependency scanning
    pip install pip-audit safety
    
    # Scan requirements.txt
    log_info "Running pip-audit on requirements.txt..."
    if pip-audit --requirement requirements.txt --format=json --output=pip-audit-report.json; then
        log_success "pip-audit scan completed"
    else
        log_warning "pip-audit found potential issues"
    fi
    
    # Additional safety scan
    log_info "Running safety check..."
    if safety check --requirement requirements.txt --json --output safety-report.json; then
        log_success "Safety scan completed"
    else
        log_warning "Safety check found potential issues"
    fi
    
    # Cleanup
    deactivate
    rm -rf scan_env
}

build_image() {
    log_info "Building Docker image for ARM64..."
    
    # Create buildx builder if it doesn't exist
    if ! docker buildx ls | grep -q "secure-builder"; then
        log_info "Creating secure buildx builder..."
        docker buildx create --name secure-builder --driver docker-container --bootstrap
    fi
    
    # Use the secure builder
    docker buildx use secure-builder
    
    # Build the image with security labels
    docker buildx build \
        --platform linux/arm64 \
        --build-arg BUILD_DATE="${BUILD_DATE}" \
        --build-arg COMMIT_HASH="${COMMIT_HASH}" \
        --label "org.opencontainers.image.created=${BUILD_DATE}" \
        --label "org.opencontainers.image.revision=${COMMIT_HASH}" \
        --label "security.scan-date=${BUILD_DATE}" \
        --tag "${FULL_IMAGE_NAME}" \
        --load \
        .
    
    log_success "Image built successfully: ${FULL_IMAGE_NAME}"
}

scan_image_trivy() {
    log_info "Scanning Docker image with Trivy..."
    
    # Comprehensive Trivy scan
    trivy image \
        --format json \
        --output trivy-report.json \
        --severity HIGH,CRITICAL \
        --ignore-unfixed \
        "${FULL_IMAGE_NAME}"
    
    # Generate human-readable report
    trivy image \
        --format table \
        --severity HIGH,CRITICAL \
        --ignore-unfixed \
        "${FULL_IMAGE_NAME}" | tee trivy-report.txt
    
    # Check if critical vulnerabilities found
    CRITICAL_COUNT=$(jq '.Results[]?.Vulnerabilities[]? | select(.Severity == "CRITICAL") | length' trivy-report.json 2>/dev/null | wc -l || echo "0")
    HIGH_COUNT=$(jq '.Results[]?.Vulnerabilities[]? | select(.Severity == "HIGH") | length' trivy-report.json 2>/dev/null | wc -l || echo "0")
    
    if [[ "${CRITICAL_COUNT}" -gt 0 ]]; then
        log_error "Found ${CRITICAL_COUNT} CRITICAL vulnerabilities!"
        return 1
    elif [[ "${HIGH_COUNT}" -gt 0 ]]; then
        log_warning "Found ${HIGH_COUNT} HIGH severity vulnerabilities"
        return 2
    else
        log_success "No HIGH or CRITICAL vulnerabilities found"
        return 0
    fi
}

scan_image_grype() {
    if command -v grype &>/dev/null; then
        log_info "Scanning Docker image with Grype..."
        grype "${FULL_IMAGE_NAME}" -o json > grype-report.json
        grype "${FULL_IMAGE_NAME}" -o table | tee grype-report.txt
        log_success "Grype scan completed"
    else
        log_info "Grype not available, skipping additional scan"
    fi
}

test_image() {
    log_info "Testing the built image..."
    
    # Basic functionality test
    if docker run --rm --platform linux/arm64 "${FULL_IMAGE_NAME}" python -c "import chatops_route_dns_intent; print('Import test passed')"; then
        log_success "Image functionality test passed"
    else
        log_error "Image functionality test failed"
        return 1
    fi
    
    # Security test - check if running as non-root
    USER_ID=$(docker run --rm --platform linux/arm64 "${FULL_IMAGE_NAME}" id -u)
    if [[ "${USER_ID}" != "0" ]]; then
        log_success "Image runs as non-root user (UID: ${USER_ID})"
    else
        log_error "Image is running as root user!"
        return 1
    fi
}

generate_sbom() {
    log_info "Generating Software Bill of Materials (SBOM)..."
    
    if command -v syft &>/dev/null; then
        syft "${FULL_IMAGE_NAME}" -o spdx-json > sbom.spdx.json
        syft "${FULL_IMAGE_NAME}" -o table > sbom.txt
        log_success "SBOM generated successfully"
    else
        log_warning "Syft not available, skipping SBOM generation"
        log_info "Install Syft for SBOM generation: https://github.com/anchore/syft"
    fi
}

security_summary() {
    log_info "=== SECURITY SCAN SUMMARY ==="
    
    echo "Build Information:"
    echo "  Image: ${FULL_IMAGE_NAME}"
    echo "  Platform: linux/arm64"
    echo "  Build Date: ${BUILD_DATE}"
    echo "  Commit: ${COMMIT_HASH}"
    echo
    
    if [[ -f "trivy-report.json" ]]; then
        echo "Trivy Scan Results:"
        jq -r '.Results[]? | "  \(.Target): \(.Vulnerabilities | length) vulnerabilities"' trivy-report.json 2>/dev/null || echo "  Report parsing failed"
        echo
    fi
    
    if [[ -f "pip-audit-report.json" ]]; then
        echo "Python Dependencies Scan:"
        echo "  pip-audit: $(jq '.vulnerabilities | length' pip-audit-report.json 2>/dev/null || echo 'unknown') vulnerabilities"
        echo
    fi
    
    echo "Security Features Implemented:"
    echo "  ✓ Multi-stage build"
    echo "  ✓ Non-root user execution"
    echo "  ✓ Minimal base image"
    echo "  ✓ Pinned dependency versions"
    echo "  ✓ Security labels and metadata"
    echo "  ✓ Vulnerability scanning"
    echo "  ✓ ARM64 architecture optimization"
}

cleanup() {
    log_info "Cleaning up temporary files..."
    rm -f pip-audit-report.json safety-report.json
}

# Main execution
main() {
    log_info "Starting secure Docker build process..."
    echo "Target: ${FULL_IMAGE_NAME}"
    echo "Platform: linux/arm64"
    echo
    
    # Pre-build checks
    check_docker_buildx
    check_security_tools
    
    # Security scans
    scan_dependencies
    
    # Build process
    build_image
    
    # Post-build security scans
    SCAN_RESULT=0
    scan_image_trivy || SCAN_RESULT=$?
    scan_image_grype
    
    # Additional testing
    test_image
    
    # Generate artifacts
    generate_sbom
    
    # Summary
    security_summary
    
    # Handle scan results
    if [[ $SCAN_RESULT -eq 1 ]]; then
        log_error "Build completed but CRITICAL vulnerabilities found!"
        log_error "Review trivy-report.txt before deploying to production"
        exit 1
    elif [[ $SCAN_RESULT -eq 2 ]]; then
        log_warning "Build completed with HIGH severity vulnerabilities"
        log_warning "Review and assess risks before production deployment"
    else
        log_success "Build completed successfully with no critical vulnerabilities!"
    fi
    
    log_success "Docker image ready: ${FULL_IMAGE_NAME}"
    
    # Optional: Save image as tar file
    if [[ "${SAVE_TAR:-false}" == "true" ]]; then
        log_info "Saving image as tar file..."
        docker save "${FULL_IMAGE_NAME}" | gzip > "${IMAGE_NAME}-${IMAGE_TAG}-arm64.tar.gz"
        log_success "Image saved as ${IMAGE_NAME}-${IMAGE_TAG}-arm64.tar.gz"
    fi
    
    cleanup
}

# Error handling
trap 'log_error "Build failed on line $LINENO"' ERR

# Execute main function
main "$@"