# Cloud Shell Deployment Troubleshooting Guide

## Quick Start for Cloud Shell

### 1. Extract and Setup
```bash
tar -xzf dns-lookup-fixed-cloudshell-20251101-211910.tar.gz
cd dns-lookup-fixed-cloudshell-20251101-211910
chmod +x setup-cloudshell.sh deploy.sh
```

### 2. Environment Setup
```bash
./setup-cloudshell.sh
source cloudshell-env.sh
```

### 3. Deploy
```bash
./deploy.sh
```

## Temporary Credentials Setup

### Option 1: Environment Variables (Recommended for temporary access)
```bash
export AWS_ACCESS_KEY_ID=your_access_key_here
export AWS_SECRET_ACCESS_KEY=your_secret_access_key_here
export AWS_SESSION_TOKEN=your_session_token_here  # Only if using STS
```

### Option 2: AWS Configure
```bash
aws configure
# Enter: Access Key ID, Secret Access Key, Region (us-east-1), Output format (json)
```

### Option 3: Assume Role (Cross-account access)
```bash
# Replace with your actual role ARN
aws sts assume-role \
  --role-arn arn:aws:iam::123456789012:role/YourCrossAccountRole \
  --role-session-name CloudShellDNSDeployment

# Then export the returned credentials
```

## Common Issues and Solutions

### Issue: AWS Credentials Not Found
**Error**: `Unable to locate credentials`

**Solution**:
1. Check current credentials: `aws sts get-caller-identity`
2. If failed, configure credentials using one of the options above
3. Ensure the session hasn't expired (temporary credentials typically last 1-12 hours)

### Issue: ECR Permission Denied
**Error**: `denied: User: arn:aws:iam::123456789012:user/username is not authorized`

**Required Permissions**:
- `ecr:GetAuthorizationToken`
- `ecr:BatchCheckLayerAvailability`
- `ecr:GetDownloadUrlForLayer`
- `ecr:BatchGetImage`
- `ecr:CreateRepository` (if repository doesn't exist)
- `ecr:PutImage`
- `ecr:InitiateLayerUpload`
- `ecr:UploadLayerPart`
- `ecr:CompleteLayerUpload`

**Quick Fix Policy**:
```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "ecr:*"
            ],
            "Resource": "*"
        }
    ]
}
```

### Issue: Docker Not Running
**Error**: `Cannot connect to the Docker daemon`

**Solution**:
```bash
sudo systemctl start docker
sudo usermod -aG docker $USER
# Log out and log back in, or run:
newgrp docker
```

### Issue: Multi-Architecture Build Fails
**Error**: `failed to solve: failed to create LLB definition`

**Expected Behavior**: 
- The script will automatically fall back to single architecture (x86_64)
- This is normal in Cloud Shell environments with QEMU limitations
- The resulting image will still work with Agent Core Runtime

### Issue: ECR Repository Doesn't Exist
**Error**: `RepositoryNotFoundException`

**Solution**: 
- The deploy script will automatically create the repository
- If it fails, manually create it:
```bash
aws ecr create-repository --repository-name dns-lookup-service --region us-east-1
```

### Issue: Build Times Out
**Error**: `context deadline exceeded`

**Solution**:
1. Clean Docker environment: `docker system prune -f`
2. Increase Docker resources if possible
3. The script includes retry logic for transient failures

### Issue: jq Command Not Found
**Error**: `jq: command not found`

**Solution**:
```bash
sudo apt-get update && sudo apt-get install -y jq
```

## Verification Commands

### Check AWS Setup
```bash
aws sts get-caller-identity
aws ecr describe-repositories --region us-east-1
```

### Check Docker Setup
```bash
docker info
docker buildx version
```

### Check Deployment Success
```bash
aws ecr describe-images --repository-name dns-lookup-service --region us-east-1
```

## Expected Output

### Successful Deployment
```
🎉 Container Build and Deployment Successful!

📋 Deployment Summary:
   🏷️  Repository: dns-lookup-service
   🔖 Tag: v1.3.0
   🔗 URI: 123456789012.dkr.ecr.us-east-1.amazonaws.com/dns-lookup-service:v1.3.0
   🏗️  Architecture: Multi-platform (ARM64 + x86_64) or x86_64 fallback
   🎯 Target: AWS Bedrock Agent Core Runtime
```

### Agent Core Runtime Configuration
```
Image URI: 123456789012.dkr.ecr.us-east-1.amazonaws.com/dns-lookup-service:v1.3.0
```

### Test Input
```json
{"domain": "google.com"}
```

### Expected Response
```json
{
  "statusCode": 200,
  "body": "{\"dns_records\": [{\"type\": \"A\", \"value\": \"172.217.164.14\"}]}"
}
```

## Support Information

- **Package Version**: dns-lookup-fixed-cloudshell-20251101-211910
- **Container Version**: v1.3.0
- **Default Region**: us-east-1
- **Architecture Support**: ARM64 + x86_64 (with x86_64 fallback)
- **Target Platform**: AWS Bedrock Agent Core Runtime
- **Entry Point**: lambda_handler.lambda_handler