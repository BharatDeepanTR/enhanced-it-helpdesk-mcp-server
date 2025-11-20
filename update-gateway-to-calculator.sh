#!/bin/bash
# CloudShell: Update Existing Gateway to Use Calculator MCP Server
# Quick script to switch your gateway from the problematic Lambda to the working calculator

echo "🔗 Update Gateway to Calculator MCP Server"
echo "=========================================="
echo ""

GATEWAY_ID="a208194-askjulius-agentcore-gateway-mcp-iam-fvro4phd59"
CALCULATOR_FUNCTION_NAME="calculator-mcp-server"

echo "🎯 Configuration:"
echo "  Gateway ID: $GATEWAY_ID"
echo "  Calculator Function: $CALCULATOR_FUNCTION_NAME"
echo ""

echo "🔍 Step 1: Get Calculator Function ARN"
echo "===================================="

echo "Looking up calculator Lambda function..."

CALCULATOR_ARN=$(aws lambda get-function --function-name "$CALCULATOR_FUNCTION_NAME" --query 'Configuration.FunctionArn' --output text 2>/dev/null)

if [ $? -eq 0 ]; then
    echo "✅ Calculator function found!"
    echo "📋 ARN: $CALCULATOR_ARN"
else
    echo "❌ Calculator function not found!"
    echo ""
    echo "🔧 Please run the calculator deployment script first:"
    echo "   ./create-calculator-mcp-server.sh"
    exit 1
fi

echo ""
echo "🔍 Step 2: Check Current Gateway Configuration"
echo "==========================================="

echo "Checking current gateway settings..."

GATEWAY_INFO=$(aws bedrock-agentcore-control get-gateway \
  --gateway-id "$GATEWAY_ID" \
  --output json 2>/dev/null)

if [ $? -eq 0 ]; then
    echo "✅ Gateway found!"
    
    # Show current configuration
    echo ""
    echo "📊 Current Gateway Configuration:"
    echo "$GATEWAY_INFO" | jq '{
      id: .id,
      name: .name,
      status: .status,
      authorizerType: .authorizerType,
      protocolType: .protocolType,
      roleArn: .roleArn,
      lambdaArn: .lambdaArn
    }' 2>/dev/null || echo "$GATEWAY_INFO"
    
    # Check current Lambda target
    CURRENT_LAMBDA=$(echo "$GATEWAY_INFO" | jq -r '.lambdaArn // "none"' 2>/dev/null)
    
    if [ "$CURRENT_LAMBDA" != "none" ] && [ "$CURRENT_LAMBDA" != "null" ]; then
        echo ""
        echo "📋 Current Lambda target: $CURRENT_LAMBDA"
        
        if [[ "$CURRENT_LAMBDA" == *"calculator"* ]]; then
            echo "✅ Gateway is already configured with calculator!"
            echo "🎉 No update needed!"
            exit 0
        fi
    else
        echo ""
        echo "⚠️  No Lambda target currently configured"
    fi
else
    echo "❌ Gateway not found or access error"
    echo "Please check gateway ID and permissions"
    exit 1
fi

echo ""
echo "🔧 Step 3: Update Gateway to Calculator"
echo "====================================="

echo "Updating gateway to use calculator MCP server..."

# Try different methods to update gateway
echo "Method 1: Using --target-lambda-arn parameter..."

UPDATE_RESPONSE_1=$(aws bedrock-agentcore-control update-gateway \
  --gateway-id "$GATEWAY_ID" \
  --target-lambda-arn "$CALCULATOR_ARN" \
  --output json 2>&1)

UPDATE_RESULT_1=$?

echo "Response: $UPDATE_RESPONSE_1"

if [ $UPDATE_RESULT_1 -eq 0 ]; then
    echo "🎉 SUCCESS with method 1!"
    UPDATE_SUCCESS=true
else
    echo ""
    echo "Method 2: Using --lambda-arn parameter..."
    
    UPDATE_RESPONSE_2=$(aws bedrock-agentcore-control update-gateway \
      --gateway-id "$GATEWAY_ID" \
      --lambda-arn "$CALCULATOR_ARN" \
      --output json 2>&1)
    
    UPDATE_RESULT_2=$?
    echo "Response: $UPDATE_RESPONSE_2"
    
    if [ $UPDATE_RESULT_2 -eq 0 ]; then
        echo "🎉 SUCCESS with method 2!"
        UPDATE_SUCCESS=true
    else
        echo ""
        echo "Method 3: Using --backend-configuration parameter..."
        
        UPDATE_RESPONSE_3=$(aws bedrock-agentcore-control update-gateway \
          --gateway-id "$GATEWAY_ID" \
          --backend-configuration "lambdaArn=$CALCULATOR_ARN" \
          --output json 2>&1)
        
        UPDATE_RESULT_3=$?
        echo "Response: $UPDATE_RESPONSE_3"
        
        if [ $UPDATE_RESULT_3 -eq 0 ]; then
            echo "🎉 SUCCESS with method 3!"
            UPDATE_SUCCESS=true
        fi
    fi
fi

echo ""
echo "🔍 Step 4: Verify Gateway Update"
echo "=============================="

sleep 3

echo "Checking updated gateway configuration..."

UPDATED_GATEWAY=$(aws bedrock-agentcore-control get-gateway \
  --gateway-id "$GATEWAY_ID" \
  --output json 2>/dev/null)

if [ $? -eq 0 ]; then
    echo "✅ Updated gateway configuration:"
    
    echo "$UPDATED_GATEWAY" | jq '{
      id: .id,
      name: .name,
      status: .status,
      lambdaArn: .lambdaArn,
      lastModified: .lastModified
    }' 2>/dev/null || echo "$UPDATED_GATEWAY"
    
    # Check if calculator is now configured
    CONFIGURED_LAMBDA=$(echo "$UPDATED_GATEWAY" | jq -r '.lambdaArn // "none"' 2>/dev/null)
    
    if [ "$CONFIGURED_LAMBDA" = "$CALCULATOR_ARN" ]; then
        echo ""
        echo "🎉 PERFECT! Gateway now configured with calculator!"
        echo "✅ Lambda ARN matches: $CONFIGURED_LAMBDA"
        GATEWAY_UPDATED=true
    elif [[ "$CONFIGURED_LAMBDA" == *"calculator"* ]]; then
        echo ""
        echo "✅ Gateway has calculator function (possibly different version)"
        echo "📋 Configured: $CONFIGURED_LAMBDA"
        echo "📋 Expected: $CALCULATOR_ARN"
        GATEWAY_UPDATED=true
    else
        echo ""
        echo "⚠️  Gateway may not be updated correctly"
        echo "📋 Current Lambda: $CONFIGURED_LAMBDA"
        echo "📋 Expected: $CALCULATOR_ARN"
    fi
else
    echo "❌ Could not verify gateway update"
fi

echo ""
echo "🧪 Step 5: Test Updated Gateway"
echo "=============================="

if [ "$GATEWAY_UPDATED" = "true" ]; then
    echo "Testing gateway with calculator..."
    
    # Create test script
    cat > /tmp/test_calculator_gateway.py << 'EOF'
import boto3
import requests
from botocore.auth import SigV4Auth
from botocore.awsrequest import AWSRequest
import json
from urllib.parse import urlparse

def test_calculator_gateway():
    gateway_url = "https://a208194-askjulius-agentcore-gateway-mcp-iam-fvro4phd59.gateway.bedrock-agentcore.us-east-1.amazonaws.com/mcp"
    
    print("🧮 Testing Calculator Gateway Integration")
    print("=" * 45)
    
    session = boto3.Session()
    credentials = session.get_credentials()
    
    # Test 1: tools/list
    print("\n📋 Test 1: Get available calculator tools")
    print("-" * 35)
    
    payload = {
        "jsonrpc": "2.0",
        "id": "calc-tools-test",
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
                print(f"🎉 SUCCESS! Found {len(tools)} calculator tools:")
                for tool in tools:
                    print(f"  • {tool.get('name', 'Unknown')}: {tool.get('description', 'No description')}")
                
                # Test 2: tools/call - Addition
                print(f"\n🧮 Test 2: Calculator addition (5 + 3)")
                print("-" * 35)
                
                calc_payload = {
                    "jsonrpc": "2.0",
                    "id": "calc-add-test",
                    "method": "tools/call",
                    "params": {
                        "name": "add",
                        "arguments": {
                            "a": 5,
                            "b": 3
                        }
                    }
                }
                
                calc_body = json.dumps(calc_payload)
                calc_request = AWSRequest(
                    method='POST',
                    url=gateway_url,
                    data=calc_body,
                    headers={
                        'Content-Type': 'application/json',
                        'Host': parsed_url.netloc
                    }
                )
                
                SigV4Auth(credentials, 'bedrock-agentcore', 'us-east-1').add_auth(calc_request)
                calc_headers = dict(calc_request.headers)
                
                calc_response = requests.post(gateway_url, headers=calc_headers, data=calc_body, timeout=30)
                
                print(f"Status: {calc_response.status_code}")
                
                if calc_response.status_code == 200:
                    calc_result = calc_response.json()
                    
                    if 'result' in calc_result:
                        print("🎉 CALCULATION SUCCESS!")
                        content = calc_result['result'].get('content', [])
                        if content:
                            result_text = content[0].get('text', '')
                            print(f"📊 {result_text}")
                        
                        return True
                    else:
                        print("⚠️  Unexpected calculation response format")
                        print(json.dumps(calc_result, indent=2)[:300])
                else:
                    print(f"❌ Calculation request failed: {calc_response.status_code}")
                    print(calc_response.text[:200])
                
            else:
                print("⚠️  Unexpected tools/list response format")
                print(json.dumps(result, indent=2)[:300])
        else:
            print(f"❌ Gateway request failed: {response.status_code}")
            print(response.text[:200])
    
    except Exception as e:
        print(f"❌ Test failed: {str(e)}")
    
    return False

if __name__ == "__main__":
    success = test_calculator_gateway()
    if success:
        print("\n🎉 COMPLETE SUCCESS!")
        print("✅ Gateway → Calculator MCP server working perfectly!")
        print("🧮 Ready to use calculator operations through gateway!")
    else:
        print("\n⚠️  Issues detected")
        print("🔧 Check gateway configuration and calculator deployment")
EOF

    python3 /tmp/test_calculator_gateway.py
    
    # Clean up
    rm -f /tmp/test_calculator_gateway.py
    
else
    echo "⚠️  Skipping test - gateway not properly updated"
fi

echo ""
echo "📋 GATEWAY UPDATE SUMMARY"
echo "========================"

echo ""
echo "🎯 Update Status:"

if [ "$UPDATE_SUCCESS" = "true" ]; then
    echo "   ✅ Gateway Update Command: Successful"
else
    echo "   ❌ Gateway Update Command: Failed"
fi

if [ "$GATEWAY_UPDATED" = "true" ]; then
    echo "   ✅ Gateway Configuration: Calculator configured"
    echo "   ✅ Calculator ARN: $CALCULATOR_ARN"
else
    echo "   ⚠️  Gateway Configuration: Needs verification"
fi

echo ""
echo "🧮 Calculator Tools Available:"
echo "   • add(a, b) - Addition"
echo "   • subtract(a, b) - Subtraction"
echo "   • multiply(a, b) - Multiplication" 
echo "   • divide(a, b) - Division"
echo "   • power(base, exponent) - Exponentiation"
echo "   • sqrt(number) - Square root"
echo "   • factorial(n) - Factorial"

echo ""
echo "🚀 Gateway Endpoint:"
echo "   https://a208194-askjulius-agentcore-gateway-mcp-iam-fvro4phd59.gateway.bedrock-agentcore.us-east-1.amazonaws.com/mcp"

echo ""
echo "🧪 Test Commands:"
echo "   tools/list: Get all available tools"
echo "   tools/call: Execute calculator operations"

echo ""
if [ "$GATEWAY_UPDATED" = "true" ]; then
    echo "✅ Gateway update completed successfully!"
    echo "🧮 Your gateway now provides calculator functionality via MCP protocol!"
else
    echo "⚠️  Gateway update may need manual configuration"
    echo "🔧 Try updating via AWS Console if CLI methods failed"
fi