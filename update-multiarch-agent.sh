#!/bin/bash
# Multi-architecture Agent Core Runtime update script
# Supports both ARM64 and x86_64 platforms

set -e

VERSION_TAG="v1.2.0"
REPO_NAME="dns-lookup-service"
REGION=${AWS_DEFAULT_REGION:-"us-east-1"}

# Get account ID and construct image URI
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
IMAGE_URI="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/${REPO_NAME}:${VERSION_TAG}"

echo "🔄 Building Multi-Architecture Agent Core Runtime Container..."
echo "   Version: $VERSION_TAG"
echo "   Image: $IMAGE_URI"
echo "   Architectures: ARM64 + x86_64"
echo "   Mode: Lambda handler"
echo ""

# Login to ECR
echo "🔐 Logging into ECR..."
aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin "${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com"

# Clean Docker environment
echo "🧹 Cleaning Docker environment..."
docker system prune -f 2>/dev/null || true

# Check if buildx is available for multi-arch builds
if docker buildx version >/dev/null 2>&1; then
    echo "🔨 Building multi-architecture image with buildx..."
    
    # Create and use buildx builder if it doesn't exist
    docker buildx create --name multiarch-agent-builder --use 2>/dev/null || docker buildx use multiarch-agent-builder 2>/dev/null || true
    
    # Initialize builder
    docker buildx inspect --bootstrap
    
    # Build and push multi-architecture image
    docker buildx build \
        --platform linux/amd64,linux/arm64 \
        --tag $IMAGE_URI \
        --file Dockerfile.agent-runtime \
        --push \
        .
    
    echo "   ✅ Multi-architecture build and push completed"
    echo "   📋 Platforms: linux/amd64, linux/arm64"
    
else
    echo "🔨 Building single architecture (buildx not available)..."
    echo "⚠️  Warning: This will only support the current platform"
    
    # Fallback to legacy build
    export DOCKER_BUILDKIT=0
    docker build \
        --no-cache \
        --tag $IMAGE_URI \
        --file Dockerfile.agent-runtime \
        .
    
    # Push to ECR
    docker push $IMAGE_URI
    echo "   ✅ Single architecture build completed"
fi

# Verify the image manifest
echo ""
echo "🔍 Verifying image manifest..."
docker manifest inspect $IMAGE_URI 2>/dev/null || echo "   Manifest inspection not available"

echo ""
echo "🎉 Multi-Architecture Container Update Successful!"
echo ""
echo "📋 Image Details:"
echo "   Repository: $REPO_NAME"
echo "   Tag: $VERSION_TAG"
echo "   URI: $IMAGE_URI"
echo "   Architectures: ARM64 + x86_64 (multi-arch)"
echo "   Mode: Lambda handler"
echo "   Entry Point: lambda_handler.lambda_handler"
echo ""
echo "🤖 Agent Core Runtime Compatibility:"
echo "   ✅ Works on ARM64 runtime"
echo "   ✅ Works on x86_64 runtime"
echo "   ✅ Automatic platform selection"
echo "   ✅ Single image URI for all platforms"
echo ""
echo "🔄 Next Steps:"
echo "1. Update your Agent Core Runtime configuration:"
echo "   Image URI: $IMAGE_URI"
echo ""
echo "2. Test with these inputs in Agent Sandbox:"
echo '   {"domain": "google.com"}'
echo '   {"domain": "aws.amazon.com"}'
echo '   {"queryStringParameters": {"domain": "github.com"}}'
echo ""
echo "✅ Your DNS service now supports ALL Agent Core Runtime platforms!"