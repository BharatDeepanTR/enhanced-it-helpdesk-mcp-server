#!/bin/bash
# CloudShell Authentication Diagnostic for MCP Gateway
# Helps troubleshoot the "Invalid Bearer token" error

GATEWAY_URL="https://a208194-askjulius-agentcore-mcp-gateway-dhy8ntpcvu.gateway.bedrock-agentcore.us-east-1.amazonaws.com/mcp"
REGION="us-east-1"

echo "🔍 MCP Gateway Authentication Diagnostic"
echo "========================================"
echo "Gateway URL: $GATEWAY_URL"
echo "Region: $REGION"
echo ""

# Check AWS credentials
echo "🔧 Checking AWS credentials..."
if aws sts get-caller-identity > /dev/null 2>&1; then
    ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
    USER=$(aws sts get-caller-identity --query Arn --output text)
    echo "✅ AWS Account: $ACCOUNT"
    echo "✅ User/Role: $USER"
else
    echo "❌ AWS credentials not configured"
    exit 1
fi

echo ""
echo "📦 Installing diagnostic dependencies..."
pip3 install --user requests-aws4auth boto3 > /dev/null 2>&1

# Create and run diagnostic script
echo ""
echo "🚀 Running authentication diagnostic..."
echo ""

python3 << 'DIAGNOSTIC_EOF'
import json
import uuid
import requests
import boto3
from requests_aws4auth import AWS4Auth
import logging

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(name)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

GATEWAY_URL = "https://a208194-askjulius-agentcore-mcp-gateway-dhy8ntpcvu.gateway.bedrock-agentcore.us-east-1.amazonaws.com/mcp"
REGION = "us-east-1"

def test_authentication_methods():
    print("🔍 Testing different authentication methods...")
    print("=" * 50)
    
    session = boto3.Session()
    credentials = session.get_credentials()
    
    if not credentials:
        print("❌ No AWS credentials found")
        return
    
    # Test payload
    payload = {
        "jsonrpc": "2.0",
        "method": "tools/list",
        "id": str(uuid.uuid4())
    }
    
    headers_base = {
        'Content-Type': 'application/json',
        'Accept': 'application/json'
    }
    
    # Method 1: bedrock-agentcore service
    print("\n🧪 Method 1: AWS SigV4 with bedrock-agentcore service")
    try:
        auth = AWS4Auth(
            credentials.access_key,
            credentials.secret_key,
            REGION,
            'bedrock-agentcore',
            session_token=credentials.token
        )
        
        response = requests.post(GATEWAY_URL, json=payload, headers=headers_base, auth=auth, timeout=30)
        print(f"   Status: {response.status_code}")
        
        if response.status_code == 200:
            print("   ✅ SUCCESS! This method works!")
            result = response.json()
            print(f"   Response: {json.dumps(result, indent=2)}")
            return True
        else:
            print(f"   ❌ Failed: {response.text}")
    except Exception as e:
        print(f"   ❌ Exception: {e}")
    
    # Method 2: bedrock service
    print("\n🧪 Method 2: AWS SigV4 with bedrock service")
    try:
        auth = AWS4Auth(
            credentials.access_key,
            credentials.secret_key,
            REGION,
            'bedrock',
            session_token=credentials.token
        )
        
        response = requests.post(GATEWAY_URL, json=payload, headers=headers_base, auth=auth, timeout=30)
        print(f"   Status: {response.status_code}")
        
        if response.status_code == 200:
            print("   ✅ SUCCESS! This method works!")
            result = response.json()
            print(f"   Response: {json.dumps(result, indent=2)}")
            return True
        else:
            print(f"   ❌ Failed: {response.text}")
    except Exception as e:
        print(f"   ❌ Exception: {e}")
    
    # Method 3: execute-api service
    print("\n🧪 Method 3: AWS SigV4 with execute-api service")
    try:
        auth = AWS4Auth(
            credentials.access_key,
            credentials.secret_key,
            REGION,
            'execute-api',
            session_token=credentials.token
        )
        
        response = requests.post(GATEWAY_URL, json=payload, headers=headers_base, auth=auth, timeout=30)
        print(f"   Status: {response.status_code}")
        
        if response.status_code == 200:
            print("   ✅ SUCCESS! This method works!")
            result = response.json()
            print(f"   Response: {json.dumps(result, indent=2)}")
            return True
        else:
            print(f"   ❌ Failed: {response.text}")
    except Exception as e:
        print(f"   ❌ Exception: {e}")
    
    # Method 4: Try with session token as Bearer
    print("\n🧪 Method 4: Bearer token with session token")
    try:
        headers_bearer = headers_base.copy()
        headers_bearer['Authorization'] = f'Bearer {credentials.token}'
        
        response = requests.post(GATEWAY_URL, json=payload, headers=headers_bearer, timeout=30)
        print(f"   Status: {response.status_code}")
        
        if response.status_code == 200:
            print("   ✅ SUCCESS! This method works!")
            result = response.json()
            print(f"   Response: {json.dumps(result, indent=2)}")
            return True
        else:
            print(f"   ❌ Failed: {response.text}")
    except Exception as e:
        print(f"   ❌ Exception: {e}")
    
    # Method 5: Try with access key as Bearer
    print("\n🧪 Method 5: Bearer token with access key")
    try:
        headers_bearer = headers_base.copy()
        headers_bearer['Authorization'] = f'Bearer {credentials.access_key}'
        
        response = requests.post(GATEWAY_URL, json=payload, headers=headers_bearer, timeout=30)
        print(f"   Status: {response.status_code}")
        
        if response.status_code == 200:
            print("   ✅ SUCCESS! This method works!")
            result = response.json()
            print(f"   Response: {json.dumps(result, indent=2)}")
            return True
        else:
            print(f"   ❌ Failed: {response.text}")
    except Exception as e:
        print(f"   ❌ Exception: {e}")
    
    # Method 6: No authentication
    print("\n🧪 Method 6: No authentication")
    try:
        response = requests.post(GATEWAY_URL, json=payload, headers=headers_base, timeout=30)
        print(f"   Status: {response.status_code}")
        
        if response.status_code == 200:
            print("   ✅ SUCCESS! This method works!")
            result = response.json()
            print(f"   Response: {json.dumps(result, indent=2)}")
            return True
        else:
            print(f"   ❌ Failed: {response.text}")
    except Exception as e:
        print(f"   ❌ Exception: {e}")
    
    print("\n❌ All authentication methods failed")
    print("\n🔍 Next steps:")
    print("1. Check if the gateway is correctly configured for IAM authentication")
    print("2. Verify the gateway URL is accessible")
    print("3. Check IAM permissions for your role")
    print("4. Try recreating the gateway with proper auth config")
    
    return False

if __name__ == "__main__":
    test_authentication_methods()
DIAGNOSTIC_EOF

echo ""
echo "🏁 Authentication diagnostic completed"
echo ""
echo "💡 If all methods failed, try:"
echo "   1. Recreate the gateway with updated auth config"
echo "   2. Check gateway status in AWS console"
echo "   3. Verify IAM role permissions"