#!/usr/bin/env python3
"""
Minimal Authentication Test for Application Details Gateway
Tests different authentication approaches without heavy dependencies
"""

import json
import uuid
import os
import subprocess
import sys
from datetime import datetime

def get_aws_credentials():
    """Get AWS credentials using AWS CLI"""
    try:
        # Get access key
        result = subprocess.run(['aws', 'configure', 'get', 'aws_access_key_id'], 
                              capture_output=True, text=True)
        access_key = result.stdout.strip() if result.returncode == 0 else None
        
        # Get secret key
        result = subprocess.run(['aws', 'configure', 'get', 'aws_secret_access_key'], 
                              capture_output=True, text=True)
        secret_key = result.stdout.strip() if result.returncode == 0 else None
        
        # Get session token (if available)
        result = subprocess.run(['aws', 'configure', 'get', 'aws_session_token'], 
                              capture_output=True, text=True)
        session_token = result.stdout.strip() if result.returncode == 0 else None
        
        # Get region
        result = subprocess.run(['aws', 'configure', 'get', 'region'], 
                              capture_output=True, text=True)
        region = result.stdout.strip() if result.returncode == 0 else 'us-east-1'
        
        return {
            'access_key': access_key,
            'secret_key': secret_key,
            'session_token': session_token,
            'region': region
        }
    except Exception as e:
        print(f"❌ Error getting AWS credentials: {e}")
        return None

def test_gateway_endpoints():
    """Test different gateway endpoints and authentication methods"""
    
    print("🧪 Minimal Authentication Test for Application Details Gateway")
    print("=" * 65)
    
    # Gateway configuration
    gateway_name = "a208194-askjulius-agentcore-mcp-gateway"
    gateway_base = "https://a208194-askjulius-agentcore-mcp-gateway-dhy8ntpcvu.gateway.bedrock-agentcore.us-east-1.amazonaws.com"
    
    endpoints_to_test = [
        f"{gateway_base}/mcp",
        f"{gateway_base}/invoke", 
        f"{gateway_base}/tools",
        f"{gateway_base}/api",
        f"{gateway_base}",
    ]
    
    print(f"Gateway Name: {gateway_name}")
    print(f"Base URL: {gateway_base}")
    print("")
    
    # Get AWS credentials
    print("🔑 Getting AWS credentials...")
    creds = get_aws_credentials()
    if creds and creds['access_key']:
        print("✅ AWS credentials found")
        print(f"   Region: {creds['region']}")
        print(f"   Access Key: {creds['access_key'][:8]}...")
        if creds['session_token']:
            print(f"   Session Token: {creds['session_token'][:20]}...")
    else:
        print("❌ No AWS credentials found")
        return
    
    print("")
    
    # Test 1: Basic endpoint accessibility
    print("📡 Test 1: Basic endpoint accessibility...")
    for i, endpoint in enumerate(endpoints_to_test, 1):
        print(f"   {i}. Testing {endpoint}")
        try:
            # Use curl to test basic connectivity
            result = subprocess.run([
                'curl', '-s', '-w', '%{http_code}', '-o', '/dev/null', 
                '--max-time', '10', endpoint
            ], capture_output=True, text=True)
            
            status_code = result.stdout.strip()
            print(f"      Status: {status_code}")
            
            if status_code == '200':
                print(f"      ✅ Endpoint accessible")
            elif status_code == '401':
                print(f"      🔐 Endpoint requires authentication")
            elif status_code == '403':
                print(f"      🚫 Endpoint forbidden")
            elif status_code == '404':
                print(f"      ❌ Endpoint not found")
            else:
                print(f"      ⚠️ Unexpected status")
                
        except Exception as e:
            print(f"      ❌ Connection failed: {e}")
    
    print("")
    
    # Test 2: MCP tools list with different authentication
    print("📋 Test 2: MCP tools list with different auth...")
    mcp_endpoint = f"{gateway_base}/mcp"
    
    # Create MCP tools list request
    mcp_request = {
        "jsonrpc": "2.0",
        "method": "tools/list",
        "id": str(uuid.uuid4())
    }
    
    # Save request to temp file
    with open('/tmp/mcp_request.json', 'w') as f:
        json.dump(mcp_request, f)
    
    auth_methods = [
        # Method 1: No authentication
        {
            "name": "No Auth",
            "curl_args": []
        },
        # Method 2: Bearer token with session token
        {
            "name": "Bearer (Session Token)",
            "curl_args": ["-H", f"Authorization: Bearer {creds['session_token']}"] if creds['session_token'] else []
        },
        # Method 3: Bearer token with access key
        {
            "name": "Bearer (Access Key)",
            "curl_args": ["-H", f"Authorization: Bearer {creds['access_key']}"] if creds['access_key'] else []
        },
        # Method 4: Basic auth
        {
            "name": "Basic Auth",
            "curl_args": ["-u", f"{creds['access_key']}:{creds['secret_key']}"] if creds['access_key'] and creds['secret_key'] else []
        }
    ]
    
    for i, auth_method in enumerate(auth_methods, 1):
        if not auth_method["curl_args"]:
            continue
            
        print(f"   {i}. Testing {auth_method['name']}...")
        
        try:
            curl_cmd = [
                'curl', '-s', '-X', 'POST',
                '-H', 'Content-Type: application/json',
                '-H', 'Accept: application/json',
                '--max-time', '15',
                '-d', '@/tmp/mcp_request.json'
            ]
            curl_cmd.extend(auth_method["curl_args"])
            curl_cmd.append(mcp_endpoint)
            
            result = subprocess.run(curl_cmd, capture_output=True, text=True)
            
            if result.returncode == 0:
                try:
                    response = json.loads(result.stdout)
                    if "result" in response:
                        print(f"      ✅ Success! Found tools:")
                        tools = response["result"].get("tools", [])
                        for tool in tools:
                            print(f"         • {tool.get('name', 'Unknown')}")
                    elif "error" in response:
                        error_msg = response["error"].get("message", "Unknown error")
                        print(f"      ❌ MCP Error: {error_msg}")
                    else:
                        print(f"      ⚠️ Unexpected response: {result.stdout[:100]}...")
                except json.JSONDecodeError:
                    print(f"      ⚠️ Non-JSON response: {result.stdout[:100]}...")
            else:
                print(f"      ❌ Request failed: {result.stderr}")
                
        except Exception as e:
            print(f"      ❌ Test failed: {e}")
    
    print("")
    
    # Test 3: Direct Lambda invocation test
    print("🔧 Test 3: Direct Lambda invocation test...")
    lambda_arn = "arn:aws:lambda:us-east-1:818565325759:function:a208194-chatops_application_details_intent"
    
    print(f"   Testing direct invocation of: {lambda_arn}")
    
    # Create test payload for the Lambda
    lambda_payload = {
        "asset_id": "a12345",
        "request_type": "application_details"
    }
    
    try:
        # Save payload to temp file
        with open('/tmp/lambda_payload.json', 'w') as f:
            json.dump(lambda_payload, f)
        
        # Try to invoke Lambda directly
        result = subprocess.run([
            'aws', 'lambda', 'invoke',
            '--function-name', lambda_arn,
            '--payload', 'file:///tmp/lambda_payload.json',
            '--region', creds['region'],
            '/tmp/lambda_response.json'
        ], capture_output=True, text=True)
        
        if result.returncode == 0:
            print("   ✅ Direct Lambda invocation successful")
            
            # Read response
            try:
                with open('/tmp/lambda_response.json', 'r') as f:
                    lambda_response = json.load(f)
                print(f"   📄 Response: {json.dumps(lambda_response, indent=2)[:200]}...")
            except:
                print("   ⚠️ Could not read Lambda response")
        else:
            print(f"   ❌ Direct Lambda invocation failed: {result.stderr}")
            
    except Exception as e:
        print(f"   ❌ Lambda test failed: {e}")
    
    print("")
    
    # Clean up temp files
    try:
        os.remove('/tmp/mcp_request.json')
        os.remove('/tmp/lambda_payload.json')
        os.remove('/tmp/lambda_response.json')
    except:
        pass
    
    print("📊 Test Summary:")
    print("   ✅ Gateway endpoints tested")
    print("   🔐 Authentication methods tested")
    print("   🔧 Direct Lambda access tested")
    print("")
    print("💡 Next steps:")
    print("   - If any authentication method worked, use that pattern")
    print("   - If direct Lambda works but gateway doesn't, check gateway config")
    print("   - If nothing works, investigate AWS credentials or permissions")

if __name__ == "__main__":
    test_gateway_endpoints()