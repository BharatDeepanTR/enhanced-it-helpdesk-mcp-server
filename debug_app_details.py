#!/usr/bin/env python3
"""
Debug Application Details Tool
Compare direct Lambda invocation vs Gateway MCP call
"""

import json
import boto3
import requests
from requests_aws4auth import AWS4Auth
from datetime import datetime

# Configuration
LAMBDA_FUNCTION = "a208194-chatops_application_details_intent"
GATEWAY_URL = "https://a208194-askjulius-agentcore-gateway-mcp-iam-fvro4phd59.gateway.bedrock-agentcore.us-east-1.amazonaws.com/mcp"
REGION = "us-east-1"
ASSET_ID = "a208194"

def test_direct_lambda():
    """Test Lambda function directly"""
    print("🔍 Testing Lambda function directly...")
    
    try:
        lambda_client = boto3.client('lambda', region_name=REGION)
        
        # Test payload that matches MCP format
        test_payload = {
            "asset_id": ASSET_ID
        }
        
        print(f"📤 Invoking Lambda with payload: {json.dumps(test_payload, indent=2)}")
        
        response = lambda_client.invoke(
            FunctionName=LAMBDA_FUNCTION,
            Payload=json.dumps(test_payload)
        )
        
        # Read the response
        result = json.loads(response['Payload'].read())
        print(f"📥 Lambda Response:")
        print(f"   Status Code: {response.get('StatusCode')}")
        print(f"   Response: {json.dumps(result, indent=2)}")
        
        return result
        
    except Exception as e:
        print(f"❌ Direct Lambda test failed: {e}")
        return None

def test_gateway_mcp():
    """Test through Agent Core Gateway MCP"""
    print("\n🌐 Testing through Agent Core Gateway...")
    
    try:
        # Set up AWS authentication
        session = boto3.Session()
        credentials = session.get_credentials()
        auth = AWS4Auth(
            credentials.access_key,
            credentials.secret_key,
            REGION,
            'bedrock-agentcore',
            session_token=credentials.token
        )
        
        # First, list available tools
        print("📋 Listing available tools...")
        list_request = {
            "jsonrpc": "2.0",
            "id": 1,
            "method": "tools/list"
        }
        
        response = requests.post(
            GATEWAY_URL,
            json=list_request,
            auth=auth,
            headers={'Content-Type': 'application/json'}
        )
        
        print(f"   Status: {response.status_code}")
        if response.status_code == 200:
            tools_result = response.json()
            print(f"   Available tools: {json.dumps(tools_result, indent=2)}")
            
            # Extract tool name
            if 'result' in tools_result and 'tools' in tools_result['result']:
                tools = tools_result['result']['tools']
                if tools:
                    tool_name = tools[0]['name']
                    print(f"   Using tool: {tool_name}")
                    
                    # Now call the tool
                    print(f"\n🔧 Calling tool with asset_id: {ASSET_ID}")
                    tool_request = {
                        "jsonrpc": "2.0",
                        "id": 2,
                        "method": "tools/call",
                        "params": {
                            "name": tool_name,
                            "arguments": {
                                "asset_id": ASSET_ID
                            }
                        }
                    }
                    
                    print(f"📤 Tool request: {json.dumps(tool_request, indent=2)}")
                    
                    tool_response = requests.post(
                        GATEWAY_URL,
                        json=tool_request,
                        auth=auth,
                        headers={'Content-Type': 'application/json'}
                    )
                    
                    print(f"📥 Tool response:")
                    print(f"   Status: {tool_response.status_code}")
                    print(f"   Headers: {dict(tool_response.headers)}")
                    print(f"   Response: {json.dumps(tool_response.json(), indent=2)}")
                    
                    return tool_response.json()
                    
        else:
            print(f"❌ Failed to list tools: {response.text}")
            
    except Exception as e:
        print(f"❌ Gateway MCP test failed: {e}")
        return None

def compare_responses():
    """Compare both responses to identify the issue"""
    print(f"\n{'='*60}")
    print(f"🔍 DEBUGGING APPLICATION DETAILS TOOL")
    print(f"Asset ID: {ASSET_ID}")
    print(f"Lambda: {LAMBDA_FUNCTION}")
    print(f"Gateway: {GATEWAY_URL}")
    print(f"Time: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print(f"{'='*60}")
    
    # Test direct Lambda
    lambda_result = test_direct_lambda()
    
    # Test through gateway
    gateway_result = test_gateway_mcp()
    
    # Analysis
    print(f"\n{'='*60}")
    print("📊 ANALYSIS")
    print(f"{'='*60}")
    
    if lambda_result:
        print("✅ Direct Lambda: Working")
        if isinstance(lambda_result, dict) and 'errorMessage' not in lambda_result:
            print("   ✅ Lambda returns valid response")
        else:
            print("   ⚠️ Lambda returned error response")
    else:
        print("❌ Direct Lambda: Failed")
    
    if gateway_result:
        print("✅ Gateway MCP: Connected")
        if 'result' in gateway_result and not gateway_result.get('result', {}).get('isError', False):
            print("   ✅ Gateway returns successful response")
        else:
            error_content = gateway_result.get('result', {}).get('content', [])
            if error_content and isinstance(error_content, list):
                for content in error_content:
                    if content.get('type') == 'text':
                        print(f"   ❌ Gateway error: {content.get('text', 'Unknown error')}")
    else:
        print("❌ Gateway MCP: Failed")
    
    # Recommendations
    print(f"\n💡 RECOMMENDATIONS:")
    if lambda_result and not gateway_result:
        print("• Lambda works but gateway fails - check gateway configuration")
        print("• Verify tool schema matches Lambda input/output format")
        print("• Check service role permissions for Lambda invocation")
    elif not lambda_result:
        print("• Fix Lambda function first before testing gateway")
    
    print(f"\n🔧 Next Steps:")
    print("1. Fix any Lambda issues identified above")
    print("2. Verify gateway target configuration matches Lambda requirements")
    print("3. Test with updated MCP client")

if __name__ == "__main__":
    compare_responses()