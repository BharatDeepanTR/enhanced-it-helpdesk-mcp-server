#!/bin/bash
set -e

# Create corrected Agent Core Runtime package
TIMESTAMP=$(date +"%Y%m%d-%H%M%S")
PACKAGE_NAME="dns-lookup-agent-fixed-${TIMESTAMP}"
PACKAGE_DIR="/tmp/${PACKAGE_NAME}"

echo "📦 Creating corrected Agent Runtime package..."

# Create package directory
mkdir -p "$PACKAGE_DIR"

# Copy files
cp chatops_route_dns_intent.py "$PACKAGE_DIR/"
cp chatops_helpers.py "$PACKAGE_DIR/"
cp chatops_config.py "$PACKAGE_DIR/"
cp container_handler.py "$PACKAGE_DIR/"
cp requirements-minimal.txt "$PACKAGE_DIR/requirements.txt"
cp .dockerignore "$PACKAGE_DIR/"
cp deploy-multiarch.sh "$PACKAGE_DIR/"
cp Dockerfile.multiarch "$PACKAGE_DIR/Dockerfile"

# Create simple deployment instructions
cat > "$PACKAGE_DIR/README.md" << 'EOF'
# DNS Lookup Service - Agent Runtime (Fixed)

## Quick Deploy:
```bash
tar -xzf dns-lookup-agent-fixed-*.tar.gz
cd dns-lookup-agent-fixed-*
chmod +x deploy-multiarch.sh
./deploy-multiarch.sh v1.0.0
```

## What's Fixed:
✅ Dockerfile reference corrected
✅ Multi-architecture support
✅ Agent Core Runtime compatible

## Output:
Multi-arch container that works on any platform (ARM64 or x86_64)
EOF

# Create the package
cd /tmp
tar -czf "/mnt/c/Users/6135616/chatops_route_dns/${PACKAGE_NAME}.tar.gz" "$PACKAGE_NAME"

# Cleanup
rm -rf "$PACKAGE_DIR"

echo "✅ Fixed package created: ${PACKAGE_NAME}.tar.gz"
echo "📊 Size: $(du -h "/mnt/c/Users/6135616/chatops_route_dns/${PACKAGE_NAME}.tar.gz" | cut -f1)"
echo ""
echo "🔧 Fixed: Dockerfile reference issue resolved"