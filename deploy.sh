#!/bin/bash
set -euo pipefail

# Quick deployment script for DNS Lookup Service
# Supports local testing, Kubernetes, and AWS ECS deployment

DEPLOYMENT_TYPE="${1:-local}"
IMAGE_TAG="${2:-latest}"
REGISTRY="${REGISTRY:-localhost:5000}"

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

# Function to deploy locally for testing
deploy_local() {
    log_info "Deploying locally for testing..."
    
    # Build the image first
    log_info "Building Docker image..."
    ./build-secure.sh "${IMAGE_TAG}"
    
    # Stop any existing container
    docker stop dns-lookup-test 2>/dev/null || true
    docker rm dns-lookup-test 2>/dev/null || true
    
    # Run the container
    log_info "Starting container..."
    docker run -d \
        --name dns-lookup-test \
        --platform linux/arm64 \
        -p 8080:8080 \
        -e ENV=test \
        -e APP_CONFIG_PATH=/config \
        "${REGISTRY}/dns-lookup-service:${IMAGE_TAG}"
    
    # Wait for container to be ready
    log_info "Waiting for service to be ready..."
    for i in {1..30}; do
        if curl -f http://localhost:8080/health &>/dev/null; then
            break
        fi
        sleep 1
    done
    
    # Test the service
    log_info "Testing the service..."
    echo "Health check:"
    curl -s http://localhost:8080/health | jq .
    
    echo -e "\nService info:"
    curl -s http://localhost:8080/ | jq .
    
    log_success "Local deployment completed!"
    log_info "Service available at: http://localhost:8080"
    log_info "Health check: http://localhost:8080/health"
    log_info "API endpoint: http://localhost:8080/lookup"
    log_info ""
    log_info "Example curl command:"
    log_info "curl -X POST http://localhost:8080/lookup -H 'Content-Type: application/json' -d '{\"dns_name\": \"example.com\"}'"
    log_info ""
    log_info "To stop: docker stop dns-lookup-test"
}

# Function to deploy to Kubernetes
deploy_kubernetes() {
    log_info "Deploying to Kubernetes..."
    
    # Check if kubectl is available
    if ! command -v kubectl &>/dev/null; then
        log_error "kubectl is required for Kubernetes deployment"
        exit 1
    fi
    
    # Check if cluster is accessible
    if ! kubectl cluster-info &>/dev/null; then
        log_error "Cannot connect to Kubernetes cluster"
        exit 1
    fi
    
    # Build and push image
    log_info "Building and pushing image..."
    ./build-secure.sh "${IMAGE_TAG}"
    
    # Push to registry (assuming registry is configured)
    docker push "${REGISTRY}/dns-lookup-service:${IMAGE_TAG}"
    
    # Update image tag in deployment
    sed -i.bak "s|localhost:5000/dns-lookup-service:latest|${REGISTRY}/dns-lookup-service:${IMAGE_TAG}|g" k8s/deployment.yaml
    
    # Apply Kubernetes manifests
    log_info "Applying Kubernetes manifests..."
    kubectl apply -f k8s/deployment.yaml
    kubectl apply -f k8s/ingress.yaml
    
    # Wait for deployment to be ready
    log_info "Waiting for deployment to be ready..."
    kubectl wait --for=condition=available --timeout=300s deployment/dns-lookup-service -n dns-lookup
    
    # Get service information
    log_info "Getting service information..."
    kubectl get all -n dns-lookup
    
    # Restore original deployment file
    mv k8s/deployment.yaml.bak k8s/deployment.yaml
    
    log_success "Kubernetes deployment completed!"
    log_info "Check status: kubectl get pods -n dns-lookup"
    log_info "View logs: kubectl logs -f deployment/dns-lookup-service -n dns-lookup"
    log_info "Port forward for testing: kubectl port-forward svc/dns-lookup-service 8080:80 -n dns-lookup"
}

# Function to deploy to AWS ECS
deploy_ecs() {
    log_info "Deploying to AWS ECS..."
    
    # Check if AWS CLI is available
    if ! command -v aws &>/dev/null; then
        log_error "AWS CLI is required for ECS deployment"
        exit 1
    fi
    
    # Check AWS credentials
    if ! aws sts get-caller-identity &>/dev/null; then
        log_error "AWS credentials not configured"
        exit 1
    fi
    
    # Build and push to ECR
    log_info "Building and pushing to ECR..."
    
    # Get ECR login token
    aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin "${REGISTRY}"
    
    # Build image
    ./build-secure.sh "${IMAGE_TAG}"
    
    # Tag for ECR
    docker tag "${REGISTRY}/dns-lookup-service:${IMAGE_TAG}" "${REGISTRY}/dns-lookup-service:${IMAGE_TAG}"
    
    # Push to ECR
    docker push "${REGISTRY}/dns-lookup-service:${IMAGE_TAG}"
    
    # Update task definition
    log_info "Updating ECS task definition..."
    TASK_DEF_ARN=$(aws ecs register-task-definition \
        --cli-input-json file://aws-ecs/task-definition.json \
        --query 'taskDefinition.taskDefinitionArn' \
        --output text)
    
    log_info "Task definition registered: ${TASK_DEF_ARN}"
    
    # Update service
    log_info "Updating ECS service..."
    aws ecs update-service \
        --cli-input-json file://aws-ecs/service-definition.json \
        --task-definition "${TASK_DEF_ARN}"
    
    # Wait for service to stabilize
    log_info "Waiting for service to stabilize..."
    aws ecs wait services-stable --cluster dns-lookup-cluster --services dns-lookup-service
    
    log_success "ECS deployment completed!"
    log_info "Check status: aws ecs describe-services --cluster dns-lookup-cluster --services dns-lookup-service"
}

# Function to show usage
show_usage() {
    echo "Usage: $0 [DEPLOYMENT_TYPE] [IMAGE_TAG]"
    echo ""
    echo "DEPLOYMENT_TYPE:"
    echo "  local      - Deploy locally for testing (default)"
    echo "  k8s        - Deploy to Kubernetes"
    echo "  ecs        - Deploy to AWS ECS"
    echo ""
    echo "IMAGE_TAG:"
    echo "  Tag for the Docker image (default: latest)"
    echo ""
    echo "Environment Variables:"
    echo "  REGISTRY   - Docker registry URL (default: localhost:5000)"
    echo ""
    echo "Examples:"
    echo "  $0 local                    # Deploy locally"
    echo "  $0 k8s v1.0.0              # Deploy to Kubernetes with tag v1.0.0"
    echo "  REGISTRY=my-registry.com $0 ecs latest  # Deploy to ECS"
}

# Main execution
main() {
    case "${DEPLOYMENT_TYPE}" in
        "local")
            deploy_local
            ;;
        "k8s"|"kubernetes")
            deploy_kubernetes
            ;;
        "ecs")
            deploy_ecs
            ;;
        "help"|"--help"|"-h")
            show_usage
            ;;
        *)
            log_error "Unknown deployment type: ${DEPLOYMENT_TYPE}"
            show_usage
            exit 1
            ;;
    esac
}

# Check if script is being sourced or executed
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi