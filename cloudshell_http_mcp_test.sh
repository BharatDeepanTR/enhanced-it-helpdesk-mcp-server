#!/bin/bash
# CloudShell HTTP MCP Test for Application Details Gateway
# Uses direct HTTP calls with AWS SigV4 authentication similar to calculator approach

set -e

GATEWAY_URL="https://a208194-askjulius-agentcore-mcp-gateway-dhy8ntpcvu.gateway.bedrock-agentcore.us-east-1.amazonaws.com/mcp"
REGION="us-east-1"
ASSET_ID="${1:-a12345}"

echo "🌐 CloudShell HTTP MCP Test - Application Details"
echo "=" * 55
echo "Gateway URL: $GATEWAY_URL"
echo "Region: $REGION"
echo "Asset ID: $ASSET_ID"
echo ""

# Check if required tools are available
echo "🔧 Checking dependencies..."

if ! command -v python3 >/dev/null 2>&1; then
    echo "❌ Python3 not found"
    exit 1
fi

echo "✅ Python3 available"

# Install required packages
echo "📦 Installing required packages..."
pip3 install --user requests-aws4auth boto3 > /dev/null 2>&1 || {
    echo "⚠️ Failed to install packages - trying to continue anyway"
}

# Create the HTTP MCP test script
cat > http_mcp_test.py << 'EOF'
#!/usr/bin/env python3
"""
CloudShell HTTP MCP Test Script
"""

import json
import uuid
import requests
import boto3
from requests_aws4auth import AWS4Auth
import sys
import argparse

def create_mcp_client(gateway_url, region):
    """Create MCP client with AWS SigV4 authentication"""
    
    # Get AWS credentials
    session = boto3.Session()
    credentials = session.get_credentials()
    
    if not credentials:
        print("❌ AWS credentials not found")
        return None
    
    # Set up AWS SigV4 authentication
    auth = AWS4Auth(
        credentials.access_key,
        credentials.secret_key,
        region,
        'bedrock-agentcore',
        session_token=credentials.token
    )
    
    print(f"✅ AWS credentials configured")
    return auth

def make_mcp_request(gateway_url, auth, method, params=None):
    """Make MCP request"""
    
    payload = {
        "jsonrpc": "2.0",
        "method": method,
        "id": str(uuid.uuid4())
    }
    
    if params:
        payload["params"] = params
    
    headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json'
    }
    
    print(f"🔧 Making request: {method}")
    if params:
        print(f"📤 Parameters: {json.dumps(params, indent=2)}")
    
    try:
        response = requests.post(
            gateway_url,
            json=payload,
            headers=headers,
            auth=auth,
            timeout=30
        )
        
        print(f"📥 Status: {response.status_code}")
        
        if response.status_code == 200:
            result = response.json()
            print("✅ Request successful")
            return result
        else:
            print(f"❌ Request failed: {response.status_code}")
            print(f"📥 Error: {response.text}")
            return None
            
    except Exception as e:
        print(f"❌ Exception: {e}")
        return None

def test_tools_list(gateway_url, auth):
    """Test tools/list endpoint"""
    print("\n🧪 Testing tools/list...")
    print("-" * 30)
    
    result = make_mcp_request(gateway_url, auth, "tools/list")
    
    if result:
        print("📋 Tools list response:")
        print(json.dumps(result, indent=2))
        
        if "result" in result and "tools" in result["result"]:
            tools = result["result"]["tools"]
            print(f"\n📊 Found {len(tools)} tools:")
            for tool in tools:
                print(f"   • {tool.get('name', 'Unknown')}: {tool.get('description', 'No description')}")
        
        return True
    else:
        return False

def test_application_details(gateway_url, auth, asset_id):
    """Test application details call"""
    print(f"\n🧪 Testing application details for asset: {asset_id}")
    print("-" * 50)
    
    # Clean asset ID
    clean_asset_id = asset_id.strip()
    if not clean_asset_id.startswith('a') and clean_asset_id.isdigit():
        clean_asset_id = f"a{clean_asset_id}"
    
    params = {
        "name": "get_application_details",
        "arguments": {
            "asset_id": clean_asset_id
        }
    }
    
    result = make_mcp_request(gateway_url, auth, "tools/call", params)
    
    if result:
        print("📊 Application details response:")
        print(json.dumps(result, indent=2))
        
        if "result" in result:
            response_result = result["result"]
            if isinstance(response_result, dict) and "content" in response_result:
                content = response_result["content"]
                if isinstance(content, list) and len(content) > 0:
                    text_content = content[0].get("text", "No text content")
                    print(f"\n💬 Application Details:")
                    print(f"   {text_content}")
        
        return True
    else:
        return False

def main():
    parser = argparse.ArgumentParser(description='CloudShell HTTP MCP Test')
    parser.add_argument('--gateway-url', required=True, help='Gateway MCP URL')
    parser.add_argument('--region', default='us-east-1', help='AWS region')
    parser.add_argument('--asset-id', default='a12345', help='Asset ID to test')
    parser.add_argument('--test-type', choices=['tools', 'details', 'both'], 
                       default='both', help='Type of test to run')
    
    args = parser.parse_args()
    
    print(f"🚀 HTTP MCP Test Starting...")
    print(f"Gateway: {args.gateway_url}")
    print(f"Region: {args.region}")
    print(f"Asset ID: {args.asset_id}")
    print(f"Test Type: {args.test_type}")
    
    # Create client
    auth = create_mcp_client(args.gateway_url, args.region)
    if not auth:
        print("❌ Failed to create MCP client")
        return 1
    
    success_count = 0
    total_tests = 0
    
    # Run tests based on type
    if args.test_type in ['tools', 'both']:
        total_tests += 1
        if test_tools_list(args.gateway_url, auth):
            success_count += 1
    
    if args.test_type in ['details', 'both']:
        total_tests += 1
        if test_application_details(args.gateway_url, auth, args.asset_id):
            success_count += 1
    
    print(f"\n📊 Test Summary:")
    print(f"   Total: {total_tests}")
    print(f"   Success: {success_count}")
    print(f"   Failed: {total_tests - success_count}")
    
    if success_count == total_tests:
        print("✅ All tests passed!")
        return 0
    else:
        print("❌ Some tests failed")
        return 1

if __name__ == "__main__":
    sys.exit(main())
EOF

echo "📝 HTTP MCP test script created"

# Run the test
echo ""
echo "🚀 Running HTTP MCP test..."
echo ""

python3 http_mcp_test.py \
    --gateway-url "$GATEWAY_URL" \
    --region "$REGION" \
    --asset-id "$ASSET_ID" \
    --test-type both

echo ""
echo "🏁 CloudShell HTTP MCP test completed"

# Cleanup
rm -f http_mcp_test.py

echo ""
echo "💡 Usage examples:"
echo "  $0 a12345      # Test with asset ID a12345"
echo "  $0 208194      # Test with asset ID 208194 (auto-prefixed to a208194)"