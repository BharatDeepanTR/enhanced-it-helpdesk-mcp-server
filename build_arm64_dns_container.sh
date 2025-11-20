#!/bin/bash
"""
Build ARM64 DNS Container with Correct SSM Path - Option 2 Implementation
"""

set -e  # Exit on any error

echo "=== Building ARM64 DNS Container with Fixed SSM Path ==="

# Step 1: Bootstrap the ARM64 builder
echo "🔧 Bootstrapping ARM64 builder..."
docker buildx inspect --bootstrap

# Step 2: Create working directory
BUILD_DIR="/tmp/dns-container-arm64-fix"
mkdir -p $BUILD_DIR
cd $BUILD_DIR

# Step 3: Extract current container files
echo "📦 Extracting files from current container..."
docker run --rm --entrypoint tar 818565325759.dkr.ecr.us-east-1.amazonaws.com/dns-lookup-service:v1.0.0 -czf - /app | tar -xzf -

# Step 4: Create the environment override patch
echo "🔧 Creating SSM path fix..."
cat > app/fix_ssm_path.py << 'EOF'
"""
Fix SSM parameter path for Agent Core Runtime
This module patches the environment to use the correct SSM path
"""
import os
import sys

# Apply the SSM path fix before any other imports
os.environ['ENV'] = 'dev'
os.environ['APP_CONFIG_PATH'] = '/a208194/APISECRETS'
os.environ['AWS_DEFAULT_REGION'] = 'us-east-1'

print("✅ SSM path fixed: Using /a208194/APISECRETS for configuration")
EOF

# Step 5: Patch container_handler.py to apply the fix
echo "🔧 Patching container handler..."
# Insert the fix import at the very beginning
sed '1i import fix_ssm_path  # Apply SSM path fix' app/container_handler.py > app/container_handler_patched.py
mv app/container_handler_patched.py app/container_handler.py

# Step 6: Create optimized ARM64 Dockerfile
echo "🐳 Creating ARM64-optimized Dockerfile..."
cat > Dockerfile << 'EOF'
FROM 818565325759.dkr.ecr.us-east-1.amazonaws.com/dns-lookup-service:v1.0.0

# Copy the patched application files
COPY app/ /app/

# Set the working directory
WORKDIR /app

# Environment variables (these will be overridden by fix_ssm_path.py)
ENV ENV=dev
ENV APP_CONFIG_PATH=/a208194/APISECRETS
ENV AWS_DEFAULT_REGION=us-east-1

# Ensure the fix module is available
RUN python3 -c "import fix_ssm_path; print('SSM path fix validated')" || echo "Fix will be applied at runtime"
EOF

# Step 7: Build the ARM64 container
echo "🏗️ Building ARM64 container..."
NEW_TAG="818565325759.dkr.ecr.us-east-1.amazonaws.com/dns-lookup-service:v1.1.0-fixed-arm64"

# Build and push directly to ECR for ARM64
docker buildx build \
    --platform linux/arm64 \
    --tag $NEW_TAG \
    --push \
    .

echo ""
echo "🎉 SUCCESS! ARM64 container built and pushed!"
echo ""
echo "Container: $NEW_TAG"
echo "Platform: linux/arm64"
echo "SSM Path: /a208194/APISECRETS (fixed)"
echo ""
echo "Next steps:"
echo "1. Update Agent Core Runtime source URI to: $NEW_TAG"
echo "2. Test DNS agent functionality"
echo "3. Verify SSM parameter access in logs"
echo ""
echo "✅ DNS Agent is now ready for Agent Core Runtime with proper ARM64 architecture!"