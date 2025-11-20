#!/bin/bash
set -e

# Create corrected Cloud Shell package with fixed Dockerfile references
TIMESTAMP=$(date +"%Y%m%d-%H%M%S")
PACKAGE_NAME="dns-lookup-fixed-cloudshell-${TIMESTAMP}"
PACKAGE_DIR="/tmp/${PACKAGE_NAME}"

echo "📦 Creating Fixed Cloud Shell Package..."

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

# Create quick deployment guide
cat > "$PACKAGE_DIR/README.md" << 'EOF'
# DNS Lookup Service - Fixed Cloud Shell Package

## Fixed Issues:
✅ **Dockerfile reference corrected**
✅ **Cloud Shell QEMU workarounds**
✅ **Simplified build process**
✅ **Automatic fallback strategy**

## Deploy Commands:
```bash
tar -xzf dns-lookup-fixed-cloudshell-*.tar.gz
cd dns-lookup-fixed-cloudshell-*
chmod +x deploy.sh
./deploy.sh
```

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

Should build successfully without Dockerfile reference errors!
EOF

# Create the package
cd /tmp
tar -czf "/mnt/c/Users/6135616/chatops_route_dns/${PACKAGE_NAME}.tar.gz" "$PACKAGE_NAME"

# Cleanup
rm -rf "$PACKAGE_DIR"

echo "✅ Fixed package created: ${PACKAGE_NAME}.tar.gz"
echo "📊 Size: $(du -h "/mnt/c/Users/6135616/chatops_route_dns/${PACKAGE_NAME}.tar.gz" | cut -f1)"
echo ""
echo "🔧 Fixes Applied:"
echo "   ✅ Dockerfile references corrected"
echo "   ✅ All files properly included"
echo "   ✅ Cloud Shell optimizations"
echo ""
echo "🚀 Upload to Cloud Shell and run:"
echo "   tar -xzf ${PACKAGE_NAME}.tar.gz"
echo "   cd ${PACKAGE_NAME}"
echo "   chmod +x deploy.sh"
echo "   ./deploy.sh"