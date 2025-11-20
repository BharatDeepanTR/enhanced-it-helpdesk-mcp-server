#!/bin/bash
# Diagnose Gateway and Target Configuration Issues
# Check what's actually configured vs what we expect

echo "🔍 Gateway and Target Configuration Diagnosis"
echo "=" * 60

# Configuration
GATEWAY_NAME="a208194-askjulius-agentcore-gateway-mcp-iam"
REGION="us-east-1"
LAMBDA_ARN="arn:aws:lambda:us-east-1:818565325759:function:a208194-ai-bedrock-calculator-mcp-server"

echo "Gateway Name: $GATEWAY_NAME"
echo "Expected Target: target-lambda-direct-ai-calculator-mcp"
echo "Lambda ARN: $LAMBDA_ARN"
echo ""

# Check Lambda function exists and configuration
echo "🔍 1. Checking Lambda Function Configuration..."
echo "------------------------------------------------"

if aws lambda get-function --function-name "a208194-ai-bedrock-calculator-mcp-server" --region $REGION >/dev/null 2>&1; then
    echo "✅ Lambda function exists"
    
    echo ""
    echo "📋 Lambda function details:"
    aws lambda get-function --function-name "a208194-ai-bedrock-calculator-mcp-server" \
        --region $REGION \
        --query 'Configuration.{FunctionName:FunctionName,Runtime:Runtime,Role:Role,Handler:Handler,LastModified:LastModified}' \
        --output table
        
    echo ""
    echo "📋 Lambda execution role:"
    aws lambda get-function --function-name "a208194-ai-bedrock-calculator-mcp-server" \
        --region $REGION \
        --query 'Configuration.Role' \
        --output text
        
else
    echo "❌ Lambda function not found!"
    echo "Please check the function name and region"
    exit 1
fi

echo ""
echo "🔍 2. Testing Lambda Function Directly..."
echo "------------------------------------------------"

# Test Lambda function directly
echo "Testing Lambda function with MCP payload..."

cat > test-payload.json << 'EOF'
{
  "jsonrpc": "2.0",
  "id": "direct-test",
  "method": "tools/call",
  "params": {
    "name": "ai_calculate",
    "arguments": {
      "query": "What is 15% of $50,000?"
    }
  }
}
EOF

echo "📤 Invoking Lambda directly..."
aws lambda invoke \
    --function-name "a208194-ai-bedrock-calculator-mcp-server" \
    --region $REGION \
    --payload file://test-payload.json \
    --cli-binary-format raw-in-base64-out \
    lambda-response.json

echo ""
echo "📥 Lambda direct response:"
if [ -f lambda-response.json ]; then
    cat lambda-response.json | jq '.' 2>/dev/null || cat lambda-response.json
    echo ""
else
    echo "❌ No response file created"
fi

# Check Lambda logs for errors
echo ""
echo "🔍 3. Recent Lambda Logs (last 5 minutes)..."
echo "------------------------------------------------"

# Get the latest log group
LOG_GROUP="/aws/lambda/a208194-ai-bedrock-calculator-mcp-server"

echo "Checking log group: $LOG_GROUP"

# Get recent log events (last 5 minutes)
START_TIME=$(date -d '5 minutes ago' '+%s')000
END_TIME=$(date '+%s')000

aws logs filter-log-events \
    --log-group-name "$LOG_GROUP" \
    --region $REGION \
    --start-time $START_TIME \
    --end-time $END_TIME \
    --query 'events[*].[timestamp,message]' \
    --output table 2>/dev/null || echo "⚠️  No recent logs found or log group doesn't exist"

echo ""
echo "🔍 4. Gateway Configuration Check..."
echo "------------------------------------------------"

# Unfortunately, we can't directly query Agent Core Gateway via CLI
# But we can check the service role permissions
SERVICE_ROLE="a208194-askjulius-agentcore-gateway"

echo "Service Role: $SERVICE_ROLE"
echo ""
echo "📋 Service role policies:"
aws iam list-attached-role-policies \
    --role-name $SERVICE_ROLE \
    --region $REGION \
    --query 'AttachedPolicies[*].[PolicyName,PolicyArn]' \
    --output table 2>/dev/null || echo "❌ Cannot access service role"

echo ""
echo "📋 Service role trust policy:"
aws iam get-role \
    --role-name $SERVICE_ROLE \
    --region $REGION \
    --query 'Role.AssumeRolePolicyDocument' 2>/dev/null || echo "❌ Cannot access trust policy"

echo ""
echo "🔍 5. Diagnosis Summary..."
echo "=================================================="

if [ -f lambda-response.json ]; then
    if grep -q "error" lambda-response.json; then
        echo "❌ Lambda function has errors - check the response above"
        echo "🔧 Common issues:"
        echo "   - Missing environment variables"
        echo "   - Bedrock permissions issues"
        echo "   - Code execution errors"
    elif grep -q "result" lambda-response.json; then
        echo "✅ Lambda function works directly!"
        echo "🎯 Issue is likely in Gateway target configuration:"
        echo "   - Target name mismatch in console"
        echo "   - Wrong tool schema configuration"
        echo "   - MCP protocol version mismatch"
    else
        echo "⚠️  Lambda response unclear - check response above"
    fi
else
    echo "❌ Could not test Lambda function directly"
fi

echo ""
echo "🛠️  Next Steps:"
echo "1. Check Lambda response above for any errors"
echo "2. If Lambda works, verify target name in AWS Console"
echo "3. Compare tool schema in console with expected schema"
echo "4. Ensure target is configured as 'Lambda ARN' type"

# Cleanup
rm -f test-payload.json lambda-response.json