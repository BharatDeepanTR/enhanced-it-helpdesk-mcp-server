#!/bin/bash
set -e

# Create ARM64-compatible Agent Core Runtime package
TIMESTAMP=$(date +"%Y%m%d-%H%M%S")
PACKAGE_NAME="dns-lookup-agent-arm64-${TIMESTAMP}"
PACKAGE_DIR="/tmp/${PACKAGE_NAME}"

echo "📦 Creating ARM64-compatible Agent Runtime package..."

# Create package directory
mkdir -p "$PACKAGE_DIR"

# Copy all essential files
cp chatops_route_dns_intent.py "$PACKAGE_DIR/"
cp chatops_helpers.py "$PACKAGE_DIR/"
cp chatops_config.py "$PACKAGE_DIR/"
cp container_handler.py "$PACKAGE_DIR/"
cp lambda_handler.py "$PACKAGE_DIR/"
cp requirements-minimal.txt "$PACKAGE_DIR/requirements.txt"
cp .dockerignore "$PACKAGE_DIR/"
cp update-agent-runtime-arm64.sh "$PACKAGE_DIR/update-agent-runtime.sh"
cp Dockerfile.agent-runtime "$PACKAGE_DIR/"

# Create deployment instructions
cat > "$PACKAGE_DIR/README.md" << 'EOF'
# DNS Lookup Service - Agent Core Runtime ARM64 Compatible

## Deploy Commands:
```bash
tar -xzf dns-lookup-agent-arm64-*.tar.gz
cd dns-lookup-agent-arm64-*
chmod +x update-agent-runtime.sh
./update-agent-runtime.sh
```

## ARM64 Architecture:
✅ Built specifically for ARM64 Agent Core Runtime
✅ Lambda handler for proper invocation
✅ Multi-format input support
✅ Compatible with AWS Graviton

## Test Input After Deploy:
```json
{"domain": "google.com"}
```

## Expected Output:
```json
{
  "statusCode": 200,
  "body": {
    "domain": "google.com",
    "records": [{"type": "A", "value": "142.250.180.14"}],
    "status": "success"
  }
}
```

## Architecture Notes:
- This build targets linux/arm64 platform
- Compatible with AWS Graviton processors
- Optimized for Agent Core Runtime environments
EOF

# Create the package
cd /tmp
tar -czf "/mnt/c/Users/6135616/chatops_route_dns/${PACKAGE_NAME}.tar.gz" "$PACKAGE_NAME"

# Cleanup
rm -rf "$PACKAGE_DIR"

echo "✅ ARM64 package created: ${PACKAGE_NAME}.tar.gz"
echo "📊 Size: $(du -h "/mnt/c/Users/6135616/chatops_route_dns/${PACKAGE_NAME}.tar.gz" | cut -f1)"
echo ""
echo "🏗️  ARM64 Features:"
echo "   ✅ linux/arm64 platform build"
echo "   ✅ Lambda handler entry point"
echo "   ✅ Agent Core Runtime compatible"
echo "   ✅ AWS Graviton optimized"
echo ""
echo "🚀 Upload this package to Cloud Shell and run:"
echo "   tar -xzf ${PACKAGE_NAME}.tar.gz"
echo "   cd ${PACKAGE_NAME}"
echo "   chmod +x update-agent-runtime.sh"
echo "   ./update-agent-runtime.sh"