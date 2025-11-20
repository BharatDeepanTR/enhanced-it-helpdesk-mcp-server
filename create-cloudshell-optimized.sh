#!/bin/bash
set -e

# Create simplified multi-arch package that avoids QEMU issues
TIMESTAMP=$(date +"%Y%m%d-%H%M%S")
PACKAGE_NAME="dns-lookup-simple-multiarch-${TIMESTAMP}"
PACKAGE_DIR="/tmp/${PACKAGE_NAME}"

echo "📦 Creating Simplified Multi-Arch Agent Runtime package..."

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
cp build-simple-multiarch.sh "$PACKAGE_DIR/deploy.sh"
cp Dockerfile.simple-multiarch "$PACKAGE_DIR/Dockerfile"

# Create deployment guide
cat > "$PACKAGE_DIR/README.md" << 'EOF'
# DNS Lookup Service - Simplified Multi-Architecture

## Cloud Shell Compatible Build
✅ **Avoids QEMU emulation issues**
✅ **Simplified Dockerfile** (no complex operations)
✅ **Retry logic** for multi-arch builds
✅ **Fallback to single architecture** if needed

## Deploy Commands:
```bash
tar -xzf dns-lookup-simple-multiarch-*.tar.gz
cd dns-lookup-simple-multiarch-*
chmod +x deploy.sh
./deploy.sh
```

## Build Strategy:
1. **Attempt multi-arch** (ARM64 + x86_64)
2. **Retry on failure** with clean builder
3. **Fallback to x86_64** if multi-arch fails
4. **Always produces working image**

## Test Inputs:

### Basic Domain Lookup:
```json
{"domain": "google.com"}
```

### Multiple Formats Supported:
```json
{"queryStringParameters": {"domain": "aws.amazon.com"}}
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

## Fallback Behavior:
- If multi-arch fails → builds x86_64 only
- x86_64 images work on most Agent Core Runtime platforms
- Still provides full DNS lookup functionality
EOF

# Create the package
cd /tmp
tar -czf "/mnt/c/Users/6135616/chatops_route_dns/${PACKAGE_NAME}.tar.gz" "$PACKAGE_NAME"

# Cleanup
rm -rf "$PACKAGE_DIR"

echo "✅ Simplified package created: ${PACKAGE_NAME}.tar.gz"
echo "📊 Size: $(du -h "/mnt/c/Users/6135616/chatops_route_dns/${PACKAGE_NAME}.tar.gz" | cut -f1)"
echo ""
echo "🔧 Cloud Shell Optimizations:"
echo "   ✅ Simplified Dockerfile (no apt-get issues)"
echo "   ✅ QEMU emulation workarounds"
echo "   ✅ Retry logic for build stability"
echo "   ✅ Automatic fallback strategy"
echo ""
echo "🚀 Upload to Cloud Shell and run:"
echo "   tar -xzf ${PACKAGE_NAME}.tar.gz"
echo "   cd ${PACKAGE_NAME}"
echo "   chmod +x deploy.sh"
echo "   ./deploy.sh"