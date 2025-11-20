#!/bin/bash
# CloudShell: Create API Gateway Endpoint for Calculator MCP Server
# Creates HTTP endpoint that can be used as target in Agent Core Gateway

echo "🌐 Creating API Gateway Endpoint for Calculator MCP Server"
echo "========================================================="
echo ""

CALCULATOR_FUNCTION_NAME="calculator-mcp-server"
API_NAME="calculator-mcp-api"
STAGE_NAME="prod"
REGION="us-east-1"

echo "🎯 Configuration:"
echo "  Calculator Lambda: $CALCULATOR_FUNCTION_NAME"
echo "  API Gateway Name: $API_NAME"
echo "  Stage: $STAGE_NAME"
echo "  Region: $REGION"
echo ""

echo "🔍 Step 1: Verify Calculator Lambda Exists"
echo "========================================"

echo "Checking if calculator Lambda function exists..."

CALCULATOR_ARN=$(aws lambda get-function --function-name "$CALCULATOR_FUNCTION_NAME" --query 'Configuration.FunctionArn' --output text 2>/dev/null)

if [ $? -eq 0 ]; then
    echo "✅ Calculator Lambda found!"
    echo "📋 ARN: $CALCULATOR_ARN"
else
    echo "❌ Calculator Lambda not found!"
    echo ""
    echo "🔧 Please run the calculator deployment script first:"
    echo "   ./create-calculator-mcp-server.sh"
    exit 1
fi

echo ""
echo "🌐 Step 2: Create API Gateway REST API"
echo "===================================="

echo "Creating REST API..."

# Create REST API
API_RESPONSE=$(aws apigateway create-rest-api \
  --name "$API_NAME" \
  --description "API Gateway endpoint for Calculator MCP Server" \
  --endpoint-configuration types=REGIONAL \
  --output json)

if [ $? -eq 0 ]; then
    API_ID=$(echo "$API_RESPONSE" | jq -r '.id')
    echo "✅ REST API created!"
    echo "📋 API ID: $API_ID"
else
    echo "❌ Failed to create REST API"
    exit 1
fi

# Get root resource ID
ROOT_RESOURCE_ID=$(aws apigateway get-resources \
  --rest-api-id "$API_ID" \
  --query 'items[?path==`/`].id' \
  --output text)

echo "📋 Root Resource ID: $ROOT_RESOURCE_ID"

echo ""
echo "🔧 Step 3: Create MCP Resource and Method"
echo "======================================"

# Create /mcp resource
echo "Creating /mcp resource..."

MCP_RESOURCE_RESPONSE=$(aws apigateway create-resource \
  --rest-api-id "$API_ID" \
  --parent-id "$ROOT_RESOURCE_ID" \
  --path-part "mcp" \
  --output json)

MCP_RESOURCE_ID=$(echo "$MCP_RESOURCE_RESPONSE" | jq -r '.id')
echo "✅ /mcp resource created!"
echo "📋 MCP Resource ID: $MCP_RESOURCE_ID"

# Create POST method
echo "Creating POST method..."

aws apigateway put-method \
  --rest-api-id "$API_ID" \
  --resource-id "$MCP_RESOURCE_ID" \
  --http-method POST \
  --authorization-type NONE \
  --no-api-key-required \
  --output json

echo "✅ POST method created!"

echo ""
echo "🔗 Step 4: Configure Lambda Integration"
echo "====================================="

echo "Setting up Lambda proxy integration..."

# Get account ID for Lambda URI
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
LAMBDA_URI="arn:aws:apigateway:${REGION}:lambda:path/2015-03-31/functions/${CALCULATOR_ARN}/invocations"

echo "📋 Lambda URI: $LAMBDA_URI"

# Put integration
aws apigateway put-integration \
  --rest-api-id "$API_ID" \
  --resource-id "$MCP_RESOURCE_ID" \
  --http-method POST \
  --type AWS_PROXY \
  --integration-http-method POST \
  --uri "$LAMBDA_URI" \
  --output json

echo "✅ Lambda integration configured!"

echo ""
echo "🔑 Step 5: Grant API Gateway Permission to Invoke Lambda"
echo "====================================================="

echo "Adding Lambda permission for API Gateway..."

# Generate unique statement ID
STATEMENT_ID="allow-api-gateway-invoke-$(date +%s)"

aws lambda add-permission \
  --function-name "$CALCULATOR_FUNCTION_NAME" \
  --statement-id "$STATEMENT_ID" \
  --action lambda:InvokeFunction \
  --principal apigateway.amazonaws.com \
  --source-arn "arn:aws:execute-api:${REGION}:${ACCOUNT_ID}:${API_ID}/*/*" \
  --output json

echo "✅ Lambda permission added!"

echo ""
echo "🚀 Step 6: Deploy API"
echo "==================="

echo "Deploying API to $STAGE_NAME stage..."

aws apigateway create-deployment \
  --rest-api-id "$API_ID" \
  --stage-name "$STAGE_NAME" \
  --stage-description "Production stage for Calculator MCP Server" \
  --description "Initial deployment of Calculator MCP API" \
  --output json

echo "✅ API deployed to $STAGE_NAME stage!"

# Construct API endpoint URL
API_ENDPOINT="https://${API_ID}.execute-api.${REGION}.amazonaws.com/${STAGE_NAME}/mcp"

echo ""
echo "🎉 API Gateway Endpoint Created!"
echo "📋 MCP Endpoint URL: $API_ENDPOINT"

echo ""
echo "🧪 Step 7: Test API Gateway Endpoint"
echo "=================================="

echo "Testing the API Gateway endpoint..."

# Test 1: Simple health check
echo ""
echo "Test 1: MCP tools/list via API Gateway"
echo "====================================="

sleep 5  # Wait for deployment to propagate

# Create test script
cat > /tmp/test_api_endpoint.py << 'EOF'
import requests
import json
import time

def test_mcp_api_endpoint():
    api_endpoint = "API_ENDPOINT_PLACEHOLDER"
    
    print(f"🌐 Testing API Endpoint: {api_endpoint}")
    print("=" * 50)
    
    # Test 1: tools/list
    print("\n📋 Test 1: MCP tools/list")
    print("-" * 25)
    
    payload = {
        "jsonrpc": "2.0",
        "id": "api-test-1",
        "method": "tools/list", 
        "params": {}
    }
    
    headers = {
        'Content-Type': 'application/json'
    }
    
    try:
        response = requests.post(api_endpoint, 
                               headers=headers, 
                               json=payload, 
                               timeout=30)
        
        print(f"Status Code: {response.status_code}")
        print(f"Response Headers: {dict(response.headers)}")
        
        if response.status_code == 200:
            try:
                result = response.json()
                print("✅ JSON Response received:")
                
                if 'result' in result and 'tools' in result['result']:
                    tools = result['result']['tools']
                    print(f"🎉 SUCCESS! Found {len(tools)} calculator tools:")
                    for tool in tools:
                        print(f"  • {tool.get('name', 'Unknown')}: {tool.get('description', 'No description')}")
                    
                    # Test 2: tools/call
                    print(f"\n🧮 Test 2: Calculator addition (7 + 5)")
                    print("-" * 30)
                    
                    calc_payload = {
                        "jsonrpc": "2.0",
                        "id": "api-test-2", 
                        "method": "tools/call",
                        "params": {
                            "name": "add",
                            "arguments": {
                                "a": 7,
                                "b": 5
                            }
                        }
                    }
                    
                    calc_response = requests.post(api_endpoint,
                                                headers=headers,
                                                json=calc_payload,
                                                timeout=30)
                    
                    print(f"Status Code: {calc_response.status_code}")
                    
                    if calc_response.status_code == 200:
                        calc_result = calc_response.json()
                        
                        if 'result' in calc_result:
                            print("🎉 CALCULATION SUCCESS!")
                            content = calc_result['result'].get('content', [])
                            if content:
                                result_text = content[0].get('text', '')
                                print(f"📊 {result_text}")
                                
                                if "12" in result_text:  # 7 + 5 = 12
                                    print("✅ Correct calculation result!")
                                    return True
                                else:
                                    print("⚠️  Unexpected calculation result")
                            else:
                                print("⚠️  No content in calculation response")
                        else:
                            print("⚠️  Unexpected calculation response format")
                            print(json.dumps(calc_result, indent=2)[:300])
                    else:
                        print(f"❌ Calculation request failed: {calc_response.status_code}")
                        print(calc_response.text[:200])
                        
                else:
                    print("⚠️  Unexpected tools/list response format")
                    print(json.dumps(result, indent=2)[:300])
                    
            except json.JSONDecodeError as e:
                print(f"❌ JSON parse error: {e}")
                print("Raw response:")
                print(response.text[:500])
                
        else:
            print(f"❌ HTTP Error: {response.status_code}")
            print("Response:")
            print(response.text[:300])
    
    except Exception as e:
        print(f"❌ Test failed: {str(e)}")
    
    return False

if __name__ == "__main__":
    success = test_mcp_api_endpoint()
    if success:
        print("\n🎉 API ENDPOINT TEST SUCCESSFUL!")
        print("✅ MCP server is accessible via HTTP endpoint!")
        print("🌐 Ready to use as Agent Core Gateway target!")
    else:
        print("\n⚠️  API endpoint test failed")
        print("🔧 Check API Gateway configuration and Lambda function")
EOF

# Replace placeholder with actual endpoint
sed -i "s|API_ENDPOINT_PLACEHOLDER|$API_ENDPOINT|g" /tmp/test_api_endpoint.py

python3 /tmp/test_api_endpoint.py

echo ""
echo "🔍 Step 8: Configure CORS (Optional)"
echo "=================================="

echo "Adding CORS support for web browser access..."

# Add OPTIONS method for CORS
aws apigateway put-method \
  --rest-api-id "$API_ID" \
  --resource-id "$MCP_RESOURCE_ID" \
  --http-method OPTIONS \
  --authorization-type NONE \
  --no-api-key-required \
  --output json >/dev/null 2>&1

# Add mock integration for OPTIONS
aws apigateway put-integration \
  --rest-api-id "$API_ID" \
  --resource-id "$MCP_RESOURCE_ID" \
  --http-method OPTIONS \
  --type MOCK \
  --request-templates '{"application/json":"{\"statusCode\":200}"}' \
  --output json >/dev/null 2>&1

# Add OPTIONS method response
aws apigateway put-method-response \
  --rest-api-id "$API_ID" \
  --resource-id "$MCP_RESOURCE_ID" \
  --http-method OPTIONS \
  --status-code 200 \
  --response-parameters '{"method.response.header.Access-Control-Allow-Headers":false,"method.response.header.Access-Control-Allow-Methods":false,"method.response.header.Access-Control-Allow-Origin":false}' \
  --output json >/dev/null 2>&1

# Add OPTIONS integration response  
aws apigateway put-integration-response \
  --rest-api-id "$API_ID" \
  --resource-id "$MCP_RESOURCE_ID" \
  --http-method OPTIONS \
  --status-code 200 \
  --response-parameters '{"method.response.header.Access-Control-Allow-Headers":"'"'"'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"'"'","method.response.header.Access-Control-Allow-Methods":"'"'"'POST,OPTIONS'"'"'","method.response.header.Access-Control-Allow-Origin":"'"'"'*'"'"'"}' \
  --output json >/dev/null 2>&1

# Redeploy API with CORS
aws apigateway create-deployment \
  --rest-api-id "$API_ID" \
  --stage-name "$STAGE_NAME" \
  --description "Added CORS support" \
  --output json >/dev/null 2>&1

echo "✅ CORS support added!"

# Clean up test file
rm -f /tmp/test_api_endpoint.py

echo ""
echo "📋 API GATEWAY ENDPOINT SUMMARY"
echo "==============================="

echo ""
echo "🎯 Created Resources:"
echo "   📡 REST API ID: $API_ID"
echo "   📋 API Name: $API_NAME" 
echo "   🌐 MCP Endpoint: $API_ENDPOINT"
echo "   📊 Stage: $STAGE_NAME"

echo ""
echo "🔗 Target Configuration for Agent Core Gateway:"
echo "=============================================="
echo ""
echo "🎯 Use this endpoint URL in your gateway target configuration:"
echo ""
echo "   Target Type: HTTP Endpoint"
echo "   Endpoint URL: $API_ENDPOINT"
echo "   Protocol: HTTPS"
echo "   Method: POST"
echo ""

echo "📋 Gateway Update Command:"
echo "========================="
echo ""
echo "aws bedrock-agentcore-control update-gateway \\"
echo "  --gateway-id \"a208194-askjulius-agentcore-gateway-mcp-iam-fvro4phd59\" \\"
echo "  --target-endpoint-url \"$API_ENDPOINT\" \\"
echo "  --output json"
echo ""
echo "(Note: Parameter name might be different - try --endpoint-url or --backend-endpoint)"

echo ""
echo "🧪 Test Commands:"
echo "================"
echo ""
echo "# Test with curl:"
echo "curl -X POST '$API_ENDPOINT' \\"
echo "  -H 'Content-Type: application/json' \\"
echo "  -d '{\"jsonrpc\":\"2.0\",\"id\":\"test\",\"method\":\"tools/list\",\"params\":{}}'"
echo ""

echo "🌐 Available Calculator Tools via HTTP:"
echo "======================================="
echo "   • add(a, b) - Addition"
echo "   • subtract(a, b) - Subtraction"
echo "   • multiply(a, b) - Multiplication"
echo "   • divide(a, b) - Division"
echo "   • power(base, exponent) - Exponentiation"
echo "   • sqrt(number) - Square root"
echo "   • factorial(n) - Factorial"

echo ""
echo "✅ API Gateway MCP endpoint creation completed!"
echo "🌐 Your MCP server now has an HTTP endpoint!"
echo "🎯 Ready to configure as Agent Core Gateway target!"