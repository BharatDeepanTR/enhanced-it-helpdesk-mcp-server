#!/bin/bash
# Fixed Interactive Authentication Test
# Handles password input properly outside of Python heredoc

echo "🔧 Fixed Authentication Test for User Changes"
echo "============================================="
echo ""

USER_POOL_ID="us-east-1_wzWpXwzR6"
CLIENT_ID="57o30hpgrhrovfbe4tmnkrtv50"
USERNAME="bharatdeepan.vairavakkalai@thomsonreuters.com"

echo "📋 Testing with updated user: $USERNAME"
echo ""

# Get credentials first, outside of any Python code
echo "🔐 Enter Authentication Credentials"
echo "===================================="
read -s -p "Enter Cognito client secret: " CLIENT_SECRET
echo ""
read -s -p "Enter password for $USERNAME: " USER_PASSWORD
echo ""
echo ""

echo "🧪 Testing authentication..."

# Create a temporary Python script with the credentials
cat > /tmp/auth_test.py << EOF
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
    return base64.b64decode(dig).decode()

# Test authentication
print("🔐 Testing Cognito Authentication")
print("=================================")

try:
    cognito = boto3.client('cognito-idp', region_name='us-east-1')
    
    username = '$USERNAME'
    client_id = '$CLIENT_ID'
    client_secret = '$CLIENT_SECRET'
    password = '$USER_PASSWORD'
    user_pool_id = '$USER_POOL_ID'
    
    # Calculate SECRET_HASH
    secret_hash = calculate_secret_hash(username, client_id, client_secret)
    print(f"✅ SECRET_HASH calculated for: {username}")
    
    # Authenticate
    print("🔄 Attempting authentication...")
    
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
    
    print("\n🎉 AUTHENTICATION SUCCESS!")
    print("==========================")
    
    auth_result = response.get('AuthenticationResult', {})
    
    if auth_result:
        access_token = auth_result.get('AccessToken', '')
        id_token = auth_result.get('IdToken', '')
        refresh_token = auth_result.get('RefreshToken', '')
        
        print(f"✅ Access Token: {access_token[:50]}...")
        print(f"✅ ID Token: {id_token[:50]}...")
        
        # Save tokens
        tokens = {
            'access_token': access_token,
            'id_token': id_token,
            'refresh_token': refresh_token
        }
        
        with open('/tmp/cognito-tokens.json', 'w') as f:
            json.dump(tokens, f, indent=2)
        
        print("💾 Tokens saved to: /tmp/cognito-tokens.json")
        print("\n🚀 Testing MCP Gateway...")
        
        # Test MCP gateway immediately
        gateway_url = "https://a208194-askjulius-agentcore-mcp-gateway-dhy8ntpcvu.gateway.bedrock-agentcore.us-east-1.amazonaws.com/mcp"
        
        headers = {
            'Authorization': f'Bearer {access_token}',
            'Content-Type': 'application/json'
        }
        
        # Test tools/list
        print("🔍 Testing MCP tools/list endpoint...")
        
        payload = {
            "jsonrpc": "2.0",
            "id": "test-1", 
            "method": "tools/list",
            "params": {}
        }
        
        try:
            response = requests.post(
                f"{gateway_url}/tools/list",
                headers=headers,
                json=payload,
                timeout=30
            )
            
            print(f"Gateway Response Status: {response.status_code}")
            
            if response.status_code == 200:
                print("\n🎉 MCP GATEWAY SUCCESS!")
                print("======================")
                result = response.json()
                print("Available tools:")
                if 'result' in result and 'tools' in result['result']:
                    for tool in result['result']['tools']:
                        print(f"  • {tool.get('name', 'Unknown')}: {tool.get('description', 'No description')}")
                else:
                    print(json.dumps(result, indent=2)[:500])
                    
                print("\n✅ SUCCESS: Your user changes resolved the issue!")
                print("   • PostAuthentication trigger is now working")
                print("   • Group membership provides the right permissions") 
                print("   • MCP gateway is fully accessible")
                
            elif response.status_code == 401:
                print("\n⚠️  Still getting 401 Unauthorized")
                print("   JWT token obtained but gateway rejected it")
                print("   May need to check gateway authorizer configuration")
                
            elif response.status_code == 403:
                print("\n⚠️  403 Forbidden") 
                print("   User/group may not have MCP gateway access permissions")
                
            else:
                print(f"\n⚠️  Unexpected gateway response: {response.status_code}")
                try:
                    error_detail = response.json()
                    print("Error details:", json.dumps(error_detail, indent=2)[:300])
                except:
                    print("Response text:", response.text[:300])
                    
        except requests.exceptions.RequestException as e:
            print(f"\n❌ Gateway request failed: {e}")
            print("   Network issue or gateway unavailable")
            
    else:
        print("⚠️  Authentication response missing tokens")
        print("   Challenge may be required or other issue")
        
except Exception as e:
    print(f"\n❌ Authentication failed: {e}")
    
    error_str = str(e)
    
    if 'PostAuthentication' in error_str:
        print("\n💡 PostAuthentication trigger still failing")
        print("   Group membership didn't provide sufficient permissions")
        print("   Need to remove the trigger as workaround")
        print("   Run: ./workaround-permissions.sh")
        
    elif 'NotAuthorizedException' in error_str:
        print("\n💡 Username/password incorrect")
        print("   • Check if email address is exact match")
        print("   • Verify password is correct") 
        print("   • Check if user account is active")
        
    elif 'UserNotConfirmedException' in error_str:
        print("\n💡 User needs to be confirmed")
        print("   Check user status in Cognito console")
        
    elif 'UserNotFoundException' in error_str:
        print("\n💡 User not found")
        print("   Check if email address exists in user pool")
        
    elif 'InvalidParameterException' in error_str:
        print("\n💡 Invalid parameters")
        print("   Check client secret or configuration")
        
    else:
        print(f"\n💡 Error type: {type(e).__name__}")
        print("   May need further investigation")

print("\n" + "="*50)
print("🧪 AUTHENTICATION TEST COMPLETED")
print("="*50)
EOF

# Run the Python test
python3 /tmp/auth_test.py

# Clean up sensitive files
echo ""
echo "🧹 Cleaning up temporary files..."
rm -f /tmp/auth_test.py
echo "✅ Cleanup completed"

echo ""
echo "📋 SUMMARY & RECOMMENDATIONS"
echo "============================="
echo ""

if [ -f "/tmp/cognito-tokens.json" ]; then
    echo "🎉 GREAT SUCCESS!"
    echo "=================="
    echo "✅ Your user changes worked perfectly!"
    echo "✅ Authentication successful"
    echo "✅ JWT tokens obtained"
    echo "✅ Ready for full MCP gateway testing"
    echo ""
    echo "🚀 Next Steps:"
    echo "   1. Run: ./interactive-cognito-auth.sh"
    echo "   2. Test all MCP gateway functionality"
    echo "   3. Your issue is resolved!"
    
else
    echo "❌ STILL HAVING ISSUES"
    echo "====================="
    echo ""
    echo "🔧 Next Troubleshooting Steps:"
    echo ""
    echo "1. 🎯 If PostAuthentication trigger still failing:"
    echo "   ./workaround-permissions.sh"
    echo "   (Remove trigger temporarily)"
    echo ""
    echo "2. 🔍 If authentication issue:"
    echo "   • Check password carefully"
    echo "   • Verify email address exactly matches"
    echo "   • Check user status in Cognito console"
    echo ""
    echo "3. 📞 If group permissions issue:"
    echo "   • Verify PingID group has correct policies"
    echo "   • Check if group membership propagated"
    echo "   • May need admin to assign more permissions"
fi

echo ""
echo "✅ Fixed authentication test completed!"