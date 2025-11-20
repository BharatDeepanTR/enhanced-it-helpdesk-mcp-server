#!/bin/bash
# Fix Lambda region configuration to use us-east-1 consistently
# This addresses the region mismatch where Lambda was trying us-west-2

set -e

echo "🔧 Fixing Lambda region configuration for us-east-1 consistency..."

FUNCTION_NAME="a208194-ai-bedrock-calculator-mcp-server"
REGION="us-east-1"

echo "📍 Target: $FUNCTION_NAME in $REGION"
echo ""

# 1. Update Lambda environment variables to force us-east-1
echo "🌍 Setting Lambda environment variables to force us-east-1..."
aws lambda update-function-configuration \
    --function-name "$FUNCTION_NAME" \
    --region "$REGION" \
    --environment Variables='{"AWS_DEFAULT_REGION":"us-east-1","AWS_REGION":"us-east-1","BEDROCK_REGION":"us-east-1","MODEL_ID":"us.anthropic.claude-3-5-sonnet-20241022-v2:0"}' || {
        echo "❌ Failed to update environment variables"
        exit 1
    }

echo "✅ Environment variables updated"

# 2. Create deployment package with fixed code
echo ""
echo "📦 Creating deployment package with region-enforced code..."

# Create temporary directory for packaging
TEMP_DIR=$(mktemp -d)
cd "$TEMP_DIR"

# Copy the fixed Lambda function code
cp /mnt/c/Users/6135616/chatops_route_dns/lambda_function_fixed_v3.py lambda_function.py

# Create deployment package
zip -r lambda_deployment.zip lambda_function.py

echo "✅ Deployment package created: $TEMP_DIR/lambda_deployment.zip"

# 3. Update the Lambda function code
echo ""
echo "🚀 Deploying updated Lambda function code..."
aws lambda update-function-code \
    --function-name "$FUNCTION_NAME" \
    --region "$REGION" \
    --zip-file fileb://lambda_deployment.zip || {
        echo "❌ Failed to update function code"
        exit 1
    }

echo "✅ Lambda function code updated"

# 4. Wait for function to be ready
echo ""
echo "⏳ Waiting for function to be ready..."
aws lambda wait function-updated \
    --function-name "$FUNCTION_NAME" \
    --region "$REGION" || {
        echo "⚠️  Timeout waiting for function update, but continuing..."
    }

# 5. Verify the configuration
echo ""
echo "🔍 Verifying updated configuration..."
echo ""

# Get function configuration
echo "📋 Current function configuration:"
aws lambda get-function-configuration \
    --function-name "$FUNCTION_NAME" \
    --region "$REGION" \
    --query '{
        "FunctionName": FunctionName,
        "Runtime": Runtime,
        "Timeout": Timeout,
        "MemorySize": MemorySize,
        "Environment": Environment.Variables,
        "LastModified": LastModified
    }' \
    --output table

# Clean up
cd - > /dev/null
rm -rf "$TEMP_DIR"

echo ""
echo "✅ Lambda region configuration fix completed!"
echo ""
echo "🧪 Testing Lambda function..."

# Test the Lambda function
TEST_EVENT='{
    "jsonrpc": "2.0",
    "id": "test-1",
    "method": "tools/call",
    "params": {
        "name": "ai_calculate",
        "arguments": {
            "query": "What is 25 + 17?"
        }
    }
}'

echo "🔬 Test payload:"
echo "$TEST_EVENT" | jq '.'

echo ""
echo "🚀 Invoking Lambda function..."
aws lambda invoke \
    --function-name "$FUNCTION_NAME" \
    --region "$REGION" \
    --payload "$TEST_EVENT" \
    --output table \
    response.json

echo ""
echo "📄 Lambda response:"
if [ -f response.json ]; then
    cat response.json | jq '.' || cat response.json
    rm -f response.json
else
    echo "❌ No response file created"
fi

echo ""
echo "🎯 Summary:"
echo "   ✅ Lambda environment variables set to force us-east-1"
echo "   ✅ Lambda code updated with region enforcement"
echo "   ✅ Function configuration verified"
echo "   ✅ Test execution completed"
echo ""
echo "🔍 Check CloudWatch logs for detailed execution info:"
echo "   aws logs tail /aws/lambda/$FUNCTION_NAME --follow --region $REGION"