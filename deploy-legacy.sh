#!/bin/bash
set -e

# Cloud Shell ECR Deployment - Legacy Docker Build (No BuildKit)
# This bypasses BuildKit cache corruption issues completely

VERSION_TAG=${1:-"v1.0.0"}
REPO_NAME="dns-lookup-service"
REGION=${AWS_DEFAULT_REGION:-"us-east-1"}

echo "🚀 Starting ECR deployment (Legacy Docker Mode)..."
echo "   Version: $VERSION_TAG"
echo "   Region: $REGION"
echo ""

# Disable BuildKit completely
export DOCKER_BUILDKIT=0

# Get AWS Account ID
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ECR_URI="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com"
IMAGE_URI="${ECR_URI}/${REPO_NAME}:${VERSION_TAG}"

echo "📋 AWS Account: $ACCOUNT_ID"
echo "📋 Image will be: $IMAGE_URI"
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

# Clean any existing cache/images
echo "🧹 Cleaning Docker cache..."
docker system prune -f 2>/dev/null || true
docker image prune -f 2>/dev/null || true

# Build with legacy Docker (no BuildKit, no platform flag)
echo "🔨 Building Docker image (Legacy Mode)..."
docker build \
    --no-cache \
    --tag $IMAGE_URI \
    --file Dockerfile \
    .

echo "   ✅ Build completed"

# Push to ECR
echo "📤 Pushing image to ECR..."
docker push $IMAGE_URI
echo "   ✅ Push completed"

echo ""
echo "🎉 Deployment successful!"
echo ""
echo "📋 Image Details:"
echo "   Repository: $REPO_NAME"
echo "   Tag: $VERSION_TAG"
echo "   URI: $IMAGE_URI"
echo ""
echo "⚠️  Note: Built with legacy Docker (ARM64 emulation)"
echo "   This will work on ARM64 instances but may be slower to build"
echo ""