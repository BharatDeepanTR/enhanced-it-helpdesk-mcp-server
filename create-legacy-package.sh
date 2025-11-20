#!/bin/bash
set -e

# Create final Cloud Shell package with legacy Docker support
TIMESTAMP=$(date +"%Y%m%d-%H%M%S")
PACKAGE_NAME="dns-lookup-legacy-${TIMESTAMP}"
PACKAGE_DIR="/tmp/${PACKAGE_NAME}"

echo "📦 Creating Cloud Shell package (Legacy Docker - Cache Issue Workaround)..."

# Create package directory
mkdir -p "$PACKAGE_DIR"

# Copy files
cp chatops_route_dns_intent.py "$PACKAGE_DIR/"
cp chatops_helpers.py "$PACKAGE_DIR/"
cp chatops_config.py "$PACKAGE_DIR/"
cp container_handler.py "$PACKAGE_DIR/"
cp requirements.txt "$PACKAGE_DIR/"
cp .dockerignore "$PACKAGE_DIR/"
cp deploy-legacy.sh "$PACKAGE_DIR/"
cp Dockerfile.legacy "$PACKAGE_DIR/Dockerfile"

# Create simple instructions
cat > "$PACKAGE_DIR/DEPLOY.md" << 'EOF'
# Cloud Shell Deployment - Legacy Docker Mode

## Commands to Run:
```bash
tar -xzf dns-lookup-legacy-*.tar.gz
cd dns-lookup-legacy-*
chmod +x deploy-legacy.sh
./deploy-legacy.sh v1.0.0
```

## What This Does:
- Disables Docker BuildKit completely
- Uses legacy Docker build process
- Bypasses cache corruption issues
- Creates ARM64-compatible container

## Expected Output:
✅ Repository created/verified
✅ Docker login successful  
✅ Build completed (legacy mode)
✅ Push completed

Your image will be ready for ECS/EKS deployment!
EOF

# Create the package
cd /tmp
tar -czf "/mnt/c/Users/6135616/chatops_route_dns/${PACKAGE_NAME}.tar.gz" "$PACKAGE_NAME"

# Cleanup
rm -rf "$PACKAGE_DIR"

echo "✅ Legacy package created: ${PACKAGE_NAME}.tar.gz"
echo "📊 Size: $(du -h "/mnt/c/Users/6135616/chatops_route_dns/${PACKAGE_NAME}.tar.gz" | cut -f1)"
echo ""
echo "🔧 This completely bypasses BuildKit cache issues"
echo "📋 Uses legacy Docker build - should work reliably in Cloud Shell"