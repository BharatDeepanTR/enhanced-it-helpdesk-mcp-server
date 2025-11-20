#!/bin/bash
set -e

# Create package with fixed Dockerfile for Cloud Shell deployment
TIMESTAMP=$(date +"%Y%m%d-%H%M%S")
PACKAGE_NAME="dns-lookup-arm64-fixed-${TIMESTAMP}"
PACKAGE_DIR="/tmp/${PACKAGE_NAME}"

echo "📦 Creating Cloud Shell deployment package with fixed Dockerfile..."

# Create package directory
mkdir -p "$PACKAGE_DIR"

# Copy essential files only
echo "📋 Copying essential files..."
cp chatops_route_dns_intent.py "$PACKAGE_DIR/"
cp chatops_helpers.py "$PACKAGE_DIR/"
cp chatops_config.py "$PACKAGE_DIR/"
cp container_handler.py "$PACKAGE_DIR/"
cp Dockerfile "$PACKAGE_DIR/"
cp requirements.txt "$PACKAGE_DIR/"
cp .dockerignore "$PACKAGE_DIR/"
cp deploy-cloudshell.sh "$PACKAGE_DIR/deploy.sh"

# Create function description
cat > "$PACKAGE_DIR/function.txt" << 'EOF'
DNS Lookup Service - ARM64 Container
===================================
Core functionality: Route53 DNS record lookup with GenAI integration
Lex functionality: Completely removed
Architecture: ARM64 optimized for AWS Graviton
Container: Secure multi-stage build with non-root execution
Deployment: AWS ECR ready with automated scripts
EOF

# Create simple README
cat > "$PACKAGE_DIR/README.md" << 'EOF'
# DNS Lookup Service - Cloud Shell Deployment

## Quick Deploy to ECR

1. Extract: `tar -xzf dns-lookup-arm64-fixed-*.tar.gz && cd dns-lookup-arm64-fixed-*`
2. Deploy: `chmod +x deploy.sh && ./deploy.sh v1.0.0`

## What's Included
- Python service files (Lex functionality removed)
- ARM64 optimized Dockerfile (fixed image references)
- ECR deployment script
- Security-hardened container configuration

## Requirements
- Cloud Shell environment
- AWS credentials (auto-configured in Cloud Shell)
- Docker with BuildKit support (pre-installed)
EOF

# Create the package
cd /tmp
echo "🗜️  Creating tarball..."
tar -czf "/mnt/c/Users/6135616/chatops_route_dns/${PACKAGE_NAME}.tar.gz" "$PACKAGE_NAME"

# Cleanup
rm -rf "$PACKAGE_DIR"

echo "✅ Fixed package created: ${PACKAGE_NAME}.tar.gz"
echo "📊 Package size: $(du -h "/mnt/c/Users/6135616/chatops_route_dns/${PACKAGE_NAME}.tar.gz" | cut -f1)"
echo ""
echo "🚀 Ready for Cloud Shell deployment!"
echo "   Upload this file and run the 3-step process."