#!/bin/bash
# CloudShell: Update Gateway with Manual MCP Wrapper Function
# Run this AFTER you've manually created the Lambda function

echo "🔧 CloudShell Gateway Update for Manual MCP Wrapper"
echo "================================================="
echo ""

GATEWAY_ID="a208194-askjulius-agentcore-gateway-mcp-iam-fvro4phd59"
WRAPPER_FUNCTION_NAME="mcp-wrapper-lambda"

echo "📋 Configuration:"
echo "  Gateway ID: $GATEWAY_ID"
echo "  Expected Lambda: $WRAPPER_FUNCTION_NAME"
echo ""

echo "🔍 Step 1: Verify Lambda Function Exists"
echo "======================================="

echo "Looking for your manually created Lambda function..."

# Check if the function exists
aws lambda get-function --function-name "$WRAPPER_FUNCTION_NAME" --output table 2>/dev/null

if [ $? -eq 0 ]; then
    echo "✅ Lambda function found!"
    
    # Get the function ARN
    WRAPPER_ARN=$(aws lambda get-function --function-name "$WRAPPER_FUNCTION_NAME" --query 'Configuration.FunctionArn' --output text)
    echo "📋 Function ARN: $WRAPPER_ARN"
    
    # Get function details
    echo ""
    echo "📊 Function Details:"
    aws lambda get-function --function-name "$WRAPPER_FUNCTION_NAME" --query '{
      FunctionName: Configuration.FunctionName,
      Runtime: Configuration.Runtime,
      Role: Configuration.Role,
      State: Configuration.State,
      LastModified: Configuration.LastModified
    }' --output table
    
else
    echo "❌ Lambda function not found!"
    echo ""
    echo "🔧 Please ensure you've created the function manually:"
    echo "   1. Go to AWS Lambda Console"
    echo "   2. Create function: $WRAPPER_FUNCTION_NAME"
    echo "   3. Use role: a208194-askjulius-agentcore-gateway"
    echo "   4. Deploy the MCP wrapper code"
    echo "   5. Re-run this script"
    echo ""
    
    # List available functions for reference
    echo "📋 Available Lambda functions in your account:"
    aws lambda list-functions --query 'Functions[?contains(FunctionName, `a208194`) || contains(FunctionName, `mcp`) || contains(FunctionName, `wrapper`)].{Name: FunctionName, Runtime: Runtime}' --output table
    
    exit 1
fi

echo ""
echo "🧪 Step 2: Test Lambda Function"
echo "==============================="

echo "Testing the MCP wrapper function..."

# Create test payload
TEST_PAYLOAD='{
    "jsonrpc": "2.0",
    "id": "gateway-update-test",
    "method": "tools/list",
    "params": {}
}'

echo "Test payload: $TEST_PAYLOAD"

# Test the function
aws lambda invoke \
  --function-name "$WRAPPER_FUNCTION_NAME" \
  --payload "$TEST_PAYLOAD" \
  /tmp/wrapper-response.json \
  --output table

INVOKE_RESULT=$?

if [ $INVOKE_RESULT -eq 0 ]; then
    echo ""
    echo "✅ Lambda invocation successful!"
    echo "📄 Response:"
    
    if command -v jq >/dev/null 2>&1; then
        cat /tmp/wrapper-response.json | jq .
    else
        cat /tmp/wrapper-response.json
    fi
    
    # Check if response is valid MCP format
    if grep -q '"jsonrpc":"2.0"' /tmp/wrapper-response.json && grep -q '"tools"' /tmp/wrapper-response.json; then
        echo ""
        echo "🎉 MCP Protocol Response Detected!"
        echo "✅ Function is working correctly"
        FUNCTION_WORKING=true
    else
        echo ""
        echo "⚠️  Response doesn't look like MCP format"
        echo "   Please check the function code"
    fi
else
    echo "❌ Lambda test failed"
    echo "   Please check the function configuration and code"
    exit 1
fi

echo ""
echo "🔍 Step 3: Update Gateway Configuration"
echo "===================================="

if [ "$FUNCTION_WORKING" = "true" ]; then
    echo "Updating gateway to use MCP wrapper function..."
    
    # Method 1: Try target-lambda-arn
    echo "Method 1: Using --target-lambda-arn..."
    
    UPDATE_RESPONSE=$(aws bedrock-agentcore-control update-gateway \
      --gateway-id "$GATEWAY_ID" \
      --target-lambda-arn "$WRAPPER_ARN" \
      --output json 2>&1)
    
    UPDATE_RESULT_1=$?
    echo "Response: $UPDATE_RESPONSE"
    
    if [ $UPDATE_RESULT_1 -eq 0 ]; then
        echo "🎉 SUCCESS with method 1!"
        UPDATE_SUCCESS=true
    else
        echo ""
        echo "Method 2: Using --lambda-arn..."
        
        UPDATE_RESPONSE=$(aws bedrock-agentcore-control update-gateway \
          --gateway-id "$GATEWAY_ID" \
          --lambda-arn "$WRAPPER_ARN" \
          --output json 2>&1)
        
        UPDATE_RESULT_2=$?
        echo "Response: $UPDATE_RESPONSE"
        
        if [ $UPDATE_RESULT_2 -eq 0 ]; then
            echo "🎉 SUCCESS with method 2!"
            UPDATE_SUCCESS=true
        else
            echo ""
            echo "Method 3: Using --backend-configuration..."
            
            UPDATE_RESPONSE=$(aws bedrock-agentcore-control update-gateway \
              --gateway-id "$GATEWAY_ID" \
              --backend-configuration "lambdaArn=$WRAPPER_ARN" \
              --output json 2>&1)
            
            UPDATE_RESULT_3=$?
            echo "Response: $UPDATE_RESPONSE"
            
            if [ $UPDATE_RESULT_3 -eq 0 ]; then
                echo "🎉 SUCCESS with method 3!"
                UPDATE_SUCCESS=true
            fi
        fi
    fi
else
    echo "⚠️  Skipping gateway update - Lambda function not working properly"
fi

echo ""
echo "🔍 Step 4: Verify Gateway Configuration"
echo "===================================="

sleep 3

echo "Checking updated gateway configuration..."

GATEWAY_INFO=$(aws bedrock-agentcore-control get-gateway \
  --gateway-id "$GATEWAY_ID" \
  --output json 2>/dev/null)

if [ $? -eq 0 ]; then
    echo "✅ Gateway information retrieved:"
    
    if command -v jq >/dev/null 2>&1; then
        echo "$GATEWAY_INFO" | jq '{
          id: .id,
          name: .name,
          status: .status,
          lambdaArn: .lambdaArn,
          roleArn: .roleArn
        }'
        
        # Check if our Lambda is configured
        CONFIGURED_LAMBDA=$(echo "$GATEWAY_INFO" | jq -r '.lambdaArn // "none"')
    else
        echo "$GATEWAY_INFO"
        CONFIGURED_LAMBDA=$(echo "$GATEWAY_INFO" | grep -o 'arn:aws:lambda[^"]*' | head -1)
    fi
    
    if [ "$CONFIGURED_LAMBDA" = "$WRAPPER_ARN" ]; then
        echo ""
        echo "🎉 PERFECT! Gateway configured with wrapper function!"
        echo "✅ Lambda ARN matches: $CONFIGURED_LAMBDA"
        GATEWAY_CONFIGURED=true
    elif [[ "$CONFIGURED_LAMBDA" == *"mcp-wrapper"* ]]; then
        echo ""
        echo "✅ Gateway has MCP wrapper function (possibly different version)"
        echo "📋 Configured: $CONFIGURED_LAMBDA"
        echo "📋 Expected: $WRAPPER_ARN"
        GATEWAY_CONFIGURED=true
    else
        echo ""
        echo "⚠️  Gateway may not be configured with wrapper function"
        echo "📋 Current Lambda: $CONFIGURED_LAMBDA"
        echo "📋 Expected: $WRAPPER_ARN"
    fi
else
    echo "❌ Could not retrieve gateway information"
fi

echo ""
echo "🧪 Step 5: End-to-End Gateway Test"
echo "================================="

if [ "$GATEWAY_CONFIGURED" = "true" ]; then
    echo "Testing complete gateway → wrapper → target Lambda flow..."
    
    # Create comprehensive test
    cat > /tmp/test_complete_flow.py << 'EOF'
import boto3
import requests
from botocore.auth import SigV4Auth
from botocore.awsrequest import AWSRequest
import json
from urllib.parse import urlparse

def test_gateway_flow():
    gateway_url = "https://a208194-askjulius-agentcore-gateway-mcp-iam-fvro4phd59.gateway.bedrock-agentcore.us-east-1.amazonaws.com/mcp"
    
    print("🧪 Testing Complete MCP Gateway Flow")
    print("=" * 45)
    
    session = boto3.Session()
    credentials = session.get_credentials()
    
    # Test 1: tools/list
    print("\n📋 Test 1: MCP tools/list")
    print("-" * 25)
    
    payload = {
        "jsonrpc": "2.0",
        "id": "test-tools-list",
        "method": "tools/list",
        "params": {}
    }
    
    try:
        body = json.dumps(payload)
        parsed_url = urlparse(gateway_url)
        
        request = AWSRequest(
            method='POST',
            url=gateway_url,
            data=body,
            headers={
                'Content-Type': 'application/json',
                'Host': parsed_url.netloc
            }
        )
        
        SigV4Auth(credentials, 'bedrock-agentcore', 'us-east-1').add_auth(request)
        headers = dict(request.headers)
        
        response = requests.post(gateway_url, headers=headers, data=body, timeout=30)
        
        print(f"Status: {response.status_code}")
        
        if response.status_code == 200:
            result = response.json()
            
            if 'result' in result and 'tools' in result['result']:
                tools = result['result']['tools']
                print(f"🎉 SUCCESS! Found {len(tools)} tools:")
                for tool in tools:
                    print(f"  • {tool.get('name', 'Unknown')}")
                
                # Test 2: tools/call
                print(f"\n🔧 Test 2: MCP tools/call")
                print("-" * 25)
                
                call_payload = {
                    "jsonrpc": "2.0",
                    "id": "test-tools-call",
                    "method": "tools/call",
                    "params": {
                        "name": "get_application_details",
                        "arguments": {
                            "asset_id": "a208194"
                        }
                    }
                }
                
                call_body = json.dumps(call_payload)
                call_request = AWSRequest(
                    method='POST',
                    url=gateway_url,
                    data=call_body,
                    headers={
                        'Content-Type': 'application/json',
                        'Host': parsed_url.netloc
                    }
                )
                
                SigV4Auth(credentials, 'bedrock-agentcore', 'us-east-1').add_auth(call_request)
                call_headers = dict(call_request.headers)
                
                call_response = requests.post(gateway_url, headers=call_headers, data=call_body, timeout=30)
                
                print(f"Status: {call_response.status_code}")
                
                if call_response.status_code == 200:
                    call_result = call_response.json()
                    
                    if 'result' in call_result:
                        print("🎉 TOOLS/CALL SUCCESS!")
                        print("✅ Gateway → Wrapper → Target Lambda working!")
                        
                        content = call_result['result'].get('content', [])
                        if content:
                            print(f"📄 Response content preview:")
                            text_content = content[0].get('text', '')[:200]
                            print(f"   {text_content}...")
                        
                        return True
                    else:
                        print("⚠️  tools/call returned unexpected format")
                        print(json.dumps(call_result, indent=2)[:300])
                else:
                    print(f"❌ tools/call failed: {call_response.status_code}")
                    print(call_response.text[:200])
                
            else:
                print("⚠️  tools/list returned unexpected format")
                print(json.dumps(result, indent=2)[:300])
        else:
            print(f"❌ Request failed: {response.status_code}")
            print(response.text[:200])
    
    except Exception as e:
        print(f"❌ Test failed: {str(e)}")
    
    return False

if __name__ == "__main__":
    success = test_gateway_flow()
    if success:
        print("\n🎉 COMPLETE SUCCESS!")
        print("✅ Your MCP gateway is fully functional!")
    else:
        print("\n⚠️  Some issues detected")
        print("🔧 Check logs and configuration")
EOF

    python3 /tmp/test_complete_flow.py
    
    # Clean up
    rm -f /tmp/test_complete_flow.py /tmp/wrapper-response.json
    
else
    echo "⚠️  Skipping end-to-end test - gateway not properly configured"
    echo "   Please check gateway configuration manually"
fi

echo ""
echo "📋 FINAL SUMMARY"
echo "================"

echo ""
echo "🎯 Deployment Status:"

if [ "$FUNCTION_WORKING" = "true" ]; then
    echo "   ✅ MCP Wrapper Lambda: Working"
else
    echo "   ❌ MCP Wrapper Lambda: Issues detected"
fi

if [ "$UPDATE_SUCCESS" = "true" ]; then
    echo "   ✅ Gateway Update: Successful"
else
    echo "   ❌ Gateway Update: Failed or needs manual configuration"
fi

if [ "$GATEWAY_CONFIGURED" = "true" ]; then
    echo "   ✅ Gateway Configuration: Correct"
else
    echo "   ⚠️  Gateway Configuration: Needs verification"
fi

echo ""
echo "🚀 Next Steps:"

if [ "$FUNCTION_WORKING" = "true" ] && [ "$GATEWAY_CONFIGURED" = "true" ]; then
    echo "   🎉 Your setup is complete!"
    echo "   📋 Gateway URL: https://a208194-askjulius-agentcore-gateway-mcp-iam-fvro4phd59.gateway.bedrock-agentcore.us-east-1.amazonaws.com/mcp"
    echo "   🧪 Use MCP tools/list and tools/call methods"
    echo "   🔐 Authenticate with AWS SigV4 or Bearer token"
else
    echo "   🔧 Manual configuration still needed"
    echo "   📖 Check manual deployment guide"
    echo "   🌐 Use AWS Console if CLI methods fail"
fi

echo ""
echo "✅ Gateway update process completed!"