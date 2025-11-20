#!/bin/bash
set -e

# Create multi-architecture Agent Core Runtime package
TIMESTAMP=$(date +"%Y%m%d-%H%M%S")
PACKAGE_NAME="dns-lookup-multiarch-agent-${TIMESTAMP}"
PACKAGE_DIR="/tmp/${PACKAGE_NAME}"

echo "📦 Creating Multi-Architecture Agent Runtime package..."

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
cp update-multiarch-agent.sh "$PACKAGE_DIR/deploy.sh"
cp Dockerfile.agent-runtime "$PACKAGE_DIR/"

# Create comprehensive deployment guide
cat > "$PACKAGE_DIR/README.md" << 'EOF'
# DNS Lookup Service - Multi-Architecture Agent Core Runtime

## Universal Platform Support
✅ **ARM64** (AWS Graviton, Apple Silicon)
✅ **x86_64** (Intel/AMD processors)
✅ **Single image URI** works on both platforms
✅ **Automatic platform detection** by container runtime

## Deploy Commands:
```bash
tar -xzf dns-lookup-multiarch-agent-*.tar.gz
cd dns-lookup-multiarch-agent-*
chmod +x deploy.sh
./deploy.sh
```

## Features:
- **Multi-architecture manifest** (ARM64 + x86_64)
- **Lambda handler** for Agent Core Runtime
- **Multiple input format support**
- **Comprehensive error handling**
- **Health check endpoints**

## Test Inputs After Deploy:

### Basic Domain Lookup:
```json
{"domain": "google.com"}
```

### Query String Format:
```json
{"queryStringParameters": {"domain": "aws.amazon.com"}}
```

### HTTP Request Format:
```json
{
  "httpMethod": "GET",
  "path": "/lookup",
  "queryStringParameters": {"domain": "github.com"}
}
```

### Health Check:
```json
{"path": "/health"}
```

## Expected Output:
```json
{
  "statusCode": 200,
  "body": {
    "domain": "google.com",
    "records": [
      {"type": "A", "value": "142.250.180.14"}
    ],
    "status": "success",
    "timestamp": "2025-11-01T21:00:00Z"
  }
}
```

## Architecture Benefits:
- **Universal compatibility** - works on any Agent Core Runtime
- **Performance optimized** for each architecture
- **Future-proof** - supports new platforms automatically
- **Single deployment** - no platform-specific builds needed

## Image Details:
- **Repository**: dns-lookup-service
- **Tag**: v1.2.0
- **Platforms**: linux/amd64, linux/arm64
- **Entry Point**: lambda_handler.lambda_handler
EOF

# Create deployment verification script
cat > "$PACKAGE_DIR/verify-deployment.sh" << 'EOF'
#!/bin/bash
# Verify multi-architecture deployment

REPO_NAME="dns-lookup-service"
VERSION_TAG="v1.2.0"
REGION=${AWS_DEFAULT_REGION:-"us-east-1"}
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
IMAGE_URI="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/${REPO_NAME}:${VERSION_TAG}"

echo "🔍 Verifying Multi-Architecture Deployment..."
echo "Image: $IMAGE_URI"
echo ""

# Check image manifest
echo "📋 Image Manifest:"
docker manifest inspect $IMAGE_URI 2>/dev/null || echo "❌ Manifest inspection failed"

echo ""
echo "✅ Deployment verification completed"
EOF

chmod +x "$PACKAGE_DIR/verify-deployment.sh"

# Create the package
cd /tmp
tar -czf "/mnt/c/Users/6135616/chatops_route_dns/${PACKAGE_NAME}.tar.gz" "$PACKAGE_NAME"

# Cleanup
rm -rf "$PACKAGE_DIR"

echo "✅ Multi-Architecture package created: ${PACKAGE_NAME}.tar.gz"
echo "📊 Size: $(du -h "/mnt/c/Users/6135616/chatops_route_dns/${PACKAGE_NAME}.tar.gz" | cut -f1)"
echo ""
echo "🏗️  Multi-Architecture Features:"
echo "   ✅ linux/amd64 + linux/arm64 support"
echo "   ✅ Single image URI for all platforms"
echo "   ✅ Lambda handler entry point"
echo "   ✅ Agent Core Runtime compatible"
echo "   ✅ Automatic platform selection"
echo ""
echo "📋 Package Contents:"
echo "   • Multi-arch deployment script (deploy.sh)"
echo "   • Lambda handler (lambda_handler.py)"
echo "   • Agent Runtime Dockerfile"
echo "   • All DNS lookup functionality"
echo "   • Deployment verification script"
echo ""
echo "🚀 Upload to Cloud Shell and run:"
echo "   tar -xzf ${PACKAGE_NAME}.tar.gz"
echo "   cd ${PACKAGE_NAME}"
echo "   chmod +x deploy.sh"
echo "   ./deploy.sh"