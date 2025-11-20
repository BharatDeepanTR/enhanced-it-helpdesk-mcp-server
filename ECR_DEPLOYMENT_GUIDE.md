# AWS ECR Deployment Guide for DNS Lookup Service

## 🚀 Quick Start for ECR Deployment

### Prerequisites

1. **AWS CLI configured with appropriate permissions**
   ```bash
   aws configure
   # Ensure you have ECR permissions: ecr:*, iam:PassRole
   ```

2. **Docker with ARM64 support**
   ```bash
   docker version
   docker buildx version
   ```

3. **Required AWS IAM permissions**:
   - `ecr:CreateRepository`
   - `ecr:GetAuthorizationToken`
   - `ecr:BatchCheckLayerAvailability`
   - `ecr:GetDownloadUrlForLayer`
   - `ecr:BatchGetImage`
   - `ecr:PutImage`
   - `ecr:InitiateLayerUpload`
   - `ecr:UploadLayerPart`
   - `ecr:CompleteLayerUpload`
   - `ecr:StartImageScan`
   - `ecr:DescribeImageScanFindings`

### Option 1: One-Command Deployment

```bash
# Deploy with latest tag
./deploy-ecr.sh

# Deploy with specific version
./deploy-ecr.sh v1.0.0

# Deploy to different region
AWS_REGION=eu-west-1 ./deploy-ecr.sh v1.0.0

# Use custom repository name
ECR_REPOSITORY_NAME=my-dns-service ./deploy-ecr.sh
```

### Option 2: Step-by-Step Manual Process

```bash
# 1. Set environment variables
export AWS_REGION=us-east-1
export ECR_REPOSITORY_NAME=dns-lookup-service
export IMAGE_TAG=v1.0.0

# 2. Get AWS Account ID
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ECR_URI="$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPOSITORY_NAME"

# 3. Create ECR repository (if it doesn't exist)
aws ecr create-repository \
    --repository-name $ECR_REPOSITORY_NAME \
    --region $AWS_REGION \
    --image-scanning-configuration scanOnPush=true

# 4. Login to ECR
aws ecr get-login-password --region $AWS_REGION | \
    docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com

# 5. Build and push the image
docker buildx build --platform linux/arm64 \
    --tag $ECR_URI:$IMAGE_TAG \
    --tag $ECR_URI:latest \
    --push .

# 6. Start vulnerability scan
aws ecr start-image-scan \
    --repository-name $ECR_REPOSITORY_NAME \
    --image-id imageTag=$IMAGE_TAG \
    --region $AWS_REGION
```

## 📋 What the Script Does

### 1. **Prerequisites Check**
- Verifies AWS CLI installation and configuration
- Checks Docker and Docker Buildx availability
- Validates AWS credentials

### 2. **ECR Repository Setup**
- Creates ECR repository if it doesn't exist
- Configures vulnerability scanning on push
- Sets up lifecycle policy for image retention
- Enables AES256 encryption

### 3. **Docker Authentication**
- Authenticates Docker client with ECR
- Uses temporary tokens for secure access

### 4. **Secure Image Build**
- Builds ARM64 Docker image using multi-stage Dockerfile
- Adds build metadata and security labels
- Pushes both specific tag and latest tag

### 5. **Security Scanning**
- Initiates ECR vulnerability scan
- Waits for scan completion
- Reports scan results
- Fails build if critical vulnerabilities found

### 6. **Deployment Artifacts**
- Creates ECS task definition with ECR URI
- Creates Kubernetes deployment manifest
- Generates immutable image references using digest

## 🔧 Configuration Options

### Environment Variables

```bash
# AWS Configuration
export AWS_REGION=us-east-1                    # Target AWS region
export AWS_ACCOUNT_ID=123456789012             # Your AWS account ID (auto-detected)

# ECR Configuration
export ECR_REPOSITORY_NAME=dns-lookup-service  # ECR repository name

# Build Configuration
export DOCKERFILE_PATH=./Dockerfile            # Path to Dockerfile
export IMAGE_TAG=latest                        # Docker image tag
```

### AWS CLI Profile

```bash
# Use specific AWS profile
export AWS_PROFILE=production
./deploy-ecr.sh v1.0.0
```

## 📁 Generated Files

After successful deployment, you'll find these files:

```
.ecr-image-uri-tag              # ECR URI with tag
.ecr-image-uri-digest           # ECR URI with digest (immutable)
ecr-scan-results.json           # Detailed vulnerability scan results
ecs-task-definition-ecr.json    # Ready-to-use ECS task definition
k8s-deployment-ecr.yaml         # Ready-to-use Kubernetes deployment
```

## 🔍 Monitoring and Verification

### Check Repository Status
```bash
aws ecr describe-repositories --repository-names dns-lookup-service
```

### View Images in Repository
```bash
aws ecr describe-images --repository-name dns-lookup-service
```

### Check Vulnerability Scan Results
```bash
aws ecr describe-image-scan-findings \
    --repository-name dns-lookup-service \
    --image-id imageTag=latest
```

### Test the Image
```bash
# Pull and run locally
ECR_URI=$(cat .ecr-image-uri-tag)
docker run -p 8080:8080 $ECR_URI

# Test the service
curl http://localhost:8080/health
```

## 🚀 Deploy to AWS Services

### Deploy to ECS

```bash
# Register task definition
aws ecs register-task-definition \
    --cli-input-json file://ecs-task-definition-ecr.json

# Create ECS service
aws ecs create-service \
    --cluster my-cluster \
    --service-name dns-lookup-service \
    --task-definition dns-lookup-service \
    --desired-count 3 \
    --launch-type FARGATE \
    --network-configuration "awsvpcConfiguration={subnets=[subnet-12345],securityGroups=[sg-12345],assignPublicIp=ENABLED}"
```

### Deploy to Kubernetes

```bash
# Apply the deployment
kubectl apply -f k8s-deployment-ecr.yaml

# Check deployment status
kubectl get pods -n dns-lookup
kubectl logs -f deployment/dns-lookup-service -n dns-lookup
```

### Deploy to Lambda (Container)

```bash
# Create Lambda function using container image
aws lambda create-function \
    --function-name dns-lookup-service \
    --package-type Image \
    --code ImageUri=$(cat .ecr-image-uri-digest) \
    --role arn:aws:iam::ACCOUNT:role/lambda-execution-role \
    --timeout 300 \
    --memory-size 512 \
    --architectures arm64
```

## 🛠️ Troubleshooting

### Common Issues

#### 1. Authentication Failed
```bash
# Error: login attempt to https://123456789012.dkr.ecr.us-east-1.amazonaws.com/dns-lookup-service failed
# Solution: Re-authenticate
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin 123456789012.dkr.ecr.us-east-1.amazonaws.com
```

#### 2. Repository Does Not Exist
```bash
# Error: The repository with name 'dns-lookup-service' does not exist
# Solution: Create repository first
aws ecr create-repository --repository-name dns-lookup-service --region us-east-1
```

#### 3. Insufficient Permissions
```bash
# Error: User is not authorized to perform ecr:CreateRepository
# Solution: Add ECR permissions to your IAM user/role
```

#### 4. Platform Mismatch
```bash
# Error: exec /usr/local/bin/python: exec format error
# Solution: Ensure you're building for ARM64
docker buildx build --platform linux/arm64 ...
```

#### 5. Critical Vulnerabilities Found
```bash
# Error: Found X CRITICAL vulnerabilities!
# Solution: Review scan results and update base image/dependencies
cat ecr-scan-results.json
```

### Debug Commands

```bash
# Check Docker buildx builders
docker buildx ls

# Check current platform
docker buildx inspect --bootstrap

# Test image locally with platform specification
docker run --platform linux/arm64 -p 8080:8080 your-image

# Check ECR repository policies
aws ecr get-repository-policy --repository-name dns-lookup-service

# View detailed ECR repository information
aws ecr describe-repositories --repository-names dns-lookup-service --region us-east-1
```

## 💰 Cost Optimization

### ECR Storage Costs
- Use lifecycle policies to automatically delete old images
- Consider using image compression
- Regular cleanup of unused images

### Transfer Costs
- Deploy ECR and compute services in the same region
- Use VPC endpoints for ECR to avoid NAT Gateway charges

### Example Lifecycle Policy
```json
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
        }
    ]
}
```

## 🔒 Security Best Practices

### 1. Image Scanning
- Always enable scan on push
- Review vulnerability reports before production deployment
- Set up automated alerts for new vulnerabilities

### 2. Access Control
- Use least privilege IAM policies
- Enable ECR repository encryption
- Use immutable image tags for production

### 3. Network Security
- Use VPC endpoints for ECR access
- Implement network policies in Kubernetes
- Use security groups to restrict access

### 4. Monitoring
- Enable CloudTrail for ECR API calls
- Set up CloudWatch alarms for repository events
- Monitor image pull patterns

## 📚 Additional Resources

- [AWS ECR User Guide](https://docs.aws.amazon.com/ecr/)
- [Docker Multi-platform Builds](https://docs.docker.com/build/building/multi-platform/)
- [ECS Task Definitions](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task_definitions.html)
- [Kubernetes Deployments](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/)

---

## 🎯 Summary

The `deploy-ecr.sh` script provides a complete, secure, and automated way to:

1. ✅ Build ARM64 Docker images
2. ✅ Push to AWS ECR with security scanning
3. ✅ Generate deployment artifacts
4. ✅ Provide monitoring and troubleshooting guidance
5. ✅ Follow AWS security best practices

Your DNS lookup service is now ready for production deployment on AWS! 🚀