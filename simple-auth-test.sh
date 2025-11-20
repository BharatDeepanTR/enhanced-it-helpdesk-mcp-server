#!/bin/bash
# Simple Authentication Test
# Clean prompts for client secret and user password

echo "🔐 Cognito Authentication Test"
echo "=============================="
echo ""
echo "User: bharatdeepan.vairavakkalai@thomsonreuters.com"
echo "User Pool: us-east-1_wzWpXwzR6"
echo ""

# Prompt for credentials
echo "Please enter your credentials:"
echo ""
read -s -p "Cognito Client Secret: " CLIENT_SECRET
echo ""
read -s -p "Password for bharatdeepan.vairavakkalai@thomsonreuters.com: " USER_PASSWORD
echo ""
echo ""

echo "🔄 Testing authentication..."

python3 << EOF
import boto3
import hmac
import hashlib
import base64
import json

def calculate_secret_hash(username, client_id, client_secret):
    message = username + client_id
    dig = hmac.new(
        str(client_secret).encode('utf-8'),
        msg=str(message).encode('utf-8'),
        digestmod=hashlib.sha256
    ).digest()
    return base64.b64encode(dig).decode()

try:
    # Configuration
    username = 'bharatdeepan.vairavakkalai@thomsonreuters.com'
    client_id = '57o30hpgrhrovfbe4tmnkrtv50'
    user_pool_id = 'us-east-1_wzWpXwzR6'
    client_secret = '${CLIENT_SECRET}'
    password = '${USER_PASSWORD}'
    
    print("✅ Credentials received")
    print("🔄 Calculating SECRET_HASH...")
    
    # Calculate SECRET_HASH
    secret_hash = calculate_secret_hash(username, client_id, client_secret)
    print("✅ SECRET_HASH calculated")
    
    print("🔄 Connecting to Cognito...")
    cognito = boto3.client('cognito-idp', region_name='us-east-1')
    
    print("🔄 Authenticating...")
    response = cognito.admin_initiate_auth(
        UserPoolId=user_pool_id,
        ClientId=client_id,
        AuthFlow='ADMIN_USER_PASSWORD_AUTH',
        AuthParameters={
            'USERNAME': username,
            'PASSWORD': password,
            'SECRET_HASH': secret_hash
        }
    )
    
    print("🎉 AUTHENTICATION SUCCESS!")
    print("==========================")
    
    # Extract tokens
    auth_result = response['AuthenticationResult']
    access_token = auth_result['AccessToken']
    id_token = auth_result['IdToken']
    
    print(f"✅ Access Token: {access_token[:50]}...")
    print(f"✅ ID Token: {id_token[:50]}...")
    
    # Save tokens
    tokens = {
        'access_token': access_token,
        'id_token': id_token,
        'refresh_token': auth_result.get('RefreshToken', '')
    }
    
    with open('/tmp/cognito-tokens.json', 'w') as f:
        json.dump(tokens, f, indent=2)
    
    print("💾 Tokens saved to /tmp/cognito-tokens.json")
    print("")
    print("🚀 Your user changes worked!")
    print("   PostAuthentication trigger is now functioning")
    print("   Ready to test MCP gateway")
    
except Exception as e:
    print(f"❌ Authentication failed: {e}")
    
    if 'PostAuthentication' in str(e):
        print("💡 PostAuthentication trigger still failing")
        print("   Group membership didn't resolve the issue")
        print("   Try: ./workaround-permissions.sh")
    elif 'NotAuthorizedException' in str(e):
        print("💡 Check username/password")
    elif 'UserNotConfirmedException' in str(e):
        print("💡 User needs to be confirmed")
    else:
        print("💡 Other authentication issue")

EOF

echo ""
echo "🧪 Testing MCP Gateway (if tokens exist)..."

if [ -f "/tmp/cognito-tokens.json" ]; then
    echo "✅ Found tokens! Testing gateway..."
    
    python3 << 'EOF'
import json
import requests

try:
    # Load tokens
    with open('/tmp/cognito-tokens.json', 'r') as f:
        tokens = json.load(f)
    
    access_token = tokens['access_token']
    
    # Test gateway
    url = "https://a208194-askjulius-agentcore-mcp-gateway-dhy8ntpcvu.gateway.bedrock-agentcore.us-east-1.amazonaws.com/mcp/tools/list"
    
    headers = {
        'Authorization': f'Bearer {access_token}',
        'Content-Type': 'application/json'
    }
    
    payload = {
        "jsonrpc": "2.0",
        "id": "test-1",
        "method": "tools/list",
        "params": {}
    }
    
    print("🔍 Testing MCP gateway...")
    response = requests.post(url, headers=headers, json=payload, timeout=30)
    
    print(f"Status: {response.status_code}")
    
    if response.status_code == 200:
        print("🎉 MCP GATEWAY SUCCESS!")
        result = response.json()
        print(json.dumps(result, indent=2)[:500])
    else:
        print(f"❌ Gateway error: {response.status_code}")
        print(response.text[:200])

except Exception as e:
    print(f"❌ Gateway test failed: {e}")

EOF

else
    echo "❌ No tokens found - authentication failed"
fi

echo ""
echo "✅ Test completed!"