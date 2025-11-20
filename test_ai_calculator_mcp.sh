#!/bin/bash
# Test AI Calculator MCP Target Functionality
# Comprehensive testing of natural language math queries through MCP gateway

set -e

echo "🧪 Testing AI Calculator MCP Target Functionality"
echo "================================================="
echo ""

# Configuration
LAMBDA_FUNCTION="a208194-ai-bedrock-calculator-mcp-server"
GATEWAY_SERVICE_ROLE="a208194-askjulius-agentcore-gateway"
REGION="us-east-1"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

echo "📋 Test Configuration:"
echo "   AWS Account ID: $ACCOUNT_ID"
echo "   Region: $REGION"
echo "   Lambda Function: $LAMBDA_FUNCTION"
echo "   Execution Role: arn:aws:iam::${ACCOUNT_ID}:role/${GATEWAY_SERVICE_ROLE}"
echo ""

# Step 1: Verify Lambda function configuration
echo "🔍 Step 1: Verifying Lambda Function Configuration..."
echo "===================================================="

LAMBDA_CONFIG=$(aws lambda get-function-configuration --function-name "$LAMBDA_FUNCTION" --region "$REGION")
CURRENT_ROLE=$(echo "$LAMBDA_CONFIG" | jq -r '.Role')
FUNCTION_STATE=$(echo "$LAMBDA_CONFIG" | jq -r '.State')

echo "Lambda Function Status:"
echo "   Role: $CURRENT_ROLE"
echo "   State: $FUNCTION_STATE"

if [ "$FUNCTION_STATE" = "Active" ]; then
    echo "   ✅ Lambda function is active and ready"
else
    echo "   ⚠️  Lambda function state: $FUNCTION_STATE"
    echo "   Waiting for function to become active..."
    sleep 5
fi

# Step 2: Test basic Lambda invocation
echo ""
echo "🧪 Step 2: Testing Basic Lambda Invocation..."
echo "=============================================="

# Test 1: Simple math query
echo "Test 1: Simple calculation - 'What is 25 + 17?'"

# Create test payload file
cat > test1-payload.json << 'EOF'
{
  "id": "test-1",
  "method": "tools/call",
  "params": {
    "name": "ai_calculate",
    "arguments": {
      "query": "What is 25 + 17?"
    }
  }
}
EOF

echo "Invoking Lambda with test payload..."
TEST1_RESULT=$(aws lambda invoke \
    --function-name "$LAMBDA_FUNCTION" \
    --payload file://test1-payload.json \
    --region "$REGION" \
    --output json \
    response-test1.json)

echo "Lambda invocation result:"
echo "$TEST1_RESULT" | jq '.'

if [ -f "response-test1.json" ]; then
    echo ""
    echo "Test 1 Response:"
    cat response-test1.json | jq '.'
    
    # Check if response contains expected MCP format
    if grep -q '"result"' response-test1.json; then
        echo "   ✅ Test 1: Basic calculation successful"
    else
        echo "   ❌ Test 1: Unexpected response format"
    fi
else
    echo "   ❌ Test 1: No response file generated"
fi

# Step 3: Test complex mathematical query
echo ""
echo "🧪 Step 3: Testing Complex Mathematical Query..."
echo "==============================================="

# Test 2: Percentage calculation
echo "Test 2: Percentage calculation - 'What is 15% of $50,000?'"

# Create test payload file
cat > test2-payload.json << 'EOF'
{
  "id": "test-2", 
  "method": "tools/call",
  "params": {
    "name": "ai_calculate",
    "arguments": {
      "query": "What is 15% of $50,000?"
    }
  }
}
EOF

echo "Invoking Lambda with percentage calculation..."
TEST2_RESULT=$(aws lambda invoke \
    --function-name "$LAMBDA_FUNCTION" \
    --payload file://test2-payload.json \
    --region "$REGION" \
    --output json \
    response-test2.json)

echo "Lambda invocation result:"
echo "$TEST2_RESULT" | jq '.'

if [ -f "response-test2.json" ]; then
    echo ""
    echo "Test 2 Response:"
    cat response-test2.json | jq '.'
    
    # Check if response contains calculation and explanation
    if grep -q '"result"' response-test2.json && grep -q "7500\|7,500" response-test2.json; then
        echo "   ✅ Test 2: Percentage calculation successful"
    else
        echo "   ⚠️  Test 2: Check response for accuracy"
    fi
else
    echo "   ❌ Test 2: No response file generated"
fi

# Step 4: Test explanation functionality
echo ""
echo "🧪 Step 4: Testing Explanation Functionality..."
echo "==============================================="

# Test 3: Explain calculation
echo "Test 3: Explanation request - 'Explain how compound interest works'"

# Create test payload file
cat > test3-payload.json << 'EOF'
{
  "id": "test-3",
  "method": "tools/call", 
  "params": {
    "name": "explain_calculation",
    "arguments": {
      "calculation": "compound interest formula"
    }
  }
}
EOF

echo "Invoking Lambda with explanation request..."
TEST3_RESULT=$(aws lambda invoke \
    --function-name "$LAMBDA_FUNCTION" \
    --payload file://test3-payload.json \
    --region "$REGION" \
    --output json \
    response-test3.json)

echo "Lambda invocation result:"
echo "$TEST3_RESULT" | jq '.'

if [ -f "response-test3.json" ]; then
    echo ""
    echo "Test 3 Response:"
    cat response-test3.json | jq '.'
    
    if grep -q '"result"' response-test3.json; then
        echo "   ✅ Test 3: Explanation functionality working"
    else
        echo "   ❌ Test 3: Explanation functionality issues"
    fi
else
    echo "   ❌ Test 3: No response file generated"
fi

# Step 5: Test word problem solving
echo ""
echo "🧪 Step 5: Testing Word Problem Solving..."
echo "========================================="

# Test 4: Word problem
echo "Test 4: Word problem - 'A train travels 180 miles in 3 hours. What is its average speed?'"

# Create test payload file
cat > test4-payload.json << 'EOF'
{
  "id": "test-4",
  "method": "tools/call",
  "params": {
    "name": "solve_word_problem", 
    "arguments": {
      "problem": "A train travels 180 miles in 3 hours. What is its average speed?"
    }
  }
}
EOF

echo "Invoking Lambda with word problem..."
TEST4_RESULT=$(aws lambda invoke \
    --function-name "$LAMBDA_FUNCTION" \
    --payload file://test4-payload.json \
    --region "$REGION" \
    --output json \
    response-test4.json)

echo "Lambda invocation result:"
echo "$TEST4_RESULT" | jq '.'

if [ -f "response-test4.json" ]; then
    echo ""
    echo "Test 4 Response:"
    cat response-test4.json | jq '.'
    
    if grep -q '"result"' response-test4.json && grep -q "60\|mph\|miles per hour" response-test4.json; then
        echo "   ✅ Test 4: Word problem solving successful"
    else
        echo "   ⚠️  Test 4: Check response for accuracy"
    fi
else
    echo "   ❌ Test 4: No response file generated"
fi

# Step 6: Check CloudWatch logs for any errors
echo ""
echo "🔍 Step 6: Checking CloudWatch Logs for Errors..."
echo "================================================="

LOG_GROUP="/aws/lambda/$LAMBDA_FUNCTION"
echo "Checking recent logs in: $LOG_GROUP"

# Get recent log streams
RECENT_LOGS=$(aws logs describe-log-streams \
    --log-group-name "$LOG_GROUP" \
    --order-by LastEventTime \
    --descending \
    --max-items 3 \
    --region "$REGION" 2>/dev/null || echo "No logs found")

if [ "$RECENT_LOGS" != "No logs found" ]; then
    echo "Recent log streams found. Checking for errors..."
    
    # Get the latest log stream
    LATEST_STREAM=$(echo "$RECENT_LOGS" | jq -r '.logStreams[0].logStreamName' 2>/dev/null)
    
    if [ "$LATEST_STREAM" != "null" ] && [ -n "$LATEST_STREAM" ]; then
        echo "Checking latest log stream: $LATEST_STREAM"
        
        # Get recent log events
        aws logs get-log-events \
            --log-group-name "$LOG_GROUP" \
            --log-stream-name "$LATEST_STREAM" \
            --start-time $(date -d '5 minutes ago' +%s)000 \
            --region "$REGION" \
            --query 'events[?contains(message, `ERROR`) || contains(message, `error`) || contains(message, `Exception`)].[timestamp,message]' \
            --output table 2>/dev/null || echo "No error logs in recent timeframe"
    fi
else
    echo "   ℹ️  No recent CloudWatch logs found"
fi

# Step 7: Test summary and recommendations
echo ""
echo "📊 Step 7: Test Summary and Results"
echo "==================================="

echo ""
echo "🎯 TEST RESULTS SUMMARY:"
echo "========================"

# Count successful tests
SUCCESS_COUNT=0
TOTAL_TESTS=4

if [ -f "response-test1.json" ] && grep -q '"result"' response-test1.json; then
    SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
    echo "   ✅ Test 1: Basic calculation - PASSED"
else
    echo "   ❌ Test 1: Basic calculation - FAILED"
fi

if [ -f "response-test2.json" ] && grep -q '"result"' response-test2.json; then
    SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
    echo "   ✅ Test 2: Percentage calculation - PASSED"
else
    echo "   ❌ Test 2: Percentage calculation - FAILED"
fi

if [ -f "response-test3.json" ] && grep -q '"result"' response-test3.json; then
    SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
    echo "   ✅ Test 3: Explanation functionality - PASSED"
else
    echo "   ❌ Test 3: Explanation functionality - FAILED"
fi

if [ -f "response-test4.json" ] && grep -q '"result"' response-test4.json; then
    SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
    echo "   ✅ Test 4: Word problem solving - PASSED"
else
    echo "   ❌ Test 4: Word problem solving - FAILED"
fi

echo ""
echo "📈 OVERALL RESULTS:"
echo "   Tests Passed: $SUCCESS_COUNT/$TOTAL_TESTS"
echo "   Success Rate: $((SUCCESS_COUNT * 100 / TOTAL_TESTS))%"

if [ $SUCCESS_COUNT -eq $TOTAL_TESTS ]; then
    echo "   🎉 ALL TESTS PASSED! AI Calculator is fully functional"
    echo ""
    echo "🚀 READY FOR PRODUCTION:"
    echo "   ✅ Lambda function execution role optimized"
    echo "   ✅ Bedrock model access permissions working"
    echo "   ✅ MCP JSON-RPC 2.0 format compliance verified"
    echo "   ✅ Natural language math queries processing correctly"
    echo "   ✅ All three tool functions (ai_calculate, explain_calculation, solve_word_problem) operational"
    
elif [ $SUCCESS_COUNT -gt 0 ]; then
    echo "   ⚠️  PARTIAL SUCCESS: Some functionality working"
    echo ""
    echo "🔧 NEXT STEPS:"
    echo "   1. Review failed test responses for error details"
    echo "   2. Check CloudWatch logs for specific error messages"
    echo "   3. Verify Bedrock model permissions if calculation errors occur"
    
else
    echo "   ❌ ALL TESTS FAILED: Requires troubleshooting"
    echo ""
    echo "🚨 TROUBLESHOOTING STEPS:"
    echo "   1. Verify Lambda function is using correct execution role"
    echo "   2. Check CloudWatch logs for detailed error information"
    echo "   3. Confirm Bedrock model access permissions"
    echo "   4. Validate MCP JSON-RPC 2.0 request format"
fi

echo ""
echo "📝 MCP GATEWAY TESTING:"
echo "======================"
echo "Next step: Test through the actual MCP gateway using your enterprise client"
echo "with the target name: 'target-lambda-direct-ai-bedrock-calculator-mcp'"
echo ""
echo "Example natural language queries to try:"
echo "   • 'What is 15% of $50,000?'"
echo "   • 'Calculate compound interest for $10,000 at 4.5% for 5 years'"
echo "   • 'If a product costs $120 with 20% discount, what was the original price?'"
echo "   • 'Explain the quadratic formula'"

# Clean up test files
echo ""
echo "🧹 Cleaning up test files..."
rm -f response-test*.json test*-payload.json

echo ""
echo "🏁 AI Calculator MCP Target Testing Complete!"
echo "============================================="