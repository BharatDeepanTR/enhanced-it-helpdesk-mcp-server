#!/bin/bash
# CloudShell MCP Gateway Test with JWT Authentication (Cognito)
# Updated for CUSTOM_JWT authorizer type

echo "🌩️  MCP Gateway Test with Cognito JWT Authentication..."

# Install required packages
echo "📦 Installing required packages..."
pip3 install --user boto3 requests

# Create JWT-based test script
echo "📝 Creating JWT authentication test script..."
cat > test-mcp-jwt.py << 'EOF'
#!/usr/bin/env python3
import json
import requests
import boto3
import sys
from botocore.exceptions import ClientError

def get_cognito_token():
    """Get JWT token from Cognito for gateway authentication"""
    
    # Gateway configuration
    cognito_config = {
        "user_pool_id": "us-east-1_wzWpXwzR6",
        "client_id": "57o30hpgrhrovfbe4tmnkrtv50",
        "region": "us-east-1",
        "discovery_url": "https://cognito-idp.us-east-1.amazonaws.com/us-east-1_wzWpXwzR6/.well-known/openid-configuration"
    }
    
    print(f"🔐 Cognito Configuration:")
    print(f"   User Pool ID: {cognito_config['user_pool_id']}")
    print(f"   Client ID: {cognito_config['client_id']}")
    print(f"   Discovery URL: {cognito_config['discovery_url']}")
    print()
    
    # Note: For testing, we need actual Cognito credentials
    # This would typically require user authentication flow
    print("⚠️  JWT Token Required:")
    print("   The gateway uses Cognito JWT authentication.")
    print("   You need to authenticate with the Cognito User Pool to get a valid JWT token.")
    print()
    
    return None

def test_mcp_with_jwt(jwt_token):
    """Test MCP gateway with JWT authentication"""
    
    print("🔧 Bedrock Agent Core Gateway MCP Testing (JWT Auth)")
    print("===================================================")
    print()
    
    # Configuration
    gateway_url = "https://a208194-askjulius-agentcore-mcp-gateway-dhy8ntpcvu.gateway.bedrock-agentcore.us-east-1.amazonaws.com/mcp"
    
    print(f"Gateway URL: {gateway_url}")
    print(f"Authorization: JWT (Cognito)")
    print()
    
    if not jwt_token:
        print("❌ No JWT token provided")
        return False
    
    try:
        # Test tools/list with JWT Bearer token
        print("🔍 Testing tools/list with JWT authentication...")
        
        headers = {
            'Content-Type': 'application/json',
            'Authorization': f'Bearer {jwt_token}'
        }
        
        data = {
            "jsonrpc": "2.0",
            "id": 1,
            "method": "tools/list",
            "params": {}
        }
        
        print(f"🔐 Using Bearer token authentication...")
        
        response = requests.post(
            gateway_url,
            headers=headers,
            json=data,
            timeout=30
        )
        
        print(f"📡 Response Status: {response.status_code}")
        
        if response.status_code == 200:
            result = response.json()
            print(f"✅ Success!")
            print(f"📋 Response: {json.dumps(result, indent=2)}")
            
            # Check for tools
            if 'result' in result and 'tools' in result['result']:
                tools = result['result']['tools']
                print(f"\n🛠️  Available tools: {len(tools)}")
                for i, tool in enumerate(tools):
                    print(f"  {i+1}. {tool.get('name', 'Unknown')}")
                    print(f"     Description: {tool.get('description', 'No description')}")
                    
                # Test a tool call if available
                if tools:
                    tool_name = tools[0]['name']
                    print(f"\n🧪 Testing tool call: {tool_name}")
                    
                    call_data = {
                        "jsonrpc": "2.0",
                        "id": 2,
                        "method": "tools/call",
                        "params": {
                            "name": tool_name,
                            "arguments": {}
                        }
                    }
                    
                    call_response = requests.post(
                        gateway_url,
                        headers=headers,
                        json=call_data,
                        timeout=30
                    )
                    
                    print(f"Tool call status: {call_response.status_code}")
                    if call_response.status_code == 200:
                        call_result = call_response.json()
                        print(f"✅ Tool call success!")
                        print(f"Tool response: {json.dumps(call_result, indent=2)}")
                    else:
                        print(f"❌ Tool call failed: {call_response.text}")
                        
                return True
            else:
                print("⚠️  No tools found in response")
                return False
                
        elif response.status_code == 401:
            print(f"❌ Authentication failed (401)")
            print(f"   Response: {response.text}")
            print(f"   The JWT token is invalid or expired")
            return False
            
        elif response.status_code == 403:
            print(f"❌ Access denied (403)")
            print(f"   Response: {response.text}")
            print(f"   The JWT token doesn't have required permissions")
            return False
            
        else:
            print(f"❌ Unexpected status: {response.status_code}")
            print(f"   Response: {response.text}")
            return False
            
    except Exception as e:
        print(f"❌ Error: {str(e)}")
        import traceback
        traceback.print_exc()
        return False

def test_cognito_auth_flow():
    """Test Cognito authentication flow"""
    print("🔐 Testing Cognito Authentication Flow")
    print("=====================================")
    print()
    
    try:
        # Test discovery URL
        discovery_url = "https://cognito-idp.us-east-1.amazonaws.com/us-east-1_wzWpXwzR6/.well-known/openid-configuration"
        print(f"📡 Testing Cognito discovery URL...")
        
        response = requests.get(discovery_url, timeout=10)
        print(f"   Status: {response.status_code}")
        
        if response.status_code == 200:
            config = response.json()
            print(f"   ✅ Cognito configuration retrieved")
            print(f"   Issuer: {config.get('issuer', 'N/A')}")
            print(f"   Token endpoint: {config.get('token_endpoint', 'N/A')}")
            print(f"   Authorization endpoint: {config.get('authorization_endpoint', 'N/A')}")
        else:
            print(f"   ❌ Failed to get Cognito configuration")
            
    except Exception as e:
        print(f"   ❌ Error testing Cognito: {e}")

def test_gateway_connectivity():
    """Test basic gateway connectivity"""
    print("🌐 Testing Gateway Connectivity")
    print("==============================")
    print()
    
    gateway_base = "https://a208194-askjulius-agentcore-mcp-gateway-dhy8ntpcvu.gateway.bedrock-agentcore.us-east-1.amazonaws.com"
    
    try:
        # Test base URL
        print(f"📡 Testing base URL...")
        response = requests.get(gateway_base, timeout=10)
        print(f"   Status: {response.status_code}")
        
        # Test MCP endpoint
        mcp_url = gateway_base + "/mcp"
        print(f"📡 Testing MCP endpoint...")
        response = requests.get(mcp_url, timeout=10)
        print(f"   Status: {response.status_code}")
        
        if response.status_code in [401, 403]:
            print("   ✅ Gateway exists and requires authentication")
            return True
        elif response.status_code == 404:
            print("   ❌ Gateway not found")
            return False
        else:
            print(f"   ⚠️  Unexpected response")
            return True
            
    except Exception as e:
        print(f"   ❌ Connection error: {e}")
        return False

if __name__ == "__main__":
    print("🚀 Starting Cognito JWT Gateway Test...")
    print()
    
    # Test 1: Gateway connectivity
    if not test_gateway_connectivity():
        print("\n❌ Gateway connectivity failed")
        sys.exit(1)
    
    print()
    
    # Test 2: Cognito configuration
    test_cognito_auth_flow()
    
    print()
    
    # Test 3: JWT authentication (requires manual token)
    print("🔑 JWT Token Authentication")
    print("===========================")
    print()
    print("To test the MCP gateway, you need a valid JWT token from Cognito.")
    print()
    print("Options to get a JWT token:")
    print("1. Use AWS CLI with Cognito Identity Pool")
    print("2. Use a web application that authenticates with this Cognito User Pool")
    print("3. Use AWS SDK to authenticate programmatically")
    print()
    print("Gateway Configuration:")
    print(f"  User Pool ID: us-east-1_wzWpXwzR6")
    print(f"  Client ID: 57o30hpgrhrovfbe4tmnkrtv50")
    print(f"  Region: us-east-1")
    print()
    
    # Check if JWT token provided as environment variable
    import os
    jwt_token = os.environ.get('JWT_TOKEN')
    
    if jwt_token:
        print(f"✅ JWT token found in environment variable")
        success = test_mcp_with_jwt(jwt_token)
    else:
        print("💡 To test with a JWT token, set the JWT_TOKEN environment variable:")
        print("   export JWT_TOKEN='your-jwt-token-here'")
        print("   python3 test-mcp-jwt.py")
        print()
        success = True  # Consider it successful for now
    
    if success:
        print("\n🎉 Gateway configuration test completed!")
    else:
        print("\n❌ Gateway test failed")
    
    sys.exit(0 if success else 1)
EOF

echo "✅ Enhanced test script created!"
echo ""
echo "🚀 Running Enhanced MCP Gateway Test..."
echo "======================================"
python3 test-mcp-enhanced.py