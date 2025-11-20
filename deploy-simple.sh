#!/bin/bash
set -e

# Cloud Shell ECR Deployment Script - Cache Issue Fix
# Usage: ./deploy-simple.sh <version-tag>

VERSION_TAG=${1:-"v1.0.0"}
REPO_NAME="dns-lookup-service"
REGION=${AWS_DEFAULT_REGION:-"us-east-1"}

echo "🚀 Starting ECR deployment (Cache-Free Mode)..."
echo "   Version: $VERSION_TAG"
echo "   Region: $REGION"
echo ""

# Get AWS Account ID
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ECR_URI="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com"
IMAGE_URI="${ECR_URI}/${REPO_NAME}:${VERSION_TAG}"

echo "📋 AWS Account: $ACCOUNT_ID"
echo "📋 ECR URI: $ECR_URI"
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

# Build with no cache and simplified options
echo "🔨 Building Docker image (no-cache mode)..."
export DOCKER_BUILDKIT=1
docker build \
    --no-cache \
    --platform linux/arm64 \
    --progress=plain \
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
echo "   Architecture: ARM64"
echo ""
echo "🚀 Ready for deployment to:"
echo "   • ECS Fargate (ARM64)"
echo "   • EKS (Graviton nodes)"
echo "   • Lambda Container Images"
echo ""