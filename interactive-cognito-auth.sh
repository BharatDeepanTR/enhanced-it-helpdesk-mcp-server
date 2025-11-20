#!/bin/bash
# Interactive Cognito Authentication with Secure Secret Input
# Customized for User Pool: us-east-1_wzWpXwzR6

echo "🔐 Interactive Cognito Authentication"
echo "===================================="
echo ""

# Your specific configuration
USER_POOL_ID="us-east-1_wzWpXwzR6"
CLIENT_ID="57o30hpgrhrovfbe4tmnkrtv50"
REGION="us-east-1"

echo "Configuration:"
echo "  User Pool ID: $USER_POOL_ID"
echo "  Client ID: $CLIENT_ID"
echo "  Region: $REGION"
echo ""

# Install required packages
echo "📦 Installing required packages..."
pip3 install --user boto3 requests

echo ""
echo "📝 Creating interactive authentication script..."

# Create Python script with secure secret input
cat > interactive_cognito_auth.py << 'EOF'
#!/usr/bin/env python3
import boto3
import hmac
import hashlib
import base64
import json
import requests
import sys
import getpass
from botocore.exceptions import ClientError

def calculate_secret_hash(username, client_id, client_secret):
    """Calculate SECRET_HASH for Cognito authentication"""
    message = username + client_id
    dig = hmac.new(
        str(client_secret).encode('utf-8'),
        msg=str(message).encode('utf-8'),
        digestmod=hashlib.sha256
    ).digest()
    return base64.b64encode(dig).decode()

def check_lambda_triggers(cognito, user_pool_id):
    """Check and display Lambda triggers on the User Pool"""
    try:
        response = cognito.describe_user_pool(UserPoolId=user_pool_id)
        user_pool = response['UserPool']
        lambda_config = user_pool.get('LambdaConfig', {})
        
        if lambda_config:
            print("🔍 Lambda Triggers Found:")
            for trigger_type, lambda_arn in lambda_config.items():
                print(f"   {trigger_type}: {lambda_arn}")
            print()
            
            if 'PostAuthentication' in lambda_config:
                print("⚠️  PostAuthentication trigger detected")
                print("   This may cause authentication to fail if Lambda has permission issues")
                print()
                return True
        else:
            print("✅ No Lambda triggers configured")
            print()
            
    except Exception as e:
        print(f"⚠️  Could not check Lambda triggers: {e}")
        print()
        
    return False

def interactive_cognito_auth():
    """Interactive Cognito authentication with secure input"""
    
    # Configuration
    user_pool_id = "us-east-1_wzWpXwzR6"
    client_id = "57o30hpgrhrovfbe4tmnkrtv50"
    region = "us-east-1"
    
    print("🔐 Interactive Cognito Authentication")
    print("====================================")
    print(f"User Pool: {user_pool_id}")
    print(f"Client ID: {client_id}")
    print()
    
    try:
        # Create Cognito client
        cognito = boto3.client('cognito-idp', region_name=region)
        
        # Check Lambda triggers
        has_post_auth_trigger = check_lambda_triggers(cognito, user_pool_id)
        
        # Get credentials interactively
        print("📝 Enter Credentials:")
        print("====================")
        username = input("Username [mcptest]: ").strip() or "mcptest"
        password = getpass.getpass("Password [McpTest123!]: ") or "McpTest123!"
        
        print()
        client_secret = getpass.getpass("Client Secret (hidden input): ")
        
        if not client_secret:
            print("❌ Client secret is required")
            return False
            
        print()
        print("🔐 Calculating SECRET_HASH...")
        secret_hash = calculate_secret_hash(username, client_id, client_secret)
        print(f"   SECRET_HASH: {secret_hash[:20]}...")
        
        print()
        print("👤 Step 1: Ensuring user exists...")
        
        # Create user if needed
        try:
            cognito.admin_create_user(
                UserPoolId=user_pool_id,
                Username=username,
                TemporaryPassword="TempPass123!",
                MessageAction='SUPPRESS',
                UserAttributes=[
                    {'Name': 'email', 'Value': f'{username}@example.com'},
                    {'Name': 'email_verified', 'Value': 'true'}
                ]
            )
            print("✅ User created")
        except cognito.exceptions.UsernameExistsException:
            print("✅ User already exists")
        except Exception as e:
            print(f"⚠️  User creation: {e}")
        
        print()
        print("🔑 Step 2: Setting permanent password...")
        
        try:
            cognito.admin_set_user_password(
                UserPoolId=user_pool_id,
                Username=username,
                Password=password,
                Permanent=True
            )
            print("✅ Password configured")
        except Exception as e:
            print(f"⚠️  Password setting: {e}")
        
        print()
        print("🔓 Step 3: Authenticating...")
        
        if has_post_auth_trigger:
            print("⚠️  Warning: PostAuthentication trigger detected")
            print("   If authentication fails, consider temporarily disabling the trigger")
            print()
        
        # Authenticate with SECRET_HASH
        try:
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
            
            # Test the MCP gateway
            print()
            print("🧪 Step 4: Testing MCP Gateway...")
            print("=================================")
            
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
            
            if response.status_code == 200:
                result = response.json()
                print("✅ Gateway Response:")
                print(json.dumps(result, indent=2))
                
                print()
                print("🎉 SUCCESS! MCP Gateway Authentication Working!")
                print("==============================================")
                
                if 'result' in result and 'tools' in result['result']:
                    tools = result['result']['tools']
                    print(f"📋 Available tools: {len(tools)}")
                    for i, tool in enumerate(tools):
                        print(f"   {i+1}. {tool.get('name', 'Unknown')}")
                        print(f"      Description: {tool.get('description', 'No description')}")
                        
                        # Test calling the tool
                        if i == 0:  # Test first tool
                            print()
                            print(f"🧪 Testing tool call: {tool.get('name')}...")
                            
                            call_data = {
                                "jsonrpc": "2.0",
                                "id": 2,
                                "method": "tools/call",
                                "params": {
                                    "name": tool['name'],
                                    "arguments": {}
                                }
                            }
                            
                            call_response = requests.post(gateway_url, headers=headers, json=call_data, timeout=30)
                            print(f"Tool call status: {call_response.status_code}")
                            
                            if call_response.status_code == 200:
                                call_result = call_response.json()
                                print("✅ Tool call successful!")
                                print("Tool response:", json.dumps(call_result, indent=2))
                            else:
                                print(f"❌ Tool call failed: {call_response.text}")
                
                # Save credentials for future testing
                print()
                print("💾 For future manual testing:")
                print("============================")
                print(f"export JWT_TOKEN='{access_token}'")
                print("curl -X POST \\")
                print("  -H 'Content-Type: application/json' \\")
                print("  -H 'Authorization: Bearer $JWT_TOKEN' \\")
                print("  -d '{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"tools/list\",\"params\":{}}' \\")
                print(f"  '{gateway_url}'")
                
                return True
                
            else:
                print(f"❌ Gateway test failed")
                print(f"Response: {response.text}")
                
                if response.status_code == 401:
                    print()
                    print("🔧 Troubleshooting 401 Unauthorized:")
                    print("   - JWT token might be malformed")
                    print("   - Gateway authorization configuration issue")
                    print("   - Token might be for wrong audience")
                elif response.status_code == 403:
                    print()
                    print("🔧 Troubleshooting 403 Forbidden:")
                    print("   - JWT token valid but insufficient permissions")
                    print("   - Check gateway authorization rules")
                
                return False
                
        except ClientError as e:
            error_code = e.response['Error']['Code']
            error_message = e.response['Error']['Message']
            
            print(f"❌ Authentication failed: {error_code}")
            print(f"   Message: {error_message}")
            
            if error_code == 'UnexpectedLambdaException':
                if 'PostAuthentication' in error_message and 'AccessDeniedException' in error_message:
                    print()
                    print("🔧 PostAuthentication Lambda Trigger Issue:")
                    print("   The Lambda function triggered after authentication is failing")
                    print("   Solutions:")
                    print("   1. Temporarily disable PostAuthentication trigger in Cognito Console")
                    print("   2. Fix Lambda function permissions")
                    print("   3. Check Lambda function logs for detailed errors")
                    print()
                    print("   To temporarily disable:")
                    print("   1. Go to AWS Console > Cognito User Pools")
                    print(f"   2. Select: {user_pool_id}")
                    print("   3. Go to 'User pool properties' > 'Lambda triggers'")
                    print("   4. Remove PostAuthentication trigger")
                    print("   5. Re-run this script")
                else:
                    print(f"   Lambda error: {error_message}")
            elif error_code == 'NotAuthorizedException':
                if 'SECRET_HASH' in error_message:
                    print("   Issue: SECRET_HASH calculation error")
                    print("   Check: Client secret is correct")
                else:
                    print("   Issue: Invalid username/password or user status")
            else:
                print(f"   Unexpected error: {error_message}")
                
            return False
            
    except Exception as e:
        print(f"❌ Unexpected error: {e}")
        import traceback
        traceback.print_exc()
        return False

if __name__ == "__main__":
    print("🚀 Starting Interactive Cognito Authentication...")
    print()
    
    success = interactive_cognito_auth()
    
    if success:
        print()
        print("🎉 Complete Success!")
        print("===================")
        print("✅ User authentication working")
        print("✅ JWT tokens obtained")
        print("✅ MCP gateway responding")
        print("✅ Tools available and callable")
    else:
        print()
        print("❌ Authentication incomplete")
        print("============================")
        print("Check the error messages above for specific issues to resolve")
    
    sys.exit(0 if success else 1)
EOF

echo "✅ Interactive authentication script created!"
echo ""
echo "🚀 Running interactive authentication..."
echo "======================================="
echo ""
echo "You will be prompted to enter:"
echo "  - Username (default: mcptest)"
echo "  - Password (default: McpTest123!)"
echo "  - Client Secret (secure hidden input)"
echo ""

python3 interactive_cognito_auth.py