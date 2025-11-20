#!/bin/bash
# One-liner CloudShell Tests for Calculator Lambda

echo "🔧 One-Liner Calculator Tests"
echo "============================="
echo ""

# Test 1: Simple Tools List
echo "1️⃣ Testing MCP Tools List..."
echo '{"jsonrpc":"2.0","method":"tools/list","id":1}' > test.json && \
aws lambda invoke --function-name a208194-calculator-mcp-server --payload file://test.json --region us-east-1 result.json && \
echo "Tools found: $(cat result.json | jq '.result.tools | length')" && \
rm test.json result.json

echo ""

# Test 2: Simple Addition
echo "2️⃣ Testing Addition (7 + 3)..."
echo '{"jsonrpc":"2.0","method":"tools/call","params":{"name":"add","arguments":{"a":7,"b":3}},"id":2}' > test.json && \
aws lambda invoke --function-name a208194-calculator-mcp-server --payload file://test.json --region us-east-1 result.json && \
echo "Result: $(cat result.json | jq -r '.result.content[0].text')" && \
rm test.json result.json

echo ""

# Test 3: Division Test
echo "3️⃣ Testing Division (20 ÷ 4)..."
echo '{"jsonrpc":"2.0","method":"tools/call","params":{"name":"divide","arguments":{"a":20,"b":4}},"id":3}' > test.json && \
aws lambda invoke --function-name a208194-calculator-mcp-server --payload file://test.json --region us-east-1 result.json && \
echo "Result: $(cat result.json | jq -r '.result.content[0].text')" && \
rm test.json result.json

echo ""
echo "✅ Quick tests completed!"
echo ""
echo "📋 Expected Results:"
echo "   Tools found: 10"
echo "   Addition: 7 + 3 = 10" 
echo "   Division: 20 ÷ 4 = 5"