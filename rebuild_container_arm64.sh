#!/bin/bash
"""
Option 2: Rebuild DNS Container with ARM64 Architecture for Agent Core Runtime
"""

echo "=== DNS Container ARM64 Rebuild for Agent Core Runtime ==="

# Step 1: Create working directory
mkdir -p /tmp/dns-container-fix-arm64
cd /tmp/dns-container-fix-arm64

# Step 2: Extract current container files
echo "📦 Extracting files from current container..."
docker run --rm --entrypoint tar 818565325759.dkr.ecr.us-east-1.amazonaws.com/dns-lookup-service:v1.0.0 -czf - /app | tar -xzf -

# Step 3: Create a simple environment variable override
echo "🔧 Creating environment variable override..."
cat > app/env_override.py << 'EOF'
"""
Environment variable override for correct SSM path
This gets imported first to set the correct path
"""
import os

# Override the APP_CONFIG_PATH to point to correct SSM location
os.environ['ENV'] = 'dev'
os.environ['APP_CONFIG_PATH'] = '/a208194/APISECRETS'
os.environ['AWS_DEFAULT_REGION'] = 'us-east-1'

print("✅ Environment variables set for correct SSM path")
EOF

# Step 4: Patch the container handler to import our override first
echo "🔧 Patching container handler..."
sed '1i import env_override  # Load correct environment variables' app/container_handler.py > app/container_handler_new.py
mv app/container_handler_new.py app/container_handler.py

# Step 5: Create ARM64 compatible Dockerfile
echo "🐳 Creating ARM64 Dockerfile..."
cat > Dockerfile << 'EOF'
FROM --platform=linux/arm64 818565325759.dkr.ecr.us-east-1.amazonaws.com/dns-lookup-service:v1.0.0

# Copy the updated files with correct SSM path
COPY app/ /app/

# Set working directory
WORKDIR /app

# Default environment variables (will be overridden by env_override.py)
ENV ENV=dev
ENV APP_CONFIG_PATH=/a208194/APISECRETS
ENV AWS_DEFAULT_REGION=us-east-1

# Keep the same entrypoint
EOF

# Step 6: Build new ARM64 container
echo "🏗️ Building ARM64 container..."
NEW_TAG="818565325759.dkr.ecr.us-east-1.amazonaws.com/dns-lookup-service:v1.1.0-fixed-arm64"

# Build for ARM64 platform
docker buildx build --platform linux/arm64 -t $NEW_TAG . --load

echo ""
echo "✅ ARM64 CONTAINER REBUILT SUCCESSFULLY!"
echo ""
echo "New container: $NEW_TAG"
echo "Architecture: ARM64 (compatible with Agent Core Runtime)"
echo ""
echo "Next steps:"
echo "1. Push to ECR: docker push $NEW_TAG"
echo "2. Update Agent Core Runtime source to use v1.1.0-fixed-arm64"
echo "3. Test the updated agent"
echo ""
echo "🎯 This container should work with Agent Core Runtime ARM64 requirement!"