#!/bin/bash
# Test MCP Gateway with IAM Authentication
# Connects to agentcore gateway using IAM role credentials

echo "🔐 Testing MCP Gateway with IAM Authentication"
echo "=============================================="
echo ""

# Gateway configuration
GATEWAY_ID="a208194-askjulius-agentcore-gateway-mcp-iam-fvro4phd59"
GATEWAY_NAME="a208194-askjulius-agentcore-gateway-mcp-iam"
GATEWAY_URL="https://a208194-askjulius-agentcore-gateway-mcp-iam-fvro4phd59.gateway.bedrock-agentcore.us-east-1.amazonaws.com/mcp"
IAM_ROLE="arn:aws:iam::818565325759:role/a208194-askjulius-agentcore-gateway"
REGION="us-east-1"

echo "📋 Gateway Configuration:"
echo "  Gateway ID: $GATEWAY_ID"
echo "  Gateway Name: $GATEWAY_NAME"
echo "  Gateway URL: $GATEWAY_URL"
echo "  IAM Role: $IAM_ROLE"
echo "  Region: $REGION"
echo ""

echo "🔍 Step 1: Verify Current AWS Identity"
echo "======================================"

echo "Current AWS identity:"
aws sts get-caller-identity --output table

echo ""
echo "Current AWS region:"
aws configure get region
echo ""

echo "🔍 Step 2: Test Gateway Access with IAM"
echo "======================================"

echo "Testing direct gateway access using IAM credentials..."
echo ""

# Test 1: Simple GET request to gateway
echo "🧪 Test 1: Basic Gateway Connectivity"
echo "====================================="

python3 << EOF
import boto3
import requests
from botocore.auth import SigV4Auth
from botocore.awsrequest import AWSRequest
import json
from urllib.parse import urlparse

# Gateway details
gateway_url = "$GATEWAY_URL"
region = "$REGION"

print(f"Testing gateway: {gateway_url}")
print(f"Using region: {region}")
print("")

try:
    # Get AWS credentials
    session = boto3.Session()
    credentials = session.get_credentials()
    
    print(f"✅ AWS credentials obtained")
    print(f"   Access Key: {credentials.access_key[:10]}...")
    print("")
    
    # Test simple GET request first
    print("🔄 Testing basic GET request...")
    
    # Create AWS request for signing
    parsed_url = urlparse(gateway_url)
    request = AWSRequest(
        method='GET',
        url=gateway_url,
        headers={
            'Content-Type': 'application/json',
            'Host': parsed_url.netloc
        }
    )
    
    # Sign the request with SigV4
    SigV4Auth(credentials, 'bedrock-agentcore', region).add_auth(request)
    
    # Convert to requests format
    headers = dict(request.headers)
    
    response = requests.get(gateway_url, headers=headers, timeout=30)
    
    print(f"Response Status: {response.status_code}")
    print(f"Response Headers: {dict(response.headers)}")
    
    if response.status_code == 200:
        print("✅ Basic connectivity successful!")
        try:
            print(f"Response: {response.json()}")
        except:
            print(f"Response Text: {response.text[:200]}")
    elif response.status_code == 401:
        print("❌ 401 Unauthorized - IAM permissions may be insufficient")
    elif response.status_code == 403:
        print("❌ 403 Forbidden - Role may not have gateway access")
    elif response.status_code == 404:
        print("❌ 404 Not Found - Gateway endpoint may be incorrect")
    else:
        print(f"⚠️  Unexpected status: {response.status_code}")
        print(f"Response: {response.text[:300]}")

except Exception as e:
    print(f"❌ Basic connectivity test failed: {e}")

EOF

echo ""
echo "🧪 Test 2: MCP Tools/List Request"
echo "================================="

echo "Testing MCP protocol tools/list endpoint..."
echo ""

python3 << EOF
import boto3
import requests
from botocore.auth import SigV4Auth
from botocore.awsrequest import AWSRequest
import json
from urllib.parse import urlparse

# Configuration
gateway_url = "$GATEWAY_URL"
region = "$REGION"

try:
    # Get AWS credentials
    session = boto3.Session()
    credentials = session.get_credentials()
    
    # MCP tools/list request
    tools_url = f"{gateway_url}/tools/list"
    
    payload = {
        "jsonrpc": "2.0",
        "id": "test-tools-list",
        "method": "tools/list",
        "params": {}
    }
    
    print(f"🔄 Testing MCP tools/list...")
    print(f"URL: {tools_url}")
    print(f"Payload: {json.dumps(payload, indent=2)}")
    print("")
    
    # Create AWS request for signing
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
    
    # Sign with SigV4
    SigV4Auth(credentials, 'bedrock-agentcore', region).add_auth(request)
    
    # Make the request
    headers = dict(request.headers)
    response = requests.post(tools_url, headers=headers, data=body, timeout=30)
    
    print(f"Response Status: {response.status_code}")
    
    if response.status_code == 200:
        print("🎉 MCP TOOLS/LIST SUCCESS!")
        print("=========================")
        
        try:
            result = response.json()
            print("✅ MCP Gateway is working with IAM authentication!")
            print("")
            print("📋 Response:")
            print(json.dumps(result, indent=2))
            
            # Check for tools
            if 'result' in result and 'tools' in result['result']:
                print("")
                print("📋 Available Tools:")
                for tool in result['result']['tools']:
                    print(f"  • {tool.get('name', 'Unknown')}: {tool.get('description', 'No description')}")
                    
        except json.JSONDecodeError:
            print("✅ Request successful but response not JSON:")
            print(response.text[:500])
            
    elif response.status_code == 401:
        print("❌ 401 Unauthorized")
        print("   IAM role may not have bedrock-agentcore permissions")
        print("   Check if role has: bedrock-agentcore:InvokeModel or similar")
        
    elif response.status_code == 403:
        print("❌ 403 Forbidden") 
        print("   IAM role may not be authorized for this gateway")
        print("   Check gateway resource policy")
        
    elif response.status_code == 404:
        print("❌ 404 Not Found")
        print("   MCP endpoint may not exist or path incorrect")
        
    else:
        print(f"⚠️  Unexpected response: {response.status_code}")
        print(f"Headers: {dict(response.headers)}")
        print(f"Body: {response.text[:300]}")

except Exception as e:
    print(f"❌ MCP tools/list test failed: {e}")
    import traceback
    traceback.print_exc()

EOF

echo ""
echo "🧪 Test 3: MCP Tools/Call Request"
echo "================================="

echo "Testing MCP protocol tools/call if tools are available..."
echo ""

python3 << EOF
import boto3
import requests
from botocore.auth import SigV4Auth
from botocore.awsrequest import AWSRequest
import json
from urllib.parse import urlparse

# Configuration
gateway_url = "$GATEWAY_URL"
region = "$REGION"

try:
    # Get AWS credentials
    session = boto3.Session()
    credentials = session.get_credentials()
    
    # First get available tools
    tools_url = f"{gateway_url}/tools/list"
    
    payload = {
        "jsonrpc": "2.0",
        "id": "get-tools",
        "method": "tools/list",
        "params": {}
    }
    
    # Sign and make tools/list request
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
    
    SigV4Auth(credentials, 'bedrock-agentcore', region).add_auth(request)
    headers = dict(request.headers)
    
    response = requests.post(tools_url, headers=headers, data=body, timeout=30)
    
    if response.status_code == 200:
        result = response.json()
        
        if 'result' in result and 'tools' in result['result'] and len(result['result']['tools']) > 0:
            # Get first tool
            first_tool = result['result']['tools'][0]
            tool_name = first_tool.get('name', 'unknown')
            
            print(f"🔄 Testing tools/call with: {tool_name}")
            
            # Test tools/call
            call_url = f"{gateway_url}/tools/call"
            
            call_payload = {
                "jsonrpc": "2.0",
                "id": "test-tool-call",
                "method": "tools/call",
                "params": {
                    "name": tool_name,
                    "arguments": {}
                }
            }
            
            call_body = json.dumps(call_payload)
            
            # Sign tools/call request
            call_request = AWSRequest(
                method='POST',
                url=call_url,
                data=call_body,
                headers={
                    'Content-Type': 'application/json',
                    'Host': parsed_url.netloc
                }
            )
            
            SigV4Auth(credentials, 'bedrock-agentcore', region).add_auth(call_request)
            call_headers = dict(call_request.headers)
            
            call_response = requests.post(call_url, headers=call_headers, data=call_body, timeout=30)
            
            print(f"Tools/call Status: {call_response.status_code}")
            
            if call_response.status_code == 200:
                print("🎉 TOOLS/CALL SUCCESS!")
                call_result = call_response.json()
                print(json.dumps(call_result, indent=2)[:500])
            else:
                print(f"Tools/call response: {call_response.text[:200]}")
                
        else:
            print("No tools available to test tools/call")
    else:
        print("Cannot get tools list for tools/call test")

except Exception as e:
    print(f"❌ Tools/call test failed: {e}")

EOF

echo ""
echo "🔍 Step 3: Check IAM Permissions"
echo "==============================="

echo "Checking current IAM permissions for gateway access..."
echo ""

# Test various IAM permissions
echo "Testing IAM permissions:"

echo -n "  • sts:GetCallerIdentity: "
aws sts get-caller-identity --query 'Arn' --output text 2>/dev/null
if [ $? -eq 0 ]; then echo "✅"; else echo "❌"; fi

echo -n "  • bedrock-agentcore:ListGateways: "
aws bedrock-agentcore-control list-gateways --max-results 1 --query 'gateways[0].id' --output text 2>/dev/null
if [ $? -eq 0 ]; then echo "✅"; else echo "❌"; fi

echo -n "  • bedrock-agentcore:GetGateway: "
aws bedrock-agentcore-control get-gateway --gateway-id "$GATEWAY_ID" --query 'id' --output text 2>/dev/null
if [ $? -eq 0 ]; then echo "✅"; else echo "❌"; fi

echo ""
echo "📋 Gateway Details Check"
echo "========================"

echo "Retrieving gateway configuration..."

GATEWAY_INFO=$(aws bedrock-agentcore-control get-gateway \
  --gateway-id "$GATEWAY_ID" \
  --output json 2>/dev/null)

if [ $? -eq 0 ]; then
    echo "✅ Gateway information retrieved:"
    echo "$GATEWAY_INFO" | jq '{
      id: .id,
      name: .name,
      status: .status,
      authorizerType: .authorizerType,
      protocolType: .protocolType,
      createdAt: .createdAt
    }'
    
    GATEWAY_STATUS=$(echo "$GATEWAY_INFO" | jq -r '.status')
    AUTH_TYPE=$(echo "$GATEWAY_INFO" | jq -r '.authorizerType')
    
    echo ""
    echo "📋 Gateway Status: $GATEWAY_STATUS"
    echo "📋 Authorizer Type: $AUTH_TYPE"
    
    if [ "$GATEWAY_STATUS" = "ACTIVE" ]; then
        echo "✅ Gateway is ACTIVE and ready"
    else
        echo "⚠️  Gateway status: $GATEWAY_STATUS"
        echo "   Gateway may still be provisioning"
    fi
    
    if [ "$AUTH_TYPE" = "AWS_IAM" ]; then
        echo "✅ IAM authorizer confirmed"
    else
        echo "⚠️  Authorizer type: $AUTH_TYPE"
    fi
    
else
    echo "❌ Cannot retrieve gateway information"
    echo "   Check bedrock-agentcore:GetGateway permission"
fi

echo ""
echo "📋 SUMMARY & TROUBLESHOOTING"
echo "==========================="
echo ""

echo "🎯 IAM-based gateway configuration:"
echo "   ✅ No Cognito authentication required"
echo "   ✅ Uses AWS SigV4 signing"
echo "   ✅ Bypasses PostAuthentication trigger issues"
echo ""

echo "🔧 If authentication fails:"
echo "   1. Ensure your IAM user/role has bedrock-agentcore permissions"
echo "   2. Check if gateway resource policy allows your role"
echo "   3. Verify gateway status is ACTIVE"
echo "   4. Confirm you're using the correct region (us-east-1)"
echo ""

echo "🚀 Required IAM permissions for your role:"
echo "   • bedrock-agentcore:InvokeModel"
echo "   • bedrock-agentcore:GetGateway"
echo "   • Or a broader bedrock-agentcore:* permission"
echo ""

echo "📞 If still having issues:"
echo "   • Check CloudWatch logs for the gateway"
echo "   • Verify the IAM role trust policy"
echo "   • Test with a broader IAM policy temporarily"
echo ""

echo "✅ MCP Gateway IAM testing completed!"
echo ""
echo "💡 This IAM approach completely sidesteps the Cognito issues"
echo "   and should provide direct access to your MCP gateway!"