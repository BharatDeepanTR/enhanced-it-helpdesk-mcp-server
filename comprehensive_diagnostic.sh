#!/bin/bash
# Comprehensive Diagnostic - Compare Working vs Broken Setup
# This script analyzes what's different between calculator (working) and application details (broken)

set -e

echo "🔍 COMPREHENSIVE DIAGNOSTIC ANALYSIS"
echo "===================================="
echo "Comparing working calculator Lambda vs application details Lambda"
echo ""

# Function details
CALC_LAMBDA="a208194-askjulius-calculator"
APP_LAMBDA="a208194-chatops_application_details_intent"
REGION="us-east-1"

echo "📋 STEP 1: Lambda Function Analysis"
echo "-----------------------------------"

# Test both Lambda functions directly
echo "🧪 Testing Calculator Lambda (known working):"
aws lambda invoke \
    --function-name "$CALC_LAMBDA" \
    --payload "$(echo '{"operation": "add", "x": 5, "y": 3}' | base64 -w 0)" \
    /tmp/calc_test.json \
    --region "$REGION" && echo "Response:" && cat /tmp/calc_test.json && echo ""

echo "🧪 Testing Application Details Lambda (broken):"
aws lambda invoke \
    --function-name "$APP_LAMBDA" \
    --payload "$(echo '{"asset_id": "a208194"}' | base64 -w 0)" \
    /tmp/app_test.json \
    --region "$REGION" && echo "Response:" && cat /tmp/app_test.json && echo ""

echo ""
echo "📋 STEP 2: Gateway Analysis"
echo "---------------------------"

echo "🔍 Listing all Agent Core Gateways:"
if aws bedrock-agent list-agent-core-gateways --region "$REGION" 2>/dev/null; then
    echo "✅ Found gateways via bedrock-agent"
elif aws bedrock list-agent-core-gateways --region "$REGION" 2>/dev/null; then
    echo "✅ Found gateways via bedrock"
elif aws bedrock-agent-runtime list-agent-core-gateways --region "$REGION" 2>/dev/null; then
    echo "✅ Found gateways via bedrock-agent-runtime"
else
    echo "❌ Could not list gateways - checking alternative commands..."
    echo ""
    echo "🔍 Checking if gateways exist via describe commands:"
    
    # Try to describe the calculator gateway (working)
    echo "   Calculator gateway (working):"
    aws bedrock-agent describe-agent-core-gateway \
        --gateway-identifier "a208194-askjulius-agentcore-mcp-gateway" \
        --region "$REGION" 2>/dev/null || echo "   ❌ Calculator gateway not found"
    
    # Try to describe the app details gateway
    echo "   Application details gateway:"
    aws bedrock-agent describe-agent-core-gateway \
        --gateway-identifier "a208194-askjulius-agentcore-gateway-mcp-iam" \
        --region "$REGION" 2>/dev/null || echo "   ❌ App details gateway not found"
fi

echo ""
echo "📋 STEP 3: Endpoint Discovery"
echo "----------------------------"

# Try to find the actual endpoints
echo "🔍 Searching for gateway endpoints..."

# Method 1: Check if calculator gateway endpoint is known
CALC_GATEWAY_URL="https://a208194-askjulius-agentcore-mcp-gateway-dhy8ntpcvu.execute-api.us-east-1.amazonaws.com/v1"
echo "🧪 Testing calculator gateway endpoint:"
echo "   URL: $CALC_GATEWAY_URL"

# Try tools/list on calculator gateway
curl -s -X POST "$CALC_GATEWAY_URL" \
    -H "Content-Type: application/json" \
    -d '{"jsonrpc": "2.0", "id": 1, "method": "tools/list"}' \
    --aws-sigv4 "aws:amz:us-east-1:bedrock-agentcore" \
    --user "$AWS_ACCESS_KEY_ID:$AWS_SECRET_ACCESS_KEY" 2>/dev/null || echo "   ❌ Calculator gateway not accessible"

echo ""

# Method 2: Check API Gateway endpoints
echo "🔍 Checking API Gateway endpoints:"
aws apigateway get-rest-apis --region "$REGION" --query 'items[?contains(name, `agentcore`) || contains(name, `mcp`)].{Name:name,Id:id}' --output table

echo ""
echo "📋 STEP 4: Authentication Comparison"
echo "------------------------------------"

echo "🔑 Current AWS Identity:"
aws sts get-caller-identity

echo ""
echo "🔑 Testing different authentication approaches:"

# Test 1: bedrock service
echo "   Test 1: bedrock service authentication"
python3 -c "
import boto3
from requests_aws4auth import AWS4Auth
session = boto3.Session(region_name='us-east-1')
creds = session.get_credentials()
auth = AWS4Auth(creds.access_key, creds.secret_key, 'us-east-1', 'bedrock', session_token=creds.token)
print(f'   ✅ Bedrock auth created: {auth.service}')
"

# Test 2: bedrock-agentcore service
echo "   Test 2: bedrock-agentcore service authentication"
python3 -c "
import boto3
from requests_aws4auth import AWS4Auth
session = boto3.Session(region_name='us-east-1')
creds = session.get_credentials()
auth = AWS4Auth(creds.access_key, creds.secret_key, 'us-east-1', 'bedrock-agentcore', session_token=creds.token)
print(f'   ✅ Bedrock-agentcore auth created: {auth.service}')
"

echo ""
echo "📋 STEP 5: Working Calculator Analysis"
echo "-------------------------------------"

echo "🔍 If calculator Lambda worked, let's analyze its setup:"
echo "   1. What gateway was it using?"
echo "   2. What was the exact endpoint?"
echo "   3. What authentication method worked?"
echo "   4. What was the tool name format?"

# Try to get calculator lambda configuration
echo ""
echo "📊 Calculator Lambda Configuration:"
aws lambda get-function-configuration --function-name "$CALC_LAMBDA" --region "$REGION" --query '{Runtime:Runtime,Handler:Handler,Role:Role,Environment:Environment}' --output yaml

echo ""
echo "📊 Application Details Lambda Configuration:"
aws lambda get-function-configuration --function-name "$APP_LAMBDA" --region "$REGION" --query '{Runtime:Runtime,Handler:Handler,Role:Role,Environment:Environment}' --output yaml

echo ""
echo "📋 STEP 6: Root Cause Analysis"
echo "------------------------------"

echo "🎯 Key Questions to Answer:"
echo "   1. Does the IAM gateway actually exist?"
echo "   2. What is the correct endpoint URL?"
echo "   3. Is the Lambda function syntax fixed?"
echo "   4. Are we using the right tool naming convention?"
echo "   5. What made calculator work that we're missing here?"

echo ""
echo "💡 NEXT STEPS:"
echo "   1. Fix Lambda syntax error first (known issue)"
echo "   2. Find or create the correct gateway"
echo "   3. Get the actual endpoint URL"
echo "   4. Test with working authentication pattern"
echo ""
echo "🎯 Let's focus on ONE thing at a time instead of trying everything!"