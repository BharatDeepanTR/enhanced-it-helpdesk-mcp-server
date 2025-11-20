#!/bin/bash
set -euo pipefail

# Create deployment package for Cloud Shell ECR deployment
# This script packages only the essential files needed for ECR deployment

PACKAGE_NAME="dns-lookup-ecr-deployment"
PACKAGE_VERSION="1.0.0"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
PACKAGE_FILE="${PACKAGE_NAME}-${PACKAGE_VERSION}-${TIMESTAMP}.tar.gz"

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }

log_info "Creating deployment package for Cloud Shell..."

# Create temporary directory for packaging
TEMP_DIR=$(mktemp -d)
PACKAGE_DIR="$TEMP_DIR/$PACKAGE_NAME"
mkdir -p "$PACKAGE_DIR"

log_info "Copying essential files..."

# Core application files
cp chatops_route_dns_intent.py "$PACKAGE_DIR/"
cp chatops_helpers.py "$PACKAGE_DIR/"
cp chatops_config.py "$PACKAGE_DIR/"
cp container_handler.py "$PACKAGE_DIR/"

# Docker and deployment files
cp Dockerfile "$PACKAGE_DIR/"
cp requirements.txt "$PACKAGE_DIR/"
cp requirements-security.txt "$PACKAGE_DIR/"
cp .dockerignore "$PACKAGE_DIR/"
cp function.txt "$PACKAGE_DIR/"

# Deployment scripts
cp deploy-ecr.sh "$PACKAGE_DIR/"
cp build-secure.sh "$PACKAGE_DIR/"

# Make scripts executable
chmod +x "$PACKAGE_DIR/deploy-ecr.sh"
chmod +x "$PACKAGE_DIR/build-secure.sh"

# Create a simplified Cloud Shell deployment script
cat > "$PACKAGE_DIR/cloudshell-deploy.sh" << 'EOF'
#!/bin/bash
set -euo pipefail

# Cloud Shell ECR Deployment Script
# This script is optimized for Google Cloud Shell environment

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Default configuration
AWS_REGION="${AWS_REGION:-us-east-1}"
ECR_REPOSITORY_NAME="${ECR_REPOSITORY_NAME:-dns-lookup-service}"
IMAGE_TAG="${1:-latest}"

echo "==========================================="
echo "DNS Lookup Service - Cloud Shell Deployment"
echo "==========================================="
echo "Region: $AWS_REGION"
echo "Repository: $ECR_REPOSITORY_NAME"
echo "Tag: $IMAGE_TAG"
echo "==========================================="

# Function to install AWS CLI if not present
install_aws_cli() {
    if ! command -v aws &>/dev/null; then
        log_info "Installing AWS CLI..."
        curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
        unzip -q awscliv2.zip
        sudo ./aws/install
        rm -rf aws awscliv2.zip
        log_success "AWS CLI installed"
    else
        log_info "AWS CLI already installed"
    fi
}

# Function to configure AWS credentials
configure_aws() {
    log_info "Configuring AWS credentials..."
    
    if [[ -z "${AWS_ACCESS_KEY_ID:-}" ]] || [[ -z "${AWS_SECRET_ACCESS_KEY:-}" ]]; then
        log_warning "AWS credentials not found in environment variables"
        log_info "Please set the following environment variables:"
        echo "export AWS_ACCESS_KEY_ID=your-access-key"
        echo "export AWS_SECRET_ACCESS_KEY=your-secret-key"
        echo "export AWS_DEFAULT_REGION=$AWS_REGION"
        echo ""
        log_info "Or run: aws configure"
        exit 1
    fi
    
    # Test AWS credentials
    if aws sts get-caller-identity &>/dev/null; then
        AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
        log_success "AWS credentials valid. Account ID: $AWS_ACCOUNT_ID"
    else
        log_error "AWS credentials invalid or not configured"
        exit 1
    fi
}

# Function to install Trivy for security scanning
install_trivy() {
    if ! command -v trivy &>/dev/null; then
        log_info "Installing Trivy for vulnerability scanning..."
        curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b /usr/local/bin
        log_success "Trivy installed"
    else
        log_info "Trivy already installed"
    fi
}

# Function to create ECR repository
create_ecr_repository() {
    log_info "Creating ECR repository if it doesn't exist..."
    
    if aws ecr describe-repositories --repository-names "$ECR_REPOSITORY_NAME" --region "$AWS_REGION" &>/dev/null; then
        log_info "ECR repository '$ECR_REPOSITORY_NAME' already exists"
    else
        log_info "Creating ECR repository '$ECR_REPOSITORY_NAME'..."
        aws ecr create-repository \
            --repository-name "$ECR_REPOSITORY_NAME" \
            --region "$AWS_REGION" \
            --image-scanning-configuration scanOnPush=true \
            --encryption-configuration encryptionType=AES256
        log_success "ECR repository created"
    fi
}

# Function to build and push Docker image
build_and_push() {
    local ecr_uri="$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPOSITORY_NAME"
    
    log_info "Authenticating Docker with ECR..."
    aws ecr get-login-password --region "$AWS_REGION" | \
        docker login --username AWS --password-stdin "$ecr_uri"
    
    log_info "Building Docker image..."
    
    # Build for ARM64 (or x86_64 if ARM64 not available)
    if docker buildx version &>/dev/null; then
        # Use buildx for multi-platform builds
        docker buildx create --name ecr-builder --use --bootstrap 2>/dev/null || docker buildx use ecr-builder
        
        PLATFORM="linux/arm64"
        log_info "Building for ARM64 using buildx..."
        
        docker buildx build \
            --platform "$PLATFORM" \
            --tag "$ecr_uri:$IMAGE_TAG" \
            --tag "$ecr_uri:latest" \
            --push \
            .
    else
        # Fallback to regular docker build
        log_warning "Docker buildx not available, using regular build (x86_64)"
        
        docker build -t "$ecr_uri:$IMAGE_TAG" .
        docker tag "$ecr_uri:$IMAGE_TAG" "$ecr_uri:latest"
        
        log_info "Pushing images to ECR..."
        docker push "$ecr_uri:$IMAGE_TAG"
        docker push "$ecr_uri:latest"
    fi
    
    log_success "Image pushed to ECR: $ecr_uri:$IMAGE_TAG"
    
    # Save image URI
    echo "$ecr_uri:$IMAGE_TAG" > .ecr-image-uri
    echo "$ecr_uri:latest" > .ecr-image-latest
}

# Function to run vulnerability scan
run_scan() {
    log_info "Starting ECR vulnerability scan..."
    
    aws ecr start-image-scan \
        --repository-name "$ECR_REPOSITORY_NAME" \
        --image-id imageTag="$IMAGE_TAG" \
        --region "$AWS_REGION" || log_warning "Scan may already be in progress"
    
    log_info "Vulnerability scan initiated. Check results with:"
    echo "aws ecr describe-image-scan-findings --repository-name $ECR_REPOSITORY_NAME --image-id imageTag=$IMAGE_TAG --region $AWS_REGION"
}

# Function to create deployment files
create_deployment_files() {
    local ecr_uri="$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPOSITORY_NAME:$IMAGE_TAG"
    
    log_info "Creating deployment files..."
    
    # ECS Task Definition
    cat > ecs-task-definition.json << EOF
{
  "family": "dns-lookup-service",
  "networkMode": "awsvpc",
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "512",
  "memory": "1024",
  "executionRoleArn": "arn:aws:iam::${AWS_ACCOUNT_ID}:role/ecsTaskExecutionRole",
  "runtimePlatform": {
    "cpuArchitecture": "ARM64",
    "operatingSystemFamily": "LINUX"
  },
  "containerDefinitions": [
    {
      "name": "dns-lookup-container",
      "image": "${ecr_uri}",
      "cpu": 512,
      "memory": 1024,
      "essential": true,
      "portMappings": [
        {
          "containerPort": 8080,
          "protocol": "tcp"
        }
      ],
      "environment": [
        {
          "name": "ENV",
          "value": "production"
        },
        {
          "name": "APP_CONFIG_PATH",
          "value": "/config"
        }
      ],
      "healthCheck": {
        "command": [
          "CMD-SHELL",
          "curl -f http://localhost:8080/health || exit 1"
        ],
        "interval": 30,
        "timeout": 5,
        "retries": 3
      },
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "/ecs/dns-lookup-service",
          "awslogs-region": "${AWS_REGION}",
          "awslogs-stream-prefix": "ecs",
          "awslogs-create-group": "true"
        }
      }
    }
  ]
}
EOF

    # Kubernetes Deployment
    cat > k8s-deployment.yaml << EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: dns-lookup-service
spec:
  replicas: 3
  selector:
    matchLabels:
      app: dns-lookup-service
  template:
    metadata:
      labels:
        app: dns-lookup-service
    spec:
      containers:
      - name: dns-lookup
        image: ${ecr_uri}
        ports:
        - containerPort: 8080
        resources:
          requests:
            memory: "256Mi"
            cpu: "100m"
          limits:
            memory: "512Mi"
            cpu: "500m"
        livenessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 5
          periodSeconds: 5
EOF

    log_success "Deployment files created:"
    log_info "- ecs-task-definition.json"
    log_info "- k8s-deployment.yaml"
}

# Function to show next steps
show_next_steps() {
    log_info "Deployment completed successfully!"
    echo ""
    echo "Image URIs:"
    echo "- Tagged: $(cat .ecr-image-uri)"
    echo "- Latest: $(cat .ecr-image-latest)"
    echo ""
    echo "Next steps:"
    echo "1. Test the image:"
    echo "   docker run -p 8080:8080 \$(cat .ecr-image-uri)"
    echo ""
    echo "2. Deploy to ECS:"
    echo "   aws ecs register-task-definition --cli-input-json file://ecs-task-definition.json"
    echo ""
    echo "3. Deploy to Kubernetes:"
    echo "   kubectl apply -f k8s-deployment.yaml"
    echo ""
    echo "4. Check vulnerability scan:"
    echo "   aws ecr describe-image-scan-findings --repository-name $ECR_REPOSITORY_NAME --image-id imageTag=$IMAGE_TAG --region $AWS_REGION"
}

# Main execution
main() {
    install_aws_cli
    configure_aws
    install_trivy
    create_ecr_repository
    build_and_push
    run_scan
    create_deployment_files
    show_next_steps
}

# Show usage
if [[ "${1:-}" == "-h" ]] || [[ "${1:-}" == "--help" ]]; then
    echo "Usage: $0 [IMAGE_TAG]"
    echo ""
    echo "Environment Variables:"
    echo "  AWS_ACCESS_KEY_ID      - Your AWS access key"
    echo "  AWS_SECRET_ACCESS_KEY  - Your AWS secret key"
    echo "  AWS_REGION            - AWS region (default: us-east-1)"
    echo "  ECR_REPOSITORY_NAME   - ECR repository name (default: dns-lookup-service)"
    echo ""
    echo "Example:"
    echo "  export AWS_ACCESS_KEY_ID=AKIA..."
    echo "  export AWS_SECRET_ACCESS_KEY=..."
    echo "  ./cloudshell-deploy.sh v1.0.0"
    exit 0
fi

# Run main function
main "$@"
EOF

chmod +x "$PACKAGE_DIR/cloudshell-deploy.sh"

# Create README for Cloud Shell deployment
cat > "$PACKAGE_DIR/README-CloudShell.md" << 'EOF'
# DNS Lookup Service - Cloud Shell Deployment

## Quick Start in Google Cloud Shell

### 1. Upload and Extract
```bash
# Upload the tar.gz file to Cloud Shell, then:
tar -xzf dns-lookup-ecr-deployment-*.tar.gz
cd dns-lookup-ecr-deployment*
```

### 2. Configure AWS Credentials
```bash
# Option 1: Set environment variables
export AWS_ACCESS_KEY_ID=your-access-key-id
export AWS_SECRET_ACCESS_KEY=your-secret-access-key
export AWS_DEFAULT_REGION=us-east-1

# Option 2: Use AWS CLI configure
aws configure
```

### 3. Deploy to ECR
```bash
# Deploy with latest tag
./cloudshell-deploy.sh

# Deploy with specific version
./cloudshell-deploy.sh v1.0.0

# Deploy to different region
AWS_REGION=eu-west-1 ./cloudshell-deploy.sh v1.0.0
```

### 4. Test the Deployment
```bash
# Test locally in Cloud Shell
docker run -p 8080:8080 $(cat .ecr-image-uri)

# In another terminal:
curl http://localhost:8080/health
```

## What This Package Contains

- **Application Files**: Python lambda code adapted for containers
- **Docker Files**: Secure Dockerfile and dependencies
- **Deployment Scripts**: Automated ECR deployment
- **Security**: Vulnerability scanning and security hardening

## Generated Files After Deployment

- `.ecr-image-uri` - ECR image URI with your tag
- `.ecr-image-latest` - ECR image URI with latest tag
- `ecs-task-definition.json` - Ready-to-use ECS task definition
- `k8s-deployment.yaml` - Ready-to-use Kubernetes deployment

## Troubleshooting

### AWS CLI Not Found
```bash
# Install AWS CLI in Cloud Shell
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
```

### Docker Permission Issues
```bash
# Add user to docker group (if needed)
sudo usermod -aG docker $USER
newgrp docker
```

### ECR Authentication Issues
```bash
# Re-authenticate with ECR
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin YOUR_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com
```

## Architecture Support

The deployment script automatically detects the platform:
- **ARM64**: Preferred for AWS Graviton2 instances
- **x86_64**: Fallback for standard instances

Both architectures are supported by the application.
EOF

# Create a simplified deployment guide
cat > "$PACKAGE_DIR/DEPLOYMENT-STEPS.md" << 'EOF'
# Step-by-Step Deployment Guide

## Prerequisites
- Google Cloud Shell (or any Linux environment with Docker)
- AWS Account with ECR permissions
- AWS Access Keys

## Step 1: Prepare Environment
```bash
# In Cloud Shell, upload the package and extract
tar -xzf dns-lookup-ecr-deployment-*.tar.gz
cd dns-lookup-ecr-deployment*
```

## Step 2: Set AWS Credentials
```bash
export AWS_ACCESS_KEY_ID=AKIA...
export AWS_SECRET_ACCESS_KEY=...
export AWS_DEFAULT_REGION=us-east-1
```

## Step 3: Deploy
```bash
./cloudshell-deploy.sh v1.0.0
```

## Step 4: Verify
```bash
# Check ECR repository
aws ecr describe-repositories --repository-names dns-lookup-service

# Check images
aws ecr describe-images --repository-name dns-lookup-service

# Test locally
docker run -p 8080:8080 $(cat .ecr-image-uri)
curl http://localhost:8080/health
```

## Step 5: Deploy to AWS Service

### For ECS:
```bash
aws ecs register-task-definition --cli-input-json file://ecs-task-definition.json
```

### For Kubernetes:
```bash
kubectl apply -f k8s-deployment.yaml
```

### For Lambda:
```bash
aws lambda create-function \
    --function-name dns-lookup-service \
    --package-type Image \
    --code ImageUri=$(cat .ecr-image-uri) \
    --role arn:aws:iam::ACCOUNT:role/lambda-execution-role
```

That's it! Your DNS lookup service is now in ECR and ready for deployment.
EOF

# Copy documentation files
cp ECR_DEPLOYMENT_GUIDE.md "$PACKAGE_DIR/" 2>/dev/null || log_warning "ECR deployment guide not found"
cp MIGRATION_SUMMARY.md "$PACKAGE_DIR/" 2>/dev/null || log_warning "Migration summary not found"

log_info "Creating compressed package..."

# Create the tar.gz package
cd "$TEMP_DIR"
tar -czf "$PACKAGE_FILE" "$PACKAGE_NAME"

# Move to current directory
mv "$PACKAGE_FILE" "$OLDPWD/"

# Cleanup
rm -rf "$TEMP_DIR"

log_success "Package created: $PACKAGE_FILE"

# Show package contents
echo ""
log_info "Package contents:"
tar -tzf "$PACKAGE_FILE" | sed 's/^/  /'

echo ""
log_info "Package size: $(du -h "$PACKAGE_FILE" | cut -f1)"

echo ""
log_success "Ready for Cloud Shell deployment!"
echo ""
echo "Next steps:"
echo "1. Upload '$PACKAGE_FILE' to Google Cloud Shell"
echo "2. Extract: tar -xzf $PACKAGE_FILE"
echo "3. Navigate: cd ${PACKAGE_NAME}"
echo "4. Set AWS credentials and run: ./cloudshell-deploy.sh v1.0.0"
echo ""
echo "The package includes:"
echo "  ✓ Complete application code"
echo "  ✓ Secure Dockerfile for ARM64"
echo "  ✓ Automated ECR deployment script"
echo "  ✓ Security scanning integration"
echo "  ✓ Ready-to-use deployment manifests"
echo "  ✓ Comprehensive documentation"