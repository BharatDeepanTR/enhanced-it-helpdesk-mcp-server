#!/bin/bash
# Cognito JWT Token Generator for MCP Gateway Testing
# Use this script to get a JWT token for testing the gateway

echo "🔐 Cognito JWT Token Generator"
echo "============================="
echo ""

# Cognito configuration
USER_POOL_ID="us-east-1_wzWpXwzR6"
CLIENT_ID="57o30hpgrhrovfbe4tmnkrtv50"
REGION="us-east-1"

echo "Gateway Configuration:"
echo "  User Pool ID: $USER_POOL_ID"
echo "  Client ID: $CLIENT_ID"
echo "  Region: $REGION"
echo ""

# Install required packages
pip3 install --user boto3

# Create Cognito authentication script
cat > get-cognito-token.py << 'EOF'
#!/usr/bin/env python3
import boto3
import json
import sys
import getpass
from botocore.exceptions import ClientError

def get_cognito_token(username, password):
    """Authenticate with Cognito and get JWT token"""
    
    # Configuration
    user_pool_id = "us-east-1_wzWpXwzR6"
    client_id = "57o30hpgrhrovfbe4tmnkrtv50"
    region = "us-east-1"
    
    try:
        # Create Cognito client
        cognito = boto3.client('cognito-idp', region_name=region)
        
        # Initiate authentication
        response = cognito.admin_initiate_auth(
            UserPoolId=user_pool_id,
            ClientId=client_id,
            AuthFlow='ADMIN_NO_SRP_AUTH',
            AuthParameters={
                'USERNAME': username,
                'PASSWORD': password
            }
        )
        
        # Extract token
        if 'AuthenticationResult' in response:
            access_token = response['AuthenticationResult']['AccessToken']
            id_token = response['AuthenticationResult']['IdToken']
            
            print("✅ Authentication successful!")
            print(f"Access Token: {access_token[:50]}...")
            print(f"ID Token: {id_token[:50]}...")
            print("")
            print("🔧 To test the gateway, use:")
            print(f"export JWT_TOKEN='{access_token}'")
            print("python3 test-mcp-jwt.py")
            
            return access_token
            
        elif 'ChallengeName' in response:
            print(f"⚠️  Authentication challenge required: {response['ChallengeName']}")
            return None
            
    except ClientError as e:
        error_code = e.response['Error']['Code']
        if error_code == 'NotAuthorizedException':
            print("❌ Invalid username or password")
        elif error_code == 'UserNotConfirmedException':
            print("❌ User not confirmed")
        elif error_code == 'UserNotFoundException':
            print("❌ User not found")
        else:
            print(f"❌ Authentication error: {error_code}")
            print(f"   {e.response['Error']['Message']}")
        return None
        
    except Exception as e:
        print(f"❌ Unexpected error: {e}")
        return None

if __name__ == "__main__":
    print("🔐 Cognito Authentication")
    print("========================")
    print("")
    
    if len(sys.argv) > 1:
        username = sys.argv[1]
    else:
        username = input("Username: ")
    
    password = getpass.getpass("Password: ")
    
    token = get_cognito_token(username, password)
    
    if not token:
        print("\n❌ Authentication failed")
        print("\nAlternative approaches:")
        print("1. Check if the user exists in the Cognito User Pool")
        print("2. Verify the user is confirmed")
        print("3. Check if the client allows ADMIN_NO_SRP_AUTH flow")
        print("4. Use AWS Console to create/confirm users")
        sys.exit(1)
    
    sys.exit(0)
EOF

echo "✅ Cognito authentication script created!"
echo ""
echo "📋 Usage Instructions:"
echo "====================="
echo ""
echo "1. First, ensure you have a user in the Cognito User Pool:"
echo "   - User Pool ID: $USER_POOL_ID"
echo "   - You may need to create users via AWS Console"
echo ""
echo "2. Get JWT token:"
echo "   python3 get-cognito-token.py [username]"
echo ""
echo "3. Test the gateway:"
echo "   export JWT_TOKEN='your-jwt-token'"
echo "   python3 test-mcp-jwt.py"
echo ""
echo "4. Or run the enhanced test script:"
echo "   ./cloudshell-enhanced-test.sh"
echo ""
echo "🔧 Gateway Details:"
echo "=================="
echo "  Name: a208194-askjulius-agentcore-mcp-gateway"
echo "  Role: arn:aws:iam::818565325759:role/a208194-askjulius-agentcore-gateway"
echo "  Protocol: MCP"
echo "  Authorization: CUSTOM_JWT (Cognito)"
echo "  Endpoint: https://a208194-askjulius-agentcore-mcp-gateway-dhy8ntpcvu.gateway.bedrock-agentcore.us-east-1.amazonaws.com/mcp"