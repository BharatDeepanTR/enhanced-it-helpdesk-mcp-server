#!/bin/bash
# Fixed CloudShell Calculator Lambda Test
# Proper JSON payload formatting for Lambda invoke

echo "🌩️ Fixed CloudShell Calculator Test"
echo "==================================="
echo ""

# Create test directory
mkdir -p ~/calculator-test
cd ~/calculator-test

echo "📁 Working directory: $(pwd)"
echo ""

# Test 1: MCP Tools List Test (Fixed)
echo "🔧 Test 1: MCP Tools List"
echo "========================="

# Create proper JSON payload file
cat > tools-list-payload.json << 'EOF'
{
    "jsonrpc": "2.0",
    "method": "tools/list",
    "id": 1
}
EOF

echo "Payload:"
cat tools-list-payload.json
echo ""

# Invoke with file payload (this avoids encoding issues)
aws lambda invoke \
    --function-name "a208194-calculator-mcp-server" \
    --payload file://tools-list-payload.json \
    --region us-east-1 \
    tools-response.json

if [ -f tools-response.json ]; then
    echo "✅ Lambda invocation successful"
    echo "Response:"
    cat tools-response.json | jq '.'
    
    # Check if tools are present
    TOOL_COUNT=$(cat tools-response.json | jq '.result.tools | length' 2>/dev/null || echo "0")
    echo ""
    echo "📊 Found $TOOL_COUNT calculator tools"
    
    if [ "$TOOL_COUNT" -gt 0 ]; then
        echo "✅ MCP Protocol working - Tools available:"
        cat tools-response.json | jq -r '.result.tools[].name' | sed 's/^/   • /'
    else
        echo "❌ No tools found in response"
    fi
else
    echo "❌ Lambda invocation failed - no response file"
fi
echo ""

# Test 2: Simple Addition Test (Fixed)
echo "🧮 Test 2: Addition Calculation (5 + 3)"
echo "======================================="

# Create proper calculation payload
cat > add-payload.json << 'EOF'
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

echo "Payload:"
cat add-payload.json
echo ""

# Invoke calculation
aws lambda invoke \
    --function-name "a208194-calculator-mcp-server" \
    --payload file://add-payload.json \
    --region us-east-1 \
    calc-response.json

if [ -f calc-response.json ]; then
    echo "✅ Calculation invocation successful"
    echo "Response:"
    cat calc-response.json | jq '.'
    
    # Extract calculation result
    RESULT_TEXT=$(cat calc-response.json | jq -r '.result.content[0].text' 2>/dev/null || echo "No result")
    echo ""
    echo "📊 Calculation Result: $RESULT_TEXT"
    
    if echo "$RESULT_TEXT" | grep -q "5 + 3 = 8"; then
        echo "✅ Calculation is correct!"
    else
        echo "⚠️  Unexpected calculation result"
    fi
else
    echo "❌ Calculation failed - no response file"
fi
echo ""

# Test 3: Error Handling (Division by Zero)
echo "🚫 Test 3: Error Handling (10 ÷ 0)"
echo "=================================="

cat > divide-zero-payload.json << 'EOF'
{
    "jsonrpc": "2.0",
    "method": "tools/call",
    "params": {
        "name": "divide",
        "arguments": {
            "a": 10,
            "b": 0
        }
    },
    "id": 3
}
EOF

echo "Payload:"
cat divide-zero-payload.json
echo ""

aws lambda invoke \
    --function-name "a208194-calculator-mcp-server" \
    --payload file://divide-zero-payload.json \
    --region us-east-1 \
    error-response.json

if [ -f error-response.json ]; then
    echo "✅ Error test invocation successful"
    echo "Response:"
    cat error-response.json | jq '.'
    
    # Check error handling
    IS_ERROR=$(cat error-response.json | jq '.result.isError' 2>/dev/null || echo "false")
    ERROR_TEXT=$(cat error-response.json | jq -r '.result.content[0].text' 2>/dev/null || echo "No error text")
    echo ""
    echo "📊 Error Status: $IS_ERROR"
    echo "📊 Error Message: $ERROR_TEXT"
    
    if [ "$IS_ERROR" = "true" ] && echo "$ERROR_TEXT" | grep -qi "division by zero"; then
        echo "✅ Error handling working correctly!"
    else
        echo "⚠️  Error handling may need review"
    fi
else
    echo "❌ Error test failed - no response file"
fi
echo ""

# Test 4: Advanced Function (Square Root)
echo "📐 Test 4: Advanced Function (√25)"
echo "================================="

cat > sqrt-payload.json << 'EOF'
{
    "jsonrpc": "2.0",
    "method": "tools/call",
    "params": {
        "name": "sqrt",
        "arguments": {
            "number": 25
        }
    },
    "id": 4
}
EOF

echo "Payload:"
cat sqrt-payload.json
echo ""

aws lambda invoke \
    --function-name "a208194-calculator-mcp-server" \
    --payload file://sqrt-payload.json \
    --region us-east-1 \
    sqrt-response.json

if [ -f sqrt-response.json ]; then
    echo "✅ Square root test successful"
    echo "Response:"
    cat sqrt-response.json | jq '.'
    
    SQRT_RESULT=$(cat sqrt-response.json | jq -r '.result.content[0].text' 2>/dev/null || echo "No result")
    echo ""
    echo "📊 Square Root Result: $SQRT_RESULT"
    
    if echo "$SQRT_RESULT" | grep -q "√25 = 5"; then
        echo "✅ Square root calculation correct!"
    else
        echo "⚠️  Square root result unexpected"
    fi
else
    echo "❌ Square root test failed"
fi
echo ""

# Test 5: Check CloudWatch Logs
echo "📋 Test 5: Recent CloudWatch Logs"
echo "================================="

echo "Fetching recent Lambda execution logs..."
aws logs filter-log-events \
    --log-group-name "/aws/lambda/a208194-calculator-mcp-server" \
    --start-time $(date -d '10 minutes ago' +%s)000 \
    --region us-east-1 \
    --query 'events[*].[logStream, message]' \
    --output table | head -20

echo ""

# Summary Report
echo "📊 VALIDATION SUMMARY"
echo "===================="
echo ""

# Check each test result
if [ -f tools-response.json ] && cat tools-response.json | jq -e '.result.tools' >/dev/null 2>&1; then
    echo "✅ MCP Protocol: Working"
else
    echo "❌ MCP Protocol: Failed"
fi

if [ -f calc-response.json ] && cat calc-response.json | jq -e '.result.content[0].text' >/dev/null 2>&1; then
    echo "✅ Basic Math: Working"
else
    echo "❌ Basic Math: Failed"
fi

if [ -f error-response.json ] && [ "$(cat error-response.json | jq '.result.isError' 2>/dev/null)" = "true" ]; then
    echo "✅ Error Handling: Working"
else
    echo "❌ Error Handling: Failed"
fi

if [ -f sqrt-response.json ] && cat sqrt-response.json | jq -e '.result.content[0].text' >/dev/null 2>&1; then
    echo "✅ Advanced Functions: Working"
else
    echo "❌ Advanced Functions: Failed"
fi

echo ""
echo "🎯 Next Steps:"
echo "   1. If all tests ✅: Calculator Lambda is ready for Gateway integration"
echo "   2. Check Gateway target status in AWS Console"
echo "   3. Test end-to-end via Bedrock Agent interaction"
echo ""
echo "🔗 AWS Console Links:"
echo "   • Lambda: https://console.aws.amazon.com/lambda/home?region=us-east-1#/functions/a208194-calculator-mcp-server"
echo "   • Gateway: https://console.aws.amazon.com/bedrock/home?region=us-east-1#/agent-core/gateways"
echo "   • CloudWatch: https://console.aws.amazon.com/cloudwatch/home?region=us-east-1#logsV2:log-groups/log-group/\$252Faws\$252Flambda\$252Fa208194-calculator-mcp-server"

# Cleanup
echo ""
echo "🧹 Cleaning up test files..."
rm -f *-payload.json *-response.json

echo "✅ Validation complete!"