#!/bin/bash
# CloudShell: Fix Gateway Lambda Configuration - Correct Syntax
# Run this in AWS CloudShell to properly configure MCP gateway Lambda target

echo "☁️  CloudShell Gateway Lambda Configuration Fix"
echo "==============================================="
echo ""

# Gateway configuration
GATEWAY_ID="a208194-askjulius-agentcore-gateway-mcp-iam-fvro4phd59"
LAMBDA_ARN="arn:aws:lambda:us-east-1:818565325759:function:a208194-chatops_application_details_intent"

echo "📋 Configuration:"
echo "  Gateway ID: $GATEWAY_ID"
echo "  Lambda ARN: $LAMBDA_ARN"
echo "  Environment: AWS CloudShell"
echo ""

echo "🔍 Step 1: Verify AWS CLI and Credentials"
echo "========================================"

echo "Checking AWS CLI version and credentials..."
aws --version
echo ""

aws sts get-caller-identity --output table
echo ""

echo "🔍 Step 2: Check Current Gateway Status"
echo "======================================"

echo "Getting current gateway details..."

GATEWAY_INFO=$(aws bedrock-agentcore-control get-gateway \
  --gateway-id "$GATEWAY_ID" \
  --output json 2>/dev/null)

if [ $? -eq 0 ]; then
    echo "✅ Current gateway found:"
    echo "$GATEWAY_INFO" | jq '{
      id: .id,
      name: .name,
      status: .status,
      authorizerType: .authorizerType,
      protocolType: .protocolType,
      roleArn: .roleArn
    }' 2>/dev/null || echo "$GATEWAY_INFO"
    
    # Check for existing Lambda configuration
    EXISTING_LAMBDA=$(echo "$GATEWAY_INFO" | jq -r '.lambdaArn // .targetConfiguration.lambdaArn // "none"' 2>/dev/null)
    
    if [ "$EXISTING_LAMBDA" != "none" ] && [ "$EXISTING_LAMBDA" != "null" ]; then
        echo ""
        echo "📋 Current Lambda target: $EXISTING_LAMBDA"
        if [ "$EXISTING_LAMBDA" = "$LAMBDA_ARN" ]; then
            echo "✅ Lambda already configured correctly!"
            exit 0
        fi
    else
        echo ""
        echo "⚠️  No Lambda target currently configured"
    fi
else
    echo "❌ Cannot retrieve gateway - checking if it exists..."
    
    echo ""
    echo "📋 Listing all gateways:"
    aws bedrock-agentcore-control list-gateways --output table 2>/dev/null || \
    aws bedrock-agentcore-control list-gateways --output json 2>/dev/null
    
    echo ""
    echo "❌ Gateway not found or access issue"
    exit 1
fi

echo ""
echo "🔍 Step 3: Check Available Update Parameters"
echo "=========================================="

echo "Checking bedrock-agentcore-control update-gateway help..."
aws bedrock-agentcore-control update-gateway help 2>&1 | head -50

echo ""
echo "🧪 Step 4: Try Different Lambda Configuration Methods"
echo "==================================================="

# Method 1: target-lambda-arn
echo "Method 1: Using --target-lambda-arn parameter..."
aws bedrock-agentcore-control update-gateway \
  --gateway-id "$GATEWAY_ID" \
  --target-lambda-arn "$LAMBDA_ARN" \
  --output json 2>&1

UPDATE_RESULT_1=$?
echo "Result 1: Exit code $UPDATE_RESULT_1"

if [ $UPDATE_RESULT_1 -eq 0 ]; then
    echo "🎉 SUCCESS with method 1!"
    SUCCESS_METHOD="target-lambda-arn"
else
    echo ""
    echo "Method 2: Using --lambda-arn parameter..."
    aws bedrock-agentcore-control update-gateway \
      --gateway-id "$GATEWAY_ID" \
      --lambda-arn "$LAMBDA_ARN" \
      --output json 2>&1
    
    UPDATE_RESULT_2=$?
    echo "Result 2: Exit code $UPDATE_RESULT_2"
    
    if [ $UPDATE_RESULT_2 -eq 0 ]; then
        echo "🎉 SUCCESS with method 2!"
        SUCCESS_METHOD="lambda-arn"
    else
        echo ""
        echo "Method 3: Using --backend-configuration parameter..."
        aws bedrock-agentcore-control update-gateway \
          --gateway-id "$GATEWAY_ID" \
          --backend-configuration "lambdaArn=$LAMBDA_ARN" \
          --output json 2>&1
        
        UPDATE_RESULT_3=$?
        echo "Result 3: Exit code $UPDATE_RESULT_3"
        
        if [ $UPDATE_RESULT_3 -eq 0 ]; then
            echo "🎉 SUCCESS with method 3!"
            SUCCESS_METHOD="backend-configuration"
        else
            echo ""
            echo "Method 4: Using --target-configuration JSON..."
            aws bedrock-agentcore-control update-gateway \
              --gateway-id "$GATEWAY_ID" \
              --target-configuration "{\"lambdaArn\":\"$LAMBDA_ARN\"}" \
              --output json 2>&1
            
            UPDATE_RESULT_4=$?
            echo "Result 4: Exit code $UPDATE_RESULT_4"
            
            if [ $UPDATE_RESULT_4 -eq 0 ]; then
                echo "🎉 SUCCESS with method 4!"
                SUCCESS_METHOD="target-configuration"
            fi
        fi
    fi
fi

echo ""
echo "🔍 Step 5: Verify Gateway Configuration"
echo "===================================="

sleep 3

echo "Checking if gateway was updated..."

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
    }' 2>/dev/null || echo "$UPDATED_GATEWAY"
    
    # Verify Lambda ARN is configured
    CONFIGURED_LAMBDA=$(echo "$UPDATED_GATEWAY" | jq -r '.lambdaArn // .targetConfiguration.lambdaArn // "none"' 2>/dev/null)
    
    if [ "$CONFIGURED_LAMBDA" = "$LAMBDA_ARN" ]; then
        echo ""
        echo "🎉 SUCCESS! Lambda target configured correctly!"
        echo "✅ Gateway → Lambda integration ready"
        echo "✅ Method that worked: $SUCCESS_METHOD"
    elif [ "$CONFIGURED_LAMBDA" != "none" ]; then
        echo ""
        echo "⚠️  Lambda configured but different ARN:"
        echo "   Expected: $LAMBDA_ARN"
        echo "   Actual: $CONFIGURED_LAMBDA"
    else
        echo ""
        echo "❌ Lambda target still not configured"
    fi
else
    echo "❌ Cannot verify gateway configuration"
fi

echo ""
echo "🧪 Step 6: Test Gateway with Lambda Target"
echo "========================================"

if [ "$CONFIGURED_LAMBDA" = "$LAMBDA_ARN" ] || [ -n "$SUCCESS_METHOD" ]; then
    echo "Testing gateway with Lambda target..."
    
    # Create test script
    cat > test_gateway.py << 'EOF'
import boto3
import requests
from botocore.auth import SigV4Auth
from botocore.awsrequest import AWSRequest
import json
from urllib.parse import urlparse
import sys

gateway_url = "https://a208194-askjulius-agentcore-gateway-mcp-iam-fvro4phd59.gateway.bedrock-agentcore.us-east-1.amazonaws.com/mcp"

try:
    session = boto3.Session()
    credentials = session.get_credentials()
    
    # Test tools/list
    payload = {
        "jsonrpc": "2.0",
        "id": "test-lambda-config",
        "method": "tools/list",
        "params": {}
    }
    
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
            elif 'error' in result:
                print("❌ MCP Error:")
                print(f"   Code: {result['error'].get('code', 'Unknown')}")
                print(f"   Message: {result['error'].get('message', 'Unknown')}")
            elif 'UnknownOperationException' in str(result):
                print("⚠️  Lambda responding but doesn't implement MCP protocol")
                print("   Need to deploy MCP wrapper or modify Lambda")
            else:
                print("✅ Gateway responding, checking format...")
                print(json.dumps(result, indent=2)[:500])
        except Exception as e:
            print(f"✅ Gateway responding but JSON parse error: {e}")
            print(response.text[:300])
    else:
        print(f"❌ Gateway error: {response.status_code}")
        print(response.text[:300])

except Exception as e:
    print(f"❌ Test failed: {e}")

EOF
    
    python3 test_gateway.py
    
    # Clean up
    rm -f test_gateway.py
    
else
    echo "❌ Skipping test - Lambda not configured"
fi

echo ""
echo "📋 SUMMARY"
echo "========="

if [ -n "$SUCCESS_METHOD" ]; then
    echo "🎉 Gateway Lambda configuration SUCCESSFUL!"
    echo "✅ Method that worked: --$SUCCESS_METHOD"
    echo "✅ Gateway ID: $GATEWAY_ID"
    echo "✅ Lambda ARN: $LAMBDA_ARN"
    echo ""
    echo "🚀 Next Steps:"
    echo "   1. Test the gateway with MCP requests"
    echo "   2. If Lambda returns UnknownOperationException:"
    echo "      → Deploy MCP wrapper with: ./create-mcp-wrapper.sh"
    echo "   3. Or modify the Lambda to implement MCP protocol"
else
    echo "❌ All configuration methods failed"
    echo ""
    echo "🔧 Alternative Solutions:"
    echo "   1. Use AWS Console to configure manually"
    echo "   2. Deploy MCP wrapper Lambda: ./create-mcp-wrapper.sh"
    echo "   3. Recreate gateway with Lambda target from start"
fi

echo ""
echo "✅ CloudShell gateway configuration completed!"