#!/usr/bin/env python3
"""
Gateway Configuration Validator
Verify that gateway target configuration matches Lambda implementation
"""

import boto3
import json
from requests_aws4auth import AWS4Auth
import requests

def validate_gateway_config():
    """Check if gateway configuration matches Lambda capabilities"""
    
    print("🔍 Validating Gateway Configuration vs Lambda Implementation")
    print("=" * 70)
    
    # Gateway endpoint
    gateway_url = "https://a208194-askjulius-agentcore-gateway-mcp-iam-fvro4phd59.gateway.bedrock-agentcore.us-east-1.amazonaws.com/mcp"
    
    # Get AWS credentials for authentication
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
    
    # Test 1: Get available targets/tools
    print("📋 Step 1: Getting available targets from gateway...")
    tools_payload = {
        "jsonrpc": "2.0",
        "id": 1,
        "method": "tools/list",
        "params": {}
    }
    
    try:
        response = requests.post(gateway_url, 
                               json=tools_payload, 
                               headers=headers, 
                               auth=auth)
        
        print(f"   Response Status: {response.status_code}")
        if response.status_code == 200:
            tools_response = response.json()
            print(f"   Available tools: {json.dumps(tools_response, indent=2)}")
            
            # Check if AI calculator tools are available
            if 'result' in tools_response and 'tools' in tools_response['result']:
                tools = tools_response['result']['tools']
                ai_calc_tools = [tool for tool in tools if 'ai_calculate' in tool.get('name', '')]
                
                print(f"   AI Calculator tools found: {len(ai_calc_tools)}")
                for tool in ai_calc_tools:
                    print(f"     - {tool.get('name', 'Unknown')}: {tool.get('description', 'No description')}")
            else:
                print("   ⚠️  No tools found in response")
        else:
            print(f"   ❌ Failed to get tools: {response.text}")
            
    except Exception as e:
        print(f"   ❌ Error getting tools: {e}")
        return False
    
    print("\n" + "=" * 70)
    
    # Test 2: Test direct Lambda function to compare
    print("📋 Step 2: Testing Lambda function directly...")
    lambda_client = boto3.client('lambda', region_name='us-east-1')
    
    # Test with tools/list to see what Lambda actually provides
    lambda_payload = {
        "jsonrpc": "2.0",
        "id": 1,
        "method": "tools/list",
        "params": {}
    }
    
    try:
        response = lambda_client.invoke(
            FunctionName='a208194-ai-bedrock-calculator-mcp-server',
            InvocationType='RequestResponse',
            Payload=json.dumps(lambda_payload)
        )
        
        lambda_response = json.loads(response['Payload'].read())
        print(f"   Lambda direct response: {json.dumps(lambda_response, indent=2)}")
        
        if 'result' in lambda_response and 'tools' in lambda_response['result']:
            lambda_tools = lambda_response['result']['tools'] 
            print(f"   Lambda provides {len(lambda_tools)} tools:")
            for tool in lambda_tools:
                print(f"     - {tool.get('name', 'Unknown')}: {tool.get('description', 'No description')}")
                
    except Exception as e:
        print(f"   ❌ Error testing Lambda directly: {e}")
        return False
    
    print("\n" + "=" * 70)
    
    # Test 3: Compare gateway schema vs Lambda schema
    print("📋 Step 3: Checking for schema mismatches...")
    
    # The gateway configuration from create-agentcore-gateway.sh defines these tools for AI Calculator:
    expected_tools = [
        "ai_calculate",
        "explain_calculation", 
        "solve_word_problem"
    ]
    
    print(f"   Gateway expects these AI Calculator tools: {expected_tools}")
    
    # Check if Lambda actually provides these tools
    if 'result' in lambda_response and 'tools' in lambda_response['result']:
        actual_tools = [tool['name'] for tool in lambda_response['result']['tools']]
        print(f"   Lambda actually provides: {actual_tools}")
        
        # Check for mismatches
        missing_in_lambda = set(expected_tools) - set(actual_tools)
        extra_in_lambda = set(actual_tools) - set(expected_tools)
        
        if missing_in_lambda:
            print(f"   ⚠️  Tools expected by gateway but missing in Lambda: {list(missing_in_lambda)}")
        
        if extra_in_lambda:
            print(f"   ℹ️  Extra tools in Lambda not configured in gateway: {list(extra_in_lambda)}")
            
        if not missing_in_lambda and not extra_in_lambda:
            print("   ✅ Tool schemas match!")
        else:
            print("   🔧 SCHEMA MISMATCH DETECTED - This could be the issue!")
            
    print("\n" + "=" * 70)
    print("🎯 Configuration validation completed")
    
    return True

if __name__ == "__main__":
    validate_gateway_config()