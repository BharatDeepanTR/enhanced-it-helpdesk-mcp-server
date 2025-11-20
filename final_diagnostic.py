#!/usr/bin/env python3
"""
Final Diagnostic - Target Routing Check
Since schema is correct, check if gateway is routing to wrong target
"""

import boto3
import json
from requests_aws4auth import AWS4Auth
import requests

def final_diagnostic():
    """Final check - target routing and exact error messages"""
    
    print("🔍 FINAL DIAGNOSTIC - Target Routing Check")
    print("=" * 70)
    print("✅ Schema confirmed correct in console")
    print("✅ Lambda function works perfectly")
    print("✅ IAM permissions verified")
    print("❌ Gateway returns 'An internal error occurred'")
    print("")
    print("🎯 Checking if gateway is routing to correct target...")
    
    gateway_url = "https://a208194-askjulius-agentcore-gateway-mcp-iam-fvro4phd59.gateway.bedrock-agentcore.us-east-1.amazonaws.com/mcp"
    
    session = boto3.Session()
    credentials = session.get_credentials()
    
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
    
    # Test different potential issues
    print("🔍 Test 1: Check if tools/list returns our expected tools...")
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
                               auth=auth,
                               timeout=15)
        
        if response.status_code == 200:
            result = response.json()
            tools = result.get('result', {}).get('tools', [])
            
            ai_calc_tools = [t for t in tools if t.get('name') == 'ai_calculate']
            explain_tools = [t for t in tools if t.get('name') == 'explain_calculation']
            word_tools = [t for t in tools if t.get('name') == 'solve_word_problem']
            
            print(f"   Found ai_calculate tools: {len(ai_calc_tools)}")
            print(f"   Found explain_calculation tools: {len(explain_tools)}")
            print(f"   Found solve_word_problem tools: {len(word_tools)}")
            
            if len(ai_calc_tools) > 1:
                print("   🚨 ISSUE: Multiple ai_calculate tools found!")
                for i, tool in enumerate(ai_calc_tools):
                    print(f"      Tool {i+1}: {tool}")
                    
        else:
            print(f"   ❌ Tools/list failed: {response.status_code} - {response.text}")
            
    except Exception as e:
        print(f"   ❌ Error: {e}")
    
    print("\n" + "=" * 70)
    print("🔍 Test 2: Try calling ai_calculate with verbose error logging...")
    
    test_payload = {
        "jsonrpc": "2.0", 
        "id": 2,
        "method": "tools/call",
        "params": {
            "name": "ai_calculate",
            "arguments": {
                "query": "What is 10 + 5?"
            }
        }
    }
    
    try:
        print(f"   Sending request: {json.dumps(test_payload, indent=2)}")
        
        response = requests.post(gateway_url,
                               json=test_payload,
                               headers=headers,
                               auth=auth,
                               timeout=30)
        
        print(f"   Response Status: {response.status_code}")
        print(f"   Response Headers: {dict(response.headers)}")
        
        try:
            result = response.json()
            print(f"   Response JSON: {json.dumps(result, indent=2)}")
            
            if 'error' in result:
                error = result['error']
                print(f"   🚨 ERROR DETAILS:")
                print(f"      Code: {error.get('code', 'N/A')}")
                print(f"      Message: {error.get('message', 'N/A')}")
                print(f"      Data: {error.get('data', 'N/A')}")
                
        except json.JSONDecodeError:
            print(f"   Response Body (raw): {response.text}")
            
    except Exception as e:
        print(f"   ❌ Request failed: {e}")
    
    print("\n" + "=" * 70)
    print("🔍 Test 3: Check if there's a target name conflict...")
    
    # Test if gateway might be routing to wrong target due to name conflicts
    all_tools_payload = {
        "jsonrpc": "2.0",
        "id": 3,
        "method": "tools/list",
        "params": {}
    }
    
    try:
        response = requests.post(gateway_url,
                               json=all_tools_payload,
                               headers=headers,
                               auth=auth,
                               timeout=15)
        
        if response.status_code == 200:
            result = response.json()
            all_tools = result.get('result', {}).get('tools', [])
            
            print(f"   Total tools in gateway: {len(all_tools)}")
            
            # Group by name to find duplicates
            tool_names = {}
            for tool in all_tools:
                name = tool.get('name', 'unknown')
                if name not in tool_names:
                    tool_names[name] = []
                tool_names[name].append(tool)
            
            for name, tools in tool_names.items():
                if len(tools) > 1:
                    print(f"   🚨 DUPLICATE TOOL NAME: '{name}' appears {len(tools)} times")
                    for i, tool in enumerate(tools):
                        desc = tool.get('description', 'No description')[:50]
                        print(f"      Instance {i+1}: {desc}...")
                elif name in ['ai_calculate', 'explain_calculation', 'solve_word_problem']:
                    print(f"   ✅ Tool '{name}': Found once (good)")
                    
    except Exception as e:
        print(f"   ❌ Error checking tools: {e}")
    
    print("\n" + "=" * 70)
    print("🎯 DIAGNOSIS SUMMARY:")
    print("Since Lambda works and schema is correct, likely causes:")
    print("1. 🔄 Multiple targets with same tool names causing routing confusion")
    print("2. ⏱️  Gateway timeout issues (Lambda takes time to respond)")
    print("3. 📦 Gateway service internal issue with MCP protocol handling")
    print("4. 🔧 Recent gateway configuration change not properly applied")
    print("")
    print("💡 RECOMMENDED NEXT STEPS:")
    print("1. Check if there are multiple targets with 'ai_calculate' tool")
    print("2. Try removing and re-creating the AI Calculator target")
    print("3. Check AWS Service Health for Agent Core Gateway issues")
    print("4. Test with simpler tool first (like basic calculator)")

if __name__ == "__main__":
    final_diagnostic()