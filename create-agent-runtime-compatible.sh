#!/bin/bash
set -e

# Create Agent Core Runtime compatible package
TIMESTAMP=$(date +"%Y%m%d-%H%M%S")
PACKAGE_NAME="dns-lookup-agent-runtime-compatible-${TIMESTAMP}"
PACKAGE_DIR="/tmp/${PACKAGE_NAME}"

echo "📦 Creating Agent Core Runtime compatible package..."

# Create package directory
mkdir -p "$PACKAGE_DIR"

# Copy files
cp chatops_route_dns_intent.py "$PACKAGE_DIR/"
cp chatops_helpers.py "$PACKAGE_DIR/"
cp chatops_config.py "$PACKAGE_DIR/"
cp lambda_entry.py "$PACKAGE_DIR/"
cp requirements-minimal.txt "$PACKAGE_DIR/requirements.txt"
cp .dockerignore "$PACKAGE_DIR/"
cp deploy-multiarch.sh "$PACKAGE_DIR/"
cp Dockerfile.lambda "$PACKAGE_DIR/Dockerfile"

# Create deployment instructions
cat > "$PACKAGE_DIR/AGENT_RUNTIME_DEPLOY.md" << 'EOF'
# DNS Lookup Service - Agent Core Runtime Compatible

## Fixed Runtime Issues:
✅ Lambda-compatible entry point (lambda_entry.py)
✅ Handles multiple input formats
✅ Proper error handling and response format
✅ Health check support

## Deploy Commands:
```bash
tar -xzf dns-lookup-agent-runtime-compatible-*.tar.gz
cd dns-lookup-agent-runtime-compatible-*
chmod +x deploy-multiarch.sh
./deploy-multiarch.sh v1.1.0
```

## Test Inputs for Agent Sandbox:

### Simple Format:
```json
{"domain": "google.com"}
```

### HTTP Format:
```json
{
  "queryStringParameters": {
    "domain": "aws.amazon.com"
  }
}
```

### Health Check:
```json
{"path": "/health"}
```

## Expected Response:
```json
{
  "statusCode": 200,
  "body": "{\"domain\": \"google.com\", \"records\": [...], \"status\": \"success\"}"
}
```

This version should work with Agent Core Runtime sandbox testing!
EOF

# Create the package
cd /tmp
tar -czf "/mnt/c/Users/6135616/chatops_route_dns/${PACKAGE_NAME}.tar.gz" "$PACKAGE_NAME"

# Cleanup
rm -rf "$PACKAGE_DIR"

echo "✅ Agent Runtime compatible package created: ${PACKAGE_NAME}.tar.gz"
echo "📊 Size: $(du -h "/mnt/c/Users/6135616/chatops_route_dns/${PACKAGE_NAME}.tar.gz" | cut -f1)"
echo ""
echo "🔧 Key Fixes:"
echo "   ✅ Lambda entry point: lambda_entry.lambda_handler"
echo "   ✅ Multiple input format support"
echo "   ✅ Proper Lambda response format"
echo "   ✅ Error handling and health checks"
echo ""
echo "🚀 This should fix the 'runtime startup' error in Agent Core!"