#!/usr/bin/env python3
"""
Test with Corrected Gateway Name
Test the gateway using the actual gateway name from line 7 selection
"""

import boto3
import json
from requests_aws4auth import AWS4Auth
import requests

def test_correct_gateway():
    """Test with the correct gateway name shown in selection"""
    
    print("🔍 Testing with CORRECTED Gateway Name")
    print("=" * 70)
    print("🚨 ISSUE IDENTIFIED: Gateway name mismatch!")
    print("   Selection shows: '94-askjulius-agentcore-gateway-mcp-iam'")
    print("   Script uses: 'a208194-askjulius-agentcore-gateway-mcp-iam'")
    print("   Test files use: 'a208194-askjulius-agentcore-gateway-mcp-iam'")
    print("")
    print("📋 Testing BOTH gateway URLs to find the correct one...")
    
    # Get AWS credentials
    session = boto3.Session()
    credentials = session.get_credentials()
    
    if not credentials:
        print("❌ No AWS credentials found")
        return False
    
    # Create AWS4Auth for bedrock-agentcore service
    auth = AWS4Auth(
        credentials.access_key,
        credentials.secret_key, 
        'us-east-1',
        'bedrock-agentcore',
        session_token=credentials.token
    )
    
    headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json'
    }
    
    # Test payload
    test_payload = {
        "jsonrpc": "2.0",
        "id": 1,
        "method": "tools/list",
        "params": {}
    }
    
    # Gateway URLs to test
    gateways_to_test = [
        {
            "name": "Original (from selection)",
            "url": "https://94-askjulius-agentcore-gateway-mcp-iam-fvro4phd59.gateway.bedrock-agentcore.us-east-1.amazonaws.com/mcp"
        },
        {
            "name": "Script version", 
            "url": "https://a208194-askjulius-agentcore-gateway-mcp-iam-fvro4phd59.gateway.bedrock-agentcore.us-east-1.amazonaws.com/mcp"
        }
    ]
    
    working_gateway = None
    
    for gateway in gateways_to_test:
        print(f"🔍 Testing {gateway['name']}:")
        print(f"   URL: {gateway['url']}")
        
        try:
            response = requests.post(gateway['url'], 
                                   json=test_payload, 
                                   headers=headers, 
                                   auth=auth,
                                   timeout=10)
            
            print(f"   Status: {response.status_code}")
            
            if response.status_code == 200:
                result = response.json()
                print(f"   ✅ SUCCESS! Tools found: {len(result.get('result', {}).get('tools', []))}")
                working_gateway = gateway
                
                # Test AI Calculator tool call
                print("   🧮 Testing AI Calculator tool call...")
                tool_payload = {
                    "jsonrpc": "2.0",
                    "id": 2,
                    "method": "tools/call",
                    "params": {
                        "name": "ai_calculate",
                        "arguments": {
                            "query": "What is 30 + 12?"
                        }
                    }
                }
                
                tool_response = requests.post(gateway['url'], 
                                            json=tool_payload, 
                                            headers=headers, 
                                            auth=auth,
                                            timeout=30)
                
                print(f"   Tool call status: {tool_response.status_code}")
                if tool_response.status_code == 200:
                    tool_result = tool_response.json()
                    if 'error' in tool_result:
                        print(f"   ❌ Tool call failed: {tool_result['error']}")
                    else:
                        print(f"   ✅ Tool call SUCCESS: {tool_result.get('result', 'No result')}")
                else:
                    print(f"   ❌ Tool call failed: {tool_response.text}")
                
            else:
                print(f"   ❌ Failed: {response.text}")
                
        except Exception as e:
            print(f"   ❌ Error: {e}")
            
        print("-" * 50)
    
    if working_gateway:
        print(f"🎯 WORKING GATEWAY FOUND: {working_gateway['name']}")
        print(f"   Correct URL: {working_gateway['url']}")
        print("")
        print("🔧 SOLUTION: Update all test scripts to use the correct gateway URL!")
        return working_gateway['url']
    else:
        print("❌ No working gateway found")
        return None

if __name__ == "__main__":
    test_correct_gateway()