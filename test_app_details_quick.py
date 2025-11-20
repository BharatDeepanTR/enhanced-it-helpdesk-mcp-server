#!/usr/bin/env python3
"""
Quick Application Details Test
Test the correct tool name from your gateway configuration
"""

import json
import boto3
import requests
from requests_aws4auth import AWS4Auth

def test_app_details():
    """Test application details with correct tool name from gateway script"""
    
    gateway_url = "https://a208194-askjulius-agentcore-gateway-mcp-iam-fvro4phd59.gateway.bedrock-agentcore.us-east-1.amazonaws.com/mcp"
    region = "us-east-1"
    
    # Set up authentication
    session = boto3.Session()
    credentials = session.get_credentials()
    auth = AWS4Auth(
        credentials.access_key,
        credentials.secret_key,
        region,
        'bedrock-agentcore',
        session_token=credentials.token
    )
    
    print("🔍 Testing Application Details via Gateway")
    print(f"Gateway: {gateway_url}")
    print()
    
    # Step 1: List tools to see what's available
    print("📋 Step 1: Listing available tools...")
    list_request = {
        "jsonrpc": "2.0",
        "id": 1,
        "method": "tools/list"
    }
    
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
        print(f"Response: {json.dumps(result, indent=2)}")
        
        # Extract tool name from response
        if 'result' in result and 'tools' in result['result']:
            tools = result['result']['tools']
            if tools:
                tool_name = tools[0]['name']
                print(f"\n✅ Found tool: {tool_name}")
                
                # Step 2: Test the tool with asset ID
                print(f"\n🧪 Step 2: Testing tool with asset_id 'a208194'...")
                tool_request = {
                    "jsonrpc": "2.0",
                    "id": 2,
                    "method": "tools/call",
                    "params": {
                        "name": tool_name,
                        "arguments": {
                            "asset_id": "a208194"
                        }
                    }
                }
                
                print(f"📤 Request: {json.dumps(tool_request, indent=2)}")
                
                tool_response = requests.post(
                    gateway_url,
                    json=tool_request,
                    auth=auth,
                    headers={'Content-Type': 'application/json'},
                    timeout=30
                )
                
                print(f"📥 Response Status: {tool_response.status_code}")
                print(f"📥 Response: {json.dumps(tool_response.json(), indent=2)}")
                
                return tool_response.json()
            else:
                print("❌ No tools found")
        else:
            print("❌ No tools in response")
    else:
        print(f"❌ Failed to list tools: {response.text}")
    
    return None

if __name__ == "__main__":
    test_app_details()