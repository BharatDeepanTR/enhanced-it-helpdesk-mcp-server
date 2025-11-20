#!/usr/bin/env python3
"""
Debug Target Configuration
==========================
Check what targets are actually configured in the gateway
"""

import json
import requests
import boto3
from aws_requests_auth.aws_auth import AWSRequestsAuth
from urllib.parse import urlparse

# Configuration
gateway_endpoint = "https://a208194-askjulius-agentcore-gateway-mcp-iam-fvro4phd59.gateway.bedrock-agentcore.us-east-1.amazonaws.com/mcp"
region = "us-east-1"

print("🔍 Debug Target Configuration")
print("=" * 50)
print(f"Gateway: {gateway_endpoint}")
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

# Test 1: Try to list available tools/targets
print("🔍 Test 1: Checking available tools...")
list_payload = {
    "jsonrpc": "2.0",
    "id": "list-tools",
    "method": "tools/list"
}

url = f"{gateway_endpoint}/targets/target-lambda-direct-ai-calculator-mcp/invoke"
headers = {'Content-Type': 'application/json'}

try:
    response = requests.post(
        url=url,
        json=list_payload,
        headers=headers,
        auth=auth,
        timeout=30
    )
    
    print(f"📥 List Tools Response: {response.status_code}")
    if response.status_code == 200:
        try:
            data = response.json()
            print(f"📥 Tools Response: {json.dumps(data, indent=2)}")
        except:
            print(f"📥 Raw Response: {response.text}")
    else:
        print(f"📥 Error Response: {response.text}")
        
except Exception as e:
    print(f"❌ Exception: {str(e)}")

print("\n" + "-" * 50)

# Test 2: Try different target names that might exist
target_names_to_try = [
    "target-lambda-direct-ai-calculator-mcp",
    "target-lambda-direct-ai-bedrock-calculator-mcp", 
    "ai-calculator",
    "calculator",
    "ai-bedrock-calculator"
]

print("🔍 Test 2: Testing different possible target names...")
for target_name in target_names_to_try:
    print(f"\n🎯 Testing target: {target_name}")
    
    test_payload = {
        "jsonrpc": "2.0",
        "id": f"test-{target_name}",
        "method": "tools/list"
    }
    
    target_url = f"{gateway_endpoint}/targets/{target_name}/invoke"
    
    try:
        response = requests.post(
            url=target_url,
            json=test_payload,
            headers=headers,
            auth=auth,
            timeout=10
        )
        
        print(f"   📥 Status: {response.status_code}")
        
        if response.status_code == 200:
            try:
                data = response.json()
                if "UnknownOperationException" not in str(data):
                    print(f"   ✅ SUCCESS! Target {target_name} responds correctly")
                    print(f"   📥 Response: {json.dumps(data, indent=6)}")
                else:
                    print(f"   ⚠️  UnknownOperationException - target exists but config issue")
            except:
                print(f"   📥 Raw: {response.text[:200]}...")
        elif response.status_code == 404:
            print(f"   ❌ Target not found")
        else:
            print(f"   ⚠️  HTTP {response.status_code}: {response.text[:100]}...")
            
    except Exception as e:
        print(f"   ❌ Exception: {str(e)}")

print("\n" + "=" * 50)
print("🎯 Diagnosis Summary:")
print("1. Check which target names work above")
print("2. Look for successful responses without UnknownOperationException")
print("3. Use AWS Console to verify target configuration")
print("")
print("🛠️  If all targets show UnknownOperationException:")
print("- The target exists but may have wrong tool schema")  
print("- Check Lambda function configuration")
print("- Verify MCP protocol implementation in Lambda")