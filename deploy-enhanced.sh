#!/bin/bash
# Enhanced Cloud Shell deployment script for AWS Bedrock Agent Core Runtime
# Prevents "Unable to invoke endpoint successfully" errors

set -e

VERSION_TAG="v1.4.0"
REPO_NAME="dns-lookup-service"
REGION=${AWS_DEFAULT_REGION:-"us-east-1"}

echo "🚀 AWS Bedrock Agent Core Runtime Deployment (Enhanced)"
echo "====================================================="
echo "Version: $VERSION_TAG"
echo "Region: $REGION"
echo ""

# Step 1: Validate AWS credentials and setup
echo "🔐 Step 1: Validating AWS environment..."

if ! command -v aws >/dev/null 2>&1; then
    echo "❌ AWS CLI not found. Please install AWS CLI."
    exit 1
fi

# Check for temporary credentials (Cloud Shell specific)
if [ -n "$AWS_SESSION_TOKEN" ]; then
    echo "   ✅ Using temporary AWS credentials (Cloud Shell)"
else
    echo "   ℹ️  Using standard AWS credentials"
fi

# Validate credentials
if ! aws sts get-caller-identity >/dev/null 2>&1; then
    echo "❌ AWS credentials not configured or expired."
    echo "   Run: aws configure"
    echo "   Or ensure Cloud Shell credentials are active"
    exit 1
fi

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
IMAGE_URI="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/${REPO_NAME}:${VERSION_TAG}"

echo "   ✅ AWS Account ID: $ACCOUNT_ID"
echo "   ✅ Target Image: $IMAGE_URI"

# Step 2: Setup ECR repository
echo ""
echo "📦 Step 2: Setting up ECR repository..."

# Check if repository exists
if aws ecr describe-repositories --repository-names "$REPO_NAME" --region "$REGION" >/dev/null 2>&1; then
    echo "   ✅ ECR repository '$REPO_NAME' already exists"
else
    echo "   🔄 Creating ECR repository '$REPO_NAME'..."
    aws ecr create-repository \
        --repository-name "$REPO_NAME" \
        --region "$REGION" \
        --image-scanning-configuration scanOnPush=true \
        --lifecycle-policy-text '{"rules":[{"rulePriority":1,"selection":{"tagStatus":"untagged","countType":"sinceImagePushed","countUnit":"days","countNumber":1},"action":{"type":"expire"}}]}' \
        >/dev/null
    echo "   ✅ ECR repository created successfully"
fi

# Step 3: Docker environment setup
echo ""
echo "🐳 Step 3: Setting up Docker environment..."

# Login to ECR
echo "   🔐 Logging into ECR..."
if aws ecr get-login-password --region "$REGION" | docker login --username AWS --password-stdin "${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com"; then
    echo "   ✅ ECR login successful"
else
    echo "   ❌ ECR login failed"
    exit 1
fi

# Clean Docker environment
echo "   🧹 Cleaning Docker environment..."
docker system prune -f >/dev/null 2>&1 || true

# Step 4: Build strategy with enhanced error handling
echo ""
echo "🔨 Step 4: Building container with Lambda Runtime Interface Client..."

BUILD_SUCCESS=false
BUILD_METHOD=""

# Method 1: Try multi-architecture build with buildx
if docker buildx version >/dev/null 2>&1; then
    echo "   🔄 Attempting multi-architecture build..."
    
    # Remove existing builder and create fresh one
    docker buildx rm multiarch-enhanced 2>/dev/null || true
    
    if docker buildx create --name multiarch-enhanced --driver docker-container --use >/dev/null 2>&1; then
        echo "   ✅ Multi-arch builder created"
        
        # Try multi-arch build with retry
        for attempt in 1 2; do
            echo "   🔄 Multi-arch build attempt $attempt..."
            
            if docker buildx build \
                --platform linux/amd64,linux/arm64 \
                --tag "$IMAGE_URI" \
                --file Dockerfile \
                --push \
                --cache-from type=registry,ref="${IMAGE_URI}-cache" \
                --cache-to type=registry,ref="${IMAGE_URI}-cache",mode=max \
                . 2>/dev/null; then
                
                echo "   ✅ Multi-architecture build successful"
                BUILD_SUCCESS=true
                BUILD_METHOD="multi-arch"
                break
            else
                echo "   ⚠️  Multi-arch attempt $attempt failed"
                if [ $attempt -eq 2 ]; then
                    echo "   🔄 Falling back to single architecture..."
                fi
            fi
        done
    else
        echo "   ⚠️  Failed to create multi-arch builder"
    fi
fi

# Method 2: Single architecture fallback (x86_64)
if [ "$BUILD_SUCCESS" = false ]; then
    echo "   🔄 Single architecture build (x86_64)..."
    
    if docker buildx build \
        --platform linux/amd64 \
        --tag "$IMAGE_URI" \
        --file Dockerfile \
        --push \
        . ; then
        
        echo "   ✅ Single architecture build successful"
        BUILD_SUCCESS=true
        BUILD_METHOD="single-arch-x86_64"
    fi
fi

# Method 3: Legacy Docker build (last resort)
if [ "$BUILD_SUCCESS" = false ]; then
    echo "   🔄 Legacy Docker build (last resort)..."
    
    export DOCKER_BUILDKIT=0
    
    if docker build --no-cache --tag "$IMAGE_URI" --file Dockerfile . ; then
        echo "   ✅ Legacy build successful"
        
        if docker push "$IMAGE_URI"; then
            echo "   ✅ Image pushed successfully"
            BUILD_SUCCESS=true
            BUILD_METHOD="legacy"
        else
            echo "   ❌ Failed to push image"
        fi
    fi
fi

# Verify build success
if [ "$BUILD_SUCCESS" = false ]; then
    echo ""
    echo "❌ All build methods failed!"
    echo "   Please check:"
    echo "   - Docker daemon is running"
    echo "   - ECR permissions are correct"
    echo "   - Network connectivity is stable"
    exit 1
fi

# Step 5: Post-build validation
echo ""
echo "🔍 Step 5: Validating container image..."

# Check image exists in ECR
if aws ecr describe-images \
    --repository-name "$REPO_NAME" \
    --image-ids imageTag="$VERSION_TAG" \
    --region "$REGION" >/dev/null 2>&1; then
    echo "   ✅ Image successfully pushed to ECR"
else
    echo "   ❌ Image validation failed"
    exit 1
fi

# Get image details
IMAGE_DETAILS=$(aws ecr describe-images \
    --repository-name "$REPO_NAME" \
    --image-ids imageTag="$VERSION_TAG" \
    --region "$REGION" \
    --query 'imageDetails[0]' 2>/dev/null)

if [ -n "$IMAGE_DETAILS" ]; then
    echo "   ✅ Image size: $(echo "$IMAGE_DETAILS" | jq -r '.imageSizeInBytes // "unknown"' | numfmt --to=iec 2>/dev/null || echo "unknown")"
    echo "   ✅ Push date: $(echo "$IMAGE_DETAILS" | jq -r '.imagePushedAt // "unknown"')"
fi

# Step 6: Agent Core Runtime configuration guidance
echo ""
echo "🎉 Deployment Successful!"
echo ""
echo "📋 Container Details:"
echo "   Repository: $REPO_NAME"
echo "   Tag: $VERSION_TAG"
echo "   URI: $IMAGE_URI"
echo "   Build Method: $BUILD_METHOD"
echo "   Runtime: AWS Lambda Container Runtime"
echo "   Handler: lambda_handler.lambda_handler"
echo ""
echo "🤖 Agent Core Runtime Configuration:"
echo "   1. Image URI: $IMAGE_URI"
echo "   2. Entry Point: lambda_handler.lambda_handler"
echo "   3. Memory: 512 MB (minimum recommended)"
echo "   4. Timeout: 30 seconds (recommended)"
echo ""
echo "🧪 Testing Instructions:"
echo "   Input format: {\"domain\": \"google.com\"}"
echo "   Expected output: JSON with 'statusCode': 200 and DNS records"
echo ""
echo "   Test domains:"
echo "   - {\"domain\": \"google.com\"}"
echo "   - {\"domain\": \"aws.amazon.com\"}"
echo "   - {\"domain\": \"github.com\"}"
echo ""
echo "🔧 Troubleshooting:"
echo "   - If endpoint fails: Check CloudWatch logs for detailed errors"
echo "   - If timeout: Increase memory allocation or timeout settings"
echo "   - If DNS fails: Verify Route53 permissions and cross-account roles"
echo ""
echo "✅ Your DNS lookup service is ready for Agent Core Runtime!"

# Cleanup
docker buildx rm multiarch-enhanced 2>/dev/null || true