#!/bin/bash
# Quick Lambda Function Test for CloudShell
# Test the specific Lambda ARN: arn:aws:lambda:us-east-1:818565325759:function:a208194-chatops_application_details_intent

echo "🧪 Quick Lambda Test for MCP Gateway"
echo "==================================="
echo ""

LAMBDA_ARN="arn:aws:lambda:us-east-1:818565325759:function:a208194-chatops_application_details_intent"

echo "📋 Testing Lambda: $LAMBDA_ARN"
echo ""

echo "🔍 Step 1: Basic Lambda Information"
echo "=================================="

echo "Getting Lambda function details..."

aws lambda get-function \
  --function-name "$LAMBDA_ARN" \
  --query 'Configuration.{FunctionName:FunctionName,Runtime:Runtime,Handler:Handler,State:State,Timeout:Timeout,MemorySize:MemorySize}' \
  --output table

echo ""
echo "🧪 Step 2: Test Lambda with MCP Tools/List"
echo "========================================"

echo "Testing MCP tools/list request..."

# Create MCP tools/list payload
cat > /tmp/mcp-test.json << 'EOF'
{
  "jsonrpc": "2.0",
  "id": "test-1",
  "method": "tools/list",
  "params": {}
}
EOF

echo "Payload:"
cat /tmp/mcp-test.json
echo ""

echo "Invoking Lambda..."

aws lambda invoke \
  --function-name "$LAMBDA_ARN" \
  --payload file:///tmp/mcp-test.json \
  --output json \
  /tmp/lambda-output.json

if [ $? -eq 0 ]; then
    echo "✅ Lambda invocation successful!"
    echo ""
    echo "📋 Response metadata:"
    cat /tmp/lambda-output.json
    echo ""
    
    echo "📋 Lambda output:"
    if [ -f "/tmp/lambda-output.json" ]; then
        # Check the actual response
        RESPONSE_CONTENT=$(cat /tmp/lambda-output.json)
        echo "$RESPONSE_CONTENT"
        
        # Analyze if it's MCP compliant
        echo ""
        echo "🔍 MCP Compliance Check:"
        
        if echo "$RESPONSE_CONTENT" | grep -q "tools"; then
            echo "✅ Response contains 'tools' - likely MCP compliant"
        else
            echo "⚠️  No 'tools' found in response"
        fi
        
        if echo "$RESPONSE_CONTENT" | grep -q "jsonrpc"; then
            echo "✅ Response contains 'jsonrpc' - JSON-RPC format"
        else
            echo "⚠️  No 'jsonrpc' found in response"
        fi
    fi
else
    echo "❌ Lambda invocation failed"
    echo "Check function permissions and configuration"
fi

echo ""
echo "🧪 Step 3: Test Lambda with Application Query"
echo "==========================================="

echo "Testing application details query..."

cat > /tmp/app-test.json << 'EOF'
{
  "jsonrpc": "2.0",
  "id": "test-2",
  "method": "tools/call",
  "params": {
    "name": "get_application_details",
    "arguments": {
      "application_name": "chatops"
    }
  }
}
EOF

echo "Application query payload:"
cat /tmp/app-test.json
echo ""

aws lambda invoke \
  --function-name "$LAMBDA_ARN" \
  --payload file:///tmp/app-test.json \
  --output json \
  /tmp/app-output.json

if [ $? -eq 0 ]; then
    echo "✅ Application query successful!"
    echo ""
    echo "📋 Application response:"
    cat /tmp/app-output.json
else
    echo "❌ Application query failed"
fi

echo ""
echo "📋 SUMMARY"
echo "=========="

if [ -f "/tmp/lambda-output.json" ]; then
    echo "✅ Lambda function is accessible and responding"
    
    # Quick analysis
    if grep -q "tools" /tmp/lambda-output.json 2>/dev/null; then
        echo "✅ Lambda appears to implement MCP tools/list"
        echo "🎯 Ready to configure in MCP gateway"
    else
        echo "⚠️  Lambda may need MCP protocol implementation"
        echo "🔧 Check if function returns proper tools/list response"
    fi
else
    echo "❌ Lambda function test failed"
    echo "🔧 Need to check function permissions and code"
fi

echo ""
echo "🚀 Next Steps:"
echo "1. If Lambda is working: Configure it in your MCP gateway"
echo "2. If Lambda needs fixes: Update the function code"
echo "3. Test end-to-end: Gateway → Lambda → Response"

echo ""
echo "📁 Test files created:"
echo "   /tmp/mcp-test.json - MCP tools/list payload"
echo "   /tmp/app-test.json - Application query payload"
echo "   /tmp/lambda-output.json - Lambda response"
echo "   /tmp/app-output.json - Application response"

# Cleanup
echo ""
echo "🧹 Cleaning up..."
rm -f /tmp/mcp-test.json /tmp/app-test.json
echo "✅ Test completed!"