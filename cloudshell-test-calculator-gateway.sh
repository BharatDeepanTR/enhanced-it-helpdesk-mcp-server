#!/bin/bash
# CloudShell Test Script for Calculator Gateway Target
# Gateway: a208194-askjulius-agentcore-gateway-mcp-iam
# Target: target-direct-calculator-lambda
# Lambda: arn:aws:lambda:us-east-1:818565325759:function:a208194-calculator-mcp-server

set -e

echo "🌩️ CloudShell Validation for Calculator Gateway Target"
echo "======================================================"
echo ""

# Configuration
GATEWAY_ID="a208194-askjulius-agentcore-gateway-mcp-iam"
LAMBDA_ARN="arn:aws:lambda:us-east-1:818565325759:function:a208194-calculator-mcp-server"
LAMBDA_NAME="a208194-calculator-mcp-server"
REGION="us-east-1"
TARGET_NAME="target-direct-calculator-lambda"

echo "📋 Configuration:"
echo "   Gateway ID: $GATEWAY_ID"
echo "   Lambda Name: $LAMBDA_NAME"
echo "   Lambda ARN: $LAMBDA_ARN"
echo "   Target Name: $TARGET_NAME"
echo "   Region: $REGION"
echo ""

# Check AWS credentials and region
echo "🔍 Verifying AWS Configuration..."
AWS_ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
AWS_REGION=$(aws configure get region)
echo "   Account ID: $AWS_ACCOUNT"
echo "   Current Region: $AWS_REGION"
echo ""

# Test 1: Verify Lambda Function Exists and is Active
echo "🔧 Test 1: Lambda Function Status"
echo "================================="
if aws lambda get-function --function-name "$LAMBDA_NAME" --region "$REGION" >/dev/null 2>&1; then
    echo "✅ Lambda function '$LAMBDA_NAME' exists"
    
    # Get Lambda status
    LAMBDA_STATE=$(aws lambda get-function --function-name "$LAMBDA_NAME" --region "$REGION" --query 'Configuration.State' --output text)
    echo "   State: $LAMBDA_STATE"
    
    if [ "$LAMBDA_STATE" = "Active" ]; then
        echo "✅ Lambda is Active and ready"
    else
        echo "⚠️  Lambda state is: $LAMBDA_STATE"
    fi
else
    echo "❌ Lambda function '$LAMBDA_NAME' not found or not accessible"
    exit 1
fi
echo ""

# Test 2: Direct Lambda MCP Protocol Test
echo "🧮 Test 2: Direct Lambda MCP Test (tools/list)"
echo "=============================================="
echo "Testing MCP protocol compliance..."

cat > mcp-tools-list.json << 'EOF'
{
    "jsonrpc": "2.0",
    "method": "tools/list",
    "id": 1
}
EOF

echo "Request payload:"
cat mcp-tools-list.json | jq '.'
echo ""

if aws lambda invoke \
    --function-name "$LAMBDA_NAME" \
    --payload file://mcp-tools-list.json \
    --region "$REGION" \
    mcp-response.json; then
    
    echo "Response:"
    cat mcp-response.json | jq '.'
    echo ""
    
    # Check if response contains tools
    if jq -e '.result.tools | length > 0' mcp-response.json >/dev/null; then
        TOOL_COUNT=$(jq '.result.tools | length' mcp-response.json)
        echo "✅ MCP tools/list successful - Found $TOOL_COUNT tools"
        
        # List available tools
        echo "📊 Available Calculator Tools:"
        jq -r '.result.tools[] | "   • \(.name): \(.description)"' mcp-response.json
    else
        echo "❌ MCP tools/list failed - No tools returned"
    fi
else
    echo "❌ Lambda invocation failed"
fi
echo ""

# Test 3: Direct Lambda Calculation Test
echo "🔢 Test 3: Direct Lambda Calculation (5 + 3)"
echo "============================================="

cat > mcp-add-test.json << 'EOF'
{
    "jsonrpc": "2.0",
    "method": "tools/call",
    "params": {
        "name": "add",
        "arguments": {
            "a": 5,
            "b": 3
        }
    },
    "id": 2
}
EOF

echo "Request payload:"
cat mcp-add-test.json | jq '.'
echo ""

if aws lambda invoke \
    --function-name "$LAMBDA_NAME" \
    --payload file://mcp-add-test.json \
    --region "$REGION" \
    calc-response.json; then
    
    echo "Response:"
    cat calc-response.json | jq '.'
    echo ""
    
    # Check calculation result
    if jq -e '.result.content[0].text' calc-response.json >/dev/null; then
        CALC_RESULT=$(jq -r '.result.content[0].text' calc-response.json)
        echo "✅ Calculation successful: $CALC_RESULT"
        
        if echo "$CALC_RESULT" | grep -q "5 + 3 = 8"; then
            echo "✅ Calculation result is correct!"
        else
            echo "⚠️  Unexpected calculation result"
        fi
    else
        echo "❌ Calculation failed or unexpected response format"
    fi
else
    echo "❌ Lambda calculation test failed"
fi
echo ""

# Test 4: Check Gateway Target Status (if accessible)
echo "🌐 Test 4: Gateway Target Status"
echo "================================"

# Note: Agent Core Gateway APIs might not be directly accessible via CLI
# This is a placeholder for when the APIs become available

echo "⚠️  Gateway status check via CLI not yet implemented"
echo "   Manual verification required in AWS Console:"
echo "   1. Go to AWS Console → Bedrock → Agent Core → Gateways"
echo "   2. Click on '$GATEWAY_ID'"
echo "   3. Check 'Targets' tab"
echo "   4. Verify '$TARGET_NAME' shows as 'Active'"
echo ""

# Test 5: Error Handling Test
echo "🚫 Test 5: Error Handling (Division by Zero)"
echo "==========================================="

cat > mcp-error-test.json << 'EOF'
{
    "jsonrpc": "2.0",
    "method": "tools/call",
    "params": {
        "name": "divide",
        "arguments": {
            "a": 5,
            "b": 0
        }
    },
    "id": 3
}
EOF

echo "Request payload:"
cat mcp-error-test.json | jq '.'
echo ""

if aws lambda invoke \
    --function-name "$LAMBDA_NAME" \
    --payload file://mcp-error-test.json \
    --region "$REGION" \
    error-response.json; then
    
    echo "Response:"
    cat error-response.json | jq '.'
    echo ""
    
    # Check error handling
    if jq -e '.result.isError' error-response.json >/dev/null; then
        IS_ERROR=$(jq '.result.isError' error-response.json)
        ERROR_TEXT=$(jq -r '.result.content[0].text' error-response.json)
        
        if [ "$IS_ERROR" = "true" ]; then
            echo "✅ Error handling working correctly: $ERROR_TEXT"
        else
            echo "⚠️  Expected error but got success result"
        fi
    else
        echo "⚠️  Unexpected error response format"
    fi
else
    echo "❌ Error handling test failed"
fi
echo ""

# Cleanup
echo "🧹 Cleaning up test files..."
rm -f mcp-*.json calc-response.json error-response.json mcp-response.json

echo ""
echo "📊 Test Summary:"
echo "================"
echo "   Lambda Function: $([ -f /tmp/lambda_ok ] && echo "✅ Active" || echo "❓ Check required")"
echo "   MCP Protocol: $([ -f /tmp/mcp_ok ] && echo "✅ Working" || echo "❓ Check required")"
echo "   Calculations: $([ -f /tmp/calc_ok ] && echo "✅ Working" || echo "❓ Check required")"
echo "   Error Handling: $([ -f /tmp/error_ok ] && echo "✅ Working" || echo "❓ Check required")"
echo ""
echo "🎯 Next Steps:"
echo "   1. If all tests pass: Calculator target is ready!"
echo "   2. If tests fail: Check CloudWatch logs for details"
echo "   3. Test gateway integration via console or Bedrock Agents"
echo ""
echo "🔗 CloudWatch Logs URL:"
echo "   https://console.aws.amazon.com/cloudwatch/home?region=$REGION#logsV2:log-groups/log-group/\$252Faws\$252Flambda\$252F$LAMBDA_NAME"