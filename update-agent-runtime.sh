#!/bin/bash
# Update existing Agent Core Runtime container with Lambda handler

set -e

VERSION_TAG="v1.1.0"
REPO_NAME="dns-lookup-service"
REGION=${AWS_DEFAULT_REGION:-"us-east-1"}

# Get account ID and construct image URI
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
IMAGE_URI="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/${REPO_NAME}:${VERSION_TAG}"

echo "🔄 Updating Agent Core Runtime Container with Lambda Handler..."
echo "   New Version: $VERSION_TAG"
echo "   Image: $IMAGE_URI"
echo ""

# Login to ECR
echo "🔐 Logging into ECR..."
aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin "${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com"

# Build updated image with Lambda handler
echo "🔨 Building updated container..."
export DOCKER_BUILDKIT=0
docker build \
    --no-cache \
    --tag $IMAGE_URI \
    --file Dockerfile.agent-runtime \
    .

# Push updated image
echo "📤 Pushing updated image..."
docker push $IMAGE_URI

echo ""
echo "🎉 Container update successful!"
echo ""
echo "📋 Updated Image Details:"
echo "   Repository: $REPO_NAME"
echo "   Tag: $VERSION_TAG"
echo "   URI: $IMAGE_URI"
echo "   Mode: Lambda handler (Agent Core Runtime compatible)"
echo ""
echo "🔄 Next Steps:"
echo "1. Update your Agent Core Runtime to use the new image URI"
echo "2. Test with these inputs in Agent Sandbox:"
echo '   {"domain": "google.com"}'
echo '   {"domain": "aws.amazon.com"}'
echo ""
echo "✅ Your DNS service is now Agent Core Runtime compatible!"