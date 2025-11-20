#!/usr/bin/env python3
"""
Quick Fix for AI Calculator MCP Target Testing
==============================================
"""

import json
import requests
import boto3
from aws_requests_auth.aws_auth import AWSRequestsAuth
from urllib.parse import urlparse

# CORRECTED Configuration
gateway_endpoint = "https://a208194-askjulius-agentcore-gateway-mcp-iam-fvro4phd59.gateway.bedrock-agentcore.us-east-1.amazonaws.com/mcp"
target_name = "target-lambda-direct-ai-calculator-mcp"  # CORRECTED NAME
region = "us-east-1"

print("🧪 Quick Test of AI Calculator MCP Target")
print("=" * 50)
print(f"Gateway: {gateway_endpoint}")
print(f"Target: {target_name}")
print("")

# Get AWS credentials
session = boto3.Session()
credentials = session.get_credentials()

# Parse gateway URL for auth
parsed_url = urlparse(gateway_endpoint)
aws_host = parsed_url.netloc

# Create AWS authentication
auth = AWSRequestsAuth(
    aws_access_key=credentials.access_key,
    aws_secret_access_key=credentials.secret_key,
    aws_token=credentials.token,
    aws_region=region,
    aws_service='bedrock',
    aws_host=aws_host
)

# Test payload
test_payload = {
    "jsonrpc": "2.0",
    "id": "quick-test",
    "method": "tools/call",
    "params": {
        "name": "ai_calculate",
        "arguments": {
            "query": "What is 15% of $50,000?"
        }
    }
}

# Send request
url = f"{gateway_endpoint}/targets/{target_name}/invoke"
headers = {'Content-Type': 'application/json'}

print(f"🚀 Testing URL: {url}")
print(f"📤 Payload: {json.dumps(test_payload, indent=2)}")
print("")

try:
    response = requests.post(
        url=url,
        json=test_payload,
        headers=headers,
        auth=auth,
        timeout=30
    )
    
    print(f"📥 Response Status: {response.status_code}")
    print(f"📥 Response Headers: {dict(response.headers)}")
    print("")
    
    if response.status_code == 200:
        try:
            response_data = response.json()
            print("📥 Response Body:")
            print(json.dumps(response_data, indent=2))
            
            if response_data.get('jsonrpc') == '2.0':
                print("\n✅ SUCCESS! MCP JSON-RPC 2.0 response received")
                if 'result' in response_data:
                    print("✅ AI Calculator is working correctly")
                    result = response_data['result']
                    if isinstance(result, dict) and 'content' in result:
                        content = result['content']
                        if isinstance(content, list) and len(content) > 0:
                            print(f"📊 Calculator Result: {content[0].get('text', 'No text')}")
                elif 'error' in response_data:
                    print(f"⚠️  MCP Error: {response_data['error']}")
            else:
                print("❌ Invalid MCP response format")
                
        except json.JSONDecodeError:
            print("❌ Invalid JSON response")
            print(f"Raw: {response.text}")
    else:
        print(f"❌ HTTP Error: {response.status_code}")
        print(f"Response: {response.text}")
        
except Exception as e:
    print(f"❌ Exception: {str(e)}")

print("\n" + "=" * 50)
print("🎯 Next steps if successful:")
print("1. Your AI Calculator MCP target is working!")
print("2. The permission fixes were successful")
print("3. Ready to test with Claude Desktop or other MCP clients")
print("")
print("🎯 If still failing:")
print("1. Check target configuration in AWS Console")
print("2. Verify Lambda function permissions")
print("3. Check CloudWatch logs for detailed errors")