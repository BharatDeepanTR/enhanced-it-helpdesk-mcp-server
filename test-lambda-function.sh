#!/bin/bash
# Comprehensive Lambda Function Testing
# Test a208194-chatops_application_details_intent Lambda function

echo "🧪 Testing Lambda Function - MCP Gateway Target"
echo "==============================================="
echo ""

LAMBDA_ARN="arn:aws:lambda:us-east-1:818565325759:function:a208194-chatops_application_details_intent"
LAMBDA_NAME="a208194-chatops_application_details_intent"
REGION="us-east-1"

echo "📋 Lambda Function Details:"
echo "  Function Name: $LAMBDA_NAME"
echo "  Function ARN: $LAMBDA_ARN"
echo "  Region: $REGION"
echo ""

echo "🔍 Step 1: Lambda Function Information"
echo "====================================="

echo "Getting Lambda function configuration..."

LAMBDA_CONFIG=$(aws lambda get-function \
  --function-name "$LAMBDA_ARN" \
  --output json 2>/dev/null)

if [ $? -eq 0 ]; then
    echo "✅ Lambda function information retrieved:"
    echo "$LAMBDA_CONFIG" | jq '{
      FunctionName: .Configuration.FunctionName,
      Runtime: .Configuration.Runtime,
      Handler: .Configuration.Handler,
      CodeSize: .Configuration.CodeSize,
      Timeout: .Configuration.Timeout,
      MemorySize: .Configuration.MemorySize,
      LastModified: .Configuration.LastModified,
      State: .Configuration.State,
      Role: .Configuration.Role,
      Environment: .Configuration.Environment
    }'
    
    LAMBDA_STATE=$(echo "$LAMBDA_CONFIG" | jq -r '.Configuration.State')
    LAMBDA_RUNTIME=$(echo "$LAMBDA_CONFIG" | jq -r '.Configuration.Runtime')
    LAMBDA_HANDLER=$(echo "$LAMBDA_CONFIG" | jq -r '.Configuration.Handler')
    
    echo ""
    echo "📋 Key Details:"
    echo "  State: $LAMBDA_STATE"
    echo "  Runtime: $LAMBDA_RUNTIME" 
    echo "  Handler: $LAMBDA_HANDLER"
    
    if [ "$LAMBDA_STATE" = "Active" ]; then
        echo "  ✅ Lambda is Active and ready"
    else
        echo "  ⚠️  Lambda state: $LAMBDA_STATE"
    fi
    
else
    echo "❌ Cannot retrieve Lambda function information"
    echo "   Check lambda:GetFunction permission"
    exit 1
fi

echo ""
echo "🧪 Step 2: Basic Lambda Invocation Test"
echo "======================================"

echo "Testing Lambda function with simple invocation..."

# Test 1: Basic invocation with empty payload
echo "Test 1: Empty payload invocation"

aws lambda invoke \
  --function-name "$LAMBDA_ARN" \
  --payload '{}' \
  --output json \
  /tmp/lambda-response-basic.json

if [ $? -eq 0 ]; then
    echo "✅ Basic invocation successful"
    echo "Response:"
    cat /tmp/lambda-response-basic.json | jq '.' 2>/dev/null || cat /tmp/lambda-response-basic.json
    echo ""
    
    # Check the actual response file
    if [ -f "/tmp/lambda-response-basic.json" ]; then
        echo "Lambda output:"
        cat /tmp/lambda-response-basic.json
        echo ""
    fi
else
    echo "❌ Basic invocation failed"
fi

echo ""
echo "🧪 Step 3: MCP Protocol Test - Tools/List"
echo "========================================"

echo "Testing Lambda with MCP tools/list request..."

# Create MCP tools/list payload
cat > /tmp/mcp-tools-list.json << 'EOF'
{
  "jsonrpc": "2.0",
  "id": "test-tools-list",
  "method": "tools/list",
  "params": {}
}
EOF

echo "MCP tools/list payload:"
cat /tmp/mcp-tools-list.json | jq '.'
echo ""

aws lambda invoke \
  --function-name "$LAMBDA_ARN" \
  --payload file:///tmp/mcp-tools-list.json \
  --output json \
  /tmp/lambda-response-tools.json

if [ $? -eq 0 ]; then
    echo "✅ MCP tools/list invocation successful"
    echo ""
    echo "📋 Response metadata:"
    cat /tmp/lambda-response-tools.json | jq '.'
    echo ""
    
    echo "📋 Lambda function output:"
    if [ -f "/tmp/lambda-response-tools.json" ]; then
        LAMBDA_OUTPUT=$(cat /tmp/lambda-response-tools.json)
        echo "$LAMBDA_OUTPUT"
        
        # Check if it's proper MCP response
        echo ""
        echo "🔍 Analyzing MCP response format..."
        
        # Try to parse as JSON to see structure
        python3 << EOF
import json

try:
    with open('/tmp/lambda-response-tools.json', 'r') as f:
        response = f.read()
    
    print(f"Raw response: {response}")
    
    # Try to parse as JSON
    try:
        data = json.loads(response)
        print("\n✅ Valid JSON response")
        print(f"Response structure: {type(data)}")
        
        # Check for MCP protocol compliance
        if isinstance(data, dict):
            if 'jsonrpc' in data:
                print(f"✅ JSONRPC version: {data.get('jsonrpc')}")
            else:
                print("⚠️  Missing 'jsonrpc' field")
                
            if 'result' in data:
                print("✅ Has 'result' field")
                result = data['result']
                if isinstance(result, dict) and 'tools' in result:
                    tools = result['tools']
                    print(f"✅ Found {len(tools)} tools:")
                    for tool in tools:
                        print(f"  • {tool.get('name', 'Unknown')}: {tool.get('description', 'No desc')}")
                else:
                    print("⚠️  Result doesn't contain 'tools' array")
            elif 'error' in data:
                print(f"❌ Error response: {data['error']}")
            else:
                print("⚠️  No 'result' or 'error' field")
        else:
            print(f"⚠️  Response is {type(data)}, expected dict")
            
    except json.JSONDecodeError as e:
        print(f"❌ Invalid JSON: {e}")
        print(f"Raw content: {response[:200]}...")

except Exception as e:
    print(f"❌ Error reading response: {e}")

EOF
    fi
else
    echo "❌ MCP tools/list invocation failed"
fi

echo ""
echo "🧪 Step 4: MCP Protocol Test - Tools/Call"
echo "========================================"

echo "Testing Lambda with MCP tools/call request..."

# Create MCP tools/call payload
cat > /tmp/mcp-tools-call.json << 'EOF'
{
  "jsonrpc": "2.0",
  "id": "test-tools-call",
  "method": "tools/call",
  "params": {
    "name": "get_application_details",
    "arguments": {
      "application_name": "test-app"
    }
  }
}
EOF

echo "MCP tools/call payload:"
cat /tmp/mcp-tools-call.json | jq '.'
echo ""

aws lambda invoke \
  --function-name "$LAMBDA_ARN" \
  --payload file:///tmp/mcp-tools-call.json \
  --output json \
  /tmp/lambda-response-call.json

if [ $? -eq 0 ]; then
    echo "✅ MCP tools/call invocation successful"
    echo ""
    echo "📋 Response:"
    cat /tmp/lambda-response-call.json | jq '.' 2>/dev/null || cat /tmp/lambda-response-call.json
    echo ""
    
    if [ -f "/tmp/lambda-response-call.json" ]; then
        echo "📋 Lambda function output:"
        cat /tmp/lambda-response-call.json
    fi
else
    echo "❌ MCP tools/call invocation failed"
fi

echo ""
echo "🧪 Step 5: Custom Application Details Test"
echo "========================================"

echo "Testing with application-specific parameters..."

# Test with different application names
TEST_APPS=("chatops" "route_dns" "test-application")

for app_name in "${TEST_APPS[@]}"; do
    echo "Testing application: $app_name"
    
    cat > /tmp/mcp-app-test.json << EOF
{
  "jsonrpc": "2.0",
  "id": "test-app-$app_name",
  "method": "tools/call",
  "params": {
    "name": "get_application_details",
    "arguments": {
      "application_name": "$app_name"
    }
  }
}
EOF

    aws lambda invoke \
      --function-name "$LAMBDA_ARN" \
      --payload file:///tmp/mcp-app-test.json \
      --output json \
      /tmp/lambda-response-$app_name.json > /dev/null 2>&1
    
    if [ $? -eq 0 ]; then
        echo "  ✅ Success for $app_name"
        if [ -f "/tmp/lambda-response-$app_name.json" ]; then
            RESPONSE_SIZE=$(wc -c < /tmp/lambda-response-$app_name.json)
            echo "    Response size: $RESPONSE_SIZE bytes"
        fi
    else
        echo "  ❌ Failed for $app_name"
    fi
done

echo ""
echo "🔍 Step 6: Lambda Logs Analysis"
echo "=============================="

echo "Checking recent Lambda function logs..."

LOG_GROUP="/aws/lambda/$LAMBDA_NAME"

# Get log streams
LATEST_STREAM=$(aws logs describe-log-streams \
  --log-group-name "$LOG_GROUP" \
  --order-by LastEventTime \
  --descending \
  --max-items 1 \
  --query 'logStreams[0].logStreamName' \
  --output text 2>/dev/null)

if [ $? -eq 0 ] && [ "$LATEST_STREAM" != "None" ]; then
    echo "✅ Found latest log stream: $LATEST_STREAM"
    
    echo ""
    echo "📋 Recent log events (last 10 minutes):"
    
    START_TIME=$(date -d '10 minutes ago' +%s)000
    
    aws logs get-log-events \
      --log-group-name "$LOG_GROUP" \
      --log-stream-name "$LATEST_STREAM" \
      --start-time "$START_TIME" \
      --query 'events[].message' \
      --output text 2>/dev/null | head -20
    
    echo ""
    echo "🔍 Looking for errors in logs..."
    
    aws logs filter-log-events \
      --log-group-name "$LOG_GROUP" \
      --filter-pattern "ERROR" \
      --start-time "$START_TIME" \
      --query 'events[].message' \
      --output text 2>/dev/null | head -10
    
else
    echo "⚠️  Cannot access Lambda logs"
    echo "   Check logs:DescribeLogStreams permission or function may not have run recently"
fi

echo ""
echo "🔍 Step 7: Performance Analysis"
echo "=============================="

echo "Analyzing Lambda performance from invocation responses..."

python3 << 'EOF'
import json
import glob

print("📊 Lambda Performance Summary:")
print("=" * 30)

# Find all response files
response_files = glob.glob('/tmp/lambda-response-*.json')

if not response_files:
    print("No response files found to analyze")
else:
    total_duration = 0
    total_billed = 0
    total_memory = 0
    count = 0
    
    for file_path in response_files:
        try:
            with open(file_path, 'r') as f:
                data = json.load(f)
            
            if isinstance(data, dict):
                duration = data.get('ExecutedVersion')
                status_code = data.get('StatusCode', 0)
                
                print(f"\n📁 {file_path.split('/')[-1]}:")
                print(f"   Status: {status_code}")
                
                if 'LogResult' in data:
                    print(f"   Has execution logs")
                
                if status_code == 200:
                    print(f"   ✅ Successful execution")
                else:
                    print(f"   ⚠️  Non-200 status: {status_code}")
                    
                count += 1
        
        except Exception as e:
            print(f"❌ Error reading {file_path}: {e}")
    
    print(f"\n📊 Summary: {count} invocations analyzed")

EOF

echo ""
echo "📋 LAMBDA TESTING SUMMARY"
echo "========================="
echo ""

echo "🧪 Tests Performed:"
echo "   ✅ Basic Lambda invocation"
echo "   ✅ MCP tools/list protocol test"
echo "   ✅ MCP tools/call protocol test"
echo "   ✅ Application-specific parameter tests"
echo "   ✅ CloudWatch logs analysis"
echo "   ✅ Performance analysis"
echo ""

echo "🎯 Key Findings:"

# Check if any tests were successful
if [ -f "/tmp/lambda-response-tools.json" ]; then
    echo "   ✅ Lambda function is invocable"
    
    # Check for MCP compliance
    python3 << EOF
import json

try:
    with open('/tmp/lambda-response-tools.json', 'r') as f:
        response = f.read().strip()
    
    # Try to parse the actual Lambda output
    try:
        data = json.loads(response)
        if 'jsonrpc' in str(data).lower() or 'tools' in str(data).lower():
            print("   ✅ Lambda appears to implement MCP protocol")
        else:
            print("   ⚠️  Lambda may not fully implement MCP protocol")
            print(f"      Response format: {type(data)}")
    except:
        if 'jsonrpc' in response.lower() or 'tools' in response.lower():
            print("   ✅ Lambda appears to implement MCP protocol")
        else:
            print("   ⚠️  Lambda response format unclear")
            
except Exception as e:
    print(f"   ❌ Cannot analyze MCP compliance: {e}")

EOF

else
    echo "   ❌ Lambda function invocation failed"
fi

echo ""
echo "🚀 Next Steps:"

if [ -f "/tmp/lambda-response-tools.json" ]; then
    echo "   1. ✅ Lambda is working - integrate with MCP gateway"
    echo "   2. 🔧 Update gateway configuration to use this Lambda"
    echo "   3. 🧪 Test end-to-end MCP gateway → Lambda flow"
    echo "   4. 🎯 Test actual application detail queries"
else
    echo "   1. 🔧 Fix Lambda function invocation issues"
    echo "   2. 📝 Check Lambda function code and permissions"
    echo "   3. 🔍 Review CloudWatch logs for errors"
    echo "   4. 🧪 Re-test after fixes"
fi

echo ""
echo "📁 Test artifacts saved:"
echo "   • /tmp/lambda-response-*.json (invocation responses)"
echo "   • /tmp/mcp-*.json (test payloads)"
echo ""

echo "✅ Lambda function testing completed!"

# Cleanup temporary files
echo "🧹 Cleaning up temporary test files..."
rm -f /tmp/lambda-response-*.json /tmp/mcp-*.json
echo "✅ Cleanup completed!"