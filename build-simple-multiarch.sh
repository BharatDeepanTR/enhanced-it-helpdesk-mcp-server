#!/bin/bash
# Simplified multi-architecture build for Agent Core Runtime
# Avoids QEMU emulation issues in Cloud Shell

set -e

VERSION_TAG="v1.3.0"
REPO_NAME="dns-lookup-service"
REGION=${AWS_DEFAULT_REGION:-"us-east-1"}

# Get account ID and construct image URI
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
IMAGE_URI="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/${REPO_NAME}:${VERSION_TAG}"

echo "🔄 Building Agent Core Runtime Container (Simplified Multi-arch)..."
echo "   Version: $VERSION_TAG"
echo "   Image: $IMAGE_URI"
echo ""

# Login to ECR
echo "🔐 Logging into ECR..."
aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin "${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com"

# Clean Docker environment
echo "🧹 Cleaning Docker environment..."
docker system prune -f 2>/dev/null || true

# Try multi-arch build with simplified approach
if docker buildx version >/dev/null 2>&1; then
    echo "🔨 Attempting simplified multi-arch build..."
    
    # Remove existing builder and create fresh one
    docker buildx rm multiarch-simple 2>/dev/null || true
    docker buildx create --name multiarch-simple --driver docker-container --use
    
    # Try to build multi-arch with retry logic
    MAX_RETRIES=2
    RETRY_COUNT=0
    
    while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
        if docker buildx build \
            --platform linux/amd64,linux/arm64 \
            --tag $IMAGE_URI \
            --file Dockerfile \
            --push \
            . ; then
            echo "   ✅ Multi-architecture build successful"
            MULTI_ARCH_SUCCESS=true
            break
        else
            echo "   ⚠️  Multi-arch attempt $((RETRY_COUNT + 1)) failed"
            RETRY_COUNT=$((RETRY_COUNT + 1))
        fi
    done
    
    if [ "$MULTI_ARCH_SUCCESS" != "true" ]; then
        echo "   🔄 Falling back to single architecture..."
        docker buildx build \
            --platform linux/amd64 \
            --tag $IMAGE_URI \
            --file Dockerfile \
            --push \
            .
        echo "   ✅ Single architecture (x86_64) build successful"
    fi
    
else
    echo "🔨 Building with legacy Docker..."
    
    # Legacy build
    export DOCKER_BUILDKIT=0
    docker build \
        --no-cache \
        --tag $IMAGE_URI \
        --file Dockerfile \
        .
    
    # Push to ECR
    docker push $IMAGE_URI
    echo "   ✅ Legacy build successful"
fi

echo ""
echo "🎉 Container Build Successful!"
echo ""
echo "📋 Image Details:"
echo "   Repository: $REPO_NAME"
echo "   Tag: $VERSION_TAG"
echo "   URI: $IMAGE_URI"
echo "   Mode: Lambda handler"
echo "   Entry Point: lambda_handler.lambda_handler"
echo ""
echo "🔄 Next Steps:"
echo "1. Update your Agent Core Runtime configuration:"
echo "   Image URI: $IMAGE_URI"
echo ""
echo "2. Test with these inputs in Agent Sandbox:"
echo '   {"domain": "google.com"}'
echo '   {"domain": "aws.amazon.com"}'
echo ""
echo "✅ Your DNS service is now ready for Agent Core Runtime!"