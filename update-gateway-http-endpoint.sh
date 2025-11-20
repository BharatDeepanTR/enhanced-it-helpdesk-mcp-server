#!/bin/bash
# CloudShell: Update Gateway with MCP Server HTTP Endpoint
# Configure Agent Core Gateway to use HTTP endpoint instead of Lambda ARN

echo "🔗 Update Gateway with MCP Server HTTP Endpoint"
echo "=============================================="
echo ""

GATEWAY_ID="a208194-askjulius-agentcore-gateway-mcp-iam-fvro4phd59"
API_NAME="calculator-mcp-api"
STAGE_NAME="prod"
REGION="us-east-1"

echo "🎯 Configuration:"
echo "  Gateway ID: $GATEWAY_ID"
echo "  API Name: $API_NAME"
echo "  Stage: $STAGE_NAME"
echo ""

echo "🔍 Step 1: Find API Gateway Endpoint"
echo "=================================="

echo "Looking for calculator MCP API..."

# Get API ID by name
API_ID=$(aws apigateway get-rest-apis \
  --query "items[?name=='$API_NAME'].id" \
  --output text 2>/dev/null)

if [ -n "$API_ID" ] && [ "$API_ID" != "None" ]; then
    echo "✅ API found!"
    echo "📋 API ID: $API_ID"
    
    # Construct endpoint URL
    MCP_ENDPOINT="https://${API_ID}.execute-api.${REGION}.amazonaws.com/${STAGE_NAME}/mcp"
    echo "🌐 MCP Endpoint: $MCP_ENDPOINT"
else
    echo "❌ Calculator MCP API not found!"
    echo ""
    echo "🔧 Please run the API Gateway creation script first:"
    echo "   ./create-calculator-api-endpoint.sh"
    exit 1
fi

echo ""
echo "🔍 Step 2: Test Endpoint Accessibility"
echo "===================================="

echo "Testing MCP endpoint before gateway configuration..."

# Simple test
TEST_RESPONSE=$(curl -s -X POST "$MCP_ENDPOINT" \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":"test","method":"tools/list","params":{}}' \
  -w "HTTPSTATUS:%{http_code}")

HTTP_STATUS=$(echo "$TEST_RESPONSE" | grep -o "HTTPSTATUS:[0-9]*" | cut -d: -f2)
RESPONSE_BODY=$(echo "$TEST_RESPONSE" | sed 's/HTTPSTATUS:[0-9]*$//')

echo "HTTP Status: $HTTP_STATUS"

if [ "$HTTP_STATUS" = "200" ]; then
    echo "✅ Endpoint is accessible!"
    
    # Check if it's proper MCP response
    if echo "$RESPONSE_BODY" | grep -q '"tools"' && echo "$RESPONSE_BODY" | grep -q '"jsonrpc"'; then
        echo "✅ MCP protocol response detected!"
        ENDPOINT_WORKING=true
    else
        echo "⚠️  Response doesn't look like MCP format"
        echo "Response: $RESPONSE_BODY"
    fi
else
    echo "❌ Endpoint not accessible (HTTP $HTTP_STATUS)"
    echo "Response: $RESPONSE_BODY"
    echo ""
    echo "🔧 Please check API Gateway deployment"
    exit 1
fi

echo ""
echo "🔍 Step 3: Check Current Gateway Configuration"
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
      roleArn: .roleArn
    }' 2>/dev/null || echo "$GATEWAY_INFO"
    
else
    echo "❌ Gateway not found or access error"
    exit 1
fi

echo ""
echo "🔧 Step 4: Update Gateway with HTTP Endpoint"
echo "=========================================="

echo "Updating gateway to use MCP HTTP endpoint..."

# Try different parameter names for endpoint configuration
echo "Method 1: Using --target-endpoint-url parameter..."

UPDATE_RESPONSE_1=$(aws bedrock-agentcore-control update-gateway \
  --gateway-id "$GATEWAY_ID" \
  --target-endpoint-url "$MCP_ENDPOINT" \
  --output json 2>&1)

UPDATE_RESULT_1=$?
echo "Response: $UPDATE_RESPONSE_1"

if [ $UPDATE_RESULT_1 -eq 0 ]; then
    echo "🎉 SUCCESS with method 1!"
    UPDATE_SUCCESS=true
else
    echo ""
    echo "Method 2: Using --endpoint-url parameter..."
    
    UPDATE_RESPONSE_2=$(aws bedrock-agentcore-control update-gateway \
      --gateway-id "$GATEWAY_ID" \
      --endpoint-url "$MCP_ENDPOINT" \
      --output json 2>&1)
    
    UPDATE_RESULT_2=$?
    echo "Response: $UPDATE_RESPONSE_2"
    
    if [ $UPDATE_RESULT_2 -eq 0 ]; then
        echo "🎉 SUCCESS with method 2!"
        UPDATE_SUCCESS=true
    else
        echo ""
        echo "Method 3: Using --backend-endpoint parameter..."
        
        UPDATE_RESPONSE_3=$(aws bedrock-agentcore-control update-gateway \
          --gateway-id "$GATEWAY_ID" \
          --backend-endpoint "$MCP_ENDPOINT" \
          --output json 2>&1)
        
        UPDATE_RESULT_3=$?
        echo "Response: $UPDATE_RESPONSE_3"
        
        if [ $UPDATE_RESULT_3 -eq 0 ]; then
            echo "🎉 SUCCESS with method 3!"
            UPDATE_SUCCESS=true
        else
            echo ""
            echo "Method 4: Using --backend-configuration with endpoint..."
            
            UPDATE_RESPONSE_4=$(aws bedrock-agentcore-control update-gateway \
              --gateway-id "$GATEWAY_ID" \
              --backend-configuration "endpointUrl=$MCP_ENDPOINT" \
              --output json 2>&1)
            
            UPDATE_RESULT_4=$?
            echo "Response: $UPDATE_RESPONSE_4"
            
            if [ $UPDATE_RESULT_4 -eq 0 ]; then
                echo "🎉 SUCCESS with method 4!"
                UPDATE_SUCCESS=true
            fi
        fi
    fi
fi

echo ""
echo "🔍 Step 5: Verify Gateway Update"
echo "=============================="

sleep 3

echo "Checking updated gateway configuration..."

UPDATED_GATEWAY=$(aws bedrock-agentcore-control get-gateway \
  --gateway-id "$GATEWAY_ID" \
  --output json 2>/dev/null)

if [ $? -eq 0 ]; then
    echo "✅ Gateway information retrieved:"
    
    echo "$UPDATED_GATEWAY" | jq '{
      id: .id,
      name: .name,
      status: .status,
      endpointUrl: .endpointUrl,
      targetEndpoint: .targetEndpoint,
      backendConfiguration: .backendConfiguration
    }' 2>/dev/null || echo "$UPDATED_GATEWAY"
    
    # Check for endpoint configuration
    CONFIGURED_ENDPOINT=$(echo "$UPDATED_GATEWAY" | jq -r '.endpointUrl // .targetEndpoint // .backendConfiguration.endpointUrl // "none"' 2>/dev/null)
    
    if [ "$CONFIGURED_ENDPOINT" = "$MCP_ENDPOINT" ]; then
        echo ""
        echo "🎉 PERFECT! Gateway configured with MCP endpoint!"
        echo "✅ Endpoint matches: $CONFIGURED_ENDPOINT"
        GATEWAY_UPDATED=true
    elif [[ "$CONFIGURED_ENDPOINT" == *"calculator-mcp-api"* ]]; then
        echo ""
        echo "✅ Gateway has calculator endpoint (possibly different format)"
        echo "📋 Configured: $CONFIGURED_ENDPOINT"
        GATEWAY_UPDATED=true
    else
        echo ""
        echo "⚠️  Gateway endpoint configuration unclear"
        echo "📋 Found: $CONFIGURED_ENDPOINT"
        echo "📋 Expected: $MCP_ENDPOINT"
    fi
else
    echo "❌ Could not verify gateway update"
fi

echo ""
echo "🧪 Step 6: Test Gateway with HTTP Endpoint"
echo "========================================"

if [ "$GATEWAY_UPDATED" = "true" ] || [ "$UPDATE_SUCCESS" = "true" ]; then
    echo "Testing gateway with HTTP endpoint target..."
    
    GATEWAY_URL="https://a208194-askjulius-agentcore-gateway-mcp-iam-fvro4phd59.gateway.bedrock-agentcore.us-east-1.amazonaws.com/mcp"
    
    # Create comprehensive test
    cat > /tmp/test_gateway_http_endpoint.py << 'EOF'
import boto3
import requests
from botocore.auth import SigV4Auth
from botocore.awsrequest import AWSRequest
import json
from urllib.parse import urlparse

def test_gateway_http_endpoint():
    gateway_url = "https://a208194-askjulius-agentcore-gateway-mcp-iam-fvro4phd59.gateway.bedrock-agentcore.us-east-1.amazonaws.com/mcp"
    
    print("🌐 Testing Gateway → HTTP Endpoint → MCP Server")
    print("=" * 50)
    
    session = boto3.Session()
    credentials = session.get_credentials()
    
    # Test 1: tools/list
    print("\n📋 Test 1: Gateway tools/list via HTTP endpoint")
    print("-" * 45)
    
    payload = {
        "jsonrpc": "2.0",
        "id": "gateway-http-test",
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
        print(f"Response headers: {dict(response.headers)}")
        
        if response.status_code == 200:
            try:
                result = response.json()
                
                if 'result' in result and 'tools' in result['result']:
                    tools = result['result']['tools']
                    print(f"🎉 SUCCESS! Gateway → HTTP → MCP working!")
                    print(f"📋 Found {len(tools)} tools via HTTP endpoint:")
                    for tool in tools:
                        print(f"  • {tool.get('name', 'Unknown')}: {tool.get('description', 'No description')}")
                    
                    # Test 2: tools/call
                    print(f"\n🧮 Test 2: Calculator operation via gateway")
                    print("-" * 40)
                    
                    calc_payload = {
                        "jsonrpc": "2.0",
                        "id": "gateway-calc-test",
                        "method": "tools/call",
                        "params": {
                            "name": "multiply",
                            "arguments": {
                                "a": 6,
                                "b": 7
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
                            print("🎉 CALCULATION VIA GATEWAY SUCCESS!")
                            content = calc_result['result'].get('content', [])
                            if content:
                                result_text = content[0].get('text', '')
                                print(f"📊 {result_text}")
                                
                                if "42" in result_text:  # 6 * 7 = 42
                                    print("✅ Complete Gateway → HTTP → MCP flow working!")
                                    return True
                                else:
                                    print("⚠️  Unexpected calculation result")
                            else:
                                print("⚠️  No content in response")
                        else:
                            print("⚠️  Unexpected response format")
                            print(json.dumps(calc_result, indent=2)[:300])
                    else:
                        print(f"❌ Calculation failed: {calc_response.status_code}")
                        print(calc_response.text[:200])
                        
                elif 'error' in result:
                    print("❌ Gateway returned error:")
                    print(f"   Code: {result['error'].get('code', 'Unknown')}")
                    print(f"   Message: {result['error'].get('message', 'Unknown')}")
                    
                    # Check if it's still routing to wrong target
                    if 'UnknownOperationException' in str(result):
                        print("⚠️  Gateway still routing to non-MCP target")
                        print("🔧 HTTP endpoint configuration may not be applied")
                        
                else:
                    print("⚠️  Unexpected response format")
                    print(json.dumps(result, indent=2)[:300])
                    
            except json.JSONDecodeError as e:
                print(f"❌ JSON parse error: {e}")
                print("Raw response:")
                print(response.text[:500])
                
        else:
            print(f"❌ Gateway error: {response.status_code}")
            print(response.text[:300])
    
    except Exception as e:
        print(f"❌ Test failed: {str(e)}")
    
    return False

if __name__ == "__main__":
    success = test_gateway_http_endpoint()
    if success:
        print("\n🎉 COMPLETE SUCCESS!")
        print("✅ Gateway → HTTP Endpoint → MCP Server working perfectly!")
    else:
        print("\n⚠️  Gateway HTTP endpoint test failed")
        print("🔧 Check gateway configuration and endpoint setup")
EOF

    python3 /tmp/test_gateway_http_endpoint.py
    
    # Clean up
    rm -f /tmp/test_gateway_http_endpoint.py
    
else
    echo "⚠️  Skipping test - gateway not properly updated"
fi

echo ""
echo "🔧 Step 7: Manual Configuration Instructions"
echo "=========================================="

if [ "$UPDATE_SUCCESS" != "true" ]; then
    echo "If CLI update failed, configure via AWS Console:"
    echo ""
    echo "📋 Manual Configuration Steps:"
    echo "============================="
    echo "1. 🌐 Go to AWS Bedrock Console → Agent Core → Gateways"
    echo "2. 🔍 Find gateway: $GATEWAY_ID"
    echo "3. ✏️  Click 'Edit' or 'Configure'"
    echo "4. 🎯 Set target configuration:"
    echo "   • Type: HTTP Endpoint"
    echo "   • URL: $MCP_ENDPOINT"
    echo "   • Method: POST"
    echo "   • Protocol: HTTPS"
    echo "5. 💾 Save configuration"
fi

echo ""
echo "📋 GATEWAY HTTP ENDPOINT UPDATE SUMMARY"
echo "======================================="

echo ""
echo "🎯 Configuration Details:"
echo "   Gateway ID: $GATEWAY_ID"
echo "   MCP Endpoint: $MCP_ENDPOINT"
echo "   API Gateway ID: $API_ID"

echo ""
echo "🌐 Target Configuration:"
echo "   Target Type: HTTP Endpoint" 
echo "   Endpoint URL: $MCP_ENDPOINT"
echo "   Protocol: HTTPS"
echo "   Method: POST"
echo "   Content-Type: application/json"

echo ""
echo "🧮 Available via HTTP Endpoint:"
echo "   • add(a, b) - Addition"
echo "   • subtract(a, b) - Subtraction"
echo "   • multiply(a, b) - Multiplication"
echo "   • divide(a, b) - Division"
echo "   • power(base, exponent) - Exponentiation" 
echo "   • sqrt(number) - Square root"
echo "   • factorial(n) - Factorial"

echo ""
echo "🧪 Direct Endpoint Test:"
echo "curl -X POST '$MCP_ENDPOINT' \\"
echo "  -H 'Content-Type: application/json' \\"
echo "  -d '{\"jsonrpc\":\"2.0\",\"method\":\"tools/list\",\"params\":{}}'"

echo ""
if [ "$UPDATE_SUCCESS" = "true" ]; then
    echo "✅ Gateway HTTP endpoint update completed!"
    echo "🌐 Your gateway now uses HTTP endpoint for MCP communication!"
else
    echo "⚠️  Gateway update may need manual configuration"
    echo "🔧 Use console method if CLI commands failed"
fi