#!/bin/bash
# Foolproof CloudShell Calculator Test
# Uses stdin piping to avoid all encoding issues

echo "🛡️ Foolproof CloudShell Calculator Test"
echo "======================================="
echo ""

# Function to test Lambda with piped input
test_lambda_with_stdin() {
    local test_name="$1"
    local payload="$2"
    local expected="$3"
    
    echo "Testing: $test_name"
    echo "Payload: $payload"
    echo ""
    
    # Use stdin piping method
    echo "$payload" | aws lambda invoke \
        --function-name a208194-calculator-mcp-server \
        --region us-east-1 \
        --payload file:///dev/stdin \
        /dev/stdout 2>/dev/null
    
    echo ""
    echo "---"
    echo ""
}

# Test 1: MCP Tools List
test_lambda_with_stdin "MCP Tools List" \
    '{"jsonrpc":"2.0","method":"tools/list","id":1}' \
    "Should return list of 10 tools"

# Test 2: Simple Addition
test_lambda_with_stdin "Simple Addition (6+4)" \
    '{"jsonrpc":"2.0","method":"tools/call","params":{"name":"add","arguments":{"a":6,"b":4}},"id":2}' \
    "Should return: Addition: 6 + 4 = 10"

# Test 3: Multiplication
test_lambda_with_stdin "Multiplication (5×3)" \
    '{"jsonrpc":"2.0","method":"tools/call","params":{"name":"multiply","arguments":{"a":5,"b":3}},"id":3}' \
    "Should return: Multiplication: 5 × 3 = 15"

echo "🎯 Expected Results:"
echo "=================="
echo "✅ Test 1 should show: {'jsonrpc':'2.0','result':{'tools':[...]}"
echo "✅ Test 2 should show: 'Addition: 6 + 4 = 10'"
echo "✅ Test 3 should show: 'Multiplication: 5 × 3 = 15'"
echo ""
echo "If you see JSON responses with calculation results, your Lambda is working!"
echo ""
echo "📋 Manual Gateway Check:"
echo "   AWS Console → Bedrock → Agent Core → Gateways"
echo "   → a208194-askjulius-agentcore-gateway-mcp-iam"
echo "   → Targets tab → Check 'target-direct-calculator-lambda' status"