#!/bin/bash
# Corrected Comprehensive Diagnostic - Using CORRECT Lambda Names
# Calculator: a208194-calculator-mcp-server
# App Details: a208194-chatops_application_details_intent

set -e

echo "🔍 CORRECTED COMPREHENSIVE DIAGNOSTIC"
echo "====================================="
echo "Using CORRECT Lambda function names"
echo ""

# CORRECTED Function details
CALC_LAMBDA="a208194-calculator-mcp-server"
APP_LAMBDA="a208194-chatops_application_details_intent"
REGION="us-east-1"

echo "📋 STEP 1: Lambda Function Analysis (CORRECTED)"
echo "-----------------------------------------------"
echo "Calculator Lambda: $CALC_LAMBDA"
echo "App Details Lambda: $APP_LAMBDA"
echo ""

# Test both Lambda functions directly
echo "🧪 Testing Calculator Lambda (known working):"
aws lambda invoke \
    --function-name "$CALC_LAMBDA" \
    --payload "$(echo '{"operation": "add", "x": 5, "y": 3}' | base64 -w 0)" \
    /tmp/calc_test.json \
    --region "$REGION" && echo "✅ Calculator Response:" && cat /tmp/calc_test.json && echo ""

echo "🧪 Testing Application Details Lambda (broken):"
aws lambda invoke \
    --function-name "$APP_LAMBDA" \
    --payload "$(echo '{"asset_id": "a208194"}' | base64 -w 0)" \
    /tmp/app_test.json \
    --region "$REGION" && echo "📋 App Details Response:" && cat /tmp/app_test.json && echo ""

echo ""
echo "📋 STEP 2: Gateway Discovery"
echo "---------------------------"

echo "🔍 Looking for Agent Core Gateways with various CLI approaches..."

# Try multiple CLI approaches for listing gateways
echo "   Method 1: bedrock-agent list-agent-core-gateways"
if aws bedrock-agent list-agent-core-gateways --region "$REGION" 2>/dev/null; then
    echo "   ✅ Found gateways via bedrock-agent"
else
    echo "   ❌ Method 1 failed"
fi

echo ""
echo "   Method 2: bedrock list-agent-core-gateways"
if aws bedrock list-agent-core-gateways --region "$REGION" 2>/dev/null; then
    echo "   ✅ Found gateways via bedrock"
else
    echo "   ❌ Method 2 failed"
fi

echo ""
echo "   Method 3: bedrock-agent-runtime list-agent-core-gateways"
if aws bedrock-agent-runtime list-agent-core-gateways --region "$REGION" 2>/dev/null; then
    echo "   ✅ Found gateways via bedrock-agent-runtime"
else
    echo "   ❌ Method 3 failed"
fi

echo ""
echo "📋 STEP 3: Direct Gateway Testing"
echo "---------------------------------"

# Try to find the correct gateway
TARGET_GATEWAY="a208194-askjulius-agentcore-gateway-mcp-iam"
echo "🎯 Testing target gateway: $TARGET_GATEWAY"

# Try different describe approaches
echo "   Method 1: describe-agent-core-gateway"
aws bedrock-agent describe-agent-core-gateway \
    --gateway-identifier "$TARGET_GATEWAY" \
    --region "$REGION" 2>/dev/null && echo "   ✅ Gateway found via bedrock-agent" || echo "   ❌ Gateway not found via bedrock-agent"

echo "   Method 2: get-agent-core-gateway"  
aws bedrock-agent get-agent-core-gateway \
    --gateway-identifier "$TARGET_GATEWAY" \
    --region "$REGION" 2>/dev/null && echo "   ✅ Gateway found via get-agent-core-gateway" || echo "   ❌ Gateway not found via get-agent-core-gateway"

echo ""
echo "📋 STEP 4: Lambda Configuration Comparison"
echo "-----------------------------------------"

echo "📊 Calculator Lambda Configuration (WORKING):"
aws lambda get-function-configuration \
    --function-name "$CALC_LAMBDA" \
    --region "$REGION" \
    --query '{Runtime:Runtime,Handler:Handler,Role:Role,LastModified:LastModified}' \
    --output yaml

echo ""
echo "📊 Application Details Lambda Configuration (BROKEN):"
aws lambda get-function-configuration \
    --function-name "$APP_LAMBDA" \
    --region "$REGION" \
    --query '{Runtime:Runtime,Handler:Handler,Role:Role,LastModified:LastModified}' \
    --output yaml

echo ""
echo "📋 STEP 5: API Gateway Endpoint Discovery"
echo "----------------------------------------"

echo "🔍 All API Gateway REST APIs:"
aws apigateway get-rest-apis \
    --region "$REGION" \
    --query 'items[?contains(name, `agentcore`) || contains(name, `mcp`) || contains(name, `gateway`)].{Name:name,Id:id,Description:description}' \
    --output table

echo ""
echo "📋 STEP 6: Working Pattern Analysis"
echo "----------------------------------"

echo "🎯 KEY ANALYSIS:"
echo "   1. Calculator Lambda: $CALC_LAMBDA"
echo "   2. Does calculator Lambda work directly? (see test above)"
echo "   3. App Details Lambda: $APP_LAMBDA"
echo "   4. Does app details Lambda work directly? (see test above)"
echo "   5. Target Gateway: $TARGET_GATEWAY"
echo "   6. Does the gateway actually exist? (see gateway tests above)"

echo ""
echo "💡 ROOT CAUSE IDENTIFICATION:"
echo "   - If calculator works but app details fails → Lambda code issue"
echo "   - If gateway not found → Gateway doesn't exist yet"
echo "   - If both fail → Need to check calculator working pattern"

echo ""
echo "🚀 NEXT ACTIONS:"
echo "   1. Fix app details Lambda syntax error (known issue)"
echo "   2. Confirm gateway exists or create it"
echo "   3. Get working endpoint from calculator setup"
echo "   4. Test with correct configuration"