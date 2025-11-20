#!/bin/bash
# CloudShell Quick Upload and Test Script
# Copy-paste this entire script into AWS CloudShell to test MCP gateway

echo "🌩️  Setting up MCP Gateway Test in CloudShell..."

# Install required Python package
echo "📦 Installing required packages..."
pip3 install --user requests-aws4auth

# Create the test script
echo "📝 Creating test script..."
cat > test-mcp-gateway-cloudshell.py << 'EOF'
#!/usr/bin/env python3
import json
import requests
from requests_aws4auth import AWS4Auth
import boto3
import sys

def test_mcp_gateway():
    """Test Bedrock Agent Core Gateway MCP endpoint with proper AWS authentication"""
    
    print("🔧 Bedrock Agent Core Gateway MCP Testing")
    print("=========================================")
    print()
    
    # Configuration
    gateway_url = "https://a208194-askjulius-agentcore-mcp-gateway-dhy8ntpcvu.gateway.bedrock-agentcore.us-east-1.amazonaws.com/mcp"
    region = 'us-east-1'
    service = 'bedrock-agentcore'
    
    print(f"Gateway URL: {gateway_url}")
    print(f"Region: {region}")
    print(f"Authentication: AWS IAM (SigV4)")
    print()
    
    try:
        # Get AWS credentials from boto3 session
        session = boto3.Session()
        credentials = session.get_credentials()
        
        if not credentials:
            print("❌ No AWS credentials available")
            return False
            
        # Show account info
        sts = boto3.client('sts')
        identity = sts.get_caller_identity()
        print(f"✅ AWS Account: {identity['Account']}")
        print(f"✅ User/Role: {identity['Arn']}")
        print()
        
        # Try multiple authentication approaches
        print("🔍 Testing tools/list...")
        headers = {'Content-Type': 'application/json'}
        data = {
            "jsonrpc": "2.0",
            "id": 1,
            "method": "tools/list",
            "params": {}
        }
        
        # Approach 1: Use boto3 to make the request directly
        print("  Approach 1: Using boto3 bedrock-agentcore client...")
        try:
            import boto3
            from botocore.auth import SigV4Auth
            from botocore.awsrequest import AWSRequest
            from urllib.parse import urlparse
            import json as json_lib
            
            # Parse the URL
            parsed_url = urlparse(gateway_url)
            
            # Create the request
            request = AWSRequest(
                method='POST',
                url=gateway_url,
                data=json_lib.dumps(data),
                headers=headers
            )
            
            # Sign the request
            SigV4Auth(credentials, service, region).add_auth(request)
            
            # Make the request using requests with the signed headers
            signed_headers = dict(request.headers)
            response = requests.post(gateway_url, headers=signed_headers, json=data, timeout=30)
            
        except Exception as e:
            print(f"  Boto3 approach failed: {e}")
            print("  Approach 2: Using requests-aws4auth...")
            
            # Fallback to requests-aws4auth
            auth = AWS4Auth(
                credentials.access_key,
                credentials.secret_key,
                region,
                service,
                session_token=credentials.token
            )
            
            response = requests.post(gateway_url, auth=auth, headers=headers, json=data, timeout=30)
        
        # Also create auth for potential tool calls
        auth = AWS4Auth(
            credentials.access_key,
            credentials.secret_key,
            region,
            service,
            session_token=credentials.token
        )
        print(f"Status: {response.status_code}")
        
        if response.status_code == 200:
            result = response.json()
            print(f"✅ Success!")
            print(f"Response: {json.dumps(result, indent=2)}")
            
            # Check if we have tools
            if 'result' in result and 'tools' in result['result']:
                tools = result['result']['tools']
                print(f"\n📋 Available tools: {len(tools)}")
                for tool in tools:
                    print(f"  - {tool.get('name', 'Unknown')}: {tool.get('description', 'No description')}")
                
                # Test 2: Call a tool if available
                if tools and len(tools) > 0:
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
                    
                    # Test tool call with same authentication approach
                    try:
                        # Try boto3 approach first
                        call_request = AWSRequest(
                            method='POST',
                            url=gateway_url,
                            data=json_lib.dumps(call_data),
                            headers=headers
                        )
                        SigV4Auth(credentials, service, region).add_auth(call_request)
                        signed_call_headers = dict(call_request.headers)
                        call_response = requests.post(gateway_url, headers=signed_call_headers, json=call_data, timeout=30)
                    except:
                        # Fallback to AWS4Auth
                        call_response = requests.post(gateway_url, auth=auth, headers=headers, json=call_data, timeout=30)
                    print(f"Tool call status: {call_response.status_code}")
                    
                    if call_response.status_code == 200:
                        call_result = call_response.json()
                        print(f"✅ Tool call success!")
                        print(f"Tool response: {json.dumps(call_result, indent=2)}")
                    else:
                        print(f"❌ Tool call failed: {call_response.text}")
            else:
                print("⚠️  No tools found in response")
        else:
            print(f"❌ Failed: {response.text}")
            return False
            
    except Exception as e:
        print(f"❌ Error: {str(e)}")
        return False
    
    return True

if __name__ == "__main__":
    success = test_mcp_gateway()
    sys.exit(0 if success else 1)
EOF

# Make it executable
chmod +x test-mcp-gateway-cloudshell.py

echo "✅ Setup complete!"
echo ""
echo "🚀 Running MCP Gateway Test..."
echo "=============================="
python3 test-mcp-gateway-cloudshell.py