#!/bin/bash
set -e

# Create complete Agent Core Runtime compatible package
TIMESTAMP=$(date +"%Y%m%d-%H%M%S")
PACKAGE_NAME="dns-lookup-agent-runtime-fixed-${TIMESTAMP}"
PACKAGE_DIR="/tmp/${PACKAGE_NAME}"

echo "📦 Creating complete Agent Runtime compatible package..."

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
cp update-agent-runtime.sh "$PACKAGE_DIR/"
cp Dockerfile.agent-runtime "$PACKAGE_DIR/"

# Create simple deployment instructions
cat > "$PACKAGE_DIR/README.md" << 'EOF'
# DNS Lookup Service - Agent Core Runtime Compatible

## Deploy Commands:
```bash
tar -xzf dns-lookup-agent-runtime-fixed-*.tar.gz
cd dns-lookup-agent-runtime-fixed-*
chmod +x update-agent-runtime.sh
./update-agent-runtime.sh
```

## What's Included:
✅ Lambda handler for Agent Core Runtime compatibility
✅ Updated Dockerfile with correct entry point
✅ All original DNS lookup functionality
✅ Multi-format input support

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
EOF

# Create the package
cd /tmp
tar -czf "/mnt/c/Users/6135616/chatops_route_dns/${PACKAGE_NAME}.tar.gz" "$PACKAGE_NAME"

# Cleanup
rm -rf "$PACKAGE_DIR"

echo "✅ Complete package created: ${PACKAGE_NAME}.tar.gz"
echo "📊 Size: $(du -h "/mnt/c/Users/6135616/chatops_route_dns/${PACKAGE_NAME}.tar.gz" | cut -f1)"
echo ""
echo "📋 Package Contents:"
echo "   ✅ Lambda handler (lambda_handler.py)"
echo "   ✅ Agent Runtime Dockerfile (Dockerfile.agent-runtime)"
echo "   ✅ Update script (update-agent-runtime.sh)"
echo "   ✅ All DNS lookup code"
echo "   ✅ Compatible requirements"
echo ""
echo "🚀 Upload this package to Cloud Shell and run:"
echo "   tar -xzf ${PACKAGE_NAME}.tar.gz"
echo "   cd ${PACKAGE_NAME}"
echo "   chmod +x update-agent-runtime.sh"
echo "   ./update-agent-runtime.sh"