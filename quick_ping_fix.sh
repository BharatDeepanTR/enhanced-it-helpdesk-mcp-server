#!/bin/bash
# Quick container rebuild script for ping endpoint fix

echo "🚀 Building minimal container with /ping endpoint fix..."

# Create a simple Dockerfile that should work
cat > Dockerfile.minimal << 'EOF'
FROM python:3.11-slim
WORKDIR /app
RUN pip install --no-cache-dir boto3 requests
COPY *.py ./
ENV ENV=dev
ENV APP_CONFIG_PATH=/a208194/APISECRETS
ENV PYTHONPATH=/app
EXPOSE 8080
CMD ["python", "container_handler.py"]
EOF

# Build for current platform first, then convert
echo "Building container..."
docker build -f Dockerfile.minimal -t chatops-route-dns:v1.1.1-ping-fix .

if [ $? -eq 0 ]; then
    echo "✅ Container built successfully!"
    
    # Get ECR login and push
    echo "Pushing to ECR..."
    aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin 818565325759.dkr.ecr.us-east-1.amazonaws.com
    
    # Tag and push
    docker tag chatops-route-dns:v1.1.1-ping-fix 818565325759.dkr.ecr.us-east-1.amazonaws.com/chatops-route-dns:v1.1.1-ping-fix
    docker push 818565325759.dkr.ecr.us-east-1.amazonaws.com/chatops-route-dns:v1.1.1-ping-fix
    
    echo "✅ Container pushed to ECR!"
    echo "🔄 Now updating Agent Core Runtime..."
    
    # Update the runtime with new container
    aws bedrock-agentcore update-runtime \
        --runtime-id "a208194_chatops_route_dns_lookup-Zg3E6G5ZDV" \
        --container-configuration '{
            "imageUri": "818565325759.dkr.ecr.us-east-1.amazonaws.com/chatops-route-dns:v1.1.1-ping-fix"
        }' \
        --region us-east-1
    
    echo "✅ Runtime updated! Give it 2-3 minutes to redeploy, then test again."
    
else
    echo "❌ Build failed. Check error messages above."
fi