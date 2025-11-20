#!/usr/bin/env python3
"""
Discover actual tools available on the current gateway
"""

import json
import boto3
import requests
from requests_aws4auth import AWS4Auth

def discover_gateway_tools():
    """Test what tools are actually available on the gateway"""
    
    gateway_url = "https://a208194-askjulius-agentcore-gateway-mcp-iam-fvro4phd59.gateway.bedrock-agentcore.us-east-1.amazonaws.com/mcp"
    region = "us-east-1"
    
    # Setup authentication
    session = boto3.Session()
    credentials = session.get_credentials()
    auth = AWS4Auth(
        credentials.access_key,
        credentials.secret_key,
        region,
        'bedrock-agentcore',
        session_token=credentials.token
    )
    
    print("🔍 Discovering actual tools on the gateway...")
    print(f"Gateway: {gateway_url}")
    print()
    
    # List tools
    list_request = {
        "jsonrpc": "2.0",
        "id": 1,
        "method": "tools/list"
    }
    
    try:
        response = requests.post(
            gateway_url,
            json=list_request,
            auth=auth,
            headers={'Content-Type': 'application/json'},
            timeout=30
        )
        
        print(f"Status: {response.status_code}")
        if response.status_code == 200:
            result = response.json()
            print("📋 Available Tools:")
            print(json.dumps(result, indent=2))
            
            if 'result' in result and 'tools' in result['result']:
                tools = result['result']['tools']
                print(f"\n🔧 Found {len(tools)} tool(s):")
                for tool in tools:
                    name = tool.get('name', 'Unknown')
                    description = tool.get('description', 'No description')
                    print(f"  - {name}: {description}")
                    
                    # Show input schema
                    if 'inputSchema' in tool:
                        schema = tool['inputSchema']
                        if 'properties' in schema:
                            props = list(schema['properties'].keys())
                            required = schema.get('required', [])
                            print(f"    Parameters: {props} (required: {required})")
                
                return tools
            else:
                print("❌ No tools found in response")
        else:
            print(f"❌ Failed: {response.text}")
            
    except Exception as e:
        print(f"❌ Error: {e}")
    
    return None

if __name__ == "__main__":
    discover_gateway_tools()