#!/bin/bash
set -e

# Create final working Cloud Shell package with fixed dependencies
TIMESTAMP=$(date +"%Y%m%d-%H%M%S")
PACKAGE_NAME="dns-lookup-working-${TIMESTAMP}"
PACKAGE_DIR="/tmp/${PACKAGE_NAME}"

echo "📦 Creating Cloud Shell package (Fixed Dependencies)..."

# Create package directory
mkdir -p "$PACKAGE_DIR"

# Copy files
cp chatops_route_dns_intent.py "$PACKAGE_DIR/"
cp chatops_helpers.py "$PACKAGE_DIR/"
cp chatops_config.py "$PACKAGE_DIR/"
cp container_handler.py "$PACKAGE_DIR/"
cp requirements-fixed.txt "$PACKAGE_DIR/requirements.txt"
cp .dockerignore "$PACKAGE_DIR/"
cp deploy-legacy.sh "$PACKAGE_DIR/"
cp Dockerfile.legacy "$PACKAGE_DIR/Dockerfile"

# Create deployment instructions
cat > "$PACKAGE_DIR/DEPLOY.md" << 'EOF'
# Cloud Shell Deployment - Working Version

## Fixed Issues:
✅ Docker BuildKit cache corruption - using legacy build
✅ Package dependency conflicts - compatible versions
✅ ARM64 architecture support

## Deploy Commands:
```bash
tar -xzf dns-lookup-working-*.tar.gz
cd dns-lookup-working-*
chmod +x deploy-legacy.sh
./deploy-legacy.sh v1.0.0
```

## What's Different:
- s3transfer version fixed (0.10.2 instead of 0.8.2)
- boto3/botocore compatibility verified
- Removed awslambdaric (not needed for containers)
- Legacy Docker build (no BuildKit)

Should build and deploy successfully!
EOF

# Create the package
cd /tmp
tar -czf "/mnt/c/Users/6135616/chatops_route_dns/${PACKAGE_NAME}.tar.gz" "$PACKAGE_NAME"

# Cleanup
rm -rf "$PACKAGE_DIR"

echo "✅ Working package created: ${PACKAGE_NAME}.tar.gz"
echo "📊 Size: $(du -h "/mnt/c/Users/6135616/chatops_route_dns/${PACKAGE_NAME}.tar.gz" | cut -f1)"
echo ""
echo "🔧 Fixed Issues:"
echo "   ✅ Dependency conflicts resolved"
echo "   ✅ s3transfer: 0.8.2 → 0.10.2 (boto3 compatible)"
echo "   ✅ Removed conflicting packages"
echo "   ✅ Legacy Docker build for cache stability"