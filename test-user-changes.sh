#!/bin/bash
# Test User Pool Changes and Gateway Access
# Testing after user attribute updates and group membership changes

echo "🧪 Testing Updated User Configuration"
echo "====================================="
echo ""

USER_POOL_ID="us-east-1_wzWpXwzR6"
CLIENT_ID="57o30hpgrhrovfbe4tmnkrtv50"
USERNAME="bharatdeepan.vairavakkalai@thomsonreuters.com"
GROUP_NAME="us-east-1_wzWpXwzR6_PingID"

echo "📋 Testing Configuration:"
echo "  User Pool: $USER_POOL_ID"
echo "  Client ID: $CLIENT_ID" 
echo "  Username: $USERNAME"
echo "  Group: $GROUP_NAME"
echo ""

echo "🔍 Step 1: Verify User Group Membership"
echo "======================================="

echo "Checking if user is in the PingID group..."

USER_GROUPS=$(aws cognito-idp admin-list-groups-for-user \
  --user-pool-id $USER_POOL_ID \
  --username "$USERNAME" \
  --output json 2>/dev/null)

if [ $? -eq 0 ]; then
    echo "✅ Successfully retrieved user groups:"
    echo "$USER_GROUPS" | jq '.Groups[]? | {GroupName, Description}'
    
    # Check if user is in PingID group
    PING_ID_MEMBER=$(echo "$USER_GROUPS" | jq -r ".Groups[]? | select(.GroupName==\"$GROUP_NAME\") | .GroupName")
    
    if [ "$PING_ID_MEMBER" = "$GROUP_NAME" ]; then
        echo ""
        echo "✅ SUCCESS: User is member of $GROUP_NAME"
        echo "   This should provide the necessary permissions!"
    else
        echo ""
        echo "❌ User not found in $GROUP_NAME group"
        echo "   The group membership may not have propagated yet"
    fi
else
    echo "❌ Cannot retrieve user groups (permission issue)"
    echo "   Will test authentication anyway"
fi

echo ""
echo "🔍 Step 2: Check User Attributes" 
echo "==============================="

USER_ATTRS=$(aws cognito-idp admin-get-user \
  --user-pool-id $USER_POOL_ID \
  --username "$USERNAME" \
  --output json 2>/dev/null)

if [ $? -eq 0 ]; then
    echo "✅ User attributes retrieved:"
    echo "$USER_ATTRS" | jq '.UserAttributes[] | {Name, Value}'
    
    USER_STATUS=$(echo "$USER_ATTRS" | jq -r '.UserStatus')
    echo ""
    echo "📋 User Status: $USER_STATUS"
else
    echo "❌ Cannot retrieve user attributes"
fi

echo ""
echo "🔍 Step 3: Test PostAuthentication Trigger Status"
echo "================================================="

echo "Checking if PostAuthentication trigger is still causing issues..."

LAMBDA_CONFIG=$(aws cognito-idp describe-user-pool \
  --user-pool-id $USER_POOL_ID \
  --query 'UserPool.LambdaConfig.PostAuthentication' \
  --output text 2>/dev/null)

if [ "$LAMBDA_CONFIG" != "None" ] && [ "$LAMBDA_CONFIG" != "" ]; then
    echo "⚠️  PostAuthentication trigger still present: $LAMBDA_CONFIG"
    echo "   Testing if group membership resolves the permission issue..."
else
    echo "✅ PostAuthentication trigger has been removed"
    echo "   Authentication should work smoothly now!"
fi

echo ""
echo "🧪 Step 4: Test Authentication with Updated User"
echo "==============================================="

# Get client secret
read -s -p "Enter Cognito client secret: " CLIENT_SECRET
echo ""
echo ""

echo "🔐 Testing authentication with updated user configuration..."

python3 << EOL
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

print("🔐 Attempting authentication...")
print("==============================")

try:
    cognito = boto3.client('cognito-idp', region_name='us-east-1')
    
    # Calculate SECRET_HASH
    username = '$USERNAME'
    client_id = '$CLIENT_ID'
    client_secret = '$CLIENT_SECRET'
    
    secret_hash = calculate_secret_hash(username, client_id, client_secret)
    print(f"✅ SECRET_HASH calculated for: {username}")
    
    # Get password
    password = input("Enter password for $USERNAME: ")
    
    # Authenticate
    print("\n🔄 Authenticating...")
    response = cognito.admin_initiate_auth(
        UserPoolId='$USER_POOL_ID',
        ClientId='$CLIENT_ID',
        AuthFlow='ADMIN_USER_PASSWORD_AUTH',
        AuthParameters={
            'USERNAME': username,
            'PASSWORD': password,
            'SECRET_HASH': secret_hash
        }
    )
    
    print("\n🎉 AUTHENTICATION SUCCESS!")
    print("==========================")
    
    auth_result = response.get('AuthenticationResult', {})
    
    if auth_result:
        access_token = auth_result.get('AccessToken', '')
        id_token = auth_result.get('IdToken', '')
        refresh_token = auth_result.get('RefreshToken', '')
        
        print(f"✅ Access Token: {access_token[:50]}...")
        print(f"✅ ID Token: {id_token[:50]}...")
        print(f"✅ Refresh Token: {refresh_token[:50]}...")
        
        # Save tokens for gateway testing
        tokens = {
            'access_token': access_token,
            'id_token': id_token,
            'refresh_token': refresh_token
        }
        
        with open('/tmp/cognito-tokens.json', 'w') as f:
            json.dump(tokens, f, indent=2)
        
        print("\n💾 Tokens saved to: /tmp/cognito-tokens.json")
        print("\n🚀 Ready to test MCP gateway!")
        
    else:
        print("⚠️  Authentication succeeded but no tokens returned")
        
except Exception as e:
    print(f"\n❌ Authentication failed: {e}")
    
    if 'PostAuthentication' in str(e):
        print("\n💡 PostAuthentication trigger still causing issues")
        print("   The group membership might not have the right permissions")
        print("   Or the trigger removal is still needed")
    elif 'NotAuthorizedException' in str(e):
        print("\n💡 Check username/password combination")
        print("   Make sure the email address is correct")
    elif 'UserNotConfirmedException' in str(e):
        print("\n💡 User needs to be confirmed first")
        print("   Check user status in Cognito console")
    else:
        print(f"\n💡 Unexpected error type: {type(e).__name__}")

EOL

echo ""
echo "🚀 Step 5: Test MCP Gateway (if authentication succeeded)"
echo "========================================================"

if [ -f "/tmp/cognito-tokens.json" ]; then
    echo "✅ Found authentication tokens!"
    echo ""
    echo "Testing MCP gateway with JWT tokens..."
    
    python3 << 'EOF'
import json
import requests

# Load tokens
try:
    with open('/tmp/cognito-tokens.json', 'r') as f:
        tokens = json.load(f)
    
    access_token = tokens['access_token']
    
    # Test MCP gateway
    gateway_url = "https://a208194-askjulius-agentcore-mcp-gateway-dhy8ntpcvu.gateway.bedrock-agentcore.us-east-1.amazonaws.com/mcp"
    
    headers = {
        'Authorization': f'Bearer {access_token}',
        'Content-Type': 'application/json'
    }
    
    # Test tools/list endpoint
    print("🔍 Testing MCP tools/list...")
    
    payload = {
        "jsonrpc": "2.0",
        "id": "test-1",
        "method": "tools/list",
        "params": {}
    }
    
    response = requests.post(
        f"{gateway_url}/tools/list",
        headers=headers,
        json=payload,
        timeout=30
    )
    
    print(f"Status Code: {response.status_code}")
    
    if response.status_code == 200:
        print("✅ MCP GATEWAY SUCCESS!")
        print("======================")
        result = response.json()
        print(json.dumps(result, indent=2))
        print("\n🎉 Your changes worked! Gateway is accessible!")
        
    elif response.status_code == 401:
        print("❌ Still getting 401 Unauthorized")
        print("   JWT token might not have the right permissions")
        print("   Check if the group provides gateway access")
        
    elif response.status_code == 403:
        print("❌ 403 Forbidden")
        print("   User/group might not have MCP gateway permissions")
        
    else:
        print(f"❌ Unexpected response: {response.status_code}")
        print(response.text[:500])

except Exception as e:
    print(f"❌ Gateway test failed: {e}")
    
EOF

else
    echo "❌ No authentication tokens found"
    echo "   Authentication must have failed above"
fi

echo ""
echo "📋 Summary & Next Steps"
echo "======================"
echo ""

if [ -f "/tmp/cognito-tokens.json" ]; then
    echo "✅ SUCCESS INDICATORS:"
    echo "   • User authentication worked"
    echo "   • JWT tokens obtained"
    echo "   • Ready for full MCP gateway testing"
    echo ""
    echo "🚀 Next Action:"
    echo "   Run: ./interactive-cognito-auth.sh"
    echo "   This will do comprehensive gateway testing"
else
    echo "❌ STILL BLOCKED:"
    echo "   • Authentication failed"
    echo "   • Need to investigate further"
    echo ""
    echo "🔧 Troubleshooting Options:"
    echo "   1. Verify group permissions in Cognito console"
    echo "   2. Check if PostAuthentication trigger still needs removal"
    echo "   3. Confirm user password and status"
    echo "   4. Run: ./workaround-permissions.sh for trigger removal"
fi

echo ""
echo "✅ User changes test completed!"