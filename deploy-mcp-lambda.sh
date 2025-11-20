#!/bin/bash
# Deploy MCP-Compatible Application Details Lambda Function
# This script deploys the Lambda function and updates the Agent Core Gateway

set -e

# Configuration
FUNCTION_NAME="a208194-mcp-application-details"
ROLE_NAME="a208194-mcp-app-details-role"
REGION="us-east-1"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null || echo "818565325759")

echo "🚀 Deploying MCP-Compatible Application Details Lambda"
echo "Function Name: $FUNCTION_NAME"
echo "Region: $REGION"
echo "Account ID: $ACCOUNT_ID"
echo ""

# Create execution role if it doesn't exist
echo "🔍 Checking execution role..."
if aws iam get-role --role-name "$ROLE_NAME" >/dev/null 2>&1; then
    echo "   ✅ Role '$ROLE_NAME' already exists"
else
    echo "   🛠️  Creating execution role..."
    
    # Create the role
    aws iam create-role \
        --role-name "$ROLE_NAME" \
        --assume-role-policy-document file://lambda-trust-policy.json \
        --description "Execution role for MCP-compatible application details Lambda"
    
    # Attach basic Lambda execution policy
    aws iam attach-role-policy \
        --role-name "$ROLE_NAME" \
        --policy-arn "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
    
    # Attach custom policy for data access
    aws iam put-role-policy \
        --role-name "$ROLE_NAME" \
        --policy-name "DataAccessPolicy" \
        --policy-document file://lambda-execution-policy.json
    
    echo "   ✅ Role created successfully"
    echo "   ⏳ Waiting 10 seconds for role propagation..."
    sleep 10
fi

ROLE_ARN="arn:aws:iam::${ACCOUNT_ID}:role/${ROLE_NAME}"

# Check if function exists
echo ""
echo "🔍 Checking Lambda function..."
if aws lambda get-function --function-name "$FUNCTION_NAME" >/dev/null 2>&1; then
    echo "   🔄 Function exists, updating code..."
    
    aws lambda update-function-code \
        --function-name "$FUNCTION_NAME" \
        --zip-file fileb://mcp-application-details-lambda.zip
    
    echo "   ✅ Function code updated"
else
    echo "   🛠️  Creating new function..."
    
    aws lambda create-function \
        --function-name "$FUNCTION_NAME" \
        --runtime python3.11 \
        --role "$ROLE_ARN" \
        --handler lambda_function.lambda_handler \
        --zip-file fileb://mcp-application-details-lambda.zip \
        --timeout 30 \
        --memory-size 128 \
        --description "MCP-compatible application details service for Agent Core Gateway"
    
    echo "   ✅ Function created successfully"
fi

# Get function ARN
FUNCTION_ARN=$(aws lambda get-function --function-name "$FUNCTION_NAME" --query 'Configuration.FunctionArn' --output text)

echo ""
echo "📋 Lambda Function Details:"
echo "   Function Name: $FUNCTION_NAME"
echo "   Function ARN: $FUNCTION_ARN"
echo "   Role ARN: $ROLE_ARN"

# Test the function
echo ""
echo "🧪 Testing function with MCP protocol..."

cat > test-payload.json << EOF
{
    "method": "tools/list",
    "id": 1
}
EOF

echo "   Testing tools/list..."
TEST_RESULT=$(aws lambda invoke \
    --function-name "$FUNCTION_NAME" \
    --payload file://test-payload.json \
    --output text \
    test-response.json)

if [ $? -eq 0 ]; then
    echo "   ✅ Function responds to MCP protocol"
    echo "   📄 Response preview:"
    head -n 3 test-response.json | sed 's/^/      /'
else
    echo "   ❌ Function test failed"
fi

# Test with actual asset lookup
cat > test-payload-2.json << EOF
{
    "method": "tools/call",
    "id": 2,
    "params": {
        "name": "get_application_details",
        "arguments": {
            "asset_id": "a123456"
        }
    }
}
EOF

echo ""
echo "   Testing application details lookup..."
TEST_RESULT_2=$(aws lambda invoke \
    --function-name "$FUNCTION_NAME" \
    --payload file://test-payload-2.json \
    --output text \
    test-response-2.json)

if [ $? -eq 0 ]; then
    echo "   ✅ Application details lookup working"
    echo "   📄 Response preview:"
    head -n 5 test-response-2.json | sed 's/^/      /'
else
    echo "   ❌ Application details test failed"
fi

# Clean up test files
rm -f test-payload.json test-payload-2.json test-response.json test-response-2.json

echo ""
echo "🎯 Next Steps:"
echo "================================"
echo "1. Update Agent Core Gateway to use this Lambda:"
echo "   Lambda ARN: $FUNCTION_ARN"
echo ""
echo "2. Add application details target to gateway:"
echo "   Target Name: target-direct-application-details-lambda"
echo "   Description: Application details lookup with MCP protocol support"
echo ""
echo "3. Update gateway service role permissions:"
echo "   Add permission to invoke: $FUNCTION_ARN"
echo ""
echo "4. Test gateway integration:"
echo "   Use target name: target-direct-application-details-lambda___get_application_details"
echo ""
if [ -f "create-agentcore-gateway.sh" ]; then
    echo "5. Run updated gateway script:"
    echo "   ./create-agentcore-gateway-with-app-details.sh"
    echo ""
fi
echo "✅ MCP-Compatible Lambda deployment completed!"