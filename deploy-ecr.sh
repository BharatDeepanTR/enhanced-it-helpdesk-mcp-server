#!/bin/bash
set -euo pipefail

# AWS ECR Deployment Script for DNS Lookup Service
# Builds secure ARM64 Docker image and pushes to AWS ECR

# Configuration
AWS_REGION="${AWS_REGION:-us-east-1}"
ECR_REPOSITORY_NAME="${ECR_REPOSITORY_NAME:-dns-lookup-service}"
IMAGE_TAG="${1:-latest}"
AWS_ACCOUNT_ID="${AWS_ACCOUNT_ID:-}"
DOCKERFILE_PATH="${DOCKERFILE_PATH:-./Dockerfile}"

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

# Function to check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check if AWS CLI is installed
    if ! command -v aws &>/dev/null; then
        log_error "AWS CLI is not installed. Please install it first:"
        log_info "https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html"
        exit 1
    fi
    
    # Check if Docker is installed
    if ! command -v docker &>/dev/null; then
        log_error "Docker is not installed. Please install Docker first."
        exit 1
    fi
    
    # Check if Docker Buildx is available
    if ! docker buildx version &>/dev/null; then
        log_error "Docker Buildx is required for multi-platform builds"
        exit 1
    fi
    
    # Check AWS credentials
    if ! aws sts get-caller-identity &>/dev/null; then
        log_error "AWS credentials not configured. Please run 'aws configure' first."
        exit 1
    fi
    
    log_success "All prerequisites met"
}

# Function to get AWS Account ID
get_aws_account_id() {
    if [[ -z "$AWS_ACCOUNT_ID" ]]; then
        log_info "Getting AWS Account ID..."
        AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
        log_info "AWS Account ID: $AWS_ACCOUNT_ID"
    fi
}

# Function to create ECR repository if it doesn't exist
create_ecr_repository() {
    log_info "Checking if ECR repository exists..."
    
    if aws ecr describe-repositories --repository-names "$ECR_REPOSITORY_NAME" --region "$AWS_REGION" &>/dev/null; then
        log_info "ECR repository '$ECR_REPOSITORY_NAME' already exists"
    else
        log_info "Creating ECR repository '$ECR_REPOSITORY_NAME'..."
        aws ecr create-repository \
            --repository-name "$ECR_REPOSITORY_NAME" \
            --region "$AWS_REGION" \
            --image-scanning-configuration scanOnPush=true \
            --encryption-configuration encryptionType=AES256
        
        log_success "ECR repository created successfully"
    fi
    
    # Set lifecycle policy to manage image retention
    log_info "Setting lifecycle policy..."
    cat > ecr-lifecycle-policy.json << EOF
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
EOF
    
    aws ecr put-lifecycle-policy \
        --repository-name "$ECR_REPOSITORY_NAME" \
        --region "$AWS_REGION" \
        --lifecycle-policy-text file://ecr-lifecycle-policy.json
    
    rm ecr-lifecycle-policy.json
    log_success "Lifecycle policy applied"
}

# Function to authenticate Docker with ECR
authenticate_docker() {
    log_info "Authenticating Docker with ECR..."
    
    aws ecr get-login-password --region "$AWS_REGION" | \
        docker login --username AWS --password-stdin "$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com"
    
    log_success "Docker authenticated with ECR"
}

# Function to build the Docker image
build_image() {
    local ecr_uri="$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPOSITORY_NAME"
    local full_image_name="$ecr_uri:$IMAGE_TAG"
    
    log_info "Building Docker image for ARM64..."
    log_info "Image name: $full_image_name"
    
    # Create buildx builder if it doesn't exist
    if ! docker buildx ls | grep -q "ecr-builder"; then
        log_info "Creating Docker buildx builder..."
        docker buildx create --name ecr-builder --driver docker-container --bootstrap
    fi
    
    # Use the builder
    docker buildx use ecr-builder
    
    # Build the image with security labels
    BUILD_DATE=$(date -u +'%Y-%m-%dT%H:%M:%SZ')
    COMMIT_HASH="${GITHUB_SHA:-$(git rev-parse --short HEAD 2>/dev/null || echo 'unknown')}"
    
    docker buildx build \
        --platform linux/arm64 \
        --build-arg BUILD_DATE="$BUILD_DATE" \
        --build-arg COMMIT_HASH="$COMMIT_HASH" \
        --label "org.opencontainers.image.created=$BUILD_DATE" \
        --label "org.opencontainers.image.revision=$COMMIT_HASH" \
        --label "org.opencontainers.image.source=aws-ecr" \
        --label "security.scan-date=$BUILD_DATE" \
        --tag "$full_image_name" \
        --push \
        -f "$DOCKERFILE_PATH" \
        .
    
    log_success "Image built and pushed to ECR: $full_image_name"
    
    # Also tag as latest if not already latest
    if [[ "$IMAGE_TAG" != "latest" ]]; then
        log_info "Tagging as latest..."
        docker buildx build \
            --platform linux/arm64 \
            --build-arg BUILD_DATE="$BUILD_DATE" \
            --build-arg COMMIT_HASH="$COMMIT_HASH" \
            --label "org.opencontainers.image.created=$BUILD_DATE" \
            --label "org.opencontainers.image.revision=$COMMIT_HASH" \
            --label "org.opencontainers.image.source=aws-ecr" \
            --label "security.scan-date=$BUILD_DATE" \
            --tag "$ecr_uri:latest" \
            --push \
            -f "$DOCKERFILE_PATH" \
            .
        log_success "Image also tagged as latest"
    fi
    
    echo "$full_image_name" > .ecr-image-uri
    log_info "Image URI saved to .ecr-image-uri file"
}

# Function to scan image for vulnerabilities
scan_image() {
    log_info "Initiating ECR vulnerability scan..."
    
    # Start vulnerability scan
    aws ecr start-image-scan \
        --repository-name "$ECR_REPOSITORY_NAME" \
        --image-id imageTag="$IMAGE_TAG" \
        --region "$AWS_REGION" || log_warning "Scan may already be in progress"
    
    # Wait for scan to complete
    log_info "Waiting for vulnerability scan to complete..."
    local max_attempts=30
    local attempt=1
    
    while [[ $attempt -le $max_attempts ]]; do
        local scan_status
        scan_status=$(aws ecr describe-image-scan-findings \
            --repository-name "$ECR_REPOSITORY_NAME" \
            --image-id imageTag="$IMAGE_TAG" \
            --region "$AWS_REGION" \
            --query 'imageScanStatus.status' \
            --output text 2>/dev/null || echo "IN_PROGRESS")
        
        if [[ "$scan_status" == "COMPLETE" ]]; then
            log_success "Vulnerability scan completed"
            break
        elif [[ "$scan_status" == "FAILED" ]]; then
            log_error "Vulnerability scan failed"
            return 1
        fi
        
        echo -n "."
        sleep 10
        ((attempt++))
    done
    
    # Get scan results
    log_info "Retrieving scan results..."
    aws ecr describe-image-scan-findings \
        --repository-name "$ECR_REPOSITORY_NAME" \
        --image-id imageTag="$IMAGE_TAG" \
        --region "$AWS_REGION" \
        --query 'imageScanFindings.findingCounts' \
        --output table
    
    # Save detailed results
    aws ecr describe-image-scan-findings \
        --repository-name "$ECR_REPOSITORY_NAME" \
        --image-id imageTag="$IMAGE_TAG" \
        --region "$AWS_REGION" \
        > ecr-scan-results.json
    
    log_info "Detailed scan results saved to ecr-scan-results.json"
    
    # Check for critical vulnerabilities
    local critical_count
    critical_count=$(aws ecr describe-image-scan-findings \
        --repository-name "$ECR_REPOSITORY_NAME" \
        --image-id imageTag="$IMAGE_TAG" \
        --region "$AWS_REGION" \
        --query 'imageScanFindings.findingCounts.CRITICAL' \
        --output text 2>/dev/null || echo "0")
    
    if [[ "$critical_count" != "None" && "$critical_count" -gt 0 ]]; then
        log_error "Found $critical_count CRITICAL vulnerabilities!"
        log_error "Review the scan results before deploying to production"
        return 1
    else
        log_success "No critical vulnerabilities found"
    fi
}

# Function to get image information
get_image_info() {
    local ecr_uri="$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPOSITORY_NAME:$IMAGE_TAG"
    
    log_info "Getting image information..."
    
    # Get image details
    aws ecr describe-images \
        --repository-name "$ECR_REPOSITORY_NAME" \
        --image-ids imageTag="$IMAGE_TAG" \
        --region "$AWS_REGION" \
        --query 'imageDetails[0].{Size:imageSizeInBytes,Pushed:imagePushedAt,Digest:imageDigest}' \
        --output table
    
    # Get image URI with digest for immutable reference
    local image_digest
    image_digest=$(aws ecr describe-images \
        --repository-name "$ECR_REPOSITORY_NAME" \
        --image-ids imageTag="$IMAGE_TAG" \
        --region "$AWS_REGION" \
        --query 'imageDetails[0].imageDigest' \
        --output text)
    
    local immutable_uri="$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPOSITORY_NAME@$image_digest"
    
    echo "==============================================="
    echo "Image successfully pushed to ECR!"
    echo "==============================================="
    echo "Repository: $ECR_REPOSITORY_NAME"
    echo "Region: $AWS_REGION"
    echo "Tag: $IMAGE_TAG"
    echo "URI (by tag): $ecr_uri"
    echo "URI (by digest): $immutable_uri"
    echo "==============================================="
    
    # Save URIs to files for easy reference
    echo "$ecr_uri" > .ecr-image-uri-tag
    echo "$immutable_uri" > .ecr-image-uri-digest
}

# Function to create deployment examples
create_deployment_examples() {
    local ecr_uri="$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPOSITORY_NAME:$IMAGE_TAG"
    
    log_info "Creating deployment examples..."
    
    # Create ECS task definition with actual ECR URI
    cat > ecs-task-definition-ecr.json << EOF
{
  "family": "dns-lookup-service",
  "networkMode": "awsvpc",
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "512",
  "memory": "1024",
  "executionRoleArn": "arn:aws:iam::${AWS_ACCOUNT_ID}:role/ecsTaskExecutionRole",
  "taskRoleArn": "arn:aws:iam::${AWS_ACCOUNT_ID}:role/dns-lookup-task-role",
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
      "memoryReservation": 512,
      "essential": true,
      "portMappings": [
        {
          "containerPort": 8080,
          "protocol": "tcp",
          "name": "http"
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
        },
        {
          "name": "HOST",
          "value": "0.0.0.0"
        },
        {
          "name": "PORT",
          "value": "8080"
        }
      ],
      "healthCheck": {
        "command": [
          "CMD-SHELL",
          "curl -f http://localhost:8080/health || exit 1"
        ],
        "interval": 30,
        "timeout": 5,
        "retries": 3,
        "startPeriod": 60
      },
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "/ecs/dns-lookup-service",
          "awslogs-region": "${AWS_REGION}",
          "awslogs-stream-prefix": "ecs",
          "awslogs-create-group": "true"
        }
      },
      "user": "10001:10001",
      "readonlyRootFilesystem": true,
      "linuxParameters": {
        "capabilities": {
          "drop": ["ALL"]
        }
      }
    }
  ]
}
EOF
    
    # Create Kubernetes deployment with actual ECR URI
    cat > k8s-deployment-ecr.yaml << EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: dns-lookup-service
  namespace: dns-lookup
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
      securityContext:
        runAsNonRoot: true
        runAsUser: 10001
        runAsGroup: 10001
        fsGroup: 10001
      nodeSelector:
        kubernetes.io/arch: arm64
      containers:
      - name: dns-lookup
        image: ${ecr_uri}
        imagePullPolicy: Always
        securityContext:
          runAsNonRoot: true
          runAsUser: 10001
          runAsGroup: 10001
          readOnlyRootFilesystem: true
          allowPrivilegeEscalation: false
          capabilities:
            drop:
            - ALL
        ports:
        - name: http
          containerPort: 8080
          protocol: TCP
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
            port: http
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /health
            port: http
          initialDelaySeconds: 5
          periodSeconds: 5
EOF
    
    log_success "Deployment examples created:"
    log_info "- ecs-task-definition-ecr.json (ECS task definition)"
    log_info "- k8s-deployment-ecr.yaml (Kubernetes deployment)"
}

# Function to show next steps
show_next_steps() {
    log_info "Next Steps:"
    echo "1. Review vulnerability scan results in ecr-scan-results.json"
    echo "2. Test the image locally:"
    echo "   docker run -p 8080:8080 $(cat .ecr-image-uri-tag)"
    echo "3. Deploy using ECS:"
    echo "   aws ecs register-task-definition --cli-input-json file://ecs-task-definition-ecr.json"
    echo "4. Deploy using Kubernetes:"
    echo "   kubectl apply -f k8s-deployment-ecr.yaml"
    echo "5. Monitor the deployment and check logs"
    echo ""
    echo "Image URIs:"
    echo "- By tag: $(cat .ecr-image-uri-tag)"
    echo "- By digest: $(cat .ecr-image-uri-digest)"
}

# Main function
main() {
    echo "=========================================="
    echo "AWS ECR Deployment for DNS Lookup Service"
    echo "=========================================="
    echo "Region: $AWS_REGION"
    echo "Repository: $ECR_REPOSITORY_NAME"
    echo "Tag: $IMAGE_TAG"
    echo "=========================================="
    
    check_prerequisites
    get_aws_account_id
    create_ecr_repository
    authenticate_docker
    build_image
    scan_image
    get_image_info
    create_deployment_examples
    show_next_steps
    
    log_success "ECR deployment completed successfully!"
}

# Show usage
show_usage() {
    echo "Usage: $0 [IMAGE_TAG]"
    echo ""
    echo "Environment Variables:"
    echo "  AWS_REGION           - AWS region (default: us-east-1)"
    echo "  ECR_REPOSITORY_NAME  - ECR repository name (default: dns-lookup-service)"
    echo "  AWS_ACCOUNT_ID       - AWS Account ID (auto-detected if not set)"
    echo "  DOCKERFILE_PATH      - Path to Dockerfile (default: ./Dockerfile)"
    echo ""
    echo "Examples:"
    echo "  $0                           # Build and push with 'latest' tag"
    echo "  $0 v1.0.0                   # Build and push with 'v1.0.0' tag"
    echo "  AWS_REGION=eu-west-1 $0     # Use different region"
    echo ""
}

# Error handling
set -e
trap 'log_error "Script failed on line $LINENO"' ERR

# Parse arguments
case "${1:-}" in
    -h|--help|help)
        show_usage
        exit 0
        ;;
    *)
        main "$@"
        ;;
esac