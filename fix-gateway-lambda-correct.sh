#!/bin/bash
# Fix Gateway Lambda Configuration - Correct Syntax
# Properly configure MCP gateway to target Lambda function

echo "🔧 Fixing Gateway Lambda Configuration with Correct Syntax"
echo "========================================================="
echo ""

GATEWAY_ID="a208194-askjulius-agentcore-gateway-mcp-iam-fvro4phd59"
LAMBDA_ARN="arn:aws:lambda:us-east-1:818565325759:function:a208194-chatops_application_details_intent"

echo "📋 Configuration:"
echo "  Gateway ID: $GATEWAY_ID"
echo "  Lambda ARN: $LAMBDA_ARN"
echo ""

echo "🔍 Step 1: Check Current Gateway Configuration"
echo "============================================="

echo "Getting current gateway details..."

GATEWAY_INFO=$(aws bedrock-agentcore-control get-gateway \
  --gateway-id "$GATEWAY_ID" \
  --output json 2>/dev/null)

if [ $? -eq 0 ]; then
    echo "✅ Current gateway configuration:"
    echo "$GATEWAY_INFO" | jq '{
      id: .id,
      name: .name,
      status: .status,
      authorizerType: .authorizerType,
      protocolType: .protocolType,
      roleArn: .roleArn
    }'
    
    # Check for existing Lambda configuration
    EXISTING_LAMBDA=$(echo "$GATEWAY_INFO" | jq -r '.lambdaArn // "none"')
    if [ "$EXISTING_LAMBDA" != "none" ] && [ "$EXISTING_LAMBDA" != "null" ]; then
        echo ""
        echo "📋 Current Lambda target: $EXISTING_LAMBDA"
    else
        echo ""
        echo "⚠️  No Lambda target currently configured"
    fi
else
    echo "❌ Cannot retrieve gateway information"
    exit 1
fi

echo ""
echo "🔍 Step 2: Check Available Update Parameters"
echo "==========================================="

echo "Checking what parameters are available for update-gateway..."

# Check help for update-gateway command
aws bedrock-agentcore-control update-gateway help 2>/dev/null | grep -A 20 "Synopsis\|Options" || echo "Help not available - will try common parameters"

echo ""
echo "🧪 Step 3: Try Different Configuration Methods"
echo "============================================="

echo "Method 1: Update with target-lambda-arn parameter..."

aws bedrock-agentcore-control update-gateway \
  --gateway-id "$GATEWAY_ID" \
  --target-lambda-arn "$LAMBDA_ARN" \
  --output json 2>&1

UPDATE_RESULT_1=$?

echo ""
echo "Method 2: Update with lambda-arn parameter..."

aws bedrock-agentcore-control update-gateway \
  --gateway-id "$GATEWAY_ID" \
  --lambda-arn "$LAMBDA_ARN" \
  --output json 2>&1

UPDATE_RESULT_2=$?

echo ""
echo "Method 3: Update with backend-configuration..."

aws bedrock-agentcore-control update-gateway \
  --gateway-id "$GATEWAY_ID" \
  --backend-configuration "lambdaArn=$LAMBDA_ARN" \
  --output json 2>&1

UPDATE_RESULT_3=$?

echo ""
echo "Method 4: Update with target-configuration..."

aws bedrock-agentcore-control update-gateway \
  --gateway-id "$GATEWAY_ID" \
  --target-configuration "{\"lambdaArn\":\"$LAMBDA_ARN\"}" \
  --output json 2>&1

UPDATE_RESULT_4=$?

echo ""
echo "🔍 Step 4: Alternative - Recreate Gateway with Lambda Target"
echo "=========================================================="

if [ $UPDATE_RESULT_1 -ne 0 ] && [ $UPDATE_RESULT_2 -ne 0 ] && [ $UPDATE_RESULT_3 -ne 0 ] && [ $UPDATE_RESULT_4 -ne 0 ]; then
    echo "⚠️  Update methods failed - trying to recreate gateway with Lambda target..."
    
    # Get current gateway details for recreation
    GATEWAY_NAME=$(echo "$GATEWAY_INFO" | jq -r '.name')
    GATEWAY_ROLE=$(echo "$GATEWAY_INFO" | jq -r '.roleArn')
    
    echo ""
    echo "📋 Gateway recreation parameters:"
    echo "  Name: $GATEWAY_NAME-v2"
    echo "  Role: $GATEWAY_ROLE"
    echo "  Lambda: $LAMBDA_ARN"
    echo ""
    
    read -p "Recreate gateway with Lambda target? (y/N): " recreate_gateway
    
    if [[ $recreate_gateway =~ ^[Yy]$ ]]; then
        echo ""
        echo "🔄 Creating new gateway with Lambda configuration..."
        
        # Try different creation syntax options
        echo "Trying creation method 1..."
        
        aws bedrock-agentcore-control create-gateway \
          --name "$GATEWAY_NAME-mcp-lambda" \
          --role-arn "$GATEWAY_ROLE" \
          --protocol-type MCP \
          --authorizer-type AWS_IAM \
          --target-lambda-arn "$LAMBDA_ARN" \
          --output json
        
        CREATE_RESULT_1=$?
        
        if [ $CREATE_RESULT_1 -ne 0 ]; then
            echo ""
            echo "Trying creation method 2..."
            
            aws bedrock-agentcore-control create-gateway \
              --name "$GATEWAY_NAME-mcp-lambda" \
              --role-arn "$GATEWAY_ROLE" \
              --protocol-type MCP \
              --authorizer-type AWS_IAM \
              --lambda-arn "$LAMBDA_ARN" \
              --output json
            
            CREATE_RESULT_2=$?
            
            if [ $CREATE_RESULT_2 -ne 0 ]; then
                echo ""
                echo "Trying creation method 3 with backend config..."
                
                aws bedrock-agentcore-control create-gateway \
                  --name "$GATEWAY_NAME-mcp-lambda" \
                  --role-arn "$GATEWAY_ROLE" \
                  --protocol-type MCP \
                  --authorizer-type AWS_IAM \
                  --backend-configuration "lambdaArn=$LAMBDA_ARN" \
                  --output json
            fi
        fi
    else
        echo "Skipping gateway recreation"
    fi
fi

echo ""
echo "🔍 Step 5: Manual Gateway Configuration via Console"
echo "================================================="

echo "If CLI methods don't work, configure via AWS Console:"
echo ""
echo "📋 Console Steps:"
echo "1. 🌐 Go to: https://console.aws.amazon.com/bedrock/"
echo "2. 🔍 Navigate to Agent Core → Gateways"
echo "3. 🎯 Find gateway: $GATEWAY_ID"
echo "4. ✏️  Click 'Edit' or 'Configure'"
echo "5. 🔧 Look for 'Backend Configuration' or 'Lambda Target'"
echo "6. 📝 Set Lambda ARN: $LAMBDA_ARN"
echo "7. 💾 Save configuration"
echo ""

echo "🔍 Step 6: Verify Gateway Configuration"
echo "======================================"

echo "Checking if gateway configuration was updated..."

sleep 5

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
      targetConfiguration: .targetConfiguration
    }'
    
    CONFIGURED_LAMBDA=$(echo "$UPDATED_GATEWAY" | jq -r '.lambdaArn // .targetConfiguration.lambdaArn // "none"')
    
    if [ "$CONFIGURED_LAMBDA" = "$LAMBDA_ARN" ]; then
        echo ""
        echo "🎉 SUCCESS! Lambda target configured correctly!"
        echo "✅ Gateway → Lambda integration ready"
    elif [ "$CONFIGURED_LAMBDA" != "none" ]; then
        echo ""
        echo "⚠️  Lambda configured but different ARN: $CONFIGURED_LAMBDA"
    else
        echo ""
        echo "❌ Lambda target still not configured"
    fi
else
    echo "❌ Cannot verify gateway configuration"
fi

echo ""
echo "🧪 Step 7: Test Gateway with Lambda Target"
echo "========================================"

echo "Testing gateway after Lambda configuration..."

python3 << 'EOF'
import boto3
import requests
from botocore.auth import SigV4Auth
from botocore.awsrequest import AWSRequest
import json
from urllib.parse import urlparse

gateway_url = "https://a208194-askjulius-agentcore-gateway-mcp-iam-fvro4phd59.gateway.bedrock-agentcore.us-east-1.amazonaws.com/mcp"

try:
    session = boto3.Session()
    credentials = session.get_credentials()
    
    # Test tools/list
    tools_url = f"{gateway_url}/tools/list"
    
    payload = {
        "jsonrpc": "2.0",
        "id": "test-lambda-config",
        "method": "tools/list",
        "params": {}
    }
    
    body = json.dumps(payload)
    parsed_url = urlparse(tools_url)
    
    request = AWSRequest(
        method='POST',
        url=tools_url,
        data=body,
        headers={
            'Content-Type': 'application/json',
            'Host': parsed_url.netloc
        }
    )
    
    SigV4Auth(credentials, 'bedrock-agentcore', 'us-east-1').add_auth(request)
    headers = dict(request.headers)
    
    response = requests.post(tools_url, headers=headers, data=body, timeout=30)
    
    print(f"🧪 Gateway Test Result:")
    print(f"Status: {response.status_code}")
    
    if response.status_code == 200:
        try:
            result = response.json()
            
            if 'result' in result and 'tools' in result['result']:
                print("🎉 SUCCESS! Gateway → Lambda working!")
                print("✅ MCP protocol functioning")
                tools = result['result']['tools']
                print(f"📋 Available tools: {len(tools)}")
                for tool in tools:
                    print(f"  • {tool.get('name', 'Unknown')}")
            elif 'Output' in result and 'UnknownOperationException' in str(result):
                print("⚠️  Still getting UnknownOperationException")
                print("   Lambda target may not be properly configured")
                print("   Or Lambda doesn't implement MCP protocol")
            else:
                print("✅ Gateway responding, checking format...")
                print(json.dumps(result, indent=2)[:300])
        except:
            print("✅ Gateway responding but not JSON")
            print(response.text[:200])
    else:
        print(f"❌ Gateway error: {response.status_code}")
        print(response.text[:200])

except Exception as e:
    print(f"❌ Test failed: {e}")

EOF

echo ""
echo "📋 SUMMARY & NEXT STEPS"
echo "======================="

echo ""
echo "🎯 Current Status:"
echo "   Gateway ID: $GATEWAY_ID"
echo "   Target Lambda: $LAMBDA_ARN"
echo ""

echo "✅ If Lambda target was configured successfully:"
echo "   1. Gateway should route MCP requests to your Lambda"
echo "   2. Test with tools/list and tools/call requests"
echo "   3. Check CloudWatch logs for Lambda execution"
echo ""

echo "❌ If configuration still fails:"
echo "   1. Use Console method (steps provided above)"
echo "   2. Consider deploying MCP wrapper Lambda"
echo "   3. Check Lambda function implements MCP protocol"
echo ""

echo "🚀 Alternative Solutions:"
echo "   • Deploy MCP wrapper: ./create-mcp-wrapper.sh"
echo "   • Modify existing Lambda to support MCP"
echo "   • Use different gateway configuration approach"

echo ""
echo "✅ Gateway Lambda configuration attempt completed!"
echo "📋 Check test results above to verify success"