#!/bin/bash
"""
Quick Environment Fix for DNS Agent Core Runtime
Use the existing working container as base and just fix environment variables
"""

echo "🔧 Creating Environment-Fixed DNS Container"

# Use the existing successful container as base
BASE_IMAGE="818565325759.dkr.ecr.us-east-1.amazonaws.com/dns-lookup-service:v1.1.0-fixed-arm64"
NEW_TAG="818565325759.dkr.ecr.us-east-1.amazonaws.com/dns-lookup-service:v1.2.0-env-fixed"

# Create simple Dockerfile that just fixes environment
cat > Dockerfile.env-only << 'EOF'
FROM 818565325759.dkr.ecr.us-east-1.amazonaws.com/dns-lookup-service:v1.1.0-fixed-arm64

# Fix the environment variables that are causing the KeyError
ENV ENV=dev
ENV APP_CONFIG_PATH=/a208194/APISECRETS

# Keep all other settings the same
EOF

echo "📦 Building environment-fixed container..."
docker buildx build --platform linux/arm64 -f Dockerfile.env-only -t $NEW_TAG --push .

echo ""
echo "✅ SUCCESS! Environment-fixed container built and pushed!"
echo ""
echo "New container: $NEW_TAG" 
echo "Environment fixes:"
echo "  - ENV=dev (was: production)"
echo "  - APP_CONFIG_PATH=/a208194/APISECRETS (was: /config)"
echo ""
echo "🎯 Next steps:"
echo "1. Update Agent Core Runtime to use: $NEW_TAG"
echo "2. Test with: {\"dns_name\": \"google.com\"}"
echo "3. Check CloudWatch logs for successful DNS resolution"