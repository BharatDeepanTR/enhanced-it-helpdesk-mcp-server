#!/bin/bash
set -e

# Create Agent Core Runtime compatible package
TIMESTAMP=$(date +"%Y%m%d-%H%M%S")
PACKAGE_NAME="dns-lookup-agent-runtime-${TIMESTAMP}"
PACKAGE_DIR="/tmp/${PACKAGE_NAME}"

echo "📦 Creating Agent Core Runtime package..."

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

# Create Agent Core Runtime deployment guide
cat > "$PACKAGE_DIR/AGENT_RUNTIME_DEPLOY.md" << 'EOF'
# DNS Lookup Service - Agent Core Runtime Deployment

## For Agent Core Runtime Compatibility

This package creates a **multi-architecture container** that works with Agent Core Runtime environments.

### Deploy Commands:
```bash
tar -xzf dns-lookup-agent-runtime-*.tar.gz
cd dns-lookup-agent-runtime-*
chmod +x deploy-multiarch.sh
./deploy-multiarch.sh v1.0.0
```

### What This Does:
✅ **Multi-architecture build** (ARM64 + x86_64)
✅ **Agent Core Runtime compatible**
✅ **Automatic platform detection**
✅ **ECR deployment ready**

### Image Output:
- **Single image URI** that works on any platform
- **Automatic platform selection** by container runtime
- **Compatible with all agent runtimes**

### Container Features:
- HTTP API on port 8080
- Health checks at `/health`
- DNS lookup at `/lookup?domain=example.com`
- Non-root security hardening
- Minimal attack surface

### Usage in Agent Runtime:
The container will automatically run on the correct architecture (ARM64 or x86_64) based on the agent runtime environment.

Image URI format: `{account}.dkr.ecr.{region}.amazonaws.com/dns-lookup-service:v1.0.0`
EOF

# Create the package
cd /tmp
tar -czf "/mnt/c/Users/6135616/chatops_route_dns/${PACKAGE_NAME}.tar.gz" "$PACKAGE_NAME"

# Cleanup
rm -rf "$PACKAGE_DIR"

echo "✅ Agent Runtime package created: ${PACKAGE_NAME}.tar.gz"
echo "📊 Size: $(du -h "/mnt/c/Users/6135616/chatops_route_dns/${PACKAGE_NAME}.tar.gz" | cut -f1)"
echo ""
echo "🤖 Agent Core Runtime Features:"
echo "   ✅ Multi-architecture support (ARM64 + x86_64)"
echo "   ✅ Automatic platform detection"
echo "   ✅ Single image URI for all platforms"
echo "   ✅ HTTP API for easy integration"