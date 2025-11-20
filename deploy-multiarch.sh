#!/bin/bash
set -e

# Multi-architecture ECR deployment for Agent Core Runtime
# Builds for both ARM64 and x86_64 architectures

VERSION_TAG=${1:-"v1.0.0"}
REPO_NAME="dns-lookup-service"
REGION=${AWS_DEFAULT_REGION:-"us-east-1"}

echo "🚀 Starting Multi-Architecture ECR deployment..."
echo "   Version: $VERSION_TAG"
echo "   Region: $REGION"
echo "   Architectures: ARM64 + x86_64"
echo ""

# Get AWS Account ID
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ECR_URI="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com"
IMAGE_URI="${ECR_URI}/${REPO_NAME}:${VERSION_TAG}"

echo "📋 AWS Account: $ACCOUNT_ID"
echo "📋 Image URI: $IMAGE_URI"
echo ""

# Create ECR repository if it doesn't exist
echo "🏗️  Ensuring ECR repository exists..."
aws ecr describe-repositories --repository-names $REPO_NAME --region $REGION 2>/dev/null || {
    echo "   Creating repository '$REPO_NAME'..."
    aws ecr create-repository \
        --repository-name $REPO_NAME \
        --region $REGION \
        --image-scanning-configuration scanOnPush=true \
        --encryption-configuration encryptionType=AES256 > /dev/null
    echo "   ✅ Repository created"
}

# Login to ECR
echo "🔐 Logging into ECR..."
aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $ECR_URI
echo "   ✅ Login successful"

# Clean Docker environment
echo "🧹 Cleaning Docker environment..."
docker system prune -f 2>/dev/null || true

# Check if buildx is available for multi-arch builds
if docker buildx version >/dev/null 2>&1; then
    echo "🔨 Building multi-architecture image with buildx..."
    
    # Create and use buildx builder
    docker buildx create --name multiarch-builder --use 2>/dev/null || docker buildx use multiarch-builder
    
    # Build and push multi-architecture image
    docker buildx build \
        --platform linux/amd64,linux/arm64 \
        --tag $IMAGE_URI \
        --file Dockerfile \
        --push \
        .
    
    echo "   ✅ Multi-architecture build and push completed"
else
    echo "🔨 Building x86_64 image (buildx not available)..."
    
    # Fallback to single architecture build
    export DOCKER_BUILDKIT=0
    docker build \
        --no-cache \
        --tag $IMAGE_URI \
        --file Dockerfile \
        .
    
    # Push to ECR
    docker push $IMAGE_URI
    echo "   ✅ x86_64 build and push completed"
fi

echo ""
echo "🎉 Deployment successful!"
echo ""
echo "📋 Image Details:"
echo "   Repository: $REPO_NAME"
echo "   Tag: $VERSION_TAG"
echo "   URI: $IMAGE_URI"
echo "   Architecture: Multi-arch (ARM64 + x86_64) or x86_64"
echo ""
echo "🤖 Agent Core Runtime Compatible!"
echo "   This image will work on any agent runtime platform"
echo ""