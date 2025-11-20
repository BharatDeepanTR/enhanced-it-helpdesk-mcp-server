#!/bin/bash
set -euo pipefail

# Create minimal deployment package for Cloud Shell ECR deployment
# Contains only essential files for ARM64 Docker image without Lex

PACKAGE_NAME="dns-lookup-arm64-minimal"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
PACKAGE_FILE="${PACKAGE_NAME}-${TIMESTAMP}.tar.gz"

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }

log_info "Creating minimal ARM64 deployment package..."

# Create temporary directory
TEMP_DIR=$(mktemp -d)
PACKAGE_DIR="$TEMP_DIR/$PACKAGE_NAME"
mkdir -p "$PACKAGE_DIR"

log_info "Copying essential files only..."

# Core Python files (without Lex)
cp chatops_route_dns_intent.py "$PACKAGE_DIR/"
cp chatops_helpers.py "$PACKAGE_DIR/"
cp chatops_config.py "$PACKAGE_DIR/"
cp container_handler.py "$PACKAGE_DIR/"

# Docker essentials
cp Dockerfile "$PACKAGE_DIR/"
cp requirements.txt "$PACKAGE_DIR/"
cp .dockerignore "$PACKAGE_DIR/"
cp function.txt "$PACKAGE_DIR/"

# Create simple Cloud Shell ECR deployment script
cat > "$PACKAGE_DIR/deploy.sh" << 'EOF'
#!/bin/bash
set -euo pipefail

# Simple ECR deployment for Cloud Shell
AWS_REGION="${AWS_REGION:-us-east-1}"
ECR_REPO="${ECR_REPO:-dns-lookup-service}"
IMAGE_TAG="${1:-latest}"

echo "Deploying to ECR: $ECR_REPO:$IMAGE_TAG in $AWS_REGION"

# Get AWS Account ID
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ECR_URI="$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPO"

# Create repository if it doesn't exist
aws ecr describe-repositories --repository-names "$ECR_REPO" --region "$AWS_REGION" 2>/dev/null || \
aws ecr create-repository --repository-name "$ECR_REPO" --region "$AWS_REGION" --image-scanning-configuration scanOnPush=true

# Login to ECR
aws ecr get-login-password --region "$AWS_REGION" | docker login --username AWS --password-stdin "$ECR_URI"

# Build and push ARM64 image
if docker buildx version &>/dev/null; then
    echo "Building ARM64 image with buildx..."
    docker buildx create --name arm64-builder --use --bootstrap 2>/dev/null || docker buildx use arm64-builder
    docker buildx build --platform linux/arm64 --tag "$ECR_URI:$IMAGE_TAG" --tag "$ECR_URI:latest" --push .
else
    echo "Building with regular docker (current platform)..."
    docker build -t "$ECR_URI:$IMAGE_TAG" .
    docker tag "$ECR_URI:$IMAGE_TAG" "$ECR_URI:latest"
    docker push "$ECR_URI:$IMAGE_TAG"
    docker push "$ECR_URI:latest"
fi

echo "Successfully deployed: $ECR_URI:$IMAGE_TAG"
echo "$ECR_URI:$IMAGE_TAG" > .ecr-image-uri

# Start vulnerability scan
aws ecr start-image-scan --repository-name "$ECR_REPO" --image-id imageTag="$IMAGE_TAG" --region "$AWS_REGION" 2>/dev/null || echo "Scan may already be running"

echo ""
echo "Image URI: $ECR_URI:$IMAGE_TAG"
echo "Test locally: docker run -p 8080:8080 $ECR_URI:$IMAGE_TAG"
EOF

chmod +x "$PACKAGE_DIR/deploy.sh"

# Create minimal README
cat > "$PACKAGE_DIR/README.md" << 'EOF'
# DNS Lookup Service - ARM64 Docker Deployment

## Quick Start in Cloud Shell

### 1. Extract Package
```bash
tar -xzf dns-lookup-arm64-minimal-*.tar.gz
cd dns-lookup-arm64-minimal
```

### 2. Configure AWS
```bash
export AWS_ACCESS_KEY_ID=your-access-key
export AWS_SECRET_ACCESS_KEY=your-secret-key
export AWS_DEFAULT_REGION=us-east-1
```

### 3. Deploy to ECR
```bash
./deploy.sh v1.0.0
```

## Files Included
- `chatops_route_dns_intent.py` - Main lambda function (Lex removed)
- `chatops_helpers.py` - Helper functions
- `chatops_config.py` - Configuration
- `container_handler.py` - HTTP server for containerized execution
- `Dockerfile` - Secure ARM64 multi-stage build
- `requirements.txt` - Python dependencies
- `.dockerignore` - Security-focused ignore patterns
- `function.txt` - GenAI configuration
- `deploy.sh` - Simple ECR deployment script

## Features
✅ Lex functionality completely removed
✅ ARM64 optimized Docker image
✅ Non-root execution (UID: 10001)
✅ Security hardened container
✅ Automatic ECR vulnerability scanning
✅ Multi-stage build for minimal size

## Testing
```bash
# Run locally
docker run -p 8080:8080 $(cat .ecr-image-uri)

# Test endpoints
curl http://localhost:8080/health
curl -X POST http://localhost:8080/lookup -H "Content-Type: application/json" -d '{"dns_name": "example.com"}'
```

## Environment Variables for Container
- `ENV=production`
- `APP_CONFIG_PATH=/config`
- `HOST=0.0.0.0`
- `PORT=8080`

The image is ready for deployment on:
- AWS ECS Fargate (ARM64)
- AWS Lambda (Container)
- Kubernetes (ARM64 nodes)
- Any ARM64 container platform
EOF

log_info "Creating package..."

# Create the compressed package
cd "$TEMP_DIR"
tar -czf "$PACKAGE_FILE" "$PACKAGE_NAME"
mv "$PACKAGE_FILE" "$OLDPWD/"

# Cleanup
rm -rf "$TEMP_DIR"

log_success "Minimal package created: $PACKAGE_FILE"

echo ""
log_info "Package contents:"
tar -tzf "$PACKAGE_FILE" | sed 's/^/  /'

echo ""
log_info "Package size: $(du -h "$PACKAGE_FILE" | cut -f1)"

echo ""
echo "📦 MINIMAL PACKAGE READY FOR CLOUD SHELL"
echo "=========================================="
echo "✅ Only essential files included"
echo "✅ No Lex functionality"
echo "✅ ARM64 optimized"
echo "✅ Security hardened"
echo "✅ Simple deployment script"
echo ""
echo "Upload '$PACKAGE_FILE' to Cloud Shell and run:"
echo "1. tar -xzf $PACKAGE_FILE"
echo "2. cd $PACKAGE_NAME"
echo "3. Set AWS credentials"
echo "4. ./deploy.sh v1.0.0"