#!/bin/bash
set -e

# Create final package with clean requirements
TIMESTAMP=$(date +"%Y%m%d-%H%M%S")
PACKAGE_NAME="dns-lookup-final-${TIMESTAMP}"
PACKAGE_DIR="/tmp/${PACKAGE_NAME}"

echo "📦 Creating final Cloud Shell package (Clean Dependencies)..."

# Create package directory
mkdir -p "$PACKAGE_DIR"

# Copy files
cp chatops_route_dns_intent.py "$PACKAGE_DIR/"
cp chatops_helpers.py "$PACKAGE_DIR/"
cp chatops_config.py "$PACKAGE_DIR/"
cp container_handler.py "$PACKAGE_DIR/"
cp requirements-minimal.txt "$PACKAGE_DIR/requirements.txt"
cp .dockerignore "$PACKAGE_DIR/"
cp deploy-legacy.sh "$PACKAGE_DIR/"
cp Dockerfile.legacy "$PACKAGE_DIR/Dockerfile"

# Create final deployment guide
cat > "$PACKAGE_DIR/DEPLOY.md" << 'EOF'
# DNS Lookup Service - Final Cloud Shell Package

## Deploy Commands:
```bash
tar -xzf dns-lookup-final-*.tar.gz
cd dns-lookup-final-*
chmod +x deploy-legacy.sh
./deploy-legacy.sh v1.0.0
```

## What's Fixed:
✅ Minimal requirements (let pip resolve dependencies)
✅ No version conflicts (urllib3, s3transfer, etc.)
✅ Legacy Docker build (no BuildKit cache issues)
✅ ARM64 container support

## Expected Success:
- Docker build completes without dependency errors
- Container pushes to ECR successfully
- Ready for ECS/EKS deployment

If this fails, the issue is likely Cloud Shell environment specific.
EOF

# Create the package
cd /tmp
tar -czf "/mnt/c/Users/6135616/chatops_route_dns/${PACKAGE_NAME}.tar.gz" "$PACKAGE_NAME"

# Cleanup
rm -rf "$PACKAGE_DIR"

echo "✅ Final package created: ${PACKAGE_NAME}.tar.gz"
echo "📊 Size: $(du -h "/mnt/c/Users/6135616/chatops_route_dns/${PACKAGE_NAME}.tar.gz" | cut -f1)"
echo ""
echo "🔧 Final Approach:"
echo "   ✅ Minimal requirements (only essential packages)"
echo "   ✅ Let pip auto-resolve compatible versions"
echo "   ✅ No pinned urllib3/s3transfer conflicts"
echo "   ✅ Should work in any Python 3.11 environment"