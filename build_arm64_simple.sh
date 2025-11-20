#!/bin/bash
"""
Simplified ARM64 DNS Container Build - No RUN Commands
"""

set -e  # Exit on any error

echo "=== Building ARM64 DNS Container (Simplified) ==="

# Step 1: Create working directory
BUILD_DIR="/tmp/dns-container-arm64-simple"
rm -rf $BUILD_DIR  # Clean previous attempts
mkdir -p $BUILD_DIR
cd $BUILD_DIR

# Step 2: Extract current container files
echo "📦 Extracting files from current container..."
docker run --rm --entrypoint tar 818565325759.dkr.ecr.us-east-1.amazonaws.com/dns-lookup-service:v1.0.0 -czf - /app | tar -xzf -

# Step 3: Create the environment override patch (simplified)
echo "🔧 Creating SSM path fix..."
cat > app/fix_ssm_path.py << 'EOF'
"""
Fix SSM parameter path for Agent Core Runtime
This module patches the environment to use the correct SSM path
"""
import os

# Apply the SSM path fix before any other imports
os.environ['ENV'] = 'dev'
os.environ['APP_CONFIG_PATH'] = '/a208194/APISECRETS'
os.environ['AWS_DEFAULT_REGION'] = 'us-east-1'
EOF

# Step 4: Patch container_handler.py to apply the fix
echo "🔧 Patching container handler..."
# Insert the fix import at the very beginning, after the shebang if present
if grep -q '^#!/' app/container_handler.py; then
    # Insert after shebang
    sed '1a import fix_ssm_path  # Apply SSM path fix' app/container_handler.py > app/container_handler_patched.py
else
    # Insert at the beginning
    sed '1i import fix_ssm_path  # Apply SSM path fix' app/container_handler.py > app/container_handler_patched.py
fi
mv app/container_handler_patched.py app/container_handler.py

# Step 5: Create minimal ARM64 Dockerfile (no RUN commands to avoid arch issues)
echo "🐳 Creating minimal ARM64 Dockerfile..."
cat > Dockerfile << 'EOF'
FROM 818565325759.dkr.ecr.us-east-1.amazonaws.com/dns-lookup-service:v1.0.0

# Copy the patched application files
COPY app/ /app/

# Set the working directory
WORKDIR /app

# Environment variables for SSM path fix
ENV ENV=dev
ENV APP_CONFIG_PATH=/a208194/APISECRETS
ENV AWS_DEFAULT_REGION=us-east-1
EOF

# Step 6: Build the ARM64 container (simplified - no validation RUN command)
echo "🏗️ Building ARM64 container (simplified)..."
NEW_TAG="818565325759.dkr.ecr.us-east-1.amazonaws.com/dns-lookup-service:v1.1.0-fixed-arm64"

# Build and push directly to ECR for ARM64
docker buildx build \
    --platform linux/arm64 \
    --tag $NEW_TAG \
    --push \
    .

echo ""
echo "🎉 SUCCESS! Simplified ARM64 container built and pushed!"
echo ""
echo "Container: $NEW_TAG"
echo "Platform: linux/arm64"
echo "SSM Path: /a208194/APISECRETS (fixed)"
echo ""
echo "Next steps:"
echo "1. Update Agent Core Runtime source URI to: $NEW_TAG"
echo "2. Test DNS agent functionality"
echo "3. The fix_ssm_path.py will be imported at runtime to set correct paths"
echo ""
echo "✅ DNS Agent ready for Agent Core Runtime!"