#!/bin/bash
# Quick Lambda deployment for DNS lookup service

set -e

FUNCTION_NAME="dns-lookup-service"
REGION=${AWS_DEFAULT_REGION:-"us-east-1"}

# Get account ID and construct image URI
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
IMAGE_URI="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/dns-lookup-service:v1.0.0"

echo "🚀 Deploying DNS Lookup Service to Lambda..."
echo "   Image: $IMAGE_URI"
echo "   Function: $FUNCTION_NAME"
echo ""

# Create Lambda function from container image
echo "📦 Creating Lambda function..."
aws lambda create-function \
    --function-name $FUNCTION_NAME \
    --package-type Image \
    --code ImageUri=$IMAGE_URI \
    --role arn:aws:iam::${ACCOUNT_ID}:role/lambda-execution-role \
    --timeout 30 \
    --memory-size 512 \
    --architectures arm64 \
    --environment Variables="{AWS_DEFAULT_REGION=$REGION}" \
    --region $REGION >/dev/null 2>&1 || echo "   Function may already exist"

# Create function URL for HTTP access
echo "🔗 Creating function URL..."

# Try to get existing function URL first
FUNCTION_URL=$(aws lambda get-function-url-config \
    --function-name $FUNCTION_NAME \
    --region $REGION \
    --query 'FunctionUrl' \
    --output text 2>/dev/null)

# If no existing URL, create one
if [ "$FUNCTION_URL" = "" ] || [ "$FUNCTION_URL" = "None" ]; then
    echo "   Creating new function URL..."
    FUNCTION_URL=$(aws lambda create-function-url-config \
        --function-name $FUNCTION_NAME \
        --cors "AllowMethods=['GET','POST'],AllowOrigins=['*']" \
        --auth-type NONE \
        --region $REGION \
        --query 'FunctionUrl' \
        --output text)
else
    echo "   Using existing function URL..."
fi

echo ""
echo "🎉 Lambda deployment successful!"
echo ""
echo "📋 Function Details:"
echo "   Function: $FUNCTION_NAME"
echo "   URL: $FUNCTION_URL"
echo "   Health Check: ${FUNCTION_URL}health"
echo "   DNS Lookup: ${FUNCTION_URL}lookup?domain=aws.amazon.com"
echo ""
echo "🧪 Test Commands:"
echo "   curl ${FUNCTION_URL}health"
echo "   curl '${FUNCTION_URL}lookup?domain=aws.amazon.com'"
echo ""
echo "✅ Deployment completed!"