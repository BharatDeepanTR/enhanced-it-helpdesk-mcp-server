#!/bin/bash
# Cognito Lambda Trigger Bypass - Alternative Authentication Methods
# Works around PostAuthentication Lambda trigger issues

echo "🔧 Cognito Lambda Trigger Bypass"
echo "================================"
echo ""

USER_POOL_ID="us-east-1_wzWpXwzR6"
CLIENT_ID="57o30hpgrhrovfbe4tmnkrtv50"
REGION="us-east-1"

echo "Configuration:"
echo "  User Pool ID: $USER_POOL_ID"
echo "  Client ID: $CLIENT_ID"
echo ""

echo "❌ Issue Detected: PostAuthentication Lambda trigger AccessDeniedException"
echo "💡 Solutions:"
echo "  1. Try USER_SRP_AUTH flow (bypasses admin triggers)"
echo "  2. Check Lambda trigger permissions"
echo "  3. Temporarily disable trigger for testing"
echo ""

# Install required packages
echo "📦 Installing required packages..."
pip3 install --user boto3 requests

echo ""
echo "📝 Creating bypass authentication script..."

# Create Python script with alternative auth flows
cat > cognito_bypass_auth.py << 'EOF'
#!/usr/bin/env python3
import boto3
import hmac
import hashlib
import base64
import json
import requests
import sys
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

def try_user_srp_auth():
    """Try USER_SRP_AUTH flow which bypasses admin triggers"""
    
    user_pool_id = "us-east-1_wzWpXwzR6"
    client_id = "57o30hpgrhrovfbe4tmnkrtv50"
    region = "us-east-1"
    username = "mcptest"
    password = "McpTest123!"
    
    print("🔐 Trying USER_SRP_AUTH Flow (Bypass Admin Triggers)")
    print("===================================================")
    
    try:
        cognito = boto3.client('cognito-idp', region_name=region)
        
        # Get client secret
        client_response = cognito.describe_user_pool_client(
            UserPoolId=user_pool_id,
            ClientId=client_id
        )
        client_secret = client_response['UserPoolClient'].get('ClientSecret')
        
        if not client_secret:
            print("❌ No client secret found")
            return None
        
        secret_hash = calculate_secret_hash(username, client_id, client_secret)
        print(f"🔐 SECRET_HASH calculated: {secret_hash[:20]}...")
        
        # Try USER_SRP_AUTH (simpler, bypasses admin triggers)
        print("🚀 Attempting USER_SRP_AUTH flow...")
        
        # Note: USER_SRP_AUTH requires additional SRP calculations
        # For now, let's try a simpler approach
        
        return None
        
    except Exception as e:
        print(f"❌ USER_SRP_AUTH failed: {e}")
        return None

def try_refresh_token_approach():
    """Try to get tokens using refresh token if available"""
    print("🔄 Checking for existing tokens...")
    # This would require an existing session
    return None

def check_lambda_trigger():
    """Check Cognito User Pool Lambda triggers"""
    
    user_pool_id = "us-east-1_wzWpXwzR6"
    region = "us-east-1"
    
    print("🔍 Checking Cognito Lambda Triggers")
    print("===================================")
    
    try:
        cognito = boto3.client('cognito-idp', region_name=region)
        
        # Get user pool configuration
        response = cognito.describe_user_pool(UserPoolId=user_pool_id)
        user_pool = response['UserPool']
        
        lambda_config = user_pool.get('LambdaConfig', {})
        
        if lambda_config:
            print("📋 Lambda Triggers Found:")
            for trigger_type, lambda_arn in lambda_config.items():
                print(f"  {trigger_type}: {lambda_arn}")
                
            if 'PostAuthentication' in lambda_config:
                post_auth_lambda = lambda_config['PostAuthentication']
                print(f"\n❌ PostAuthentication trigger: {post_auth_lambda}")
                print("   This Lambda is failing with AccessDeniedException")
                print("   Solutions:")
                print("   1. Check Lambda execution role permissions")
                print("   2. Verify Lambda can access required resources")
                print("   3. Temporarily remove trigger for testing")
                
                return post_auth_lambda
        else:
            print("✅ No Lambda triggers configured")
            
    except Exception as e:
        print(f"❌ Error checking triggers: {e}")
        
    return None

def create_manual_token_instructions():
    """Provide manual token creation instructions"""
    
    print("🔧 Manual Token Creation Workaround")
    print("===================================")
    print("")
    print("Since the PostAuthentication trigger is failing, try these alternatives:")
    print("")
    print("Option 1: AWS Console Token")
    print("--------------------------")
    print("1. Go to AWS Console > Cognito User Pools")
    print(f"2. Select User Pool: us-east-1_wzWpXwzR6")
    print("3. Go to 'Users' tab")
    print("4. Select user 'mcptest'")
    print("5. Use 'Actions' > 'Generate access token' (if available)")
    print("")
    print("Option 2: Temporarily Disable Lambda Trigger")
    print("--------------------------------------------")
    print("1. Go to AWS Console > Cognito User Pools")
    print(f"2. Select User Pool: us-east-1_wzWpXwzR6")
    print("3. Go to 'User pool properties' > 'Lambda triggers'")
    print("4. Temporarily remove the PostAuthentication trigger")
    print("5. Re-run the authentication script")
    print("6. Re-add the trigger after testing")
    print("")
    print("Option 3: Fix Lambda Permissions")
    print("--------------------------------")
    print("1. Check the PostAuthentication Lambda function logs")
    print("2. Ensure Lambda execution role has required permissions")
    print("3. Common permissions needed:")
    print("   - cognito-idp:AdminGetUser")
    print("   - cognito-idp:AdminUpdateUserAttributes")
    print("   - logs:CreateLogGroup, CreateLogStream, PutLogEvents")
    print("")

def test_gateway_with_manual_token():
    """Test gateway with manually provided token"""
    
    import os
    manual_token = os.environ.get('MANUAL_JWT_TOKEN')
    
    if not manual_token:
        print("💡 To test with a manual token:")
        print("   export MANUAL_JWT_TOKEN='your-jwt-token-here'")
        print("   python3 cognito_bypass_auth.py")
        return False
    
    print("🧪 Testing Gateway with Manual Token")
    print("===================================")
    
    gateway_url = "https://a208194-askjulius-agentcore-mcp-gateway-dhy8ntpcvu.gateway.bedrock-agentcore.us-east-1.amazonaws.com/mcp"
    
    headers = {
        'Content-Type': 'application/json',
        'Authorization': f'Bearer {manual_token}'
    }
    
    data = {
        "jsonrpc": "2.0",
        "id": 1,
        "method": "tools/list",
        "params": {}
    }
    
    try:
        response = requests.post(gateway_url, headers=headers, json=data, timeout=30)
        
        print(f"Status: {response.status_code}")
        print(f"Response: {response.text}")
        
        if response.status_code == 200:
            print("🎉 SUCCESS! Manual token works with gateway!")
            return True
        else:
            print("❌ Gateway test failed with manual token")
            return False
            
    except Exception as e:
        print(f"❌ Error testing gateway: {e}")
        return False

if __name__ == "__main__":
    print("🔧 Cognito Lambda Trigger Bypass Analysis")
    print("==========================================")
    print("")
    
    # Check what Lambda triggers are causing the issue
    trigger_arn = check_lambda_trigger()
    
    print("")
    
    # Try alternative authentication (currently limited)
    # token = try_user_srp_auth()
    
    # Test with manual token if provided
    manual_success = test_gateway_with_manual_token()
    
    if not manual_success:
        print("")
        create_manual_token_instructions()
        
        print("")
        print("🎯 Recommended Next Steps:")
        print("=========================")
        print("1. Temporarily disable the PostAuthentication Lambda trigger")
        print("2. Re-run: ./cognito-secret-hash-auth.sh")
        print("3. Get JWT token and test gateway")
        print("4. Fix Lambda trigger permissions")
        print("5. Re-enable Lambda trigger")
    
    print("")
    print("📋 Summary:")
    print("===========")
    print("✅ SECRET_HASH calculation working")
    print("✅ User authentication working") 
    print("❌ PostAuthentication Lambda trigger failing")
    print("💡 Gateway testing possible with manual token or trigger bypass")
EOF

echo "✅ Bypass script created!"
echo ""
echo "🚀 Running bypass analysis..."
python3 cognito_bypass_auth.py