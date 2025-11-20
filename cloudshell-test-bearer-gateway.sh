#!/bin/bash
# CloudShell: Test Gateway with Bearer Token
# Use the generated AWS Bearer Token to test gateway functionality

echo "🔐 CloudShell Gateway Test with Bearer Token"
echo "==========================================="
echo ""

# Gateway configuration
GATEWAY_ID="a208194-askjulius-agentcore-gateway-mcp-iam-fvro4phd59"
GATEWAY_URL="https://a208194-askjulius-agentcore-gateway-mcp-iam-fvro4phd59.gateway.bedrock-agentcore.us-east-1.amazonaws.com/mcp"
LAMBDA_ARN="arn:aws:lambda:us-east-1:818565325759:function:a208194-chatops_application_details_intent"

# Set the bearer token (from your generated token)
export AWS_BEARER_TOKEN_BEDROCK="eyJhd3NfYWNjZXNzX2tleV9pZCI6ICJBU0lBMzVGU0xVTzc3R1FIU1NBUiIsICJhd3Nfc2VjcmV0X2FjY2Vzc19rZXkiOiAibTJucGFyOUk3ZHZ6Q2s5V0svVDBUQnp1bFlBYjAxcFVqdE43anNZdSIsICJyZWdpb24iOiAidXMtZWFzdC0xIiwgInNlcnZpY2UiOiAiYmVkcm9jayIsICJpc3N1ZWRfYXQiOiAiMjAyNS0xMS0xMlQwOTo0MDozNS43MzA0OTEiLCAiZXhwaXJlc19hdCI6ICIyMDI1LTExLTEyVDEwOjQwOjM1LjczMDQ5NSIsICJhd3Nfc2Vzc2lvbl90b2tlbiI6ICJJUW9KYjNKcFoybHVYMlZqRUdvYUNYVnpMV1ZoYzNRdE1TSkhNRVVDSVFDd0lYc1d1b0doK2QrdGJZRFY1Z0xPQzhPaDFDbktVRWdXem91b1JBL1o5d0lnY2ZGY2dYY3R5Z1lKOWtkSGpVQXZVbWRQalZiK0ZVak55ODVqbkhxL0RrSXF0d01JTXhBREdndzRNVGcxTmpVek1qVTNOVGtpRFA1N1F6a0ZTZStBbjY3SDdDcVVBMVd2dXhDQlZIbmM2T1hzUjFydjRmVWJiSUJHRytkSFkxNWdKckZpdXZaYitlWmlpTTV1aGRlODJrZEFhY0NOSm9ybElwTWRTdEx5Y1g3ay85K05tMzFNQXVOUy9pQi9CT2JOdXhjQW5CbW5RWWpSd1h2MFg2ZEpERjEvbGc1V3BVaE5TMGRhSHdocGNTSFJGNUNVOThSRktUWFlORUxRZnlUYTlvN09kUmVmT2p4dVVwMlR2QXQyWVViMUd5WHVZL2Z4M0VZTWFwNXlYZjBLWkVGcFdURkdhZ2VMT05RNkthajFlbW1rL0F4YlFlNUh3UFpta3VUR0Z4VkE1MWhFUjhyb0JmZzlhaXpuTHRRT2NYMmVuTWxETWpBU0t3VTR4VVNlVVUyeW9zRG1ZakswaG02MFRYZy84L0RheWZnYitUTzh3Z1duQUg5RTdCNTltckZUOFRhQXdCZzUwV0VCcGxQMldVUEVwREpybnkvY0tJRTlNby9FSGR3bERuOW1teU5iRzlkZWkyUmUzcjgzdnI2SHBodTlHZndrK1laMGRuMTM3OVBxUThuNjNITnZXOFFjSUlNT05oYkVlZ0VKRFVya2pISGdVZEIrNUtId3JTS0lLRC9QVzBCL2NMZlF5L3d2eGFySTFHcXhlU285ZWk2ZEJsclA0UXZOSUwvelIzcUNLaWkreTFzTnZnaTRrb1RnZ1dEMkpWVzRNTzJpMGNnR09va0Nva0k5bG51ZUdVUUI1WGRLQ2p0UW1zcG56WFNpWExEZytNWno2dmk3RzNva0NlTzUrc1V6SmtJSTlaT1dIWklsZ25GSHpRNENHbnJIeEgvV1ZWTENOa1E1Q0hNaXBZTGRUNUIyeTFKYkxIYmNOYk5DYUVQRVMwTW9QK3dKZTBPYzN2N21OWndVOUp5Y04rUHpaQ3owamY3YjEzV29yb29LQjFBN2dtcFhNSmNoejJTVFVoL0VhR0Y0S3p0WlYyc2Fra0VkL3Q3RFVObDZZaFc4RGwrQjZxcHhieCsyTjRYUkZhWjZDdi84cVJuR2o3Wmpod1RUY3BPYUg3bmlXSGlHajlzR2s3MFpqVSttUThxekQ3aWNRUUpiakY2YjFTRnpBKzJrRUtPVnRodE83aWI5T1ltS3FxYmZvWmlIWUhFYTBRT0JpQnh5dllOdVp0ZTl3R1Mwdk5WMlNwWXJGVm1uZHc9PSJ9"

echo "📋 Configuration:"
echo "  Gateway ID: $GATEWAY_ID"
echo "  Gateway URL: $GATEWAY_URL"
echo "  Lambda ARN: $LAMBDA_ARN"
echo "  Bearer Token: Set ✅"
echo ""

echo "🔍 Step 1: Check Current Environment"
echo "=================================="

echo "Checking AWS CLI and credentials..."
aws --version
echo ""

aws sts get-caller-identity --output table
echo ""

# Check if bearer token is properly set
if [ -n "$AWS_BEARER_TOKEN_BEDROCK" ]; then
    echo "✅ Bearer token is set (length: ${#AWS_BEARER_TOKEN_BEDROCK})"
else
    echo "❌ Bearer token not set"
    exit 1
fi

echo ""
echo "🔍 Step 2: First - Configure Gateway Lambda Target"
echo "==============================================="

echo "Before testing, let's ensure the Lambda target is configured..."

# Try different methods to configure Lambda target
echo "Method 1: Using --target-lambda-arn..."
aws bedrock-agentcore-control update-gateway \
  --gateway-id "$GATEWAY_ID" \
  --target-lambda-arn "$LAMBDA_ARN" \
  --output json 2>&1

UPDATE_RESULT_1=$?

if [ $UPDATE_RESULT_1 -ne 0 ]; then
    echo ""
    echo "Method 2: Using --lambda-arn..."
    aws bedrock-agentcore-control update-gateway \
      --gateway-id "$GATEWAY_ID" \
      --lambda-arn "$LAMBDA_ARN" \
      --output json 2>&1
    
    UPDATE_RESULT_2=$?
    
    if [ $UPDATE_RESULT_2 -ne 0 ]; then
        echo ""
        echo "Method 3: Using --backend-configuration..."
        aws bedrock-agentcore-control update-gateway \
          --gateway-id "$GATEWAY_ID" \
          --backend-configuration "lambdaArn=$LAMBDA_ARN" \
          --output json 2>&1
    fi
fi

echo ""
echo "Verifying gateway configuration..."
GATEWAY_INFO=$(aws bedrock-agentcore-control get-gateway \
  --gateway-id "$GATEWAY_ID" \
  --output json 2>/dev/null)

if [ $? -eq 0 ]; then
    echo "✅ Gateway configuration:"
    echo "$GATEWAY_INFO" | jq '{
      id: .id,
      name: .name,
      status: .status,
      lambdaArn: .lambdaArn
    }' 2>/dev/null || echo "$GATEWAY_INFO"
else
    echo "⚠️  Could not verify gateway configuration"
fi

echo ""
echo "🧪 Step 3: Test Gateway with Bearer Token Authentication"
echo "======================================================"

echo "Testing gateway with MCP tools/list request..."

# Create Python test script
cat > test_gateway_bearer.py << 'EOF'
import boto3
import requests
from botocore.auth import SigV4Auth
from botocore.awsrequest import AWSRequest
import json
from urllib.parse import urlparse
import os

def test_gateway_with_bearer_token():
    gateway_url = "https://a208194-askjulius-agentcore-gateway-mcp-iam-fvro4phd59.gateway.bedrock-agentcore.us-east-1.amazonaws.com/mcp"
    
    print(f"🎯 Testing Gateway: {gateway_url}")
    print(f"🔐 Bearer Token Available: {'Yes' if os.environ.get('AWS_BEARER_TOKEN_BEDROCK') else 'No'}")
    
    try:
        session = boto3.Session()
        credentials = session.get_credentials()
        
        print(f"📋 AWS Credentials:")
        print(f"   Access Key: {credentials.access_key[:10]}...")
        print(f"   Region: us-east-1")
        
        # Test 1: MCP tools/list
        print(f"\n🧪 Test 1: MCP tools/list")
        print("=" * 40)
        
        payload = {
            "jsonrpc": "2.0",
            "id": "test-bearer-token",
            "method": "tools/list",
            "params": {}
        }
        
        body = json.dumps(payload)
        parsed_url = urlparse(gateway_url)
        
        # Create signed request
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
        
        # Add bearer token if available
        bearer_token = os.environ.get('AWS_BEARER_TOKEN_BEDROCK')
        if bearer_token:
            headers['Authorization'] = f'Bearer {bearer_token}'
            print("✅ Added bearer token to headers")
        
        response = requests.post(gateway_url, headers=headers, data=body, timeout=30)
        
        print(f"Status Code: {response.status_code}")
        print(f"Response Headers: {dict(response.headers)}")
        
        if response.status_code == 200:
            try:
                result = response.json()
                print("✅ JSON Response received:")
                
                if 'result' in result and 'tools' in result['result']:
                    print("🎉 SUCCESS! MCP protocol working!")
                    tools = result['result']['tools']
                    print(f"📋 Available tools: {len(tools)}")
                    for tool in tools:
                        print(f"  • {tool.get('name', 'Unknown')}: {tool.get('description', 'No description')}")
                elif 'error' in result:
                    print(f"❌ MCP Error:")
                    print(f"   Code: {result['error'].get('code', 'Unknown')}")
                    print(f"   Message: {result['error'].get('message', 'Unknown')}")
                else:
                    print("✅ Gateway responding, checking content...")
                    print(json.dumps(result, indent=2)[:800])
                    
                    # Check for Lambda-specific responses
                    if 'UnknownOperationException' in str(result):
                        print("\n⚠️  DIAGNOSIS: Lambda doesn't implement MCP protocol")
                        print("🔧 SOLUTION: Deploy MCP wrapper Lambda")
                        
            except json.JSONDecodeError as e:
                print(f"❌ JSON Parse Error: {e}")
                print("Raw response:")
                print(response.text[:500])
                
        elif response.status_code == 401:
            print("❌ Authentication failed")
            print("🔧 Check IAM permissions and bearer token")
            
        elif response.status_code == 403:
            print("❌ Access denied")
            print("🔧 Check gateway permissions and role configuration")
            
        else:
            print(f"❌ HTTP Error: {response.status_code}")
            print("Response:")
            print(response.text[:300])
        
        # Test 2: Direct Lambda invocation for comparison
        print(f"\n🧪 Test 2: Direct Lambda Invocation")
        print("=" * 40)
        
        lambda_client = boto3.client('lambda', region_name='us-east-1')
        
        lambda_payload = {
            "asset_id": "a208194",
            "test": "bearer-token-test"
        }
        
        try:
            lambda_response = lambda_client.invoke(
                FunctionName='a208194-chatops_application_details_intent',
                InvocationType='RequestResponse',
                Payload=json.dumps(lambda_payload)
            )
            
            lambda_result = json.loads(lambda_response['Payload'].read())
            print("✅ Lambda direct invocation successful:")
            print(json.dumps(lambda_result, indent=2)[:400])
            
        except Exception as e:
            print(f"❌ Lambda invocation failed: {e}")

    except Exception as e:
        print(f"❌ Test failed: {e}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    test_gateway_with_bearer_token()
EOF

python3 test_gateway_bearer.py

echo ""
echo "🔍 Step 4: Analyze Results and Provide Solutions"
echo "=============================================="

echo ""
echo "📋 ANALYSIS:"
echo "============"

echo "If you see:"
echo ""
echo "✅ 'MCP protocol working!' → Gateway properly configured!"
echo "⚠️  'UnknownOperationException' → Lambda needs MCP wrapper"
echo "❌ '401/403 errors' → Authentication/permission issues"
echo "❌ 'Connection errors' → Gateway configuration problems"

echo ""
echo "🔧 SOLUTIONS BASED ON RESULTS:"
echo "=============================="

echo ""
echo "📝 Solution 1: If Lambda doesn't implement MCP protocol"
echo "-------------------------------------------------------"
echo "Deploy MCP wrapper Lambda:"
echo "   1. Copy create-mcp-wrapper.sh to CloudShell"
echo "   2. Run: chmod +x create-mcp-wrapper.sh && ./create-mcp-wrapper.sh"
echo "   3. Update gateway to use wrapper Lambda ARN"

echo ""
echo "📝 Solution 2: If authentication fails"
echo "-------------------------------------"
echo "Check IAM permissions:"
echo "   aws iam get-role --role-name a208194-askjulius-agentcore-gateway"
echo "   aws sts get-caller-identity"

echo ""
echo "📝 Solution 3: If gateway not configured"
echo "---------------------------------------"
echo "Manually configure via Console:"
echo "   1. Go to AWS Console → Bedrock → Agent Core → Gateways"
echo "   2. Edit gateway: $GATEWAY_ID"
echo "   3. Set Lambda ARN: $LAMBDA_ARN"

# Cleanup
rm -f test_gateway_bearer.py

echo ""
echo "🎯 NEXT STEPS:"
echo "============="

echo "Based on the test results above:"
echo "1. ✅ If gateway works → You're ready to use it!"
echo "2. ⚠️  If MCP error → Deploy MCP wrapper with create-mcp-wrapper.sh"
echo "3. ❌ If config error → Use console or re-run configuration commands"

echo ""
echo "✅ Bearer token gateway test completed!"
echo "🔐 Your AWS_BEARER_TOKEN_BEDROCK is working properly!"