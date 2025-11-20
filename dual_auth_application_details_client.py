#!/usr/bin/env python3
"""
Dual-Authentication MCP Client for Application Details
Uses both approaches that worked with calculator:
1. Bedrock Agent Runtime API (like calculator)
2. Direct HTTP with SigV4 (like calculator)
"""

import json
import uuid
import boto3
import requests
from requests_aws4auth import AWS4Auth
from datetime import datetime
import sys
import logging

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

class DualAuthApplicationDetailsMCPClient:
    """
    Application Details MCP Client using calculator's proven authentication patterns
    """
    
    def __init__(self, region: str = "us-east-1"):
        self.region = region
        
        # Gateway configuration (same pattern as calculator)
        self.gateway_id = "a208194-askjulius-agentcore-mcp-gateway"
        self.gateway_url = "https://a208194-askjulius-agentcore-mcp-gateway-dhy8ntpcvu.gateway.bedrock-agentcore.us-east-1.amazonaws.com/mcp"
        
        # Initialize Bedrock Agent Runtime client (like calculator)
        try:
            self.bedrock_client = boto3.client(
                'bedrock-agent-runtime', 
                region_name=region
            )
            logger.info(f"✅ Bedrock Agent Runtime client initialized")
        except Exception as e:
            logger.error(f"❌ Failed to initialize Bedrock client: {e}")
            self.bedrock_client = None
        
        # Initialize HTTP authentication (like calculator)
        try:
            session = boto3.Session()
            credentials = session.get_credentials()
            
            if credentials:
                self.auth = AWS4Auth(
                    credentials.access_key,
                    credentials.secret_key,
                    region,
                    'bedrock-agentcore',  # Same service name as calculator
                    session_token=credentials.token
                )
                logger.info(f"✅ HTTP SigV4 authentication initialized")
            else:
                self.auth = None
                logger.error("❌ No AWS credentials found")
        except Exception as e:
            logger.error(f"❌ Failed to initialize HTTP auth: {e}")
            self.auth = None
        
        # Session management (like calculator)
        self.session_id = f"app-details-{datetime.now().strftime('%Y%m%d-%H%M%S')}"
        logger.info(f"Session created: {self.session_id}")
    
    def get_application_details_via_agent_api(self, asset_id: str) -> dict:
        """
        Method 1: Use Bedrock Agent Runtime API (calculator's working approach)
        """
        logger.info("🧪 Method 1: Using Bedrock Agent Runtime API...")
        
        if not self.bedrock_client:
            return {
                "success": False,
                "method": "agent_api",
                "error": "Bedrock client not available"
            }
        
        try:
            # Clean asset ID
            clean_asset_id = asset_id.strip()
            if not clean_asset_id.startswith('a') and clean_asset_id.isdigit():
                clean_asset_id = f"a{clean_asset_id}"
            
            prompt = f"Get application details for asset {clean_asset_id}"
            logger.info(f"Sending request: '{prompt}'")
            
            # Use same pattern as calculator
            response = self.bedrock_client.invoke_agent(
                agentId=self.gateway_id,
                agentAliasId="TSTALIASID",  # Same as calculator
                sessionId=self.session_id,
                inputText=prompt
            )
            
            logger.info("✅ Agent API call successful")
            
            return {
                "success": True,
                "method": "agent_api",
                "asset_id": clean_asset_id,
                "response": response,
                "timestamp": datetime.now().isoformat()
            }
            
        except Exception as e:
            logger.error(f"❌ Agent API call failed: {e}")
            return {
                "success": False,
                "method": "agent_api",
                "asset_id": asset_id,
                "error": str(e)
            }
    
    def get_application_details_via_http(self, asset_id: str) -> dict:
        """
        Method 2: Use Direct HTTP with SigV4 (calculator's working approach)
        """
        logger.info("🧪 Method 2: Using Direct HTTP with SigV4...")
        
        if not self.auth:
            return {
                "success": False,
                "method": "http_sigv4",
                "error": "HTTP authentication not available"
            }
        
        try:
            # Clean asset ID
            clean_asset_id = asset_id.strip()
            if not clean_asset_id.startswith('a') and clean_asset_id.isdigit():
                clean_asset_id = f"a{clean_asset_id}"
            
            # MCP request (same format as calculator)
            payload = {
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
            
            logger.info(f"Making HTTP request to: {self.gateway_url}")
            
            response = requests.post(
                self.gateway_url,
                json=payload,
                headers=headers,
                auth=self.auth,  # Same auth as calculator
                timeout=30
            )
            
            logger.info(f"HTTP Status: {response.status_code}")
            
            if response.status_code == 200:
                result = response.json()
                logger.info("✅ HTTP call successful")
                
                return {
                    "success": True,
                    "method": "http_sigv4",
                    "asset_id": clean_asset_id,
                    "response": result,
                    "timestamp": datetime.now().isoformat()
                }
            else:
                logger.error(f"❌ HTTP call failed: {response.status_code} - {response.text}")
                return {
                    "success": False,
                    "method": "http_sigv4",
                    "asset_id": clean_asset_id,
                    "error": f"HTTP {response.status_code}: {response.text}"
                }
                
        except Exception as e:
            logger.error(f"❌ HTTP call exception: {e}")
            return {
                "success": False,
                "method": "http_sigv4",
                "asset_id": asset_id,
                "error": str(e)
            }
    
    def get_tools_list_via_http(self) -> dict:
        """
        Get available tools using HTTP method (for debugging)
        """
        logger.info("📋 Getting tools list via HTTP...")
        
        if not self.auth:
            return {"success": False, "error": "HTTP authentication not available"}
        
        try:
            payload = {
                "jsonrpc": "2.0",
                "method": "tools/list",
                "id": str(uuid.uuid4())
            }
            
            headers = {
                'Content-Type': 'application/json',
                'Accept': 'application/json'
            }
            
            response = requests.post(
                self.gateway_url,
                json=payload,
                headers=headers,
                auth=self.auth,
                timeout=30
            )
            
            if response.status_code == 200:
                result = response.json()
                logger.info("✅ Tools list retrieved successfully")
                return {"success": True, "tools": result}
            else:
                logger.error(f"❌ Tools list failed: {response.status_code} - {response.text}")
                return {"success": False, "error": f"HTTP {response.status_code}: {response.text}"}
                
        except Exception as e:
            logger.error(f"❌ Tools list exception: {e}")
            return {"success": False, "error": str(e)}
    
    def get_application_details(self, asset_id: str) -> dict:
        """
        High-level method that tries both approaches (like calculator had options)
        """
        logger.info(f"🔍 Getting application details for: {asset_id}")
        
        # Try Method 1: Agent Runtime API (calculator's primary method)
        result1 = self.get_application_details_via_agent_api(asset_id)
        if result1["success"]:
            logger.info("✅ Success via Agent Runtime API")
            return result1
        
        logger.warning("⚠️ Agent API failed, trying HTTP method...")
        
        # Try Method 2: Direct HTTP (calculator's alternative method)
        result2 = self.get_application_details_via_http(asset_id)
        if result2["success"]:
            logger.info("✅ Success via HTTP SigV4")
            return result2
        
        logger.error("❌ Both methods failed")
        
        return {
            "success": False,
            "asset_id": asset_id,
            "error": "Both authentication methods failed",
            "attempts": {
                "agent_api": result1,
                "http_sigv4": result2
            }
        }
    
    def run_comprehensive_test(self):
        """
        Run comprehensive tests using calculator's proven patterns
        """
        print("🧪 Application Details - Dual Authentication Test")
        print("=" * 55)
        print(f"Gateway ID: {self.gateway_id}")
        print(f"Gateway URL: {self.gateway_url}")
        print(f"Session: {self.session_id}")
        print("")
        
        # Test 1: Tools list (diagnostic)
        print("📋 Test 1: Get available tools...")
        tools_result = self.get_tools_list_via_http()
        if tools_result["success"]:
            print("✅ Tools list successful")
            if "tools" in tools_result and "result" in tools_result["tools"]:
                tools = tools_result["tools"]["result"].get("tools", [])
                print(f"   Found {len(tools)} tools:")
                for tool in tools:
                    print(f"   • {tool.get('name', 'Unknown')}: {tool.get('description', 'No description')}")
        else:
            print(f"❌ Tools list failed: {tools_result['error']}")
        
        print("")
        
        # Test 2: Application details with multiple asset IDs
        test_cases = ["a12345", "12345", "a208194", "208194"]
        
        print("🔍 Test 2: Application details calls...")
        success_count = 0
        
        for i, asset_id in enumerate(test_cases, 1):
            print(f"\n   Test {i}: Asset ID '{asset_id}'")
            result = self.get_application_details(asset_id)
            
            if result["success"]:
                print(f"   ✅ Success via {result['method']}")
                success_count += 1
                
                # Show response preview
                if "response" in result:
                    response = result["response"]
                    if isinstance(response, dict) and "completion" in response:
                        print(f"   💬 Response: {response['completion']}")
                    elif isinstance(response, dict) and "result" in response:
                        res = response["result"]
                        if isinstance(res, dict) and "content" in res:
                            content = res["content"]
                            if isinstance(content, list) and len(content) > 0:
                                text_content = content[0].get("text", "No text")
                                print(f"   💬 Response: {text_content}")
            else:
                print(f"   ❌ Failed: {result['error']}")
        
        print(f"\n📊 Summary:")
        print(f"   Total tests: {len(test_cases)}")
        print(f"   Successful: {success_count}")
        print(f"   Failed: {len(test_cases) - success_count}")
        
        if success_count > 0:
            print("✅ At least one authentication method is working!")
        else:
            print("❌ All authentication methods failed")

def main():
    if len(sys.argv) > 1:
        command = sys.argv[1]
        
        client = DualAuthApplicationDetailsMCPClient()
        
        if command == "test":
            client.run_comprehensive_test()
        elif command == "tools":
            result = client.get_tools_list_via_http()
            print(json.dumps(result, indent=2))
        else:
            # Treat as asset ID
            result = client.get_application_details(command)
            print(json.dumps(result, indent=2))
    else:
        # Run comprehensive test by default
        client = DualAuthApplicationDetailsMCPClient()
        client.run_comprehensive_test()

if __name__ == "__main__":
    main()