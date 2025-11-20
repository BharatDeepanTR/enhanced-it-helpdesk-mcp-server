#!/bin/bash
# Enhanced Cloud Shell deployment script for Agent Core Runtime
# Includes temporary credentials, ECR auto-creation, and comprehensive error handling

set -e

VERSION_TAG="v1.3.0"
REPO_NAME="dns-lookup-service"
REGION=${AWS_DEFAULT_REGION:-"us-east-1"}

echo "🚀 Enhanced Cloud Shell Deployment for Agent Core Runtime"
echo "========================================================"
echo ""

# Function to check AWS credentials
check_aws_credentials() {
    echo "🔍 Checking AWS credentials..."
    
    if ! aws sts get-caller-identity >/dev/null 2>&1; then
        echo "❌ AWS credentials not configured or expired"
        echo ""
        echo "📝 Cloud Shell Credential Setup:"
        echo "   1. If using temporary credentials, ensure they're exported:"
        echo "      export AWS_ACCESS_KEY_ID=your_key"
        echo "      export AWS_SECRET_ACCESS_KEY=your_secret"
        echo "      export AWS_SESSION_TOKEN=your_token"
        echo ""
        echo "   2. Or run: aws configure"
        echo "   3. Or use: aws sts assume-role (if using cross-account)"
        exit 1
    fi
    
    ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    CURRENT_USER=$(aws sts get-caller-identity --query Arn --output text)
    echo "   ✅ Authenticated as: $CURRENT_USER"
    echo "   ✅ Account ID: $ACCOUNT_ID"
}

# Function to ensure ECR repository exists
ensure_ecr_repository() {
    echo ""
    echo "🏗️  Ensuring ECR repository exists..."
    
    if aws ecr describe-repositories --repository-names $REPO_NAME --region $REGION >/dev/null 2>&1; then
        echo "   ✅ Repository '$REPO_NAME' already exists"
    else
        echo "   🔄 Creating ECR repository '$REPO_NAME'..."
        aws ecr create-repository \
            --repository-name $REPO_NAME \
            --region $REGION \
            --image-scanning-configuration scanOnPush=true \
            --encryption-configuration encryptionType=AES256 >/dev/null
        echo "   ✅ Repository created successfully"
    fi
}

# Function to setup Docker buildx for Cloud Shell
setup_docker_buildx() {
    echo ""
    echo "🔧 Setting up Docker buildx for Cloud Shell..."
    
    # Check if Docker daemon is running
    if ! docker info >/dev/null 2>&1; then
        echo "❌ Docker daemon is not running"
        echo "   Try: sudo systemctl start docker"
        exit 1
    fi
    
    # Enable Docker BuildKit
    export DOCKER_BUILDKIT=1
    export DOCKER_CLI_EXPERIMENTAL=enabled
    
    # Check buildx availability
    if docker buildx version >/dev/null 2>&1; then
        echo "   ✅ Docker buildx available"
        
        # Clean up any existing builders
        docker buildx rm cloudshell-builder 2>/dev/null || true
        
        # Create new builder for Cloud Shell
        if docker buildx create --name cloudshell-builder --driver docker-container --use >/dev/null 2>&1; then
            echo "   ✅ Cloud Shell builder created"
        else
            echo "   ⚠️  Using default builder"
        fi
    else
        echo "   ⚠️  Docker buildx not available, using legacy build"
        LEGACY_BUILD=true
    fi
}

# Start credential and environment checks
check_aws_credentials
ensure_ecr_repository
setup_docker_buildx

# Get account ID and construct image URI
IMAGE_URI="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/${REPO_NAME}:${VERSION_TAG}"

echo ""
echo "🔄 Building Agent Core Runtime Container..."
echo "   Version: $VERSION_TAG"
echo "   Image: $IMAGE_URI"
echo "   Region: $REGION"
echo ""

# ECR Login with enhanced error handling
echo "🔐 Logging into ECR..."
ECR_ENDPOINT="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com"

if aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $ECR_ENDPOINT; then
    echo "   ✅ ECR login successful"
else
    echo "❌ ECR login failed"
    echo "   Check your AWS credentials and permissions"
    echo "   Required permissions: ecr:GetAuthorizationToken, ecr:BatchCheckLayerAvailability, ecr:BatchGetImage"
    exit 1
fi

# Clean Docker environment
echo ""
echo "🧹 Cleaning Docker environment..."
docker system prune -f 2>/dev/null || true

# Enhanced multi-architecture build with Cloud Shell optimizations
if [ "$LEGACY_BUILD" = "true" ]; then
    echo ""
    echo "🔨 Building with legacy Docker (single architecture)..."
    
    docker build \
        --no-cache \
        --tag $IMAGE_URI \
        --file Dockerfile \
        .
    
    docker push $IMAGE_URI
    echo "   ✅ Legacy build and push successful"
    
else
    echo ""
    echo "🔨 Attempting multi-architecture build..."
    
    # Cloud Shell optimized multi-arch build
    MAX_RETRIES=3
    RETRY_COUNT=0
    BUILD_SUCCESS=false
    
    while [ $RETRY_COUNT -lt $MAX_RETRIES ] && [ "$BUILD_SUCCESS" = "false" ]; do
        echo "   🔄 Build attempt $((RETRY_COUNT + 1)) of $MAX_RETRIES..."
        
        if docker buildx build \
            --platform linux/amd64,linux/arm64 \
            --tag $IMAGE_URI \
            --file Dockerfile \
            --push \
            --progress=plain \
            . 2>/dev/null; then
            echo "   ✅ Multi-architecture build successful"
            BUILD_SUCCESS=true
            break
        else
            echo "   ⚠️  Multi-arch attempt $((RETRY_COUNT + 1)) failed"
            RETRY_COUNT=$((RETRY_COUNT + 1))
            
            if [ $RETRY_COUNT -lt $MAX_RETRIES ]; then
                echo "   🔄 Waiting 10 seconds before retry..."
                sleep 10
            fi
        fi
    done
    
    # Fallback to single architecture if multi-arch fails
    if [ "$BUILD_SUCCESS" = "false" ]; then
        echo ""
        echo "   🔄 Multi-arch failed, falling back to single architecture (x86_64)..."
        
        if docker buildx build \
            --platform linux/amd64 \
            --tag $IMAGE_URI \
            --file Dockerfile \
            --push \
            --progress=plain \
            . ; then
            echo "   ✅ Single architecture (x86_64) build successful"
            BUILD_SUCCESS=true
        else
            echo "❌ All build attempts failed"
            exit 1
        fi
    fi
fi

# Verify the image was pushed successfully
echo ""
echo "🔍 Verifying image in ECR..."
if aws ecr describe-images --repository-name $REPO_NAME --image-ids imageTag=$VERSION_TAG --region $REGION >/dev/null 2>&1; then
    echo "   ✅ Image successfully pushed and verified in ECR"
    
    # Get image details
    IMAGE_DETAILS=$(aws ecr describe-images --repository-name $REPO_NAME --image-ids imageTag=$VERSION_TAG --region $REGION --query 'imageDetails[0]' 2>/dev/null)
    IMAGE_SIZE=$(echo $IMAGE_DETAILS | jq -r '.imageSizeInBytes // "unknown"' 2>/dev/null || echo "unknown")
    PUSH_DATE=$(echo $IMAGE_DETAILS | jq -r '.imagePushedAt // "unknown"' 2>/dev/null || echo "unknown")
    
    echo "   📊 Image size: $IMAGE_SIZE bytes"
    echo "   � Pushed at: $PUSH_DATE"
else
    echo "❌ Image verification failed"
    echo "   Image may not have been pushed successfully"
    exit 1
fi

# Cleanup buildx builder
if [ "$LEGACY_BUILD" != "true" ]; then
    docker buildx rm cloudshell-builder 2>/dev/null || true
fi

echo ""
echo "🎉 Container Build and Deployment Successful!"
echo ""
echo "📋 Deployment Summary:"
echo "   🏷️  Repository: $REPO_NAME"
echo "   🔖 Tag: $VERSION_TAG"
echo "   🔗 URI: $IMAGE_URI"
echo "   🏗️  Architecture: Multi-platform (ARM64 + x86_64) or x86_64 fallback"
echo "   🎯 Target: AWS Bedrock Agent Core Runtime"
echo "   📍 Region: $REGION"
echo "   👤 Account: $ACCOUNT_ID"
echo ""
echo "🔄 Next Steps for Agent Core Runtime:"
echo "1. 🤖 Update your Agent Core Runtime configuration:"
echo "   Image URI: $IMAGE_URI"
echo ""
echo "2. 🧪 Test with these inputs in Agent Sandbox:"
echo '   {"domain": "google.com"}'
echo '   {"domain": "aws.amazon.com"}'
echo '   {"domain": "github.com"}'
echo ""
echo "3. 📊 Expected response format:"
echo '   {"statusCode": 200, "body": "{\"dns_records\": [...]}"}}'
echo ""
echo "💡 Troubleshooting:"
echo "   - If Agent Core Runtime shows 'Architecture incompatible', the fallback x86_64 build will work"
echo "   - Lambda handler entry point: lambda_handler.lambda_handler"
echo "   - Input format: JSON object with 'domain' key"
echo ""
echo "✅ Your DNS service is now ready for Agent Core Runtime!"