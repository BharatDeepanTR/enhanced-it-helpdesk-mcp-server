#!/bin/bash
# Quick CloudShell Setup and Test for Calculator Target

echo "🌩️ CloudShell Quick Test Setup"
echo "=============================="
echo ""

# Create test directory
mkdir -p ~/calculator-gateway-test
cd ~/calculator-gateway-test

echo "📁 Working directory: $(pwd)"
echo ""

# Test 1: Quick Lambda Verification
echo "🔧 Quick Lambda Test:"
echo "===================="

aws lambda invoke \
    --function-name "a208194-calculator-mcp-server" \
    --payload '{"jsonrpc":"2.0","method":"tools/list","id":1}' \
    --region us-east-1 \
    quick-test.json

echo "Response:"
cat quick-test.json | jq '.result.tools | length' 2>/dev/null || echo "Error in response"
echo ""

# Test 2: Simple Calculation
echo "🧮 Quick Calculation Test (2 + 2):"
echo "=================================="

aws lambda invoke \
    --function-name "a208194-calculator-mcp-server" \
    --payload '{"jsonrpc":"2.0","method":"tools/call","params":{"name":"add","arguments":{"a":2,"b":2}},"id":2}' \
    --region us-east-1 \
    calc-test.json

echo "Response:"
cat calc-test.json | jq -r '.result.content[0].text' 2>/dev/null || echo "Error in calculation"
echo ""

# Test 3: Check CloudWatch Logs (last 5 minutes)
echo "📊 Recent Lambda Logs:"
echo "====================="

aws logs filter-log-events \
    --log-group-name "/aws/lambda/a208194-calculator-mcp-server" \
    --start-time $(date -d '5 minutes ago' +%s)000 \
    --region us-east-1 \
    --query 'events[*].message' \
    --output text | tail -10

echo ""
echo "✅ Quick tests completed!"
echo ""
echo "🔗 Manual Validation Steps:"
echo "   1. Check AWS Console → Bedrock → Agent Core → Gateways"
echo "   2. Select: a208194-askjulius-agentcore-gateway-mcp-iam"
echo "   3. Go to 'Targets' tab"
echo "   4. Verify 'target-direct-calculator-lambda' is Active"
echo "   5. Try test invocation if available"

# Cleanup
rm -f quick-test.json calc-test.json