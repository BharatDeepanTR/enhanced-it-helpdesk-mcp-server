#!/bin/bash

# CloudShell Test for CORRECT IAM-Configured Gateway
# Tests the actual gateway configured with IAM authentication

echo "🚀 CloudShell Test - CORRECT IAM-Configured Gateway"
echo "Testing: a208194-askjulius-agentcore-gateway-mcp-iam"
echo "=================================================="

# CORRECT Gateway Configuration (IAM-enabled)
GATEWAY_NAME="a208194-askjulius-agentcore-gateway-mcp-iam"
GATEWAY_ID="a208194-askjulius-agentcore-gateway-mcp-iam-fvro4phd59"
GATEWAY_URL="https://a208194-askjulius-agentcore-gateway-mcp-iam-fvro4phd59.gateway.bedrock-agentcore.us-east-1.amazonaws.com"
MCP_ENDPOINT="$GATEWAY_URL/mcp"
LAMBDA_ARN="arn:aws:lambda:us-east-1:818565325759:function:a208194-chatops_application_details_intent"
REGION="us-east-1"

echo "📋 CORRECTED Configuration:"
echo "   Gateway Name: $GATEWAY_NAME"
echo "   Gateway ID: $GATEWAY_ID" 
echo "   Gateway URL: $GATEWAY_URL"
echo "   MCP Endpoint: $MCP_ENDPOINT"
echo "   Lambda ARN: $LAMBDA_ARN"
echo ""

echo "🔧 Key Change: Using IAM-configured gateway instead of wrong one"
echo "   ❌ Previous (wrong): a208194-askjulius-agentcore-mcp-gateway"
echo "   ✅ Current (correct): $GATEWAY_NAME"
echo ""

# Install dependencies
echo "📦 Installing dependencies..."
pip3 install --user requests-aws4auth boto3 --quiet
echo "✅ Dependencies installed"
echo ""

# Create the corrected test client
echo "🔧 Creating corrected test client..."

cat > cloudshell_correct_gateway_test.py << 'EOF'
#!/usr/bin/env python3
"""
CloudShell Test for CORRECT IAM-Configured Gateway
Tests: a208194-askjulius-agentcore-gateway-mcp-iam-fvro4phd59
"""

import json, uuid, boto3, requests, sys, logging
from requests_aws4auth import AWS4Auth
from datetime import datetime

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

class CorrectGatewayMCPClient:
    def __init__(self):
        # CORRECT Gateway Configuration (IAM-enabled)
        self.gateway_name = "a208194-askjulius-agentcore-gateway-mcp-iam"
        self.gateway_id = "a208194-askjulius-agentcore-gateway-mcp-iam-fvro4phd59"
        self.gateway_base = "https://a208194-askjulius-agentcore-gateway-mcp-iam-fvro4phd59.gateway.bedrock-agentcore.us-east-1.amazonaws.com"
        self.mcp_endpoint = f"{self.gateway_base}/mcp"
        self.lambda_arn = "arn:aws:lambda:us-east-1:818565325759:function:a208194-chatops_application_details_intent"
        self.region = "us-east-1"
        
        # Initialize AWS clients and authentication
        try:
            session = boto3.Session()
            creds = session.get_credentials()
            
            if creds:
                self.auth_bedrock_agentcore = AWS4Auth(
                    creds.access_key, creds.secret_key, self.region, 
                    'bedrock-agentcore', session_token=creds.token
                )
                self.auth_bedrock = AWS4Auth(
                    creds.access_key, creds.secret_key, self.region,
                    'bedrock', session_token=creds.token
                )
                self.auth_execute_api = AWS4Auth(
                    creds.access_key, creds.secret_key, self.region,
                    'execute-api', session_token=creds.token
                )
                
                logger.info("✅ Authentication methods initialized")
            else:
                logger.error("❌ No AWS credentials found")
                
        except Exception as e:
            logger.error(f"❌ Authentication initialization failed: {e}")
    
    def test_gateway_connectivity(self):
        """Test basic connectivity to the CORRECT gateway"""
        logger.info("📡 Testing CORRECT gateway connectivity...")
        
        endpoints = [
            self.gateway_base,
            f"{self.gateway_base}/mcp",
            f"{self.gateway_base}/invoke", 
            f"{self.gateway_base}/tools"
        ]
        
        results = {}
        for endpoint in endpoints:
            try:
                response = requests.get(endpoint, timeout=10)
                results[endpoint] = {
                    "accessible": True,
                    "status": response.status_code,
                    "headers": dict(response.headers)
                }
                logger.info(f"   ✅ {endpoint}: {response.status_code}")
            except Exception as e:
                results[endpoint] = {"accessible": False, "error": str(e)}
                logger.warning(f"   ❌ {endpoint}: {e}")
        
        return results
    
    def test_mcp_authentication(self):
        """Test MCP authentication with different methods"""
        logger.info("🔐 Testing MCP authentication on CORRECT gateway...")
        
        mcp_request = {
            "jsonrpc": "2.0",
            "method": "tools/list",
            "id": str(uuid.uuid4())
        }
        
        headers = {'Content-Type': 'application/json', 'Accept': 'application/json'}
        
        auth_methods = [
            ("SigV4 bedrock-agentcore", self.auth_bedrock_agentcore),
            ("SigV4 bedrock", self.auth_bedrock),
            ("SigV4 execute-api", self.auth_execute_api)
        ]
        
        for name, auth in auth_methods:
            try:
                logger.info(f"   Testing {name}...")
                response = requests.post(
                    self.mcp_endpoint, 
                    json=mcp_request, 
                    headers=headers, 
                    auth=auth, 
                    timeout=15
                )
                
                logger.info(f"   Status: {response.status_code}")
                
                if response.status_code == 200:
                    result = response.json()
                    if "result" in result and "tools" in result["result"]:
                        tools = result["result"]["tools"]
                        logger.info(f"   ✅ {name} SUCCESS! Found {len(tools)} tools:")
                        for tool in tools:
                            logger.info(f"      • {tool.get('name', 'Unknown')}")
                        return {"success": True, "method": name, "tools": tools}
                    else:
                        logger.info(f"   ✅ {name} SUCCESS! Response: {json.dumps(result)[:100]}...")
                        return {"success": True, "method": name, "response": result}
                elif response.status_code == 401:
                    logger.warning(f"   ❌ {name}: Unauthorized - {response.text[:100]}")
                elif response.status_code == 403:
                    logger.warning(f"   ❌ {name}: Forbidden - {response.text[:100]}")
                else:
                    logger.warning(f"   ⚠️  {name}: {response.status_code} - {response.text[:100]}")
                    
            except Exception as e:
                logger.warning(f"   ❌ {name} failed: {e}")
        
        return {"success": False, "error": "All authentication methods failed"}
    
    def test_application_details(self, asset_id="a12345"):
        """Test application details call with working authentication"""
        logger.info(f"🎯 Testing application details for {asset_id}...")
        
        # First find working auth
        auth_result = self.test_mcp_authentication()
        if not auth_result["success"]:
            return auth_result
        
        # Use working auth for tool call
        auth_method = auth_result["method"]
        
        if "bedrock-agentcore" in auth_method:
            auth = self.auth_bedrock_agentcore
        elif "bedrock" in auth_method and "agentcore" not in auth_method:
            auth = self.auth_bedrock
        else:
            auth = self.auth_execute_api
        
        mcp_request = {
            "jsonrpc": "2.0",
            "method": "tools/call",
            "params": {
                "name": "get_application_details",
                "arguments": {"asset_id": asset_id}
            },
            "id": str(uuid.uuid4())
        }
        
        headers = {'Content-Type': 'application/json', 'Accept': 'application/json'}
        
        try:
            response = requests.post(
                self.mcp_endpoint,
                json=mcp_request, 
                headers=headers,
                auth=auth,
                timeout=30
            )
            
            if response.status_code == 200:
                result = response.json()
                logger.info("✅ Application details call successful!")
                return {
                    "success": True, 
                    "method": auth_method, 
                    "asset_id": asset_id,
                    "response": result
                }
            else:
                logger.error(f"❌ Tool call failed: {response.status_code} - {response.text}")
                return {
                    "success": False, 
                    "error": f"HTTP {response.status_code}: {response.text}"
                }
                
        except Exception as e:
            logger.error(f"❌ Tool call exception: {e}")
            return {"success": False, "error": str(e)}
    
    def run_comprehensive_test(self):
        """Run comprehensive test on CORRECT gateway"""
        print("🧪 CloudShell Test - CORRECT IAM Gateway")
        print("=" * 50)
        print(f"Gateway Name: {self.gateway_name}")
        print(f"Gateway ID: {self.gateway_id}")
        print(f"Gateway URL: {self.gateway_base}")
        print(f"MCP Endpoint: {self.mcp_endpoint}")
        print("")
        
        print("🎯 CORRECTED: Now testing the RIGHT gateway!")
        print("   ❌ Was testing: a208194-askjulius-agentcore-mcp-gateway")
        print(f"   ✅ Now testing: {self.gateway_name}")
        print("   ⭐ This gateway is configured with IAM authentication")
        print("")
        
        # Test 1: Connectivity
        print("📡 Test 1: Gateway connectivity...")
        connectivity = self.test_gateway_connectivity()
        accessible_count = sum(1 for result in connectivity.values() if result.get("accessible"))
        print(f"   Result: {accessible_count}/{len(connectivity)} endpoints accessible")
        print("")
        
        # Test 2: Authentication
        print("🔐 Test 2: MCP authentication...")
        auth_result = self.test_mcp_authentication()
        
        if auth_result["success"]:
            print(f"   ✅ SUCCESS! Working method: {auth_result['method']}")
            if "tools" in auth_result:
                print(f"   📋 Found {len(auth_result['tools'])} tools available")
            
            # Test 3: Application Details
            print("")
            print("🎯 Test 3: Application details call...")
            
            test_assets = ["a12345", "a208194"]
            success_count = 0
            
            for asset in test_assets:
                print(f"   Testing {asset}...")
                result = self.test_application_details(asset)
                
                if result["success"]:
                    print(f"   ✅ {asset} SUCCESS")
                    success_count += 1
                    if "response" in result:
                        response = result["response"]
                        print(f"      Response: {json.dumps(response, indent=2)[:150]}...")
                else:
                    print(f"   ❌ {asset} FAILED: {result.get('error', 'Unknown error')}")
            
            print(f"   Result: {success_count}/{len(test_assets)} assets successful")
        else:
            print(f"   ❌ FAILED: {auth_result.get('error', 'Authentication failed')}")
        
        print("")
        print("📊 Final Summary:")
        
        if accessible_count > 0:
            print("✅ Gateway connectivity: WORKING")
        else:
            print("❌ Gateway connectivity: FAILED")
        
        if auth_result["success"]:
            print(f"✅ Authentication: WORKING ({auth_result['method']})")
            print("🎉 SUCCESS! The CORRECT gateway works with IAM authentication!")
            return True
        else:
            print("❌ Authentication: FAILED")
            print("⚠️  Even the correct gateway isn't working - check IAM permissions")
            return False

if __name__ == "__main__":
    client = CorrectGatewayMCPClient()
    success = client.run_comprehensive_test()
    sys.exit(0 if success else 1)
EOF

echo "✅ Corrected test client created"
echo ""

# Run the corrected test
echo "🧪 Running test with CORRECT IAM-configured gateway..."
echo "This should resolve the Bearer token authentication issues!"
echo ""

python3 cloudshell_correct_gateway_test.py

echo ""
echo "🎯 CloudShell CORRECTED Gateway Test Complete!"
echo "============================================="
echo ""
echo "📋 Key Changes Made:"
echo "   ✅ Fixed gateway name: $GATEWAY_NAME"
echo "   ✅ Fixed gateway ID: $GATEWAY_ID"
echo "   ✅ Fixed gateway URL: $GATEWAY_URL"
echo "   ✅ Testing IAM authentication (not Bearer tokens)"
echo ""
echo "💡 Expected Result:"
echo "   If this gateway is properly configured with IAM authentication,"
echo "   the SigV4 methods should now work successfully!"
echo ""
echo "📁 Files created:"
echo "   • cloudshell_correct_gateway_test.py"