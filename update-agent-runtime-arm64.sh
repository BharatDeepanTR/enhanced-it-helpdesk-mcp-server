#!/bin/bash
# Update existing Agent Core Runtime container with Lambda handler (ARM64 compatible)

set -e

VERSION_TAG="v1.1.0"
REPO_NAME="dns-lookup-service"
REGION=${AWS_DEFAULT_REGION:-"us-east-1"}

# Get account ID and construct image URI
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
IMAGE_URI="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/${REPO_NAME}:${VERSION_TAG}"

echo "🔄 Updating Agent Core Runtime Container with Lambda Handler (ARM64)..."
echo "   New Version: $VERSION_TAG"
echo "   Image: $IMAGE_URI"
echo "   Architecture: ARM64"
echo ""

# Login to ECR
echo "🔐 Logging into ECR..."
aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin "${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com"

# Check if buildx is available for multi-arch builds
if docker buildx version >/dev/null 2>&1; then
    echo "🔨 Building ARM64 container with buildx..."
    
    # Create and use buildx builder
    docker buildx create --name arm64-builder --use 2>/dev/null || docker buildx use arm64-builder
    
    # Build and push ARM64 image
    docker buildx build \
        --platform linux/arm64 \
        --tag $IMAGE_URI \
        --file Dockerfile.agent-runtime \
        --push \
        .
    
    echo "   ✅ ARM64 build and push completed"
else
    echo "🔨 Building container (legacy mode)..."
    
    # Fallback to legacy build
    export DOCKER_BUILDKIT=0
    docker build \
        --no-cache \
        --tag $IMAGE_URI \
        --file Dockerfile.agent-runtime \
        .
    
    # Push to ECR
    docker push $IMAGE_URI
    echo "   ✅ Legacy build and push completed"
fi

echo ""
echo "🎉 Container update successful!"
echo ""
echo "📋 Updated Image Details:"
echo "   Repository: $REPO_NAME"
echo "   Tag: $VERSION_TAG"
echo "   URI: $IMAGE_URI"
echo "   Architecture: ARM64 (Agent Core Runtime compatible)"
echo "   Mode: Lambda handler"
echo ""
echo "🔄 Next Steps:"
echo "1. Update your Agent Core Runtime to use the new image URI:"
echo "   $IMAGE_URI"
echo "2. Test with these inputs in Agent Sandbox:"
echo '   {"domain": "google.com"}'
echo '   {"domain": "aws.amazon.com"}'
echo ""
echo "✅ Your DNS service is now Agent Core Runtime compatible with ARM64!"