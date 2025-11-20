#!/bin/bash
# Clean validation script for AI Calculator MCP target
# Uses only AWS CLI - no Python dependencies needed

set -e

# Configuration from user
GATEWAY_URL="https://a208194-askjulius-agentcore-gateway-mcp-iam-fvro4phd59.gateway.bedrock-agentcore.us-east-1.amazonaws.com/mcp"
TARGET_NAME="target-lambda-direct-ai-calculator-mcp"
LAMBDA_ARN="arn:aws:lambda:us-east-1:818565325759:function:a208194-ai-bedrock-calculator-mcp-server"
REGION="us-east-1"

echo "🧪 AI Calculator Validation Script"
echo "=================================="
echo "Gateway: $GATEWAY_URL"
echo "Target: $TARGET_NAME"
echo "Lambda: $LAMBDA_ARN"
echo "Region: $REGION"
echo ""

# Test 1: Verify AWS CLI access
echo "🔍 Test 1: AWS CLI Authentication"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null || echo "ERROR")
if [ "$ACCOUNT_ID" = "ERROR" ]; then
    echo "❌ AWS CLI authentication failed"
    exit 1
else
    echo "✅ AWS CLI authenticated - Account: $ACCOUNT_ID"
fi
echo ""

# Test 2: Check Lambda function exists and is accessible
echo "🔍 Test 2: Lambda Function Accessibility"
LAMBDA_EXISTS=$(aws lambda get-function --function-name "a208194-ai-bedrock-calculator-mcp-server" --region $REGION --query 'Configuration.FunctionName' --output text 2>/dev/null || echo "ERROR")
if [ "$LAMBDA_EXISTS" = "ERROR" ]; then
    echo "❌ Lambda function not accessible or doesn't exist"
    echo "   Function: a208194-ai-bedrock-calculator-mcp-server"
    echo "   Region: $REGION"
else
    echo "✅ Lambda function exists: $LAMBDA_EXISTS"
    
    # Get Lambda runtime and role
    LAMBDA_RUNTIME=$(aws lambda get-function --function-name "a208194-ai-bedrock-calculator-mcp-server" --region $REGION --query 'Configuration.Runtime' --output text 2>/dev/null || echo "UNKNOWN")
    LAMBDA_ROLE=$(aws lambda get-function --function-name "a208194-ai-bedrock-calculator-mcp-server" --region $REGION --query 'Configuration.Role' --output text 2>/dev/null || echo "UNKNOWN")
    echo "   Runtime: $LAMBDA_RUNTIME"
    echo "   Role: $LAMBDA_ROLE"
fi
echo ""

# Test 3: Directly invoke Lambda function to test MCP functionality
echo "🔍 Test 3: Direct Lambda Invocation (MCP Test)"
cat > test_payload.json << 'EOF'
{
    "jsonrpc": "2.0",
    "id": "test-direct",
    "method": "tools/call",
    "params": {
        "name": "ai_calculate",
        "arguments": {
            "query": "What is 15% of $50,000?"
        }
    }
}
EOF

echo "📤 Invoking Lambda directly with MCP payload..."
LAMBDA_RESULT=$(aws lambda invoke \
    --function-name "a208194-ai-bedrock-calculator-mcp-server" \
    --region $REGION \
    --payload file://test_payload.json \
    --cli-binary-format raw-in-base64-out \
    lambda_response.json 2>&1 || echo "INVOKE_ERROR")

if [ "$LAMBDA_RESULT" = "INVOKE_ERROR" ]; then
    echo "❌ Lambda invocation failed"
else
    echo "✅ Lambda invoked successfully"
    echo "📥 Lambda Response:"
    if [ -f lambda_response.json ]; then
        cat lambda_response.json | jq . 2>/dev/null || cat lambda_response.json
        echo ""
        
        # Check if response contains expected MCP structure
        if grep -q '"jsonrpc"' lambda_response.json 2>/dev/null; then
            echo "✅ Lambda returns MCP JSON-RPC format"
            if grep -q '"result"' lambda_response.json 2>/dev/null; then
                echo "✅ Lambda processing successful - found result"
            elif grep -q '"error"' lambda_response.json 2>/dev/null; then
                echo "⚠️  Lambda processing error - check error details above"
            fi
        else
            echo "❌ Lambda not returning MCP JSON-RPC format"
        fi
    fi
fi
echo ""

# Test 4: Check Gateway service role permissions
echo "🔍 Test 4: Gateway Service Role Permissions"
SERVICE_ROLE="a208194-askjulius-agentcore-gateway"
ROLE_EXISTS=$(aws iam get-role --role-name "$SERVICE_ROLE" --query 'Role.RoleName' --output text 2>/dev/null || echo "ERROR")
if [ "$ROLE_EXISTS" = "ERROR" ]; then
    echo "❌ Gateway service role not found: $SERVICE_ROLE"
else
    echo "✅ Gateway service role exists: $SERVICE_ROLE"
    
    # Check trust policy
    echo "📋 Trust Policy:"
    aws iam get-role --role-name "$SERVICE_ROLE" --query 'Role.AssumeRolePolicyDocument' --output json | jq .Statement[].Principal.Service 2>/dev/null || echo "Could not parse trust policy"
    
    # Check attached policies
    echo "📋 Attached Policies:"
    aws iam list-attached-role-policies --role-name "$SERVICE_ROLE" --query 'AttachedPolicies[].PolicyName' --output table 2>/dev/null || echo "Could not list policies"
    
    # Check inline policies
    echo "📋 Inline Policies:"
    aws iam list-role-policies --role-name "$SERVICE_ROLE" --query 'PolicyNames' --output table 2>/dev/null || echo "Could not list inline policies"
fi
echo ""

# Test 5: Test specific Bedrock model access (Claude)
echo "🔍 Test 5: Bedrock Claude Model Access Test"
echo "📤 Testing Claude model access..."
BEDROCK_TEST=$(aws bedrock-runtime invoke-model \
    --region $REGION \
    --model-id anthropic.claude-3-sonnet-20240229-v1:0 \
    --body '{"messages":[{"role":"user","content":"Test: what is 2+2?"}],"max_tokens":100,"anthropic_version":"bedrock-2023-05-31"}' \
    bedrock_response.json 2>&1 || echo "BEDROCK_ERROR")

if [ "$BEDROCK_TEST" = "BEDROCK_ERROR" ]; then
    echo "❌ Bedrock Claude model access failed"
    echo "   This might be the root cause if Lambda tries to call Bedrock"
else
    echo "✅ Bedrock Claude model accessible"
    if [ -f bedrock_response.json ]; then
        echo "📥 Sample Bedrock Response:"
        head -c 200 bedrock_response.json 2>/dev/null || echo "Could not read response"
        echo ""
    fi
fi
echo ""

# Test 6: Check CloudWatch logs for recent errors
echo "🔍 Test 6: Recent CloudWatch Logs Check"
LOG_GROUP="/aws/lambda/a208194-ai-bedrock-calculator-mcp-server"
echo "📋 Checking recent logs in: $LOG_GROUP"

# Get recent log streams
RECENT_STREAM=$(aws logs describe-log-streams \
    --log-group-name "$LOG_GROUP" \
    --region $REGION \
    --order-by LastEventTime \
    --descending \
    --max-items 1 \
    --query 'logStreams[0].logStreamName' \
    --output text 2>/dev/null || echo "NO_LOGS")

if [ "$RECENT_STREAM" = "NO_LOGS" ] || [ "$RECENT_STREAM" = "None" ]; then
    echo "⚠️  No recent log streams found"
    echo "   This could indicate the Lambda hasn't been invoked recently"
else
    echo "📋 Most recent log stream: $RECENT_STREAM"
    echo "📋 Recent log events:"
    aws logs get-log-events \
        --log-group-name "$LOG_GROUP" \
        --log-stream-name "$RECENT_STREAM" \
        --region $REGION \
        --start-from-head \
        --limit 10 \
        --query 'events[?contains(message, `ERROR`) || contains(message, `Exception`) || contains(message, `error`)].{Time:timestamp,Message:message}' \
        --output table 2>/dev/null || echo "Could not retrieve log events"
fi
echo ""

# Summary and recommendations
echo "📊 VALIDATION SUMMARY"
echo "==================="
echo "Gateway URL: $GATEWAY_URL"
echo "Target Name: $TARGET_NAME"
echo "Lambda ARN: $LAMBDA_ARN"
echo ""
echo "🎯 NEXT STEPS BASED ON RESULTS:"
echo "1. If Lambda direct invocation works ✅ but gateway fails ❌:"
echo "   → Target configuration issue in gateway console"
echo "   → Check target name and schema in AWS Console"
echo ""
echo "2. If Lambda fails with Bedrock errors ❌:"
echo "   → Lambda execution role needs Bedrock permissions"
echo "   → Run: aws iam attach-role-policy --role-name \$LAMBDA_ROLE --policy-arn arn:aws:iam::aws:policy/service-role/AmazonBedrockFullAccess"
echo ""
echo "3. If Bedrock access fails ❌:"
echo "   → Your account may not have Claude model access enabled"
echo "   → Request access in Bedrock console: Model access → Anthropic Claude"
echo ""
echo "4. If everything works ✅ but gateway still fails:"
echo "   → Gateway routing issue, check AWS support"
echo ""

# Cleanup
rm -f test_payload.json lambda_response.json bedrock_response.json

echo "✅ Validation complete!"
echo ""
echo "💡 TIP: Copy the output above and check each test result"
echo "🔧 Focus on the first ❌ error to identify the root cause"