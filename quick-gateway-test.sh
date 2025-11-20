#!/bin/bash
# Quick MCP Gateway Test After Lambda Trigger Fix
# Run this after removing the PostAuthentication trigger

echo "🧪 Quick MCP Gateway Test"
echo "========================="
echo ""
echo "This script will quickly test your gateway after removing the Lambda trigger."
echo ""

# Configuration
USER_POOL_ID="us-east-1_wzWpXwzR6"
CLIENT_ID="57o30hpgrhrovfbe4tmnkrtv50"

echo "Configuration:"
echo "  User Pool: $USER_POOL_ID"
echo "  Client ID: $CLIENT_ID"
echo ""

# Get client secret securely
echo "🔐 Enter client secret to test authentication..."
read -s -p "Client Secret: " CLIENT_SECRET
echo ""
echo ""

# Create quick test script
cat > quick_test.py << EOF
import boto3
import hmac
import hashlib
import base64
import json
import requests

def calculate_secret_hash(username, client_id, client_secret):
    message = username + client_id
    dig = hmac.new(
        str(client_secret).encode('utf-8'),
        msg=str(message).encode('utf-8'),
        digestmod=hashlib.sha256
    ).digest()
    return base64.b64encode(dig).decode()

# Configuration
user_pool_id = "$USER_POOL_ID"
client_id = "$CLIENT_ID"
client_secret = "$CLIENT_SECRET"
username = "mcptest"
password = "McpTest123!"

print("🚀 Quick Authentication Test")
print("============================")

try:
    cognito = boto3.client('cognito-idp', region_name='us-east-1')
    
    # Calculate SECRET_HASH
    secret_hash = calculate_secret_hash(username, client_id, client_secret)
    print(f"✅ SECRET_HASH calculated")
    
    # Authenticate
    auth_response = cognito.admin_initiate_auth(
        UserPoolId=user_pool_id,
        ClientId=client_id,
        AuthFlow='ADMIN_USER_PASSWORD_AUTH',
        AuthParameters={
            'USERNAME': username,
            'PASSWORD': password,
            'SECRET_HASH': secret_hash
        }
    )
    
    print("✅ Authentication successful!")
    
    # Get access token
    access_token = auth_response['AuthenticationResult']['AccessToken']
    print(f"✅ Access token obtained: {access_token[:30]}...")
    
    # Test MCP gateway
    gateway_url = "https://a208194-askjulius-agentcore-mcp-gateway-dhy8ntpcvu.gateway.bedrock-agentcore.us-east-1.amazonaws.com/mcp"
    
    headers = {
        'Content-Type': 'application/json',
        'Authorization': f'Bearer {access_token}'
    }
    
    data = {
        "jsonrpc": "2.0",
        "id": 1,
        "method": "tools/list",
        "params": {}
    }
    
    print("🧪 Testing MCP gateway...")
    response = requests.post(gateway_url, headers=headers, json=data, timeout=30)
    
    print(f"Gateway Status: {response.status_code}")
    
    if response.status_code == 200:
        result = response.json()
        print("🎉 SUCCESS! Gateway working!")
        print("Available tools:")
        
        if 'result' in result and 'tools' in result['result']:
            for tool in result['result']['tools']:
                print(f"  - {tool.get('name', 'Unknown')}")
        
        print()
        print("💾 Save this token for manual testing:")
        print(f"export JWT_TOKEN='{access_token}'")
        
    else:
        print(f"❌ Gateway failed: {response.text}")
        
except Exception as e:
    print(f"❌ Error: {e}")
EOF

echo "🚀 Running quick test..."
python3 quick_test.py

# Clean up
rm -f quick_test.py

echo ""
echo "🔄 Next Steps:"
echo "============="
echo ""
echo "If the test succeeded:"
echo "✅ Your MCP gateway is working perfectly!"
echo "✅ You can now use JWT tokens to access your tools"
echo "✅ Consider restoring the Lambda trigger and fixing its permissions"
echo ""
echo "If the test failed:"
echo "❌ Check if the Lambda trigger was actually removed"
echo "❌ Verify client secret is correct"
echo "❌ Check gateway configuration"