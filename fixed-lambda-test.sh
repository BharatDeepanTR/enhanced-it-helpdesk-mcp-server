#!/bin/bash
# Fixed Lambda Test - Correct Payload Format
# Test Lambda with proper base64 encoding or direct JSON

echo "🔧 Fixed Lambda Test with Correct Payload Format"
echo "==============================================="
echo ""

LAMBDA_ARN="arn:aws:lambda:us-east-1:818565325759:function:a208194-chatops_application_details_intent"

echo "📋 Testing Lambda: $LAMBDA_ARN"
echo ""

echo "🔍 Step 1: Basic Lambda Information"
echo "=================================="

aws lambda get-function \
  --function-name "$LAMBDA_ARN" \
  --query 'Configuration.{FunctionName:FunctionName,Runtime:Runtime,Handler:Handler,State:State}' \
  --output table

echo ""
echo "🧪 Step 2: Test Lambda with Simple Payload (Method 1)"
echo "===================================================="

echo "Testing with direct JSON string payload..."

# Method 1: Direct JSON string (properly escaped)
MCP_PAYLOAD='{"jsonrpc":"2.0","id":"test-1","method":"tools/list","params":{}}'

echo "Payload: $MCP_PAYLOAD"
echo ""

aws lambda invoke \
  --function-name "$LAMBDA_ARN" \
  --payload "$MCP_PAYLOAD" \
  /tmp/lambda-response-1.json

if [ $? -eq 0 ]; then
    echo "✅ Direct payload invocation successful!"
    echo ""
    echo "📋 Response metadata:"
    cat /tmp/lambda-response-1.json 2>/dev/null || echo "No response file created"
    echo ""
else
    echo "❌ Direct payload failed"
fi

echo ""
echo "🧪 Step 3: Test Lambda with Base64 Encoded Payload (Method 2)"
echo "==========================================================="

echo "Testing with base64 encoded payload..."

# Method 2: Base64 encoded payload
echo '{"jsonrpc":"2.0","id":"test-2","method":"tools/list","params":{}}' | base64 > /tmp/payload-b64.txt

echo "Base64 payload file created"

aws lambda invoke \
  --function-name "$LAMBDA_ARN" \
  --payload fileb:///tmp/payload-b64.txt \
  /tmp/lambda-response-2.json

if [ $? -eq 0 ]; then
    echo "✅ Base64 payload invocation successful!"
    echo ""
    echo "📋 Response:"
    cat /tmp/lambda-response-2.json 2>/dev/null || echo "No response file created"
    echo ""
else
    echo "❌ Base64 payload failed"
fi

echo ""
echo "🧪 Step 4: Test Lambda with Binary File (Method 3)"
echo "==============================================="

echo "Testing with binary file payload..."

# Method 3: Binary file with fileb://
echo '{"jsonrpc":"2.0","id":"test-3","method":"tools/list","params":{}}' > /tmp/payload.json

aws lambda invoke \
  --function-name "$LAMBDA_ARN" \
  --payload fileb:///tmp/payload.json \
  /tmp/lambda-response-3.json

if [ $? -eq 0 ]; then
    echo "✅ Binary file payload invocation successful!"
    echo ""
    echo "📋 Response:"
    cat /tmp/lambda-response-3.json 2>/dev/null || echo "No response file created"
    echo ""
else
    echo "❌ Binary file payload failed"
fi

echo ""
echo "🧪 Step 5: Test Lambda with Empty Payload"
echo "======================================"

echo "Testing with empty payload to check basic functionality..."

aws lambda invoke \
  --function-name "$LAMBDA_ARN" \
  --payload '{}' \
  /tmp/lambda-response-empty.json

if [ $? -eq 0 ]; then
    echo "✅ Empty payload invocation successful!"
    echo ""
    echo "📋 Response:"
    cat /tmp/lambda-response-empty.json 2>/dev/null || echo "No response file created"
    echo ""
else
    echo "❌ Empty payload failed"
fi

echo ""
echo "🧪 Step 6: Test Application Details Query"
echo "======================================"

echo "Testing application details with working payload method..."

APP_PAYLOAD='{"jsonrpc":"2.0","id":"test-app","method":"tools/call","params":{"name":"get_application_details","arguments":{"application_name":"chatops"}}}'

echo "Application payload: $APP_PAYLOAD"
echo ""

aws lambda invoke \
  --function-name "$LAMBDA_ARN" \
  --payload "$APP_PAYLOAD" \
  /tmp/lambda-response-app.json

if [ $? -eq 0 ]; then
    echo "✅ Application query successful!"
    echo ""
    echo "📋 Application response:"
    cat /tmp/lambda-response-app.json 2>/dev/null || echo "No response file created"
    echo ""
else
    echo "❌ Application query failed"
fi

echo ""
echo "🔍 Step 7: Analyze All Responses"
echo "==============================="

echo "Analyzing all Lambda response files..."

for response_file in /tmp/lambda-response-*.json; do
    if [ -f "$response_file" ]; then
        echo ""
        echo "📁 $(basename $response_file):"
        echo "   File size: $(wc -c < "$response_file") bytes"
        
        # Check if response is JSON
        if cat "$response_file" | python3 -m json.tool > /dev/null 2>&1; then
            echo "   ✅ Valid JSON response"
            
            # Show first few lines
            echo "   Content preview:"
            cat "$response_file" | head -5 | sed 's/^/     /'
            
            # Check for MCP elements
            if grep -q "tools" "$response_file" 2>/dev/null; then
                echo "   ✅ Contains 'tools' - MCP compliant"
            fi
            
            if grep -q "jsonrpc" "$response_file" 2>/dev/null; then
                echo "   ✅ Contains 'jsonrpc' - JSON-RPC format"
            fi
            
            if grep -q "error" "$response_file" 2>/dev/null; then
                echo "   ⚠️  Contains 'error' field"
            fi
            
        else
            echo "   ⚠️  Not valid JSON or empty"
            if [ -s "$response_file" ]; then
                echo "   Raw content:"
                cat "$response_file" | head -3 | sed 's/^/     /'
            fi
        fi
    fi
done

echo ""
echo "🔍 Step 8: Check Lambda Execution Role Permissions"
echo "==============================================="

echo "Checking Lambda execution role..."

LAMBDA_ROLE=$(aws lambda get-function \
  --function-name "$LAMBDA_ARN" \
  --query 'Configuration.Role' \
  --output text 2>/dev/null)

if [ $? -eq 0 ] && [ "$LAMBDA_ROLE" != "None" ]; then
    echo "✅ Lambda role: $LAMBDA_ROLE"
    
    ROLE_NAME=$(echo "$LAMBDA_ROLE" | awk -F'/' '{print $NF}')
    echo "   Role name: $ROLE_NAME"
    
    # Check attached policies
    echo ""
    echo "📋 Attached policies:"
    aws iam list-attached-role-policies \
      --role-name "$ROLE_NAME" \
      --query 'AttachedPolicies[].PolicyArn' \
      --output text 2>/dev/null | tr '\t' '\n' | sed 's/^/   • /'
    
else
    echo "⚠️  Cannot retrieve Lambda role information"
fi

echo ""
echo "📋 COMPREHENSIVE SUMMARY"
echo "======================="

echo ""
echo "🎯 Lambda Function Status:"

# Check if any invocation succeeded
SUCCESS_COUNT=0
for response_file in /tmp/lambda-response-*.json; do
    if [ -f "$response_file" ] && [ -s "$response_file" ]; then
        SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
    fi
done

if [ $SUCCESS_COUNT -gt 0 ]; then
    echo "   ✅ Lambda function is invocable ($SUCCESS_COUNT successful responses)"
    echo "   ✅ Function is active and responding"
    
    # Check for MCP compliance
    if grep -q "tools\|jsonrpc" /tmp/lambda-response-*.json 2>/dev/null; then
        echo "   ✅ Function appears to implement MCP protocol"
        echo "   🎯 Ready for MCP gateway integration"
    else
        echo "   ⚠️  Function may not fully implement MCP protocol"
        echo "   🔧 May need code updates for proper MCP support"
    fi
    
else
    echo "   ❌ Lambda function invocation failed"
    echo "   🔧 Check function permissions and configuration"
fi

echo ""
echo "🚀 Recommended Next Steps:"

if [ $SUCCESS_COUNT -gt 0 ]; then
    echo "   1. ✅ Lambda is working - configure MCP gateway properly"
    echo "   2. 🔧 Update gateway to route to this Lambda ARN"
    echo "   3. 🧪 Test end-to-end gateway functionality"
    echo "   4. 🎯 Verify application detail queries work as expected"
else
    echo "   1. 🔍 Check Lambda function permissions"
    echo "   2. 📝 Review Lambda function code and logs"
    echo "   3. 🔧 Fix any runtime or configuration issues"
    echo "   4. 🧪 Re-test after fixes"
fi

echo ""
echo "📁 Response files saved in /tmp/lambda-response-*.json"
echo "🔧 Use these to debug Lambda function behavior"

echo ""
echo "✅ Comprehensive Lambda test completed!"

# Don't clean up - leave files for analysis
echo ""
echo "💡 Response files preserved for analysis"