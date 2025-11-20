#!/bin/bash
# Quick CodeBuild setup script

echo "🚀 Setting up CodeBuild project for ARM64 container build..."

# Create CodeBuild project
aws codebuild create-project \
  --name "dns-agent-arm64-build" \
  --source '{
    "type": "NO_SOURCE",
    "buildspec": "buildspec.yml"
  }' \
  --artifacts '{
    "type": "NO_ARTIFACTS"
  }' \
  --environment '{
    "type": "LINUX_CONTAINER",
    "image": "aws/codebuild/amazonlinux2-aarch64-standard:3.0",
    "computeType": "BUILD_GENERAL1_SMALL",
    "privilegedMode": true,
    "environmentVariables": [
      {
        "name": "AWS_DEFAULT_REGION",
        "value": "us-east-1"
      },
      {
        "name": "AWS_ACCOUNT_ID", 
        "value": "818565325759"
      },
      {
        "name": "IMAGE_REPO_NAME",
        "value": "818565325759.dkr.ecr.us-east-1.amazonaws.com/dns-lookup-service"
      },
      {
        "name": "IMAGE_TAG",
        "value": "v1.2.1-ping-fix-arm64"
      }
    ]
  }' \
  --service-role "arn:aws:iam::818565325759:role/service-role/codebuild-service-role" \
  --region us-east-1

if [ $? -eq 0 ]; then
  echo "✅ CodeBuild project created successfully!"
  echo "📦 Starting build..."
  
  # Start the build
  aws codebuild start-build \
    --project-name "dns-agent-arm64-build" \
    --source-version "main" \
    --region us-east-1
    
  echo "🔄 Build started. Monitor progress in AWS CodeBuild console."
  echo "📊 Check build status: aws codebuild batch-get-builds --ids <build-id>"
else
  echo "❌ Failed to create CodeBuild project. Check IAM permissions."
fi