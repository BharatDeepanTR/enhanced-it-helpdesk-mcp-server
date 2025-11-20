#!/bin/bash
# ECS Fargate deployment script for DNS lookup service

set -e

# Configuration
CLUSTER_NAME="bedrock-agent-cluster"
SERVICE_NAME="dns-lookup-service"
TASK_FAMILY="dns-lookup-task"
REGION=${AWS_DEFAULT_REGION:-"us-east-1"}

# Get account ID and construct image URI
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
IMAGE_URI="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/dns-lookup-service:v1.0.0"

echo "🚀 Deploying DNS Lookup Service to ECS Fargate..."
echo "   Image: $IMAGE_URI"
echo "   Cluster: $CLUSTER_NAME"
echo "   Service: $SERVICE_NAME"
echo ""

# Create ECS cluster if it doesn't exist
echo "🏗️  Creating ECS cluster..."
aws ecs create-cluster \
    --cluster-name $CLUSTER_NAME \
    --capacity-providers FARGATE \
    --default-capacity-provider-strategy capacityProvider=FARGATE,weight=1 \
    --region $REGION >/dev/null 2>&1 || echo "   Cluster already exists or created"

# Create task definition
echo "📋 Creating task definition..."
cat > task-definition.json << EOF
{
  "family": "$TASK_FAMILY",
  "networkMode": "awsvpc",
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "256",
  "memory": "512",
  "executionRoleArn": "arn:aws:iam::${ACCOUNT_ID}:role/ecsTaskExecutionRole",
  "taskRoleArn": "arn:aws:iam::${ACCOUNT_ID}:role/ecsTaskExecutionRole",
  "containerDefinitions": [
    {
      "name": "dns-lookup-container",
      "image": "$IMAGE_URI",
      "portMappings": [
        {
          "containerPort": 8080,
          "protocol": "tcp"
        }
      ],
      "essential": true,
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "/ecs/dns-lookup-service",
          "awslogs-region": "$REGION",
          "awslogs-stream-prefix": "ecs"
        }
      },
      "healthCheck": {
        "command": ["CMD-SHELL", "curl -f http://localhost:8080/health || exit 1"],
        "interval": 30,
        "timeout": 5,
        "retries": 3,
        "startPeriod": 60
      },
      "environment": [
        {
          "name": "AWS_DEFAULT_REGION",
          "value": "$REGION"
        }
      ]
    }
  ]
}
EOF

# Create CloudWatch log group
echo "📊 Creating CloudWatch log group..."
aws logs create-log-group \
    --log-group-name "/ecs/dns-lookup-service" \
    --region $REGION >/dev/null 2>&1 || echo "   Log group already exists"

# Register task definition
echo "📝 Registering task definition..."
aws ecs register-task-definition \
    --cli-input-json file://task-definition.json \
    --region $REGION >/dev/null

# Get default VPC and subnets
echo "🔍 Getting VPC information..."
VPC_ID=$(aws ec2 describe-vpcs --filters "Name=is-default,Values=true" --query 'Vpcs[0].VpcId' --output text --region $REGION)
SUBNET_IDS=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID" --query 'Subnets[0:2].SubnetId' --output text --region $REGION)

# Create security group for the service
echo "🛡️  Creating security group..."
SG_ID=$(aws ec2 create-security-group \
    --group-name dns-lookup-sg \
    --description "Security group for DNS lookup service" \
    --vpc-id $VPC_ID \
    --region $REGION \
    --query 'GroupId' \
    --output text 2>/dev/null || \
    aws ec2 describe-security-groups \
        --filters "Name=group-name,Values=dns-lookup-sg" \
        --query 'SecurityGroups[0].GroupId' \
        --output text \
        --region $REGION)

# Add inbound rule for port 8080
aws ec2 authorize-security-group-ingress \
    --group-id $SG_ID \
    --protocol tcp \
    --port 8080 \
    --cidr 0.0.0.0/0 \
    --region $REGION >/dev/null 2>&1 || echo "   Security group rule already exists"

# Create ECS service
echo "🚀 Creating ECS service..."
aws ecs create-service \
    --cluster $CLUSTER_NAME \
    --service-name $SERVICE_NAME \
    --task-definition $TASK_FAMILY \
    --desired-count 1 \
    --launch-type FARGATE \
    --network-configuration "awsvpcConfiguration={subnets=[$SUBNET_IDS],securityGroups=[$SG_ID],assignPublicIp=ENABLED}" \
    --region $REGION >/dev/null

echo "⏳ Waiting for service to start (this may take 2-3 minutes)..."
aws ecs wait services-stable \
    --cluster $CLUSTER_NAME \
    --services $SERVICE_NAME \
    --region $REGION

# Get the public IP of the running task
echo "🔍 Getting service endpoint..."
TASK_ARN=$(aws ecs list-tasks \
    --cluster $CLUSTER_NAME \
    --service-name $SERVICE_NAME \
    --query 'taskArns[0]' \
    --output text \
    --region $REGION)

if [ "$TASK_ARN" != "None" ]; then
    PUBLIC_IP=$(aws ecs describe-tasks \
        --cluster $CLUSTER_NAME \
        --tasks $TASK_ARN \
        --query 'tasks[0].attachments[0].details[?name==`networkInterfaceId`].value' \
        --output text \
        --region $REGION | xargs -I {} aws ec2 describe-network-interfaces \
        --network-interface-ids {} \
        --query 'NetworkInterfaces[0].Association.PublicIp' \
        --output text \
        --region $REGION)
    
    echo ""
    echo "🎉 Deployment successful!"
    echo ""
    echo "📋 Service Details:"
    echo "   Cluster: $CLUSTER_NAME"
    echo "   Service: $SERVICE_NAME"
    echo "   Public IP: $PUBLIC_IP"
    echo "   Health Check: http://$PUBLIC_IP:8080/health"
    echo "   DNS Lookup: http://$PUBLIC_IP:8080/lookup?domain=aws.amazon.com"
    echo ""
    echo "🧪 Test Commands:"
    echo "   curl http://$PUBLIC_IP:8080/health"
    echo "   curl 'http://$PUBLIC_IP:8080/lookup?domain=aws.amazon.com'"
    echo ""
else
    echo "❌ Failed to get task information. Check ECS console."
fi

# Cleanup
rm -f task-definition.json

echo "✅ Deployment script completed!"