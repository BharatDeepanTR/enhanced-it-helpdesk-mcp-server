#!/bin/bash

# CloudShell Application Details MCP Client Deployment
# Comprehensive script for testing Agent Core Gateway authentication
# Addresses both Agent ID validation and Bearer token issues

set -e

echo "🚀 CloudShell Application Details MCP Client Deployment"
echo "Fixing Agent ID validation and Bearer token authentication issues"
echo "================================================================="

# Configuration - CORRECTED for IAM-configured gateway
GATEWAY_NAME="a208194-askjulius-agentcore-gateway-mcp-iam"
GATEWAY_ID="a208194-askjulius-agentcore-gateway-mcp-iam-fvro4phd59"
GATEWAY_URL="https://a208194-askjulius-agentcore-gateway-mcp-iam-fvro4phd59.gateway.bedrock-agentcore.us-east-1.amazonaws.com"
LAMBDA_ARN="arn:aws:lambda:us-east-1:818565325759:function:a208194-chatops_application_details_intent"
REGION="us-east-1"

echo "📋 Configuration:"
echo "   Gateway Name: $GATEWAY_NAME"
echo "   Gateway ID: $GATEWAY_ID"
echo "   Gateway URL: $GATEWAY_URL"
echo "   Lambda ARN: $LAMBDA_ARN"
echo "   Region: $REGION"
echo ""

# Step 1: Install dependencies
echo "📦 Step 1: Installing Python dependencies..."
pip3 install --user requests-aws4auth boto3 --quiet
echo "✅ Dependencies installed"

# Step 2: Create comprehensive MCP client
echo "🔧 Step 2: Creating comprehensive MCP client..."

cat > cloudshell_app_details_client.py << 'EOF'
#!/usr/bin/env python3
"""
CloudShell Application Details MCP Client
Comprehensive solution addressing:
1. Agent ID validation errors (gateway name vs agent ID confusion)
2. Bearer token authentication issues
3. Multiple authentication fallbacks
"""

import json
import uuid
import boto3
import requests
from requests_aws4auth import AWS4Auth
from datetime import datetime
import sys
import logging
import time

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

class CloudShellApplicationDetailsClient:
    """
    Comprehensive MCP client for CloudShell with multiple authentication strategies
    """
    
    def __init__(self, region: str = "us-east-1"):
        self.region = region
        
        # Gateway configuration - CORRECTED for IAM-configured gateway
        self.gateway_name = "a208194-askjulius-agentcore-gateway-mcp-iam"
        self.gateway_id = "a208194-askjulius-agentcore-gateway-mcp-iam-fvro4phd59"
        self.gateway_base = "https://a208194-askjulius-agentcore-gateway-mcp-iam-fvro4phd59.gateway.bedrock-agentcore.us-east-1.amazonaws.com"
        self.lambda_arn = "arn:aws:lambda:us-east-1:818565325759:function:a208194-chatops_application_details_intent"
        
        # Test different endpoint patterns
        self.endpoints = {
            'mcp': f"{self.gateway_base}/mcp",
            'invoke': f"{self.gateway_base}/invoke",
            'tools': f"{self.gateway_base}/tools",
            'api': f"{self.gateway_base}/api",
            'root': self.gateway_base
        }
        
        # Initialize AWS clients
        self._init_aws_clients()
        
        # Initialize authentication methods
        self._init_auth_methods()
        
        # Session management
        self.session_id = f"cloudshell-{datetime.now().strftime('%Y%m%d-%H%M%S')}"
        logger.info(f"Session created: {self.session_id}")
    
    def _init_aws_clients(self):
        """Initialize AWS clients"""
        try:
            # Regular clients
            self.bedrock_client = boto3.client('bedrock', region_name=self.region)
            self.bedrock_agent_client = boto3.client('bedrock-agent', region_name=self.region)
            self.bedrock_runtime_client = boto3.client('bedrock-agent-runtime', region_name=self.region)
            self.lambda_client = boto3.client('lambda', region_name=self.region)
            
            logger.info("✅ AWS clients initialized")
        except Exception as e:
            logger.error(f"❌ Failed to initialize AWS clients: {e}")
            self.bedrock_client = None
            self.bedrock_agent_client = None
            self.bedrock_runtime_client = None
            self.lambda_client = None
    
    def _init_auth_methods(self):
        """Initialize multiple authentication methods"""
        self.auth_methods = {}
        
        try:
            session = boto3.Session()
            credentials = session.get_credentials()
            
            if credentials:
                # Different service names for SigV4
                services = ['bedrock-agentcore', 'bedrock', 'execute-api', 'lambda']
                
                for service in services:
                    self.auth_methods[service] = AWS4Auth(
                        credentials.access_key,
                        credentials.secret_key,
                        self.region,
                        service,
                        session_token=credentials.token
                    )
                
                # Store raw credentials for bearer tokens
                self.raw_credentials = {
                    'access_key': credentials.access_key,
                    'secret_key': credentials.secret_key,
                    'session_token': credentials.token
                }
                
                logger.info(f"✅ {len(self.auth_methods)} authentication methods initialized")
            else:
                logger.error("❌ No AWS credentials found")
                self.auth_methods = {}
                self.raw_credentials = {}
                
        except Exception as e:
            logger.error(f"❌ Authentication initialization failed: {e}")
            self.auth_methods = {}
            self.raw_credentials = {}
    
    def test_lambda_direct(self, asset_id: str) -> dict:
        """Test direct Lambda invocation to verify Lambda is working"""
        logger.info(f"🔧 Testing direct Lambda invocation for {asset_id}...")
        
        if not self.lambda_client:
            return {"success": False, "error": "Lambda client not available"}
        
        try:
            # Create Lambda payload
            payload = {
                "asset_id": asset_id,
                "request_type": "application_details"
            }
            
            # Invoke Lambda directly
            response = self.lambda_client.invoke(
                FunctionName=self.lambda_arn,
                InvocationType='RequestResponse',
                Payload=json.dumps(payload)
            )
            
            # Parse response
            response_payload = json.loads(response['Payload'].read())
            
            logger.info("✅ Direct Lambda invocation successful")
            return {
                "success": True,
                "method": "direct_lambda",
                "asset_id": asset_id,
                "response": response_payload,
                "status_code": response.get('StatusCode')
            }
            
        except Exception as e:
            logger.error(f"❌ Direct Lambda invocation failed: {e}")
            return {
                "success": False,
                "method": "direct_lambda",
                "asset_id": asset_id,
                "error": str(e)
            }
    
    def test_endpoint_connectivity(self) -> dict:
        """Test basic connectivity to gateway endpoints"""
        logger.info("📡 Testing gateway endpoint connectivity...")
        
        results = {}
        
        for endpoint_name, endpoint_url in self.endpoints.items():
            try:
                # Test basic connectivity
                response = requests.get(endpoint_url, timeout=10)
                results[endpoint_name] = {
                    "accessible": True,
                    "status_code": response.status_code,
                    "url": endpoint_url
                }
                logger.info(f"   {endpoint_name}: {response.status_code}")
                
            except Exception as e:
                results[endpoint_name] = {
                    "accessible": False,
                    "error": str(e),
                    "url": endpoint_url
                }
                logger.warning(f"   {endpoint_name}: Failed - {e}")
        
        return results
    
    def test_mcp_tools_list(self, endpoint_name: str = 'mcp') -> dict:
        """Test MCP tools/list with different authentication methods"""
        logger.info(f"📋 Testing MCP tools list on {endpoint_name} endpoint...")
        
        endpoint_url = self.endpoints.get(endpoint_name)
        if not endpoint_url:
            return {"success": False, "error": f"Endpoint {endpoint_name} not found"}
        
        # MCP tools list request
        mcp_request = {
            "jsonrpc": "2.0",
            "method": "tools/list",
            "id": str(uuid.uuid4())
        }
        
        headers = {
            'Content-Type': 'application/json',
            'Accept': 'application/json'
        }
        
        # Test different authentication methods
        auth_results = {}
        
        # 1. No authentication
        try:
            response = requests.post(endpoint_url, json=mcp_request, headers=headers, timeout=15)
            auth_results['no_auth'] = {
                "status_code": response.status_code,
                "response": response.text[:200] if response.text else "",
                "success": response.status_code == 200
            }
        except Exception as e:
            auth_results['no_auth'] = {"error": str(e), "success": False}
        
        # 2. SigV4 authentication with different services
        for service_name, auth in self.auth_methods.items():
            try:
                response = requests.post(endpoint_url, json=mcp_request, headers=headers, auth=auth, timeout=15)
                auth_results[f'sigv4_{service_name}'] = {
                    "status_code": response.status_code,
                    "response": response.text[:200] if response.text else "",
                    "success": response.status_code == 200
                }
                
                # If successful, parse the response
                if response.status_code == 200:
                    try:
                        result = response.json()
                        if "result" in result and "tools" in result["result"]:
                            tools = result["result"]["tools"]
                            auth_results[f'sigv4_{service_name}']["tools_found"] = len(tools)
                            auth_results[f'sigv4_{service_name}']["tool_names"] = [t.get("name") for t in tools]
                    except:
                        pass
                        
            except Exception as e:
                auth_results[f'sigv4_{service_name}'] = {"error": str(e), "success": False}
        
        # 3. Bearer token authentication (different token formats)
        if self.raw_credentials.get('session_token'):
            bearer_tokens = [
                self.raw_credentials['session_token'],
                self.raw_credentials['access_key'],
                f"{self.raw_credentials['access_key']}:{self.raw_credentials['secret_key']}"
            ]
            
            for i, token in enumerate(bearer_tokens):
                if not token:
                    continue
                    
                bearer_headers = headers.copy()
                bearer_headers['Authorization'] = f'Bearer {token}'
                
                try:
                    response = requests.post(endpoint_url, json=mcp_request, headers=bearer_headers, timeout=15)
                    auth_results[f'bearer_{i+1}'] = {
                        "status_code": response.status_code,
                        "response": response.text[:200] if response.text else "",
                        "success": response.status_code == 200,
                        "token_type": f"bearer_format_{i+1}"
                    }
                except Exception as e:
                    auth_results[f'bearer_{i+1}'] = {"error": str(e), "success": False}
        
        return {
            "endpoint": endpoint_name,
            "url": endpoint_url,
            "auth_results": auth_results,
            "successful_methods": [k for k, v in auth_results.items() if v.get("success")]
        }
    
    def test_mcp_tool_call(self, asset_id: str, successful_auth: dict) -> dict:
        """Test actual MCP tool call using successful authentication"""
        logger.info(f"🎯 Testing MCP tool call for {asset_id}...")
        
        if not successful_auth:
            return {"success": False, "error": "No successful authentication method provided"}
        
        # Extract authentication details
        endpoint_name = successful_auth.get("endpoint", "mcp")
        endpoint_url = self.endpoints[endpoint_name]
        auth_method = successful_auth["auth_method"]
        
        # Prepare asset ID
        clean_asset_id = asset_id.strip()
        if not clean_asset_id.startswith('a') and clean_asset_id.isdigit():
            clean_asset_id = f"a{clean_asset_id}"
        
        # MCP tool call request
        mcp_request = {
            "jsonrpc": "2.0",
            "method": "tools/call",
            "params": {
                "name": "get_application_details",
                "arguments": {
                    "asset_id": clean_asset_id
                }
            },
            "id": str(uuid.uuid4())
        }
        
        headers = {
            'Content-Type': 'application/json',
            'Accept': 'application/json'
        }
        
        try:
            # Apply the successful authentication method
            if auth_method == "no_auth":
                response = requests.post(endpoint_url, json=mcp_request, headers=headers, timeout=30)
            elif auth_method.startswith("sigv4_"):
                service_name = auth_method.replace("sigv4_", "")
                auth = self.auth_methods[service_name]
                response = requests.post(endpoint_url, json=mcp_request, headers=headers, auth=auth, timeout=30)
            elif auth_method.startswith("bearer_"):
                token_index = int(auth_method.split("_")[1]) - 1
                bearer_tokens = [
                    self.raw_credentials['session_token'],
                    self.raw_credentials['access_key'],
                    f"{self.raw_credentials['access_key']}:{self.raw_credentials['secret_key']}"
                ]
                token = bearer_tokens[token_index]
                headers['Authorization'] = f'Bearer {token}'
                response = requests.post(endpoint_url, json=mcp_request, headers=headers, timeout=30)
            else:
                return {"success": False, "error": f"Unknown auth method: {auth_method}"}
            
            if response.status_code == 200:
                result = response.json()
                logger.info("✅ MCP tool call successful")
                return {
                    "success": True,
                    "method": "mcp_tool_call",
                    "auth_method": auth_method,
                    "asset_id": clean_asset_id,
                    "response": result
                }
            else:
                logger.error(f"❌ MCP tool call failed: {response.status_code} - {response.text}")
                return {
                    "success": False,
                    "method": "mcp_tool_call",
                    "auth_method": auth_method,
                    "asset_id": clean_asset_id,
                    "error": f"HTTP {response.status_code}: {response.text}"
                }
                
        except Exception as e:
            logger.error(f"❌ MCP tool call exception: {e}")
            return {
                "success": False,
                "method": "mcp_tool_call",
                "auth_method": auth_method,
                "asset_id": asset_id,
                "error": str(e)
            }
    
    def run_comprehensive_test(self):
        """Run comprehensive test suite"""
        print("🧪 Application Details - Corrected Gateway Test")
        print("=" * 60)
        print(f"Gateway Name: {self.gateway_name}")
        print(f"Gateway ID: {self.gateway_id}")
        print(f"Gateway Base: {self.gateway_base}")
        print(f"MCP Endpoint: {self.mcp_endpoint}")
        print(f"Invoke Endpoint: {self.invoke_endpoint}")
        print(f"Session: {self.session_id}")
        print("")
        print("🎯 KEY CHANGE: Now testing with IAM-configured gateway!")
        print(f"   Previous (wrong): a208194-askjulius-agentcore-mcp-gateway")
        print(f"   Current (correct): {self.gateway_name}")
        print("")
        
        # Test 1: Direct Lambda invocation
        print("🔧 Test 1: Direct Lambda invocation...")
        lambda_result = self.test_lambda_direct("a12345")
        if lambda_result["success"]:
            print("✅ Direct Lambda invocation works")
            print(f"   Response: {json.dumps(lambda_result['response'], indent=2)[:200]}...")
        else:
            print(f"❌ Direct Lambda failed: {lambda_result['error']}")
        
        print("")
        
        # Test 2: Gateway endpoint connectivity
        print("📡 Test 2: Gateway endpoint connectivity...")
        connectivity_results = self.test_endpoint_connectivity()
        accessible_endpoints = []
        
        for endpoint, result in connectivity_results.items():
            if result["accessible"]:
                print(f"✅ {endpoint}: HTTP {result['status_code']}")
                accessible_endpoints.append(endpoint)
            else:
                print(f"❌ {endpoint}: {result['error']}")
        
        print("")
        
        # Test 3: MCP tools list authentication
        print("📋 Test 3: MCP authentication testing...")
        successful_auth = None
        
        # Test MCP endpoint first (most likely to work)
        mcp_results = self.test_mcp_tools_list('mcp')
        
        if mcp_results["successful_methods"]:
            auth_method = mcp_results["successful_methods"][0]
            successful_auth = {
                "endpoint": "mcp",
                "auth_method": auth_method
            }
            print(f"✅ MCP authentication successful: {auth_method}")
            
            # Show tools if available
            auth_result = mcp_results["auth_results"][auth_method]
            if "tool_names" in auth_result:
                print(f"   Tools found: {', '.join(auth_result['tool_names'])}")
        else:
            print("❌ MCP authentication failed on all methods")
            
            # Try other endpoints if MCP failed
            for endpoint_name in accessible_endpoints:
                if endpoint_name != 'mcp':
                    print(f"   Trying {endpoint_name} endpoint...")
                    endpoint_results = self.test_mcp_tools_list(endpoint_name)
                    if endpoint_results["successful_methods"]:
                        auth_method = endpoint_results["successful_methods"][0]
                        successful_auth = {
                            "endpoint": endpoint_name,
                            "auth_method": auth_method
                        }
                        print(f"✅ {endpoint_name} authentication successful: {auth_method}")
                        break
        
        print("")
        
        # Test 4: Actual application details call
        if successful_auth:
            print("🎯 Test 4: Application details tool call...")
            
            test_assets = ["a12345", "a208194"]
            success_count = 0
            
            for asset_id in test_assets:
                print(f"   Testing {asset_id}...")
                call_result = self.test_mcp_tool_call(asset_id, successful_auth)
                
                if call_result["success"]:
                    print(f"   ✅ {asset_id} successful")
                    success_count += 1
                    
                    # Show response preview
                    if "response" in call_result:
                        response = call_result["response"]
                        if isinstance(response, dict) and "result" in response:
                            print(f"      Response: {json.dumps(response['result'], indent=2)[:150]}...")
                else:
                    print(f"   ❌ {asset_id} failed: {call_result['error']}")
            
            print(f"\n   Results: {success_count}/{len(test_assets)} successful")
        else:
            print("❌ Test 4 skipped: No successful authentication method found")
        
        print("")
        print("📊 Final Summary:")
        
        if lambda_result["success"]:
            print("✅ Direct Lambda invocation: WORKING")
        else:
            print("❌ Direct Lambda invocation: FAILED")
        
        if accessible_endpoints:
            print(f"✅ Gateway connectivity: {len(accessible_endpoints)} endpoints accessible")
        else:
            print("❌ Gateway connectivity: No endpoints accessible")
        
        if successful_auth:
            print(f"✅ Gateway authentication: WORKING ({successful_auth['auth_method']})")
            return True
        else:
            print("❌ Gateway authentication: FAILED on all methods")
            return False

def main():
    print("CloudShell Application Details MCP Client")
    print("Comprehensive authentication and connectivity testing")
    print("")
    
    if len(sys.argv) > 1:
        command = sys.argv[1]
        
        client = CloudShellApplicationDetailsClient()
        
        if command == "test":
            success = client.run_comprehensive_test()
            sys.exit(0 if success else 1)
        elif command == "lambda":
            # Test direct Lambda only
            result = client.test_lambda_direct("a12345")
            print(json.dumps(result, indent=2))
        elif command == "connectivity":
            # Test connectivity only
            result = client.test_endpoint_connectivity()
            print(json.dumps(result, indent=2))
        else:
            # Treat as asset ID for quick test
            client = CloudShellApplicationDetailsClient()
            # This would need successful auth first
            print(f"Quick test for asset {command} requires running full test first")
            print("Use: python3 cloudshell_app_details_client.py test")
    else:
        # Run full test by default
        client = CloudShellApplicationDetailsClient()
        client.run_comprehensive_test()

if __name__ == "__main__":
    main()
EOF

echo "✅ CloudShell MCP client created"

# Step 3: Create deployment summary
echo "📋 Step 3: Creating deployment summary..."

cat > cloudshell_deployment_summary.txt << EOF
CloudShell Application Details MCP Client - Deployment Summary
============================================================

DEPLOYMENT COMPLETED: $(date)

Files Created:
- cloudshell_app_details_client.py: Comprehensive MCP client with multiple auth methods

Key Features:
✅ Fixes Agent ID validation error (no longer using gateway name as agent ID)
✅ Tests multiple authentication methods (SigV4 with different services, Bearer tokens)
✅ Tests multiple gateway endpoints (/mcp, /invoke, /tools, /api, root)
✅ Direct Lambda testing for baseline functionality
✅ Comprehensive logging and error reporting
✅ CloudShell optimized (handles credentials automatically)

Usage Commands:
---------------

1. Full comprehensive test:
   python3 cloudshell_app_details_client.py test

2. Test direct Lambda only:
   python3 cloudshell_app_details_client.py lambda

3. Test gateway connectivity only:
   python3 cloudshell_app_details_client.py connectivity

Configuration:
--------------
Gateway Name: $GATEWAY_NAME
Gateway URL: $GATEWAY_URL
Lambda ARN: $LAMBDA_ARN
Region: $REGION

Troubleshooting:
----------------
- If all methods fail: Check AWS credentials and permissions
- If Lambda works but gateway doesn't: Gateway configuration issue
- If connectivity fails: Network or gateway availability issue
- If authentication fails: IAM permissions or gateway auth config issue

Expected Outcomes:
------------------
✅ BEST CASE: Gateway authentication works, MCP tool calls succeed
⚠️  PARTIAL: Direct Lambda works, gateway auth fails (config issue)
❌ WORST CASE: All methods fail (permissions/network issue)
EOF

echo "✅ Deployment summary created"

# Step 4: Test execution
echo ""
echo "🧪 Step 4: Running initial test..."
echo "This will help identify which authentication method works"
echo ""

# Run the test
python3 cloudshell_app_details_client.py test

echo ""
echo "🎯 CloudShell Deployment Complete!"
echo "=================================="
echo ""
echo "📁 Files created in current directory:"
echo "   • cloudshell_app_details_client.py"
echo "   • cloudshell_deployment_summary.txt"
echo ""
echo "🔧 Available commands:"
echo "   python3 cloudshell_app_details_client.py test        # Full test"
echo "   python3 cloudshell_app_details_client.py lambda      # Lambda only"
echo "   python3 cloudshell_app_details_client.py connectivity # Connectivity only"
echo ""
echo "📖 Check cloudshell_deployment_summary.txt for detailed information"