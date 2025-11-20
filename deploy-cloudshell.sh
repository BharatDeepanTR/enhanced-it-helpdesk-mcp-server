#!/bin/bash
set -euo pipefail

# Enhanced ECR deployment script optimized for Cloud Shell temporary authentication
# This script works with temporary AWS credentials from Cloud Shell

AWS_REGION="${AWS_REGION:-us-east-1}"
ECR_REPO="${ECR_REPO:-dns-lookup-service}"
IMAGE_TAG="${1:-latest}"

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

echo "=============================================="
echo "DNS Lookup Service - Cloud Shell ECR Deployment"
echo "=============================================="
echo "Region: $AWS_REGION"
echo "Repository: $ECR_REPO"
echo "Tag: $IMAGE_TAG"
echo "=============================================="

# Function to check AWS credentials
check_aws_credentials() {
    log_info "Checking AWS credentials..."
    
    if ! command -v aws &>/dev/null; then
        log_error "AWS CLI not found. Installing..."
        install_aws_cli
    fi
    
    # Check if we can access AWS
    if ! aws sts get-caller-identity &>/dev/null; then
        log_error "AWS credentials not configured or expired"
        log_info "Please configure AWS credentials using one of these methods:"
        echo ""
        echo "Option 1: Temporary credentials (recommended for Cloud Shell)"
        echo "  export AWS_ACCESS_KEY_ID=ASIA..."
        echo "  export AWS_SECRET_ACCESS_KEY=..."
        echo "  export AWS_SESSION_TOKEN=..."
        echo ""
        echo "Option 2: Permanent credentials"
        echo "  export AWS_ACCESS_KEY_ID=AKIA..."
        echo "  export AWS_SECRET_ACCESS_KEY=..."
        echo ""
        echo "Option 3: AWS CLI configure"
        echo "  aws configure"
        echo ""
        exit 1
    fi
    
    # Get account info
    AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    USER_ARN=$(aws sts get-caller-identity --query Arn --output text)
    
    log_success "AWS credentials valid"
    log_info "Account ID: $AWS_ACCOUNT_ID"
    log_info "User/Role: $USER_ARN"
    
    # Check if using temporary credentials
    if [[ "$USER_ARN" == *"assumed-role"* ]] || [[ -n "${AWS_SESSION_TOKEN:-}" ]]; then
        log_info "Using temporary credentials (good for Cloud Shell)"
        
        # Check token expiration if available
        if command -v jq &>/dev/null && [[ -n "${AWS_SESSION_TOKEN:-}" ]]; then
            # Try to decode the token to check expiration (this is approximate)
            log_warning "Remember that temporary credentials expire - complete deployment promptly"
        fi
    else
        log_info "Using permanent credentials"
    fi
}

# Function to install AWS CLI
install_aws_cli() {
    log_info "Installing AWS CLI v2..."
    
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        curl -s "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
        unzip -q awscliv2.zip
        sudo ./aws/install --update
        rm -rf aws awscliv2.zip
        log_success "AWS CLI installed"
    else
        log_error "Unsupported OS for automatic AWS CLI installation"
        exit 1
    fi
}

# Function to create ECR repository
create_ecr_repository() {
    log_info "Setting up ECR repository..."
    
    if aws ecr describe-repositories --repository-names "$ECR_REPO" --region "$AWS_REGION" &>/dev/null; then
        log_info "ECR repository '$ECR_REPO' already exists"
    else
        log_info "Creating ECR repository '$ECR_REPO'..."
        
        aws ecr create-repository \
            --repository-name "$ECR_REPO" \
            --region "$AWS_REGION" \
            --image-scanning-configuration scanOnPush=true \
            --encryption-configuration encryptionType=AES256 \
            --image-tag-mutability MUTABLE
        
        log_success "ECR repository created with security features enabled"
        
        # Set lifecycle policy to manage costs
        log_info "Setting lifecycle policy..."
        cat > lifecycle-policy.json << 'POLICY_EOF'
{
    "rules": [
        {
            "rulePriority": 1,
            "description": "Keep last 10 production images",
            "selection": {
                "tagStatus": "tagged",
                "tagPrefixList": ["v"],
                "countType": "imageCountMoreThan",
                "countNumber": 10
            },
            "action": {
                "type": "expire"
            }
        },
        {
            "rulePriority": 2,
            "description": "Keep last 5 latest images",
            "selection": {
                "tagStatus": "tagged",
                "tagPrefixList": ["latest"],
                "countType": "imageCountMoreThan",
                "countNumber": 5
            },
            "action": {
                "type": "expire"
            }
        },
        {
            "rulePriority": 3,
            "description": "Delete untagged images older than 1 day",
            "selection": {
                "tagStatus": "untagged",
                "countType": "sinceImagePushed",
                "countUnit": "days",
                "countNumber": 1
            },
            "action": {
                "type": "expire"
            }
        }
    ]
}
POLICY_EOF
        
        aws ecr put-lifecycle-policy \
            --repository-name "$ECR_REPO" \
            --region "$AWS_REGION" \
            --lifecycle-policy-text file://lifecycle-policy.json
        
        rm lifecycle-policy.json
        log_success "Lifecycle policy applied for cost optimization"
    fi
}

# Function to authenticate Docker with ECR
authenticate_docker() {
    log_info "Authenticating Docker with ECR..."
    
    # Get ECR login token and authenticate
    aws ecr get-login-password --region "$AWS_REGION" | \
        docker login --username AWS --password-stdin "$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com"
    
    log_success "Docker authenticated with ECR"
}

# Function to build and push image
build_and_push() {
    local ecr_uri="$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPO"
    
    log_info "Building and pushing Docker image..."
    log_info "Target URI: $ecr_uri:$IMAGE_TAG"
    
    # Check if buildx is available for ARM64 builds
    if docker buildx version &>/dev/null; then
        log_info "Using Docker Buildx for ARM64 build..."
        
        # Create builder if it doesn't exist
        docker buildx create --name ecr-builder --use --bootstrap 2>/dev/null || \
        docker buildx use ecr-builder 2>/dev/null || \
        docker buildx use default
        
        # Build and push ARM64 image
        docker buildx build \
            --platform linux/arm64 \
            --tag "$ecr_uri:$IMAGE_TAG" \
            --tag "$ecr_uri:latest" \
            --push \
            --progress=plain \
            .
        
        log_success "ARM64 image built and pushed using buildx"
    else
        log_warning "Docker Buildx not available, using regular build"
        log_info "Note: This will build for the current platform (likely x86_64)"
        
        # Regular build
        docker build -t "$ecr_uri:$IMAGE_TAG" .
        docker tag "$ecr_uri:$IMAGE_TAG" "$ecr_uri:latest"
        
        # Push images
        log_info "Pushing images to ECR..."
        docker push "$ecr_uri:$IMAGE_TAG"
        docker push "$ecr_uri:latest"
        
        log_success "Images pushed to ECR"
    fi
    
    # Save image URIs
    echo "$ecr_uri:$IMAGE_TAG" > .ecr-image-uri
    echo "$ecr_uri:latest" > .ecr-image-latest
    
    log_success "Image URIs saved to files"
}

# Function to initiate vulnerability scan
start_vulnerability_scan() {
    log_info "Initiating ECR vulnerability scan..."
    
    # Start the scan
    if aws ecr start-image-scan \
        --repository-name "$ECR_REPO" \
        --image-id imageTag="$IMAGE_TAG" \
        --region "$AWS_REGION" 2>/dev/null; then
        
        log_success "Vulnerability scan started"
        log_info "Scan results will be available in a few minutes"
        
        # Provide command to check results later
        echo ""
        log_info "To check scan results later, run:"
        echo "aws ecr describe-image-scan-findings --repository-name $ECR_REPO --image-id imageTag=$IMAGE_TAG --region $AWS_REGION"
    else
        log_warning "Could not start vulnerability scan (may already be running)"
    fi
}

# Function to display deployment information
show_deployment_info() {
    local ecr_uri="$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPO"
    
    echo ""
    echo "=============================================="
    echo "🎉 DEPLOYMENT COMPLETED SUCCESSFULLY!"
    echo "=============================================="
    echo ""
    echo "📋 Deployment Details:"
    echo "  Repository: $ECR_REPO"
    echo "  Region: $AWS_REGION"
    echo "  Account: $AWS_ACCOUNT_ID"
    echo "  Tag: $IMAGE_TAG"
    echo ""
    echo "🔗 Image URIs:"
    echo "  Tagged: $ecr_uri:$IMAGE_TAG"
    echo "  Latest: $ecr_uri:latest"
    echo ""
    echo "📁 Generated Files:"
    echo "  .ecr-image-uri     - Tagged image URI"
    echo "  .ecr-image-latest  - Latest image URI"
    echo ""
    echo "🧪 Test Commands:"
    echo "  # Run locally"
    echo "  docker run -p 8080:8080 $ecr_uri:$IMAGE_TAG"
    echo ""
    echo "  # Test health endpoint"
    echo "  curl http://localhost:8080/health"
    echo ""
    echo "  # Test DNS lookup"
    echo "  curl -X POST http://localhost:8080/lookup \\"
    echo "    -H 'Content-Type: application/json' \\"
    echo "    -d '{\"dns_name\": \"example.com\"}'"
    echo ""
    echo "🚀 Deploy to AWS Services:"
    echo "  # AWS Lambda (Container)"
    echo "  aws lambda create-function \\"
    echo "    --function-name dns-lookup-service \\"
    echo "    --package-type Image \\"
    echo "    --code ImageUri=$ecr_uri:$IMAGE_TAG \\"
    echo "    --role arn:aws:iam::$AWS_ACCOUNT_ID:role/lambda-execution-role \\"
    echo "    --timeout 300 --memory-size 512 \\"
    echo "    --architectures arm64"
    echo ""
    echo "  # ECS Task Definition (save image URI for your task definition)"
    echo "  echo 'Use: $ecr_uri:$IMAGE_TAG in your ECS task definition'"
    echo ""
    echo "🔍 Monitor:"
    echo "  # Check vulnerability scan results"
    echo "  aws ecr describe-image-scan-findings \\"
    echo "    --repository-name $ECR_REPO \\"
    echo "    --image-id imageTag=$IMAGE_TAG \\"
    echo "    --region $AWS_REGION"
    echo ""
    echo "  # List all images in repository"
    echo "  aws ecr describe-images --repository-name $ECR_REPO --region $AWS_REGION"
    echo ""
    echo "=============================================="
}

# Function to handle cleanup on exit
cleanup() {
    log_info "Cleaning up temporary files..."
    rm -f lifecycle-policy.json awscliv2.zip 2>/dev/null || true
}

# Set trap for cleanup
trap cleanup EXIT

# Main execution
main() {
    check_aws_credentials
    create_ecr_repository
    authenticate_docker
    build_and_push
    start_vulnerability_scan
    show_deployment_info
    
    log_success "All done! Your DNS lookup service is now in ECR and ready for deployment."
}

# Show usage if help requested
if [[ "${1:-}" == "-h" ]] || [[ "${1:-}" == "--help" ]]; then
    echo "Usage: $0 [IMAGE_TAG]"
    echo ""
    echo "Environment Variables:"
    echo "  AWS_REGION           - AWS region (default: us-east-1)"
    echo "  ECR_REPO            - ECR repository name (default: dns-lookup-service)"
    echo "  AWS_ACCESS_KEY_ID   - AWS access key"
    echo "  AWS_SECRET_ACCESS_KEY - AWS secret key"
    echo "  AWS_SESSION_TOKEN   - AWS session token (for temporary credentials)"
    echo ""
    echo "Examples:"
    echo "  $0                  # Deploy with 'latest' tag"
    echo "  $0 v1.0.0          # Deploy with 'v1.0.0' tag"
    echo "  AWS_REGION=eu-west-1 $0 v1.0.0  # Deploy to different region"
    echo ""
    echo "For Cloud Shell temporary credentials:"
    echo "  export AWS_ACCESS_KEY_ID=ASIA..."
    echo "  export AWS_SECRET_ACCESS_KEY=..."
    echo "  export AWS_SESSION_TOKEN=..."
    echo "  $0 v1.0.0"
    exit 0
fi

# Run main function
main "$@"