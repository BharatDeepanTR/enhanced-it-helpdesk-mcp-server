#!/usr/bin/env python3
"""
Complete Configuration Audit - Show all current values
"""

import json
import boto3
import requests
from requests_aws4auth import AWS4Auth

def audit_complete_configuration():
    """Show all current configuration values"""
    
    print("🔍 COMPLETE CONFIGURATION AUDIT")
    print("=" * 60)
    
    # 1. Script Configuration (what the script is set to create)
    print("\n📋 1. SCRIPT CONFIGURATION (create-agentcore-gateway.sh):")
    print("-" * 50)
    print("Gateway Name: a208194-askjulius-agentcore-gateway-mcp-iam")
    print("Service Role: a208194-askjulius-agentcore-gateway")
    print("Lambda ARN: arn:aws:lambda:us-east-1:818565325759:function:a208194-calculator-mcp-server")
    print("Target Name: target-direct-calculator-lambda")
    print("Region: us-east-1")
    
    # 2. Current Gateway URL being used by clients
    print("\n🌐 2. CURRENT GATEWAY URL (used by clients):")
    print("-" * 50)
    gateway_url = "https://a208194-askjulius-agentcore-gateway-mcp-iam-fvro4phd59.gateway.bedrock-agentcore.us-east-1.amazonaws.com/mcp"
    print(f"Gateway URL: {gateway_url}")
    
    # 3. Test what's actually on the gateway
    print("\n🔧 3. ACTUAL TOOLS ON GATEWAY:")
    print("-" * 50)
    
    try:
        # Setup authentication
        session = boto3.Session()
        credentials = session.get_credentials()
        auth = AWS4Auth(
            credentials.access_key,
            credentials.secret_key,
            'us-east-1',
            'bedrock-agentcore',
            session_token=credentials.token
        )
        
        # List tools
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
        
        if response.status_code == 200:
            result = response.json()
            if 'result' in result and 'tools' in result['result']:
                tools = result['result']['tools']
                print(f"✅ Found {len(tools)} tool(s) on gateway:")
                for i, tool in enumerate(tools, 1):
                    name = tool.get('name', 'Unknown')
                    description = tool.get('description', 'No description')
                    print(f"  {i}. Tool: {name}")
                    print(f"     Description: {description}")
                    
                    # Show input schema
                    if 'inputSchema' in tool:
                        schema = tool['inputSchema']
                        if 'properties' in schema:
                            props = list(schema['properties'].keys())
                            required = schema.get('required', [])
                            print(f"     Parameters: {props}")
                            print(f"     Required: {required}")
                    print()
            else:
                print("❌ No tools found in response")
        else:
            print(f"❌ Gateway request failed: {response.status_code}")
            print(f"Response: {response.text}")
            
    except Exception as e:
        print(f"❌ Gateway test error: {e}")
    
    # 4. Test calculator Lambda directly
    print("\n🧮 4. CALCULATOR LAMBDA DIRECT TEST:")
    print("-" * 50)
    
    try:
        lambda_client = boto3.client('lambda', region_name='us-east-1')
        
        # Test Lambda directly
        test_request = {
            "jsonrpc": "2.0",
            "id": 1,
            "method": "tools/list"
        }
        
        response = lambda_client.invoke(
            FunctionName="a208194-calculator-mcp-server",
            Payload=json.dumps(test_request)
        )
        
        result = json.loads(response['Payload'].read())
        
        if 'result' in result and 'tools' in result['result']:
            tools = result['result']['tools']
            print(f"✅ Calculator Lambda has {len(tools)} tool(s):")
            for i, tool in enumerate(tools, 1):
                name = tool.get('name', 'Unknown')
                description = tool.get('description', 'No description')
                print(f"  {i}. {name}: {description}")
                
                if 'inputSchema' in tool:
                    schema = tool['inputSchema']
                    if 'properties' in schema:
                        props = list(schema['properties'].keys())
                        required = schema.get('required', [])
                        print(f"     Parameters: {props} (required: {required})")
            print()
        else:
            print("❌ No tools found in Lambda response")
            
    except Exception as e:
        print(f"❌ Lambda test error: {e}")
    
    # 5. Client tool mapping
    print("\n🎯 5. CLIENT TOOL MAPPING (what clients expect):")
    print("-" * 50)
    expected_tools = {
        'add': 'target-direct-calculator-lambda___add',
        'subtract': 'target-direct-calculator-lambda___subtract', 
        'multiply': 'target-direct-calculator-lambda___multiply',
        'divide': 'target-direct-calculator-lambda___divide',
        'power': 'target-direct-calculator-lambda___power',
        'sqrt': 'target-direct-calculator-lambda___sqrt'
    }
    
    print("Clients expect these tool names:")
    for operation, full_name in expected_tools.items():
        print(f"  {operation} → {full_name}")
    
    # 6. Summary
    print("\n📊 6. CONFIGURATION ANALYSIS:")
    print("-" * 50)
    print("Script points to: a208194-calculator-mcp-server Lambda")
    print("Gateway URL: ...gateway-mcp-iam-fvro4phd59...")
    print("Clients expect: target-direct-calculator-lambda___[tool] format")
    print()
    print("🔍 DIAGNOSIS:")
    print("1. Check if gateway actually has calculator tools or app details tools")
    print("2. Verify tool name format matches client expectations")
    print("3. Confirm Lambda ARN in gateway matches script configuration")

if __name__ == "__main__":
    audit_complete_configuration()