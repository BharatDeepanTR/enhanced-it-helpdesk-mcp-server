#!/usr/bin/env python3
"""
Simple Configuration Audit - Show all current values
"""

import json
import boto3

def show_configuration_values():
    """Display all configuration values clearly"""
    
    print("🔍 COMPLETE CONFIGURATION AUDIT")
    print("=" * 60)
    
    # 1. Script Configuration
    print("\n📋 1. SCRIPT CONFIGURATION (create-agentcore-gateway.sh):")
    print("-" * 50)
    script_config = {
        "Gateway Name": "a208194-askjulius-agentcore-gateway-mcp-iam",
        "Service Role": "a208194-askjulius-agentcore-gateway", 
        "Lambda ARN": "arn:aws:lambda:us-east-1:818565325759:function:a208194-calculator-mcp-server",
        "Target Name": "target-direct-calculator-lambda",
        "Target Description": "Direct calculator Lambda for mathematical operations and computations",
        "Region": "us-east-1"
    }
    
    for key, value in script_config.items():
        print(f"  {key}: {value}")
    
    # 2. Current Gateway URL
    print("\n🌐 2. GATEWAY URL (used by clients):")
    print("-" * 50)
    gateway_url = "https://a208194-askjulius-agentcore-gateway-mcp-iam-fvro4phd59.gateway.bedrock-agentcore.us-east-1.amazonaws.com/mcp"
    print(f"  Full URL: {gateway_url}")
    print(f"  Gateway ID: a208194-askjulius-agentcore-gateway-mcp-iam-fvro4phd59")
    print(f"  Base Name: a208194-askjulius-agentcore-gateway-mcp-iam")
    
    # 3. Calculator Lambda Test
    print("\n🧮 3. CALCULATOR LAMBDA DIRECT TEST:")
    print("-" * 50)
    
    try:
        lambda_client = boto3.client('lambda', region_name='us-east-1')
        
        # Test Lambda directly
        test_request = {
            "jsonrpc": "2.0",
            "id": 1,
            "method": "tools/list"
        }
        
        print(f"  Testing Lambda: a208194-calculator-mcp-server")
        response = lambda_client.invoke(
            FunctionName="a208194-calculator-mcp-server",
            Payload=json.dumps(test_request)
        )
        
        result = json.loads(response['Payload'].read())
        print(f"  Status Code: {response['StatusCode']}")
        
        if 'result' in result and 'tools' in result['result']:
            tools = result['result']['tools']
            print(f"  ✅ Lambda has {len(tools)} tool(s):")
            for i, tool in enumerate(tools, 1):
                name = tool.get('name', 'Unknown')
                description = tool.get('description', 'No description')
                print(f"    {i}. {name}: {description}")
                
                if 'inputSchema' in tool:
                    schema = tool['inputSchema']
                    if 'properties' in schema:
                        props = list(schema['properties'].keys())
                        required = schema.get('required', [])
                        print(f"       Parameters: {props} (required: {required})")
        else:
            print(f"  ❌ Unexpected response: {result}")
            
    except Exception as e:
        print(f"  ❌ Lambda test error: {e}")
    
    # 4. Expected Tool Names
    print("\n🎯 4. EXPECTED TOOL NAME FORMAT:")
    print("-" * 50)
    target_name = "target-direct-calculator-lambda"
    calculator_tools = ["add", "subtract", "multiply", "divide", "power", "sqrt"]
    
    print(f"  Target Name: {target_name}")
    print(f"  Expected format: {target_name}___[tool_name]")
    print(f"  Expected tools:")
    for tool in calculator_tools:
        expected_name = f"{target_name}___{tool}"
        print(f"    {tool} → {expected_name}")
    
    # 5. Common Issues
    print("\n⚠️  5. POTENTIAL ISSUES:")
    print("-" * 50)
    print("  Issue 1: Gateway still configured for application details")
    print("           (returns 'An internal error occurred. Please retry later.')")
    print("  Issue 2: Tool name format mismatch")
    print("           (Client expects target-direct-calculator-lambda___add)")
    print("           (Gateway might have different format)")
    print("  Issue 3: Lambda ARN mismatch in gateway configuration")
    print("           (Gateway points to wrong Lambda)")
    
    # 6. Action Items
    print("\n✅ 6. NEXT STEPS:")
    print("-" * 50)
    print("  1. Check what's actually configured on the gateway")
    print("  2. Either update gateway OR use correct gateway URL")
    print("  3. Test simple add operation: 2 + 3")
    print("  4. Verify tool name format matches expectations")
    
    # 7. Test Commands
    print("\n🧪 7. TEST COMMANDS:")
    print("-" * 50)
    print("  # Test calculator Lambda directly:")
    print('  aws lambda invoke --function-name a208194-calculator-mcp-server \\')
    print('    --payload \'{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"add","arguments":{"a":2,"b":3}}}\' \\')
    print('    /tmp/calc-test.json && cat /tmp/calc-test.json')
    print()
    print("  # Check gateway tools (if requests module available):")
    print("  python discover_gateway_tools.py")

if __name__ == "__main__":
    show_configuration_values()