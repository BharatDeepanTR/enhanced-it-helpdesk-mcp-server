#!/bin/bash
# Deploy MCP-compatible Application Details Lambda

set -e

LAMBDA_NAME="a208194-mcp-application-details"
REGION="us-east-1"
ROLE_NAME="a208194-lambda-execution-role"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null || echo "ACCOUNT_ID_NEEDED")
EXISTING_LAMBDA="a208194-chatops_application_details_intent"

echo "🚀 Deploying MCP-compatible Application Details Lambda..."
echo "New Lambda Name: $LAMBDA_NAME"
echo "Region: $REGION"
echo "Account ID: $ACCOUNT_ID"
echo ""

# Check if execution role exists, create if needed
echo "🔍 Checking Lambda execution role..."
ROLE_ARN="arn:aws:iam::${ACCOUNT_ID}:role/${ROLE_NAME}"

if aws iam get-role --role-name "$ROLE_NAME" >/dev/null 2>&1; then
    echo "   ✅ Role '$ROLE_NAME' found"
else
    echo "   🛠️  Creating Lambda execution role..."
    
    # Create trust policy
    cat > lambda-trust-policy.json << EOF
{
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
}
EOF

    # Create the role
    aws iam create-role \
        --role-name "$ROLE_NAME" \
        --assume-role-policy-document file://lambda-trust-policy.json \
        --description "Execution role for MCP Lambda functions"
    
    # Attach basic Lambda execution policy
    aws iam attach-role-policy \
        --role-name "$ROLE_NAME" \
        --policy-arn "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
    
    # Attach Lambda invoke policy for calling other Lambdas
    aws iam attach-role-policy \
        --role-name "$ROLE_NAME" \
        --policy-arn "arn:aws:iam::aws:policy/service-role/AWSLambdaRole"
    
    echo "   ✅ Role created successfully"
    echo "   ⏳ Waiting 15 seconds for role propagation..."
    sleep 15
    
    rm -f lambda-trust-policy.json
fi

# Create deployment package
echo ""
echo "📦 Creating deployment package..."
mkdir -p lambda-package
cp mcp_compatible_application_details_lambda.py lambda-package/lambda_function.py

# Create a simple requirements.txt if needed
cat > lambda-package/requirements.txt << EOF
boto3
requests
EOF

cd lambda-package

# Create zip package
echo "   📝 Creating ZIP file..."
zip -r ../mcp-application-details-lambda.zip . >/dev/null

cd ..
rm -rf lambda-package

echo "   ✅ Package created: mcp-application-details-lambda.zip"

# Deploy or update the Lambda function
echo ""
echo "🚀 Deploying Lambda function..."

if aws lambda get-function --function-name "$LAMBDA_NAME" --region "$REGION" >/dev/null 2>&1; then
    echo "   🔄 Updating existing function..."
    aws lambda update-function-code \
        --function-name "$LAMBDA_NAME" \
        --zip-file fileb://mcp-application-details-lambda.zip \
        --region "$REGION"
    
    # Update configuration if needed
    aws lambda update-function-configuration \
        --function-name "$LAMBDA_NAME" \
        --runtime python3.9 \
        --handler lambda_function.lambda_handler \
        --timeout 30 \
        --memory-size 256 \
        --region "$REGION"
    
    echo "   ✅ Function updated successfully"
else
    echo "   🆕 Creating new function..."
    aws lambda create-function \
        --function-name "$LAMBDA_NAME" \
        --runtime python3.9 \
        --role "$ROLE_ARN" \
        --handler lambda_function.lambda_handler \
        --zip-file fileb://mcp-application-details-lambda.zip \
        --description "MCP-compatible Application Details Lambda with proper response format" \
        --timeout 30 \
        --memory-size 256 \
        --region "$REGION"
    
    echo "   ✅ Function created successfully"
fi

# Test the function
echo ""
echo "🧪 Testing deployed function..."

TEST_PAYLOAD='{"asset_id": "a123456"}'
aws lambda invoke \
    --function-name "$LAMBDA_NAME" \
    --payload "$TEST_PAYLOAD" \
    --region "$REGION" \
    response.json

if [ -f response.json ]; then
    echo "   📄 Test response:"
    cat response.json | python3 -m json.tool || cat response.json
    echo ""
    rm -f response.json
fi

# Test MCP format
echo ""
echo "🔧 Testing MCP format..."
MCP_TEST_PAYLOAD='{"method": "tools/list", "id": 1}'
aws lambda invoke \
    --function-name "$LAMBDA_NAME" \
    --payload "$MCP_TEST_PAYLOAD" \
    --region "$REGION" \
    mcp-response.json

if [ -f mcp-response.json ]; then
    echo "   📄 MCP test response:"
    cat mcp-response.json | python3 -m json.tool || cat mcp-response.json
    echo ""
    rm -f mcp-response.json
fi

# Clean up
rm -f mcp-application-details-lambda.zip

NEW_LAMBDA_ARN="arn:aws:lambda:${REGION}:${ACCOUNT_ID}:function:${LAMBDA_NAME}"

echo ""
echo "✅ Deployment complete!"
echo "📝 Summary:"
echo "   Function Name: $LAMBDA_NAME"
echo "   ARN: $NEW_LAMBDA_ARN"
echo "   Region: $REGION"
echo ""
echo "🔧 Next Steps:"
echo "1. Update your gateway configuration to use: $NEW_LAMBDA_ARN"
echo "2. Test the gateway with the new MCP-compatible Lambda"
echo "3. If this works, consider updating the existing Lambda: $EXISTING_LAMBDA"
echo ""
echo "💡 To use this Lambda ARN in your gateway:"
echo "   Replace the Lambda ARN in create-agentcore-gateway.sh with:"
echo "   $NEW_LAMBDA_ARN"