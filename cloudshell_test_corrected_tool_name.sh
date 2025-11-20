#!/bin/bash

# CloudShell Test - CORRECTED Tool Name for Application Details
# Uses the correct tool name: target-chatops-application-details___get_application_details

echo "🎯 CloudShell Test - CORRECTED Tool Name"
echo "Using proper prefixed tool name format"
echo "========================================"

# Configuration
GATEWAY_NAME="a208194-askjulius-agentcore-gateway-mcp-iam"
GATEWAY_ID="a208194-askjulius-agentcore-gateway-mcp-iam-fvro4phd59"
GATEWAY_URL="https://a208194-askjulius-agentcore-gateway-mcp-iam-fvro4phd59.gateway.bedrock-agentcore.us-east-1.amazonaws.com"
MCP_ENDPOINT="$GATEWAY_URL/mcp"
TARGET_NAME="target-chatops-application-details"
CORRECT_TOOL_NAME="target-chatops-application-details___get_application_details"
LAMBDA_ARN="arn:aws:lambda:us-east-1:818565325759:function:a208194-chatops_application_details_intent"

echo "📋 CORRECTED Configuration:"
echo "   Gateway: $GATEWAY_NAME"
echo "   Target: $TARGET_NAME"
echo "   Correct Tool Name: $CORRECT_TOOL_NAME"
echo "   MCP Endpoint: $MCP_ENDPOINT"
echo ""

echo "🔧 Key Fix: Using prefixed tool name format"
echo "   ❌ Wrong: get_application_details"
echo "   ✅ Correct: $CORRECT_TOOL_NAME"
echo ""

# Install dependencies
echo "📦 Installing dependencies..."
pip3 install --user requests-aws4auth boto3 --quiet
echo "✅ Dependencies installed"

# Create the corrected test client
echo "🔧 Creating corrected test client..."

cat > test_corrected_tool_name.py << 'EOF'
#!/usr/bin/env python3
"""
CloudShell Test - CORRECTED Tool Name
Uses: target-chatops-application-details___get_application_details
"""

import json, uuid, boto3, requests, sys, logging
from requests_aws4auth import AWS4Auth
from datetime import datetime

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

class CorrectedToolNameMCPClient:
    def __init__(self):
        # Configuration
        self.gateway_name = "a208194-askjulius-agentcore-gateway-mcp-iam"
        self.gateway_id = "a208194-askjulius-agentcore-gateway-mcp-iam-fvro4phd59"
        self.gateway_url = "https://a208194-askjulius-agentcore-gateway-mcp-iam-fvro4phd59.gateway.bedrock-agentcore.us-east-1.amazonaws.com"
        self.mcp_endpoint = f"{self.gateway_url}/mcp"
        self.target_name = "target-chatops-application-details"
        
        # CORRECTED: Use the full prefixed tool name
        self.correct_tool_name = "target-chatops-application-details___get_application_details"
        
        # Initialize authentication
        try:
            session = boto3.Session()
            creds = session.get_credentials()
            
            if creds:
                self.auth = AWS4Auth(
                    creds.access_key, creds.secret_key, "us-east-1",
                    'bedrock-agentcore', session_token=creds.token
                )
                logger.info("✅ Authentication initialized")
            else:
                logger.error("❌ No AWS credentials found")
                
        except Exception as e:
            logger.error(f"❌ Authentication failed: {e}")
    
    def test_application_details_corrected(self, asset_id):
        """Test application details with CORRECTED tool name"""
        logger.info(f"🎯 Testing application details with CORRECTED tool name...")
        logger.info(f"   Asset ID: {asset_id}")
        logger.info(f"   Tool Name: {self.correct_tool_name}")
        
        # MCP request with CORRECTED tool name
        mcp_request = {
            "jsonrpc": "2.0",
            "method": "tools/call",
            "params": {
                "name": self.correct_tool_name,  # Using prefixed name
                "arguments": {
                    "asset_id": asset_id
                }
            },
            "id": str(uuid.uuid4())
        }
        
        headers = {
            'Content-Type': 'application/json',
            'Accept': 'application/json'
        }
        
        try:
            response = requests.post(
                self.mcp_endpoint,
                json=mcp_request,
                headers=headers,
                auth=self.auth,
                timeout=30
            )
            
            logger.info(f"   HTTP Status: {response.status_code}")
            
            if response.status_code == 200:
                result = response.json()
                logger.info("✅ Application details call SUCCESSFUL!")
                
                return {
                    "success": True,
                    "tool_name": self.correct_tool_name,
                    "asset_id": asset_id,
                    "response": result
                }
            else:
                logger.error(f"❌ Call failed: {response.status_code} - {response.text}")
                return {
                    "success": False,
                    "error": f"HTTP {response.status_code}: {response.text}"
                }
                
        except Exception as e:
            logger.error(f"❌ Exception: {e}")
            return {"success": False, "error": str(e)}
    
    def run_corrected_test(self):
        """Run test with corrected tool name"""
        print("🎯 Corrected Tool Name Test")
        print("=" * 35)
        print(f"Gateway: {self.gateway_name}")
        print(f"Target: {self.target_name}")
        print(f"Tool Name: {self.correct_tool_name}")
        print(f"MCP Endpoint: {self.mcp_endpoint}")
        print("")
        
        print("🔧 CORRECTION APPLIED:")
        print("   ❌ Previous (wrong): get_application_details")
        print(f"   ✅ Current (correct): {self.correct_tool_name}")
        print("")
        
        # Test with multiple asset IDs
        test_assets = ["a12345", "a208194", "208194"]
        success_count = 0
        
        for i, asset_id in enumerate(test_assets, 1):
            print(f"🧪 Test {i}: Asset ID '{asset_id}'")
            
            result = self.test_application_details_corrected(asset_id)
            
            if result["success"]:
                print(f"   ✅ SUCCESS! Asset {asset_id}")
                success_count += 1
                
                # Show response details
                if "response" in result:
                    response = result["response"]
                    print(f"   📄 Response preview:")
                    
                    if "result" in response:
                        res_content = response["result"]
                        if "content" in res_content:
                            content = res_content["content"]
                            if isinstance(content, list) and len(content) > 0:
                                text_content = content[0].get("text", "")
                                print(f"      {text_content[:150]}...")
                        elif "output" in res_content:
                            print(f"      {json.dumps(res_content['output'])[:150]}...")
                        else:
                            print(f"      {json.dumps(res_content)[:150]}...")
                    else:
                        print(f"      {json.dumps(response)[:150]}...")
            else:
                print(f"   ❌ FAILED: {result.get('error', 'Unknown error')}")
            
            print("")
        
        print("📊 Final Results:")
        print(f"   Total tests: {len(test_assets)}")
        print(f"   Successful: {success_count}")
        print(f"   Failed: {len(test_assets) - success_count}")
        
        if success_count > 0:
            print("🎉 SUCCESS! Corrected tool name works!")
            print(f"✅ Use tool name: {self.correct_tool_name}")
            return True
        else:
            print("❌ All tests failed - investigate further")
            return False

if __name__ == "__main__":
    client = CorrectedToolNameMCPClient()
    success = client.run_corrected_test()
    sys.exit(0 if success else 1)
EOF

echo "✅ Corrected test client created"
echo ""

# Run the corrected test
echo "🧪 Running test with CORRECTED tool name..."
echo "This should finally work end-to-end!"
echo ""

python3 test_corrected_tool_name.py

echo ""
echo "🎯 Corrected Tool Name Test Complete!"
echo "===================================="
echo ""
echo "💡 Key Learning:"
echo "   The gateway uses prefixed tool names:"
echo "   Format: {target-name}___{original-tool-name}"
echo "   Actual tool: $CORRECT_TOOL_NAME"
echo ""
echo "📁 Files created:"
echo "   • test_corrected_tool_name.py"