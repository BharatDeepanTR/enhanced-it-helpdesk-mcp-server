#!/bin/bash
# Cognito Authentication with SECRET_HASH Support
# Handles Cognito clients that have a client secret configured

echo "🔐 Cognito Authentication with SECRET_HASH"
echo "=========================================="
echo ""

USER_POOL_ID="us-east-1_wzWpXwzR6"
CLIENT_ID="57o30hpgrhrovfbe4tmnkrtv50"
REGION="us-east-1"
TEST_USERNAME="mcptest"
PERMANENT_PASSWORD="McpTest123!"

echo "Configuration:"
echo "  User Pool ID: $USER_POOL_ID"
echo "  Client ID: $CLIENT_ID"
echo "  Username: $TEST_USERNAME"
echo ""

# First, get the client secret
echo "🔍 Getting client secret..."

CLIENT_SECRET=$(aws cognito-idp describe-user-pool-client \
  --user-pool-id $USER_POOL_ID \
  --client-id $CLIENT_ID \
  --query 'UserPoolClient.ClientSecret' \
  --output text)

if [ "$CLIENT_SECRET" = "None" ] || [ -z "$CLIENT_SECRET" ]; then
    echo "❌ No client secret found. This should not happen based on the error."
    exit 1
else
    echo "✅ Client secret retrieved"
fi

echo ""

# Install Python for SECRET_HASH calculation
echo "📦 Installing Python libraries..."
pip3 install --user boto3 requests

# Create Python script for SECRET_HASH authentication
echo "📝 Creating SECRET_HASH authentication script..."

cat > cognito_auth_with_secret.py << 'EOF'
#!/usr/bin/env python3
import boto3
import hmac
import hashlib
import base64
import json
import requests
import sys

def calculate_secret_hash(username, client_id, client_secret):
    """Calculate SECRET_HASH for Cognito authentication"""
    message = username + client_id
    dig = hmac.new(
        str(client_secret).encode('utf-8'),
        msg=str(message).encode('utf-8'),
        digestmod=hashlib.sha256
    ).digest()
    return base64.b64encode(dig).decode()

def test_cognito_auth():
    """Test Cognito authentication with SECRET_HASH"""
    
    # Configuration
    user_pool_id = "us-east-1_wzWpXwzR6"
    client_id = "57o30hpgrhrovfbe4tmnkrtv50"
    region = "us-east-1"
    username = "mcptest"
    password = "McpTest123!"
    
    print("🔐 Cognito Authentication with SECRET_HASH")
    print("==========================================")
    print(f"User Pool: {user_pool_id}")
    print(f"Client ID: {client_id}")
    print(f"Username: {username}")
    print()
    
    try:
        # Create Cognito client
        cognito = boto3.client('cognito-idp', region_name=region)
        
        # Get client secret
        print("🔍 Retrieving client secret...")
        client_response = cognito.describe_user_pool_client(
            UserPoolId=user_pool_id,
            ClientId=client_id
        )
        
        client_secret = client_response['UserPoolClient'].get('ClientSecret')
        if not client_secret:
            print("❌ No client secret found")
            return False
            
        print("✅ Client secret retrieved")
        
        # Calculate SECRET_HASH
        secret_hash = calculate_secret_hash(username, client_id, client_secret)
        print(f"🔐 SECRET_HASH calculated: {secret_hash[:20]}...")
        
        print()
        print("🚀 Step 1: Create user...")
        
        # Create user (if not exists)
        try:
            cognito.admin_create_user(
                UserPoolId=user_pool_id,
                Username=username,
                TemporaryPassword="TempPass123!",
                MessageAction='SUPPRESS',
                UserAttributes=[
                    {'Name': 'email', 'Value': 'mcptest@example.com'},
                    {'Name': 'email_verified', 'Value': 'true'}
                ]
            )
            print("✅ User created")
        except cognito.exceptions.UsernameExistsException:
            print("✅ User already exists")
        except Exception as e:
            print(f"⚠️  User creation: {e}")
        
        print()
        print("🔑 Step 2: Set permanent password...")
        
        # Set permanent password
        try:
            cognito.admin_set_user_password(
                UserPoolId=user_pool_id,
                Username=username,
                Password=password,
                Permanent=True
            )
            print("✅ Permanent password set")
        except Exception as e:
            print(f"⚠️  Password setting: {e}")
        
        print()
        print("🔓 Step 3: Authenticate with SECRET_HASH...")
        
        # Authenticate with SECRET_HASH
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
        
        # Extract tokens
        auth_result = auth_response['AuthenticationResult']
        access_token = auth_result['AccessToken']
        id_token = auth_result['IdToken']
        
        print()
        print("🎫 JWT Tokens Retrieved:")
        print("========================")
        print(f"Access Token: {access_token[:50]}...")
        print(f"ID Token: {id_token[:50]}...")
        
        print()
        print("🧪 Step 4: Testing MCP Gateway...")
        print("=================================")
        
        # Test the gateway
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
        
        print(f"Gateway URL: {gateway_url}")
        print("Making MCP tools/list request...")
        
        response = requests.post(gateway_url, headers=headers, json=data, timeout=30)
        
        print(f"Response Status: {response.status_code}")
        print(f"Response Body: {response.text}")
        
        if response.status_code == 200:
            result = response.json()
            print()
            print("🎉 SUCCESS! Gateway is working!")
            print("===============================")
            
            if 'result' in result and 'tools' in result['result']:
                tools = result['result']['tools']
                print(f"Available tools: {len(tools)}")
                for i, tool in enumerate(tools):
                    print(f"  {i+1}. {tool.get('name', 'Unknown')}")
                    print(f"     Description: {tool.get('description', 'No description')}")
            
            # Save token for manual testing
            print()
            print("💾 Manual Testing Commands:")
            print("==========================")
            print(f"export JWT_TOKEN='{access_token}'")
            print("curl -X POST \\")
            print("  -H 'Content-Type: application/json' \\")
            print("  -H 'Authorization: Bearer $JWT_TOKEN' \\")
            print("  -d '{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"tools/list\",\"params\":{}}' \\")
            print(f"  '{gateway_url}'")
            
            return True
            
        else:
            print(f"❌ Gateway test failed: {response.status_code}")
            print(f"Response: {response.text}")
            return False
            
    except Exception as e:
        print(f"❌ Error: {e}")
        import traceback
        traceback.print_exc()
        return False

if __name__ == "__main__":
    success = test_cognito_auth()
    sys.exit(0 if success else 1)
EOF

echo "✅ SECRET_HASH authentication script created!"
echo ""
echo "🚀 Running authentication test..."
echo "================================="

python3 cognito_auth_with_secret.py