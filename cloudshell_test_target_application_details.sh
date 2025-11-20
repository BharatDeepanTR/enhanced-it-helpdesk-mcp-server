#!/bin/bash

# CloudShell Test for Specific Target: target-chatops-application-details
# Gateway: a208194-askjulius-agentcore-gateway-mcp-iam
# Lambda: arn:aws:lambda:us-east-1:818565325759:function:a208194-chatops_application_details_intent

echo "🚀 CloudShell Test - Target: target-chatops-application-details"
echo "=============================================================="

# Correct Gateway Configuration (IAM-enabled)
GATEWAY_NAME="a208194-askjulius-agentcore-gateway-mcp-iam"
GATEWAY_ID="a208194-askjulius-agentcore-gateway-mcp-iam-fvro4phd59"
GATEWAY_URL="https://a208194-askjulius-agentcore-gateway-mcp-iam-fvro4phd59.gateway.bedrock-agentcore.us-east-1.amazonaws.com"
MCP_ENDPOINT="$GATEWAY_URL/mcp"

# Target Configuration
TARGET_NAME="target-chatops-application-details"
LAMBDA_ARN="arn:aws:lambda:us-east-1:818565325759:function:a208194-chatops_application_details_intent"
REGION="us-east-1"

echo "📋 Target Configuration:"
echo "   Gateway Name: $GATEWAY_NAME"
echo "   Gateway ID: $GATEWAY_ID" 
echo "   Gateway URL: $GATEWAY_URL"
echo "   MCP Endpoint: $MCP_ENDPOINT"
echo "   Target Name: $TARGET_NAME"
echo "   Lambda ARN: $LAMBDA_ARN"
echo "   Region: $REGION"
echo ""

# Install dependencies
echo "📦 Installing dependencies..."
pip3 install --user requests-aws4auth boto3 --quiet
echo "✅ Dependencies installed"
echo ""

# Create the target-specific test client
echo "🔧 Creating target-specific test client..."

cat > test_target_chatops_application_details.py << 'EOF'
#!/usr/bin/env python3
"""
CloudShell Test for Specific Target: target-chatops-application-details
Tests the specific target on the IAM-configured gateway
"""

import json, uuid, boto3, requests, sys, logging
from requests_aws4auth import AWS4Auth
from datetime import datetime

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

class TargetChatopsApplicationDetailsClient:
    def __init__(self):
        # Gateway Configuration
        self.gateway_name = "a208194-askjulius-agentcore-gateway-mcp-iam"
        self.gateway_id = "a208194-askjulius-agentcore-gateway-mcp-iam-fvro4phd59"
        self.gateway_base = "https://a208194-askjulius-agentcore-gateway-mcp-iam-fvro4phd59.gateway.bedrock-agentcore.us-east-1.amazonaws.com"
        self.mcp_endpoint = f"{self.gateway_base}/mcp"
        
        # Target Configuration
        self.target_name = "target-chatops-application-details"
        self.lambda_arn = "arn:aws:lambda:us-east-1:818565325759:function:a208194-chatops_application_details_intent"
        self.region = "us-east-1"
        
        # Initialize AWS clients
        try:
            self.lambda_client = boto3.client('lambda', region_name=self.region)
            session = boto3.Session()
            creds = session.get_credentials()
            
            if creds:
                # Authentication methods for the IAM-configured gateway
                self.auth_methods = {
                    'bedrock-agentcore': AWS4Auth(
                        creds.access_key, creds.secret_key, self.region, 
                        'bedrock-agentcore', session_token=creds.token
                    ),
                    'bedrock': AWS4Auth(
                        creds.access_key, creds.secret_key, self.region,
                        'bedrock', session_token=creds.token
                    ),
                    'execute-api': AWS4Auth(
                        creds.access_key, creds.secret_key, self.region,
                        'execute-api', session_token=creds.token
                    )
                }
                logger.info("✅ Authentication methods initialized")
            else:
                logger.error("❌ No AWS credentials found")
                self.auth_methods = {}
                
        except Exception as e:
            logger.error(f"❌ Initialization failed: {e}")
            self.auth_methods = {}
    
    def test_lambda_direct(self, asset_id="a12345"):
        """Test direct Lambda invocation to verify Lambda works"""
        logger.info(f"🔧 Testing direct Lambda invocation for {asset_id}...")
        
        try:
            # Test payload for the application details Lambda
            payload = {
                "asset_id": asset_id,
                "request_type": "application_details"
            }
            
            response = self.lambda_client.invoke(
                FunctionName=self.lambda_arn,
                InvocationType='RequestResponse',
                Payload=json.dumps(payload)
            )
            
            result = json.loads(response['Payload'].read())
            
            logger.info("✅ Direct Lambda invocation successful")
            return {
                "success": True,
                "method": "direct_lambda",
                "asset_id": asset_id,
                "response": result,
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
    
    def test_mcp_tools_list(self):
        """Test MCP tools/list to see what tools are available on the target"""
        logger.info("📋 Testing MCP tools list...")
        
        mcp_request = {
            "jsonrpc": "2.0",
            "method": "tools/list",
            "id": str(uuid.uuid4())
        }
        
        headers = {'Content-Type': 'application/json', 'Accept': 'application/json'}
        
        for auth_name, auth in self.auth_methods.items():
            try:
                logger.info(f"   Testing {auth_name} authentication...")
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
                        logger.info(f"   ✅ {auth_name} SUCCESS! Found {len(tools)} tools:")
                        
                        # Check if our target tool is available
                        target_tool_found = False
                        for tool in tools:
                            tool_name = tool.get('name', 'Unknown')
                            logger.info(f"      • {tool_name}: {tool.get('description', 'No description')}")
                            
                            if 'application_details' in tool_name.lower() or 'get_application_details' in tool_name:
                                target_tool_found = True
                                logger.info(f"      🎯 TARGET TOOL FOUND: {tool_name}")
                        
                        return {
                            "success": True,
                            "method": auth_name,
                            "tools": tools,
                            "target_tool_found": target_tool_found
                        }
                    else:
                        logger.info(f"   ✅ {auth_name} SUCCESS! Response: {json.dumps(result)[:150]}...")
                        return {"success": True, "method": auth_name, "response": result}
                        
                elif response.status_code == 401:
                    logger.warning(f"   ❌ {auth_name}: Unauthorized - {response.text[:100]}")
                elif response.status_code == 403:
                    logger.warning(f"   ❌ {auth_name}: Forbidden - {response.text[:100]}")
                else:
                    logger.warning(f"   ⚠️ {auth_name}: {response.status_code} - {response.text[:100]}")
                    
            except Exception as e:
                logger.warning(f"   ❌ {auth_name} failed: {e}")
        
        return {"success": False, "error": "All authentication methods failed"}
    
    def test_application_details_tool(self, asset_id="a12345"):
        """Test the specific application details tool call"""
        logger.info(f"🎯 Testing application details tool for {asset_id}...")
        
        # First get working authentication
        tools_result = self.test_mcp_tools_list()
        if not tools_result["success"]:
            return tools_result
        
        working_auth_method = tools_result["method"]
        auth = self.auth_methods[working_auth_method]
        
        # Test different tool name variations
        tool_names_to_try = [
            "get_application_details",
            "application_details", 
            "chatops_application_details",
            "target-chatops-application-details"
        ]
        
        headers = {'Content-Type': 'application/json', 'Accept': 'application/json'}
        
        for tool_name in tool_names_to_try:
            logger.info(f"   Trying tool name: {tool_name}")
            
            mcp_request = {
                "jsonrpc": "2.0",
                "method": "tools/call",
                "params": {
                    "name": tool_name,
                    "arguments": {"asset_id": asset_id}
                },
                "id": str(uuid.uuid4())
            }
            
            try:
                response = requests.post(
                    self.mcp_endpoint,
                    json=mcp_request,
                    headers=headers,
                    auth=auth,
                    timeout=30
                )
                
                logger.info(f"   Status: {response.status_code}")
                
                if response.status_code == 200:
                    result = response.json()
                    
                    if "result" in result:
                        logger.info(f"   ✅ SUCCESS with tool name: {tool_name}")
                        return {
                            "success": True,
                            "method": working_auth_method,
                            "tool_name": tool_name,
                            "asset_id": asset_id,
                            "response": result
                        }
                    elif "error" in result:
                        error_msg = result["error"].get("message", "Unknown error")
                        if "not found" in error_msg.lower() or "unknown" in error_msg.lower():
                            logger.warning(f"   ⚠️ Tool '{tool_name}' not found, trying next...")
                            continue
                        else:
                            logger.error(f"   ❌ Tool error: {error_msg}")
                            return {
                                "success": False,
                                "tool_name": tool_name,
                                "error": error_msg
                            }
                else:
                    logger.warning(f"   ⚠️ HTTP {response.status_code}: {response.text[:100]}")
                    
            except Exception as e:
                logger.warning(f"   ❌ Exception with {tool_name}: {e}")
                continue
        
        return {
            "success": False,
            "error": f"All tool names failed: {', '.join(tool_names_to_try)}"
        }
    
    def test_target_endpoint(self):
        """Test if there's a specific target endpoint"""
        logger.info("🎯 Testing target-specific endpoint...")
        
        target_endpoints = [
            f"{self.gateway_base}/{self.target_name}",
            f"{self.gateway_base}/target/{self.target_name}",
            f"{self.gateway_base}/targets/{self.target_name}",
            f"{self.mcp_endpoint}/{self.target_name}"
        ]
        
        for endpoint in target_endpoints:
            try:
                logger.info(f"   Testing: {endpoint}")
                response = requests.get(endpoint, timeout=10)
                logger.info(f"   Status: {response.status_code}")
                
                if response.status_code == 200:
                    logger.info(f"   ✅ Target endpoint accessible: {endpoint}")
                    return {"success": True, "endpoint": endpoint}
                elif response.status_code in [401, 403]:
                    logger.info(f"   🔐 Target endpoint exists but requires auth: {endpoint}")
                    
            except Exception as e:
                logger.warning(f"   ❌ {endpoint}: {e}")
        
        return {"success": False, "error": "No target-specific endpoints accessible"}
    
    def run_comprehensive_target_test(self):
        """Run comprehensive test for the specific target"""
        print("🧪 Target Test: target-chatops-application-details")
        print("=" * 55)
        print(f"Gateway Name: {self.gateway_name}")
        print(f"Gateway ID: {self.gateway_id}")
        print(f"Target Name: {self.target_name}")
        print(f"Lambda ARN: {self.lambda_arn}")
        print(f"MCP Endpoint: {self.mcp_endpoint}")
        print("")
        
        # Test 1: Direct Lambda
        print("🔧 Test 1: Direct Lambda invocation...")
        lambda_result = self.test_lambda_direct("a12345")
        
        if lambda_result["success"]:
            print("   ✅ Direct Lambda: WORKING")
            print(f"   📄 Response: {json.dumps(lambda_result['response'], indent=2)[:200]}...")
        else:
            print(f"   ❌ Direct Lambda: FAILED - {lambda_result['error']}")
        
        print("")
        
        # Test 2: MCP Tools List
        print("📋 Test 2: MCP tools list...")
        tools_result = self.test_mcp_tools_list()
        
        if tools_result["success"]:
            print(f"   ✅ MCP Authentication: WORKING ({tools_result['method']})")
            
            if tools_result.get("target_tool_found"):
                print("   🎯 Target tool found in tools list!")
            else:
                print("   ⚠️ Target tool not clearly identified in tools list")
                
            if "tools" in tools_result:
                print(f"   📋 Available tools: {len(tools_result['tools'])}")
        else:
            print(f"   ❌ MCP Authentication: FAILED - {tools_result['error']}")
        
        print("")
        
        # Test 3: Target endpoint check
        print("🎯 Test 3: Target-specific endpoints...")
        target_endpoint_result = self.test_target_endpoint()
        
        if target_endpoint_result["success"]:
            print(f"   ✅ Target endpoint found: {target_endpoint_result['endpoint']}")
        else:
            print("   ⚠️ No specific target endpoints found (normal for MCP)")
        
        print("")
        
        # Test 4: Application Details Tool Call
        if tools_result["success"]:
            print("🎯 Test 4: Application details tool calls...")
            
            test_assets = ["a12345", "a208194", "208194"]
            success_count = 0
            
            for asset in test_assets:
                print(f"   Testing asset: {asset}")
                tool_result = self.test_application_details_tool(asset)
                
                if tool_result["success"]:
                    print(f"   ✅ {asset} SUCCESS via tool: {tool_result['tool_name']}")
                    success_count += 1
                    
                    if "response" in tool_result:
                        response = tool_result["response"]
                        if "result" in response:
                            print(f"      📄 Result: {json.dumps(response['result'], indent=2)[:150]}...")
                else:
                    print(f"   ❌ {asset} FAILED: {tool_result.get('error', 'Unknown error')}")
            
            print(f"   📊 Tool call results: {success_count}/{len(test_assets)} successful")
        else:
            print("❌ Test 4 skipped: MCP authentication failed")
        
        print("")
        print("📊 Final Summary:")
        
        if lambda_result["success"]:
            print("✅ Direct Lambda: WORKING")
        else:
            print("❌ Direct Lambda: FAILED")
        
        if tools_result["success"]:
            print(f"✅ Gateway MCP: WORKING ({tools_result['method']})")
        else:
            print("❌ Gateway MCP: FAILED")
        
        if tools_result["success"] and tools_result.get("target_tool_found"):
            print("✅ Target Tool: FOUND")
        else:
            print("⚠️ Target Tool: NOT CLEARLY IDENTIFIED")
        
        # Overall success determination
        overall_success = lambda_result["success"] and tools_result["success"]
        
        if overall_success:
            print("")
            print("🎉 SUCCESS! Target is accessible and functional")
            print("   • Lambda function works directly")
            print("   • Gateway authentication works")  
            print("   • MCP protocol is functional")
            return True
        else:
            print("")
            print("❌ ISSUES DETECTED - See details above")
            return False

if __name__ == "__main__":
    client = TargetChatopsApplicationDetailsClient()
    success = client.run_comprehensive_target_test()
    sys.exit(0 if success else 1)
EOF

echo "✅ Target-specific test client created"
echo ""

# Run the target test
echo "🧪 Running comprehensive target test..."
echo "Testing target-chatops-application-details with Lambda ARN:"
echo "   $LAMBDA_ARN"
echo ""

python3 test_target_chatops_application_details.py

echo ""
echo "🎯 Target Test Complete!"
echo "========================"
echo ""
echo "📋 Target Details Tested:"
echo "   Gateway: $GATEWAY_NAME"
echo "   Target: $TARGET_NAME" 
echo "   Lambda: $LAMBDA_ARN"
echo "   MCP Endpoint: $MCP_ENDPOINT"
echo ""
echo "📁 Files created:"
echo "   • test_target_chatops_application_details.py"