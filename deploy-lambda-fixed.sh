#!/bin/bash
# Simple Lambda deployment for DNS lookup service

set -e

FUNCTION_NAME="dns-lookup-service"
REGION=${AWS_DEFAULT_REGION:-"us-east-1"}

# Get account ID and construct image URI
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
IMAGE_URI="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/dns-lookup-service:v1.0.0"

echo "🚀 Deploying DNS Lookup Service to Lambda..."
echo "   Account: $ACCOUNT_ID"
echo "   Image: $IMAGE_URI"
echo "   Function: $FUNCTION_NAME"
echo "   Region: $REGION"
echo ""

# Check if function exists
echo "🔍 Checking if function exists..."
if aws lambda get-function --function-name $FUNCTION_NAME --region $REGION >/dev/null 2>&1; then
    echo "   Function exists, updating..."
    aws lambda update-function-code \
        --function-name $FUNCTION_NAME \
        --image-uri $IMAGE_URI \
        --region $REGION >/dev/null
else
    echo "   Creating new function..."
    
    # Create a basic execution role first if needed
    echo "🔐 Ensuring execution role exists..."
    aws iam create-role \
        --role-name lambda-execution-role \
        --assume-role-policy-document '{
            "Version": "2012-10-17",
            "Statement": [
                {
                    "Effect": "Allow",
                    "Principal": {
                        "Service": "lambda.amazonaws.com"
                    },
                    "Action": "sts:AssumeRole"
                }
            ]
        }' >/dev/null 2>&1 || echo "   Role already exists"
    
    # Attach basic execution policy
    aws iam attach-role-policy \
        --role-name lambda-execution-role \
        --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole >/dev/null 2>&1 || true
    
    # Wait a moment for role to propagate
    echo "   Waiting for role to propagate..."
    sleep 10
    
    # Create Lambda function
    aws lambda create-function \
        --function-name $FUNCTION_NAME \
        --package-type Image \
        --code ImageUri=$IMAGE_URI \
        --role arn:aws:iam::${ACCOUNT_ID}:role/lambda-execution-role \
        --timeout 30 \
        --memory-size 512 \
        --architectures arm64 \
        --environment Variables="{AWS_DEFAULT_REGION=$REGION}" \
        --region $REGION >/dev/null
fi

# Wait for function to be ready
echo "⏳ Waiting for function to be ready..."
aws lambda wait function-active --function-name $FUNCTION_NAME --region $REGION

# Handle function URL creation
echo "🔗 Setting up function URL..."
FUNCTION_URL=""

# Try to get existing function URL
FUNCTION_URL=$(aws lambda get-function-url-config \
    --function-name $FUNCTION_NAME \
    --region $REGION \
    --query 'FunctionUrl' \
    --output text 2>/dev/null || echo "")

if [ "$FUNCTION_URL" = "" ] || [ "$FUNCTION_URL" = "None" ]; then
    echo "   Creating function URL..."
    FUNCTION_URL=$(aws lambda create-function-url-config \
        --function-name $FUNCTION_NAME \
        --cors "AllowMethods=['GET','POST'],AllowOrigins=['*']" \
        --auth-type NONE \
        --region $REGION \
        --query 'FunctionUrl' \
        --output text)
    echo "   ✅ Function URL created"
else
    echo "   ✅ Function URL already exists"
fi

echo ""
echo "🎉 Lambda deployment successful!"
echo ""
echo "📋 Function Details:"
echo "   Function Name: $FUNCTION_NAME"
echo "   Function URL: $FUNCTION_URL"
echo "   Region: $REGION"
echo "   Architecture: ARM64"
echo ""
echo "🧪 Test Commands:"
echo "   Health Check:"
echo "     curl ${FUNCTION_URL}health"
echo ""
echo "   DNS Lookup:"
echo "     curl '${FUNCTION_URL}lookup?domain=aws.amazon.com'"
echo ""
echo "📋 Your container host for testing:"
echo "   ${FUNCTION_URL%/}"
echo ""
echo "✅ Ready for Bedrock Agent Core integration!"