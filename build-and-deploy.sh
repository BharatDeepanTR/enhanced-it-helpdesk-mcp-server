#!/bin/bash

# DNS Agent Core Runtime - Build and Deploy Script
# This script builds and deploys the HTTP container with fixed DNS logic

set -e

echo "🚀 DNS Agent Core Runtime - Build and Deploy"
echo "============================================="

# Configuration
ECR_REGISTRY="818565325759.dkr.ecr.us-east-1.amazonaws.com"
ECR_REPO="dns-lookup-service"
VERSION="v10.0.0-fixed-logic"
RUNTIME_ID="a208194_chatops_route_dns_lookup-Zg3E6G5ZDV"

echo "📦 Building ARM64 container for Agent Core Runtime..."
docker buildx build \
    --platform linux/arm64 \
    -t dns-lookup-http:${VERSION} \
    -f Dockerfile.http-multiarch \
    --load .

echo "🏷️  Tagging container for ECR..."
docker tag dns-lookup-http:${VERSION} ${ECR_REGISTRY}/${ECR_REPO}:${VERSION}

echo "⬆️  Pushing container to ECR..."
docker push ${ECR_REGISTRY}/${ECR_REPO}:${VERSION}

echo "🔄 Updating Agent Core Runtime..."
aws bedrock-agent update-agent-runtime \
    --runtime-id ${RUNTIME_ID} \
    --image-uri ${ECR_REGISTRY}/${ECR_REPO}:${VERSION} \
    --region us-east-1

echo "✅ Deployment complete!"
echo ""
echo "🧪 Test with:"
echo '   {"dns_name": "microsoft.com"}'
echo ""
echo "📊 Monitor CloudWatch logs:"
echo "   /aws/bedrock-agentcore/runtimes/${RUNTIME_ID}-DEFAULT"
echo ""
echo "🎯 Agent Core Runtime ready for team integration!"