#!/bin/bash
# Test Agent Core Gateway with Calculator Lambda Target
# Gateway: a208194-askjulius-agentcore-gateway-mcp-iam
# Target: target-direct-calculator-lambda

set -e

GATEWAY_ID="a208194-askjulius-agentcore-gateway-mcp-iam"
REGION="us-east-1"

echo "🧮 Testing Calculator Lambda Target via Agent Core Gateway"
echo "Gateway: $GATEWAY_ID"
echo "Target: target-direct-calculator-lambda"
echo "Region: $REGION"
echo ""

# Test 1: Simple Addition
echo "📋 Test 1: Basic Addition (5 + 3)"
cat > test-addition.json << 'EOF'
{
    "inputText": "Calculate 5 + 3",
    "sessionId": "test-session-001"
}
EOF

echo "Request:"
cat test-addition.json
echo ""

aws bedrock-agent-runtime invoke-agent \
    --agent-id "$GATEWAY_ID" \
    --session-id "test-session-001" \
    --input-text "Calculate 5 + 3" \
    --region "$REGION" \
    response-addition.json

echo "Response:"
cat response-addition.json | jq '.'
echo ""

# Test 2: Division with validation
echo "📋 Test 2: Division (15 ÷ 3)"
aws bedrock-agent-runtime invoke-agent \
    --agent-id "$GATEWAY_ID" \
    --session-id "test-session-002" \
    --input-text "Divide 15 by 3" \
    --region "$REGION" \
    response-division.json

echo "Response:"
cat response-division.json | jq '.'
echo ""

# Test 3: Square Root
echo "📋 Test 3: Square Root (√16)"
aws bedrock-agent-runtime invoke-agent \
    --agent-id "$GATEWAY_ID" \
    --session-id "test-session-003" \
    --input-text "What is the square root of 16?" \
    --region "$REGION" \
    response-sqrt.json

echo "Response:"
cat response-sqrt.json | jq '.'
echo ""

# Test 4: Advanced - Trigonometry
echo "📋 Test 4: Trigonometry (sin(30°))"
aws bedrock-agent-runtime invoke-agent \
    --agent-id "$GATEWAY_ID" \
    --session-id "test-session-004" \
    --input-text "Calculate sine of 30 degrees" \
    --region "$REGION" \
    response-trig.json

echo "Response:"
cat response-trig.json | jq '.'
echo ""

# Test 5: Error Handling - Division by Zero
echo "📋 Test 5: Error Handling (5 ÷ 0)"
aws bedrock-agent-runtime invoke-agent \
    --agent-id "$GATEWAY_ID" \
    --session-id "test-session-005" \
    --input-text "Divide 5 by 0" \
    --region "$REGION" \
    response-error.json

echo "Response:"
cat response-error.json | jq '.'
echo ""

# Clean up test files
echo "🧹 Cleaning up test files..."
rm -f test-*.json response-*.json

echo ""
echo "✅ Calculator target testing completed!"
echo ""
echo "🔍 What to look for in responses:"
echo "   ✅ Successful calculations return correct numeric results"
echo "   ✅ Error cases (division by zero) return appropriate error messages"
echo "   ✅ Gateway properly routes requests to calculator Lambda"
echo "   ✅ MCP protocol communication working correctly"
echo ""
echo "📊 Expected Results:"
echo "   Test 1 (5+3): Should return 8"
echo "   Test 2 (15÷3): Should return 5"
echo "   Test 3 (√16): Should return 4"
echo "   Test 4 (sin(30°)): Should return 0.5"
echo "   Test 5 (5÷0): Should return error message"