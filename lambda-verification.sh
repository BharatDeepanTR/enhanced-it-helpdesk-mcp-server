#!/bin/bash
# Lambda Function Code Verification
# Since direct invocation has encoding issues, let's verify the code deployment

echo "🔍 Lambda Function Code Verification"
echo "===================================="
echo ""

FUNCTION_NAME="a208194-calculator-mcp-server"
REGION="us-east-1"

echo "Checking Lambda function: $FUNCTION_NAME"
echo ""

# 1. Check if Lambda function exists and basic info
echo "📋 Lambda Function Details:"
echo "=========================="
aws lambda get-function \
    --function-name "$FUNCTION_NAME" \
    --region "$REGION" \
    --query '{
        FunctionName: Configuration.FunctionName,
        State: Configuration.State,
        Runtime: Configuration.Runtime,
        Handler: Configuration.Handler,
        LastModified: Configuration.LastModified,
        CodeSize: Configuration.CodeSize,
        Description: Configuration.Description
    }' \
    --output table

echo ""

# 2. Check function configuration
echo "⚙️ Function Configuration:"
echo "========================="
aws lambda get-function-configuration \
    --function-name "$FUNCTION_NAME" \
    --region "$REGION" \
    --query '{
        Timeout: Timeout,
        MemorySize: MemorySize,
        Environment: Environment.Variables
    }' \
    --output json

echo ""

# 3. Check recent invocations (metrics)
echo "📊 Recent Activity (Last 24 hours):"
echo "=================================="
aws logs describe-log-streams \
    --log-group-name "/aws/lambda/$FUNCTION_NAME" \
    --region "$REGION" \
    --order-by LastEventTime \
    --descending \
    --max-items 5 \
    --query 'logStreams[*].{LogStream: logStreamName, LastEventTime: lastEventTime, StoredBytes: storedBytes}' \
    --output table

echo ""

# 4. Get recent logs (if any)
echo "📋 Recent Log Events:"
echo "===================="
aws logs filter-log-events \
    --log-group-name "/aws/lambda/$FUNCTION_NAME" \
    --region "$REGION" \
    --start-time $(date -d '1 hour ago' +%s)000 \
    --query 'events[*].[logStream, message]' \
    --output table

echo ""

# 5. Check IAM permissions for the function
echo "🔐 Function Execution Role:"
echo "=========================="
EXECUTION_ROLE=$(aws lambda get-function \
    --function-name "$FUNCTION_NAME" \
    --region "$REGION" \
    --query 'Configuration.Role' \
    --output text)

echo "Execution Role: $EXECUTION_ROLE"

if [ "$EXECUTION_ROLE" != "None" ] && [ "$EXECUTION_ROLE" != "null" ]; then
    ROLE_NAME=$(echo "$EXECUTION_ROLE" | sed 's|.*role/||')
    echo "Role Name: $ROLE_NAME"
    
    echo ""
    echo "Attached Policies:"
    aws iam list-attached-role-policies \
        --role-name "$ROLE_NAME" \
        --query 'AttachedPolicies[*].PolicyName' \
        --output table 2>/dev/null
fi

echo ""

# 6. Alternative test using AWS CloudShell-specific method
echo "🌩️ CloudShell Alternative Test Method:"
echo "======================================"
echo ""
echo "Since direct invocation has encoding issues, here's what to do:"
echo ""
echo "1. 📁 Upload Test File Method:"
echo "   Create a file called 'test-payload.json' with this content:"
echo "   {\"jsonrpc\":\"2.0\",\"method\":\"tools/list\",\"id\":1}"
echo ""
echo "   Then run:"
echo "   aws lambda invoke --function-name $FUNCTION_NAME --payload file://test-payload.json --region $REGION response.json"
echo "   cat response.json"
echo ""
echo "2. 🔧 Alternative: Check Lambda Code Deployment:"
echo "   The encoding error suggests the Lambda might not have the correct code deployed."
echo "   Expected: MCP-compliant calculator code with JSON-RPC 2.0 support"
echo ""
echo "3. 🎯 Gateway Status Check:"
echo "   Since Lambda testing has encoding issues, check gateway directly:"
echo "   • AWS Console → Bedrock → Agent Core → Gateways"
echo "   • a208194-askjulius-agentcore-gateway-mcp-iam"
echo "   • Targets tab → target-direct-calculator-lambda"
echo "   • Status should be 'Active' with green indicator"
echo ""
echo "4. 📋 Manual Console Test:"
echo "   In the Gateway console, try the 'Test' button if available"
echo "   Use simple prompts like: 'Calculate 5 plus 3'"
echo ""

# 7. Provide the exact file content needed
echo ""
echo "📝 Manual File Creation for CloudShell:"
echo "======================================="
echo ""
echo "If you want to test manually, create this file as 'test-payload.json':"
echo ""
cat << 'EOF'
{
    "jsonrpc": "2.0",
    "method": "tools/list", 
    "id": 1
}
EOF

echo ""
echo "Then run: aws lambda invoke --function-name $FUNCTION_NAME --payload file://test-payload.json --region $REGION response.json"
echo ""

# 8. Check if the function code is correct
echo "🔍 Verify Lambda Code Deployment:"
echo "================================="
echo ""
echo "The encoding error (CTRL-CHAR, code 142) suggests:"
echo "• Lambda function might not have the correct MCP calculator code deployed"
echo "• Or the deployed code has encoding issues"
echo "• Or the Lambda handler is not properly configured"
echo ""
echo "Expected Handler: lambda_function.lambda_handler"
echo "Expected Runtime: python3.10 or python3.11"
echo ""
echo "✅ Next Steps:"
echo "1. Verify Lambda has the calculator-lambda-with-comprehensive-inline-schemas.py code"
echo "2. Check Handler configuration matches the deployed code"
echo "3. Test Gateway target status in AWS Console"
echo "4. If Gateway shows 'Active', the integration should work despite local encoding issues"