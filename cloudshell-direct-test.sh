#!/bin/bash
# CloudShell Calculator Test - No File Dependencies
# Direct AWS CLI invocation with proper encoding

echo "🌩️ Direct CloudShell Calculator Test"
echo "===================================="
echo ""

FUNCTION_NAME="a208194-calculator-mcp-server"
REGION="us-east-1"

echo "Testing Lambda: $FUNCTION_NAME"
echo "Region: $REGION"
echo ""

# Test 1: Direct invoke with base64 encoding (AWS CLI handles this)
echo "🔧 Test 1: MCP Tools List (Direct Method)"
echo "========================================="

RESPONSE=$(aws lambda invoke \
    --function-name "$FUNCTION_NAME" \
    --payload '{"jsonrpc":"2.0","method":"tools/list","id":1}' \
    --region "$REGION" \
    --cli-binary-format raw-in-base64-out \
    /dev/stdout 2>/dev/null)

if [ $? -eq 0 ] && [ -n "$RESPONSE" ]; then
    echo "✅ Lambda invocation successful"
    echo "Response:"
    echo "$RESPONSE" | jq '.'
    
    # Count tools
    TOOL_COUNT=$(echo "$RESPONSE" | jq '.result.tools | length' 2>/dev/null || echo "0")
    echo ""
    echo "📊 Tools found: $TOOL_COUNT"
    
    if [ "$TOOL_COUNT" -gt 0 ]; then
        echo "✅ MCP Protocol working!"
        echo "Available tools:"
        echo "$RESPONSE" | jq -r '.result.tools[].name' | sed 's/^/   • /'
    fi
else
    echo "❌ Lambda invocation failed"
    
    # Try alternative method
    echo ""
    echo "🔄 Trying alternative invoke method..."
    
    # Method 2: Using temporary file with proper encoding
    echo '{"jsonrpc":"2.0","method":"tools/list","id":1}' | base64 -w 0 > temp_payload.b64
    
    aws lambda invoke \
        --function-name "$FUNCTION_NAME" \
        --payload fileb://temp_payload.b64 \
        --region "$REGION" \
        temp_response.json 2>/dev/null
    
    if [ -f temp_response.json ]; then
        echo "✅ Alternative method successful"
        cat temp_response.json | jq '.'
        rm -f temp_payload.b64 temp_response.json
    else
        echo "❌ Both methods failed"
    fi
fi

echo ""

# Test 2: Simple calculation using working method
echo "🧮 Test 2: Simple Calculation (2+2)"
echo "===================================="

# Try the simplest possible method
aws lambda invoke \
    --function-name "$FUNCTION_NAME" \
    --payload "$(echo '{"jsonrpc":"2.0","method":"tools/call","params":{"name":"add","arguments":{"a":2,"b":2}},"id":2}' | base64)" \
    --region "$REGION" \
    --output text \
    --query 'Payload' | base64 -d | jq '.'

echo ""

# Test 3: Check if Lambda exists and permissions
echo "🔍 Test 3: Lambda Function Check"
echo "================================"

echo "Checking Lambda function details..."
aws lambda get-function \
    --function-name "$FUNCTION_NAME" \
    --region "$REGION" \
    --query '{State: Configuration.State, Runtime: Configuration.Runtime, LastModified: Configuration.LastModified}' 2>/dev/null

if [ $? -eq 0 ]; then
    echo "✅ Lambda function accessible"
else
    echo "❌ Lambda function not accessible - check permissions"
fi

echo ""

# Test 4: Check CloudWatch logs for any execution
echo "📋 Test 4: Recent CloudWatch Activity"
echo "===================================="

echo "Checking recent Lambda activity..."
aws logs describe-log-streams \
    --log-group-name "/aws/lambda/$FUNCTION_NAME" \
    --region "$REGION" \
    --order-by LastEventTime \
    --descending \
    --max-items 1 \
    --query 'logStreams[0].{LastEventTime: lastEventTime, LogStreamName: logStreamName}' 2>/dev/null

echo ""

# Test 5: Simple connectivity test
echo "🌐 Test 5: Basic Connectivity Test"
echo "=================================="

echo "Testing basic AWS connectivity..."
aws sts get-caller-identity --query '{Account: Account, UserId: UserId}' 2>/dev/null

if [ $? -eq 0 ]; then
    echo "✅ AWS credentials working"
else
    echo "❌ AWS credentials issue"
fi

echo ""

# Test 6: Alternative Lambda invoke method
echo "💡 Test 6: Alternative Invoke Strategy"
echo "======================================"

echo "Using AWS CLI invoke without file dependencies..."

# Create base64 encoded payload inline
PAYLOAD_B64=$(echo -n '{"jsonrpc":"2.0","method":"tools/list","id":1}' | base64 -w 0)

# Direct invoke with base64 payload
aws lambda invoke \
    --function-name "$FUNCTION_NAME" \
    --payload "$PAYLOAD_B64" \
    --region "$REGION" \
    response_direct.json 2>&1

if [ -f response_direct.json ]; then
    echo "✅ Direct base64 invoke successful"
    echo "Response:"
    cat response_direct.json | jq '.' 2>/dev/null || cat response_direct.json
    rm -f response_direct.json
else
    echo "❌ Direct invoke failed"
fi

echo ""
echo "🎯 SUMMARY"
echo "=========="
echo "If any test above shows a valid JSON response with tools, your Lambda is working!"
echo "Gateway integration status should be checked in AWS Console:"
echo ""
echo "🔗 Manual Validation:"
echo "   1. AWS Console → Bedrock → Agent Core → Gateways"
echo "   2. Select: a208194-askjulius-agentcore-gateway-mcp-iam"
echo "   3. Go to 'Targets' tab"
echo "   4. Check if 'target-direct-calculator-lambda' is Active"
echo ""
echo "🔧 If Lambda tests work but Gateway doesn't:"
echo "   • Check IAM permissions on gateway service role"
echo "   • Verify inline schema matches Lambda tool definitions"
echo "   • Ensure Lambda ARN is correct in target configuration"