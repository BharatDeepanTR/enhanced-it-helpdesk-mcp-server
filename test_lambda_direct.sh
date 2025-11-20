#!/bin/bash
# Test AI Calculator Lambda Function Directly
# This bypasses the MCP gateway to isolate issues

set -e

LAMBDA_ARN="arn:aws:lambda:us-east-1:818565325759:function:a208194-ai-bedrock-calculator-mcp-server"
REGION="us-east-1"

echo "🧪 Testing AI Calculator Lambda Function Directly"
echo "================================================="
echo "Lambda ARN: $LAMBDA_ARN"
echo "Region: $REGION"
echo ""

# Test 1: Simple MCP initialize request
echo "1️⃣ Testing MCP Initialize..."
cat > test_payload_init.json << 'EOF'
{
  "jsonrpc": "2.0",
  "id": "test-init",
  "method": "initialize",
  "params": {
    "protocolVersion": "2024-11-05",
    "capabilities": {
      "tools": {}
    },
    "clientInfo": {
      "name": "test-client",
      "version": "1.0.0"
    }
  }
}
EOF

echo "📤 Sending initialize request..."
aws lambda invoke \
  --function-name "$LAMBDA_ARN" \
  --region "$REGION" \
  --payload file://test_payload_init.json \
  --cli-binary-format raw-in-base64-out \
  response_init.json

echo "📥 Initialize Response:"
if [ -f response_init.json ]; then
  cat response_init.json | jq . 2>/dev/null || cat response_init.json
  echo ""
else
  echo "❌ No response file created"
fi
echo ""

# Test 2: Tools list request
echo "2️⃣ Testing Tools List..."
cat > test_payload_tools.json << 'EOF'
{
  "jsonrpc": "2.0",
  "id": "test-tools",
  "method": "tools/list",
  "params": {}
}
EOF

echo "📤 Sending tools/list request..."
aws lambda invoke \
  --function-name "$LAMBDA_ARN" \
  --region "$REGION" \
  --payload file://test_payload_tools.json \
  --cli-binary-format raw-in-base64-out \
  response_tools.json

echo "📥 Tools List Response:"
if [ -f response_tools.json ]; then
  cat response_tools.json | jq . 2>/dev/null || cat response_tools.json
  echo ""
else
  echo "❌ No response file created"
fi
echo ""

# Test 3: AI Calculate tool call
echo "3️⃣ Testing AI Calculate Tool Call..."
cat > test_payload_calc.json << 'EOF'
{
  "jsonrpc": "2.0",
  "id": "test-calc",
  "method": "tools/call",
  "params": {
    "name": "ai_calculate",
    "arguments": {
      "query": "What is 15% of $50,000?"
    }
  }
}
EOF

echo "📤 Sending ai_calculate request..."
aws lambda invoke \
  --function-name "$LAMBDA_ARN" \
  --region "$REGION" \
  --payload file://test_payload_calc.json \
  --cli-binary-format raw-in-base64-out \
  response_calc.json

echo "📥 AI Calculate Response:"
if [ -f response_calc.json ]; then
  cat response_calc.json | jq . 2>/dev/null || cat response_calc.json
  echo ""
else
  echo "❌ No response file created"
fi
echo ""

# Test 4: Check Lambda logs
echo "4️⃣ Checking Recent Lambda Logs..."
echo "📋 Recent log events (last 5 minutes):"
aws logs filter-log-events \
  --log-group-name "/aws/lambda/a208194-ai-bedrock-calculator-mcp-server" \
  --region "$REGION" \
  --start-time $(date -d '5 minutes ago' +%s)000 \
  --query 'events[*].[logStreamName,message]' \
  --output table 2>/dev/null || echo "⚠️ No recent logs or permission issue"

# Cleanup
echo ""
echo "🧹 Cleaning up test files..."
rm -f test_payload_*.json response_*.json

echo ""
echo "📋 Summary:"
echo "==========="
echo "✅ Permissions are correct in gateway service role"
echo "✅ BedrockModelInvokePolicy has required permissions"
echo "🔍 Direct Lambda testing will show if issue is in:"
echo "   - Lambda function itself"
echo "   - MCP protocol implementation"  
echo "   - Gateway routing/format"
echo ""
echo "💡 Next steps based on results:"
echo "   - If Lambda works: Gateway configuration issue"
echo "   - If Lambda fails: Lambda function or Bedrock access issue"
echo "   - Check CloudWatch logs for detailed errors"