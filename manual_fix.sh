#!/bin/bash
# Manual ARM64 container build (requires ARM64 environment)

echo "🔧 Building ARM64 container with /ping endpoint fix..."

# Create optimized Dockerfile
cat > Dockerfile.ping-fix << 'EOF'
FROM --platform=linux/arm64 python:3.11-slim
WORKDIR /app
RUN pip install --no-cache-dir boto3 requests
COPY chatops_route_dns_intent.py chatops_helpers.py chatops_config.py container_handler.py ./
ENV ENV=dev
ENV APP_CONFIG_PATH=/a208194/APISECRETS
ENV PYTHONPATH=/app
ENV PYTHONUNBUFFERED=1
EXPOSE 8080
CMD ["python", "container_handler.py"]
EOF

# Build and push
docker buildx build --platform linux/arm64 \
  -f Dockerfile.ping-fix \
  -t 818565325759.dkr.ecr.us-east-1.amazonaws.com/dns-lookup-service:v1.2.1-ping-fix-arm64 \
  . --push

# Update runtime
aws bedrock-agentcore update-agent-runtime \
  --runtime-id "a208194_chatops_route_dns_lookup-Zg3E6G5ZDV" \
  --container-configuration imageUri="818565325759.dkr.ecr.us-east-1.amazonaws.com/dns-lookup-service:v1.2.1-ping-fix-arm64" \
  --region us-east-1

echo "✅ Container updated! Wait 2-3 minutes then test again."