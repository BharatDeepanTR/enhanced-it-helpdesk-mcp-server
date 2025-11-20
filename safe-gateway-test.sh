#!/bin/bash
# Safe Gateway Testing - No Lambda Trigger Removal Required
# Uses IAM authentication as alternative to Cognito

echo "🔐 Safe Gateway Testing (No Trigger Removal)"
echo "============================================="
echo ""
echo "🚨 Why NOT to Remove Lambda Triggers:"
echo "====================================="
echo ""
echo "❌ Potential Issues:"
echo "   • Loss of business logic (user provisioning, permissions, etc.)"
echo "   • Security vulnerabilities"
echo "   • Breaking downstream integrations"
echo "   • Compliance violations"
echo "   • User experience degradation"
echo ""
echo "✅ Better Approach: Test with IAM Authentication"
echo "==============================================="
echo ""

# Configuration
GATEWAY_ID="a208194-askjulius-agentcore-mcp-gateway-dhy8ntpcvu"
GATEWAY_ENDPOINT="https://a208194-askjulius-agentcore-mcp-gateway-dhy8ntpcvu.gateway.bedrock-agentcore.us-east-1.amazonaws.com/mcp"
IAM_ROLE="arn:aws:iam::818565325759:role/a208194-askjulius-agentcore-gateway"

echo "🧪 Testing Gateway with Current AWS Credentials"
echo "==============================================="

# Install required packages
pip3 install --user boto3 requests requests-aws4auth >/dev/null 2>&1

# Create comprehensive test
cat > safe_gateway_test.py << 'EOF'
#!/usr/bin/env python3
import boto3
import json
import requests
from requests_aws4auth import AWS4Auth
import sys

def check_current_identity():
    """Check current AWS identity and permissions"""
    try:
        sts = boto3.client('sts')
        identity = sts.get_caller_identity()
        
        print("🔍 Current AWS Identity:")
        print(f"   Account: {identity['Account']}")
        print(f"   User/Role: {identity['Arn']}")
        print(f"   User ID: {identity['UserId']}")
        print()
        
        return identity
    except Exception as e:
        print(f"❌ Cannot get AWS identity: {e}")
        return None

def test_gateway_describe():
    """Test if we can describe the gateway (indicates permissions)"""
    try:
        client = boto3.client('bedrock-agentcore', region_name='us-east-1')
        
        response = client.describe_gateway(
            GatewayId='a208194-askjulius-agentcore-mcp-gateway-dhy8ntpcvu'
        )
        
        print("✅ Gateway Description Successful:")
        gateway = response['Gateway']
        print(f"   Name: {gateway.get('Name', 'Unknown')}")
        print(f"   Status: {gateway.get('Status', 'Unknown')}")
        print(f"   Auth Type: {gateway.get('AuthorizerType', 'Unknown')}")
        print(f"   Protocol: {gateway.get('ProtocolType', 'Unknown')}")
        print(f"   Created: {gateway.get('CreatedAt', 'Unknown')}")
        print()
        
        # Check if gateway supports IAM
        auth_type = gateway.get('AuthorizerType', '')
        if auth_type == 'IAM':
            print("✅ Gateway supports IAM authentication!")
            return True
        elif auth_type == 'CUSTOM_JWT':
            print("⚠️  Gateway uses JWT authentication only")
            print("   IAM requests may not work")
            return False
        else:
            print(f"⚠️  Unknown auth type: {auth_type}")
            return False
            
    except Exception as e:
        print(f"❌ Cannot describe gateway: {e}")
        print("   This could indicate:")
        print("   • No bedrock-agentcore permissions")
        print("   • Gateway doesn't exist")
        print("   • Wrong region")
        return False

def test_iam_gateway_access():
    """Test MCP gateway access with IAM credentials"""
    
    gateway_url = "https://a208194-askjulius-agentcore-mcp-gateway-dhy8ntpcvu.gateway.bedrock-agentcore.us-east-1.amazonaws.com/mcp"
    
    print("🧪 Testing MCP Gateway with IAM Authentication")
    print("==============================================")
    print(f"Gateway URL: {gateway_url}")
    print()
    
    try:
        # Get AWS credentials
        session = boto3.Session()
        credentials = session.get_credentials()
        
        if not credentials:
            print("❌ No AWS credentials available")
            return False
        
        # Create AWS4Auth
        auth = AWS4Auth(
            credentials.access_key,
            credentials.secret_key,
            'us-east-1',
            'bedrock-agentcore',
            session_token=credentials.token
        )
        
        # Test tools/list
        headers = {'Content-Type': 'application/json'}
        data = {
            "jsonrpc": "2.0",
            "id": 1,
            "method": "tools/list",
            "params": {}
        }
        
        print("📡 Making MCP tools/list request...")
        response = requests.post(gateway_url, auth=auth, headers=headers, json=data, timeout=30)
        
        print(f"Status Code: {response.status_code}")
        
        if response.status_code == 200:
            result = response.json()
            print("🎉 SUCCESS! IAM Authentication Working!")
            print()
            print("📋 Response:")
            print(json.dumps(result, indent=2))
            
            if 'result' in result and 'tools' in result['result']:
                tools = result['result']['tools']
                print(f"\n🛠️  Available Tools ({len(tools)}):")
                for i, tool in enumerate(tools):
                    print(f"   {i+1}. {tool.get('name', 'Unknown')}")
                    print(f"      Description: {tool.get('description', 'No description')}")
                
                # Test calling a tool
                if tools:
                    print(f"\n🧪 Testing tool call: {tools[0]['name']}")
                    call_data = {
                        "jsonrpc": "2.0",
                        "id": 2,
                        "method": "tools/call",
                        "params": {
                            "name": tools[0]['name'],
                            "arguments": {}
                        }
                    }
                    
                    call_response = requests.post(gateway_url, auth=auth, headers=headers, json=call_data, timeout=30)
                    print(f"Tool call status: {call_response.status_code}")
                    
                    if call_response.status_code == 200:
                        call_result = call_response.json()
                        print("✅ Tool call successful!")
                        print("Tool response:", json.dumps(call_result, indent=2))
                    else:
                        print(f"❌ Tool call failed: {call_response.text}")
            
            return True
            
        elif response.status_code == 401:
            print("❌ Unauthorized (401)")
            print(f"Response: {response.text}")
            print()
            print("💡 This confirms the gateway uses JWT authentication")
            print("   IAM credentials are not accepted")
            return False
            
        elif response.status_code == 403:
            print("❌ Forbidden (403)")
            print(f"Response: {response.text}")
            print()
            print("💡 IAM credentials recognized but insufficient permissions")
            return False
            
        else:
            print(f"❌ Unexpected status: {response.status_code}")
            print(f"Response: {response.text}")
            return False
            
    except Exception as e:
        print(f"❌ Error testing gateway: {e}")
        return False

def suggest_lambda_fix():
    """Provide guidance on fixing the Lambda trigger instead of removing it"""
    
    print("🔧 How to Fix Lambda Trigger (Safer than Removing)")
    print("=================================================")
    print()
    print("1. Analyze the Lambda Function:")
    print("   • Go to AWS Console > Lambda")
    print("   • Find the PostAuthentication function")
    print("   • Review the code to understand what it does")
    print("   • Check CloudWatch logs for specific errors")
    print()
    
    print("2. Common Lambda Permission Fixes:")
    print("   Add these policies to Lambda execution role:")
    print("   • AWSLambdaBasicExecutionRole (for logging)")
    print("   • Custom policy with cognito-idp permissions:")
    print()
    print('   {')
    print('     "Version": "2012-10-17",')
    print('     "Statement": [')
    print('       {')
    print('         "Effect": "Allow",')
    print('         "Action": [')
    print('           "cognito-idp:AdminGetUser",')
    print('           "cognito-idp:AdminUpdateUserAttributes",')
    print('           "cognito-idp:AdminAddUserToGroup"')
    print('         ],')
    print('         "Resource": "arn:aws:cognito-idp:us-east-1:*:userpool/us-east-1_wzWpXwzR6"')
    print('       }')
    print('     ]')
    print('   }')
    print()
    
    print("3. Test Lambda Function Directly:")
    print("   • Use AWS Console Lambda test feature")
    print("   • Create a test event mimicking Cognito PostAuth trigger")
    print("   • Check execution results and logs")
    print()
    
    print("4. Alternative: Temporary User Pool for Testing")
    print("   • Create a new User Pool without triggers")
    print("   • Test MCP gateway with new pool")
    print("   • Keep original pool unchanged")

if __name__ == "__main__":
    print("🚀 Safe Gateway Testing (Preserving Lambda Triggers)")
    print("====================================================")
    print()
    
    # Check current identity
    identity = check_current_identity()
    if not identity:
        sys.exit(1)
    
    # Try to describe gateway
    gateway_accessible = test_gateway_describe()
    
    print()
    
    # Test IAM access
    iam_success = test_iam_gateway_access()
    
    print()
    
    if iam_success:
        print("🎉 EXCELLENT NEWS!")
        print("==================")
        print("✅ Your gateway works with IAM authentication")
        print("✅ No need to fix Cognito Lambda trigger for testing")
        print("✅ You can access your tools directly with AWS credentials")
        print()
        print("🔄 Next steps:")
        print("• Use IAM authentication for immediate testing")
        print("• Fix Lambda trigger when convenient (not urgent)")
        print("• Consider creating IAM-authenticated gateway for production")
        
    else:
        print("📋 Results Summary:")
        print("==================")
        print("❌ Gateway uses JWT authentication only")
        print("❌ IAM credentials not accepted")
        print("🔧 Must fix Cognito authentication to proceed")
        print()
        
        suggest_lambda_fix()
        
        print()
        print("🎯 Safest Next Steps:")
        print("====================")
        print("1. Don't remove Lambda trigger (could break business logic)")
        print("2. Fix Lambda execution role permissions instead")
        print("3. Or create temporary test User Pool without triggers")
        print("4. Or reconfigure gateway for IAM authentication")
    
    print()
    print("💡 Key Takeaway:")
    print("================")
    print("Removing Lambda triggers can have serious consequences.")
    print("Always understand what the trigger does before removing it!")
EOF

echo "✅ Safe testing script created!"
echo ""
echo "🚀 Running safe gateway test..."
echo "==============================="

python3 safe_gateway_test.py

# Clean up
rm -f safe_gateway_test.py

echo ""
echo "📋 Summary of Safer Approaches:"
echo "==============================="
echo ""
echo "✅ Tested IAM authentication (no trigger removal needed)"
echo "🔍 Analyzed gateway configuration safely"
echo "💡 Provided Lambda fix guidance (instead of removal)"
echo ""
echo "🎯 Recommended order of attempts:"
echo "1. Use IAM authentication if it worked ↑"
echo "2. Fix Lambda trigger permissions (safer than removal)"
echo "3. Create temporary test User Pool"
echo "4. Only remove trigger as absolute last resort (with full understanding)"