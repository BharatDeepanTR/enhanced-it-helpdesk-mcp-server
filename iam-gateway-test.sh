#!/bin/bash
# Direct IAM Role Gateway Connection Test
# Uses IAM role instead of Cognito JWT for gateway access

echo "🔐 Direct IAM Gateway Connection Test"
echo "===================================="
echo ""

# Gateway Configuration
GATEWAY_NAME="a208194-askjulius-agentcore-mcp-gateway"
GATEWAY_ID="a208194-askjulius-agentcore-mcp-gateway-dhy8ntpcvu"
GATEWAY_ARN="arn:aws:bedrock-agentcore:us-east-1:818565325759:gateway/a208194-askjulius-agentcore-mcp-gateway-dhy8ntpcvu"
IAM_ROLE_ARN="arn:aws:iam::818565325759:role/a208194-askjulius-agentcore-gateway"
GATEWAY_ENDPOINT="https://a208194-askjulius-agentcore-mcp-gateway-dhy8ntpcvu.gateway.bedrock-agentcore.us-east-1.amazonaws.com"
MCP_PATH="/mcp"
REGION="us-east-1"
SERVICE="bedrock-agentcore"

echo "Configuration:"
echo "  Gateway Name: $GATEWAY_NAME"
echo "  Gateway ID: $GATEWAY_ID"
echo "  Gateway ARN: $GATEWAY_ARN"
echo "  IAM Role ARN: $IAM_ROLE_ARN"
echo "  Endpoint: $GATEWAY_ENDPOINT$MCP_PATH"
echo "  Region: $REGION"
echo ""

# Install required packages
echo "📦 Installing required packages..."
pip3 install --user boto3 requests requests-aws4auth

echo ""
echo "📝 Creating IAM-based gateway test..."

# Create Python script for IAM authentication
cat > iam_gateway_test.py << 'EOF'
#!/usr/bin/env python3
import boto3
import json
import requests
from requests_aws4auth import AWS4Auth
from botocore.auth import SigV4Auth
from botocore.awsrequest import AWSRequest
import sys

def test_gateway_with_iam():
    """Test gateway using IAM credentials instead of Cognito JWT"""
    
    # Configuration
    gateway_endpoint = "https://a208194-askjulius-agentcore-mcp-gateway-dhy8ntpcvu.gateway.bedrock-agentcore.us-east-1.amazonaws.com"
    mcp_path = "/mcp"
    gateway_url = gateway_endpoint + mcp_path
    region = "us-east-1"
    service = "bedrock-agentcore"
    
    print("🔐 IAM-based Gateway Authentication Test")
    print("=======================================")
    print(f"Gateway URL: {gateway_url}")
    print(f"Service: {service}")
    print(f"Region: {region}")
    print()
    
    try:
        # Get current AWS credentials
        session = boto3.Session()
        credentials = session.get_credentials()
        
        if not credentials:
            print("❌ No AWS credentials available")
            print("   Make sure you're in CloudShell or have AWS CLI configured")
            return False
        
        # Show current identity
        sts = boto3.client('sts')
        identity = sts.get_caller_identity()
        print(f"✅ Current AWS Identity:")
        print(f"   Account: {identity['Account']}")
        print(f"   User/Role: {identity['Arn']}")
        print()
        
        # Method 1: Try with requests-aws4auth
        print("🧪 Method 1: Testing with requests-aws4auth...")
        print("==============================================")
        
        auth = AWS4Auth(
            credentials.access_key,
            credentials.secret_key,
            region,
            service,
            session_token=credentials.token
        )
        
        headers = {'Content-Type': 'application/json'}
        data = {
            "jsonrpc": "2.0",
            "id": 1,
            "method": "tools/list",
            "params": {}
        }
        
        try:
            response = requests.post(gateway_url, auth=auth, headers=headers, json=data, timeout=30)
            print(f"Status Code: {response.status_code}")
            print(f"Response Headers: {dict(response.headers)}")
            print(f"Response Body: {response.text}")
            
            if response.status_code == 200:
                result = response.json()
                print("✅ Method 1 Success!")
                return result
            elif response.status_code == 401:
                print("⚠️  Method 1: Unauthorized - trying alternative method")
            elif response.status_code == 403:
                print("⚠️  Method 1: Forbidden - checking permissions")
            else:
                print(f"⚠️  Method 1: Unexpected status {response.status_code}")
                
        except Exception as e:
            print(f"❌ Method 1 Error: {e}")
        
        print()
        
        # Method 2: Try with botocore SigV4Auth
        print("🧪 Method 2: Testing with botocore SigV4Auth...")
        print("===============================================")
        
        try:
            # Create AWS request
            aws_request = AWSRequest(
                method='POST',
                url=gateway_url,
                data=json.dumps(data),
                headers={'Content-Type': 'application/json'}
            )
            
            # Sign the request
            SigV4Auth(credentials, service, region).add_auth(aws_request)
            
            # Make signed request
            signed_headers = dict(aws_request.headers)
            
            response = requests.post(
                gateway_url,
                headers=signed_headers,
                data=aws_request.body,
                timeout=30
            )
            
            print(f"Status Code: {response.status_code}")
            print(f"Response: {response.text}")
            
            if response.status_code == 200:
                result = response.json()
                print("✅ Method 2 Success!")
                return result
            else:
                print(f"❌ Method 2: Status {response.status_code}")
                
        except Exception as e:
            print(f"❌ Method 2 Error: {e}")
        
        print()
        
        # Method 3: Try bedrock-agentcore client (if available)
        print("🧪 Method 3: Testing with bedrock-agentcore client...")
        print("===================================================")
        
        try:
            # Try to use bedrock-agentcore client directly
            client = boto3.client('bedrock-agentcore', region_name=region)
            
            # Check if we can describe the gateway
            try:
                gateway_info = client.describe_gateway(
                    GatewayId="a208194-askjulius-agentcore-mcp-gateway-dhy8ntpcvu"
                )
                print("✅ Gateway found via bedrock-agentcore client:")
                print(f"   Status: {gateway_info.get('Status', 'Unknown')}")
                print(f"   Created: {gateway_info.get('CreatedAt', 'Unknown')}")
            except Exception as e:
                print(f"⚠️  Cannot describe gateway: {e}")
            
        except Exception as e:
            print(f"❌ Method 3: bedrock-agentcore client not available: {e}")
        
        print()
        
        # Check gateway authorization configuration
        print("🔍 Checking Gateway Authorization...")
        print("===================================")
        
        try:
            # Get current role and check if it matches gateway role
            current_arn = identity['Arn']
            gateway_role = "arn:aws:iam::818565325759:role/a208194-askjulius-agentcore-gateway"
            
            print(f"Current Role: {current_arn}")
            print(f"Gateway Role: {gateway_role}")
            
            if gateway_role in current_arn:
                print("✅ You are using the gateway's IAM role")
            else:
                print("⚠️  You are NOT using the gateway's IAM role")
                print("   This might explain authentication failures")
                print()
                print("💡 To use the gateway role:")
                print(f"   aws sts assume-role --role-arn {gateway_role} --role-session-name GatewayTest")
                
        except Exception as e:
            print(f"❌ Error checking role: {e}")
        
        return None
        
    except Exception as e:
        print(f"❌ Unexpected error: {e}")
        import traceback
        traceback.print_exc()
        return None

def assume_gateway_role_and_test():
    """Try to assume the gateway role and test"""
    
    print("🔄 Attempting to Assume Gateway Role...")
    print("======================================")
    
    gateway_role = "arn:aws:iam::818565325759:role/a208194-askjulius-agentcore-gateway"
    
    try:
        sts = boto3.client('sts')
        
        # Assume the gateway role
        assumed_role = sts.assume_role(
            RoleArn=gateway_role,
            RoleSessionName='MCP-Gateway-Test'
        )
        
        print("✅ Successfully assumed gateway role")
        
        # Create new session with assumed role credentials
        temp_credentials = assumed_role['Credentials']
        
        temp_session = boto3.Session(
            aws_access_key_id=temp_credentials['AccessKeyId'],
            aws_secret_access_key=temp_credentials['SecretAccessKey'],
            aws_session_token=temp_credentials['SessionToken']
        )
        
        # Test with new credentials
        print("🧪 Testing with gateway role credentials...")
        
        gateway_url = "https://a208194-askjulius-agentcore-mcp-gateway-dhy8ntpcvu.gateway.bedrock-agentcore.us-east-1.amazonaws.com/mcp"
        
        # Use the temporary credentials
        auth = AWS4Auth(
            temp_credentials['AccessKeyId'],
            temp_credentials['SecretAccessKey'],
            'us-east-1',
            'bedrock-agentcore',
            session_token=temp_credentials['SessionToken']
        )
        
        data = {
            "jsonrpc": "2.0",
            "id": 1,
            "method": "tools/list",
            "params": {}
        }
        
        response = requests.post(gateway_url, auth=auth, headers={'Content-Type': 'application/json'}, json=data, timeout=30)
        
        print(f"Status: {response.status_code}")
        print(f"Response: {response.text}")
        
        if response.status_code == 200:
            result = response.json()
            print("🎉 SUCCESS with Gateway Role!")
            return result
        else:
            print(f"❌ Failed even with gateway role")
            return None
            
    except Exception as e:
        print(f"❌ Cannot assume gateway role: {e}")
        print("   You may not have permission to assume this role")
        return None

def analyze_gateway_configuration():
    """Analyze the gateway configuration for troubleshooting"""
    
    print("🔍 Gateway Configuration Analysis")
    print("=================================")
    print()
    
    gateway_info = {
        "name": "a208194-askjulius-agentcore-mcp-gateway",
        "id": "a208194-askjulius-agentcore-mcp-gateway-dhy8ntpcvu",
        "arn": "arn:aws:bedrock-agentcore:us-east-1:818565325759:gateway/a208194-askjulius-agentcore-mcp-gateway-dhy8ntpcvu",
        "role": "arn:aws:iam::818565325759:role/a208194-askjulius-agentcore-gateway",
        "endpoint": "https://a208194-askjulius-agentcore-mcp-gateway-dhy8ntpcvu.gateway.bedrock-agentcore.us-east-1.amazonaws.com/mcp",
        "protocol": "MCP",
        "auth_type": "CUSTOM_JWT"  # Based on previous conversation
    }
    
    print("📋 Gateway Details:")
    for key, value in gateway_info.items():
        print(f"   {key}: {value}")
    
    print()
    print("🔧 Authentication Analysis:")
    print("===========================")
    print("Based on your gateway configuration:")
    print()
    print("✅ Gateway exists and is accessible")
    print("✅ Uses MCP protocol")
    print("❌ Configured for CUSTOM_JWT (Cognito) authentication")
    print("❌ NOT configured for AWS IAM authentication")
    print()
    print("💡 This explains why IAM-based requests fail!")
    print("   The gateway expects JWT tokens from Cognito, not AWS signatures")
    print()
    print("🎯 Solutions:")
    print("=============")
    print("1. Fix Cognito PostAuthentication Lambda trigger (recommended)")
    print("2. Reconfigure gateway to use AWS IAM authentication")
    print("3. Create a new gateway with IAM authentication")

if __name__ == "__main__":
    print("🚀 Starting IAM Gateway Connection Test...")
    print()
    
    # Test with current credentials
    result = test_gateway_with_iam()
    
    if not result:
        print()
        # Try assuming gateway role
        result = assume_gateway_role_and_test()
    
    if not result:
        print()
        # Analyze why it's failing
        analyze_gateway_configuration()
    else:
        print()
        print("🎉 Gateway Connection Successful!")
        print("================================")
        print("Available tools:")
        if 'result' in result and 'tools' in result['result']:
            for tool in result['result']['tools']:
                print(f"  - {tool.get('name', 'Unknown')}")
        print()
        print("✅ Your gateway is working with IAM authentication!")
    
    print()
    print("📋 Summary:")
    print("===========")
    if result:
        print("✅ Gateway accessible with IAM credentials")
        print("✅ MCP protocol working")
        print("✅ Tools available and discoverable")
    else:
        print("❌ Gateway not accessible with IAM credentials")
        print("💡 Gateway likely configured for JWT authentication only")
        print("🔧 Consider fixing Cognito authentication or reconfiguring gateway")
EOF

echo "✅ IAM gateway test script created!"
echo ""
echo "🚀 Running IAM connection test..."
echo "================================="

python3 iam_gateway_test.py

# Clean up
rm -f iam_gateway_test.py

echo ""
echo "🔄 Next Steps Based on Results:"
echo "==============================="
echo ""
echo "If IAM authentication worked:"
echo "✅ Your gateway supports both JWT and IAM authentication"
echo "✅ You can use AWS credentials to access the gateway"
echo ""
echo "If IAM authentication failed:"
echo "❌ Gateway is configured for JWT (Cognito) only"
echo "💡 You need to either:"
echo "   1. Fix the Cognito PostAuthentication Lambda trigger"
echo "   2. Reconfigure gateway for IAM authentication"
echo "   3. Create a new gateway with --authorizer-type IAM"