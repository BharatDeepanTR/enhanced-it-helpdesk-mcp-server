#!/usr/bin/env python3
"""
Direct HTTP MCP Client for Application Details Gateway
Uses direct HTTP calls with AWS SigV4 authentication like the calculator client
"""

import json
import uuid
import requests
import boto3
from requests_aws4auth import AWS4Auth
from datetime import datetime
import sys
import logging

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

class ApplicationDetailsHTTPMCPClient:
    """
    Direct HTTP MCP Client for Application Details Gateway
    
    Uses direct HTTP calls to the gateway MCP endpoint with AWS SigV4 authentication
    """
    
    def __init__(self, region: str = "us-east-1"):
        """
        Initialize the HTTP MCP client
        
        Args:
            region: AWS region where the gateway is deployed
        """
        self.region = region
        self.gateway_url = "https://a208194-askjulius-agentcore-mcp-gateway-dhy8ntpcvu.gateway.bedrock-agentcore.us-east-1.amazonaws.com/mcp"
        
        # Get AWS credentials for SigV4 authentication
        session = boto3.Session()
        credentials = session.get_credentials()
        
        if not credentials:
            raise Exception("AWS credentials not found. Please configure AWS credentials.")
        
        # Set up AWS SigV4 authentication
        self.auth = AWS4Auth(
            credentials.access_key,
            credentials.secret_key,
            region,
            'bedrock-agentcore',
            session_token=credentials.token
        )
        
        logger.info(f"✅ Initialized HTTP MCP client for gateway: {self.gateway_url}")
    
    def make_mcp_request(self, method: str, params: dict = None, request_id: str = None) -> dict:
        """
        Make an MCP request to the gateway
        
        Args:
            method: MCP method (e.g., 'tools/list', 'tools/call')
            params: Parameters for the method
            request_id: Request ID (auto-generated if not provided)
            
        Returns:
            MCP response dictionary
        """
        if request_id is None:
            request_id = str(uuid.uuid4())
        
        # Create MCP request payload
        payload = {
            "jsonrpc": "2.0",
            "method": method,
            "id": request_id
        }
        
        if params is not None:
            payload["params"] = params
        
        headers = {
            'Content-Type': 'application/json',
            'Accept': 'application/json'
        }
        
        logger.info(f"🔧 Making MCP request: {method}")
        logger.debug(f"📤 Payload: {json.dumps(payload, indent=2)}")
        
        try:
            response = requests.post(
                self.gateway_url,
                json=payload,
                headers=headers,
                auth=self.auth,
                timeout=30
            )
            
            logger.info(f"📥 Response status: {response.status_code}")
            
            if response.status_code == 200:
                result = response.json()
                logger.debug(f"📥 Response: {json.dumps(result, indent=2)}")
                return result
            else:
                error_detail = response.text
                logger.error(f"❌ Request failed: {response.status_code} - {error_detail}")
                return {
                    "jsonrpc": "2.0",
                    "id": request_id,
                    "error": {
                        "code": response.status_code,
                        "message": f"HTTP {response.status_code}: {error_detail}"
                    }
                }
                
        except Exception as e:
            logger.error(f"❌ Request exception: {e}")
            return {
                "jsonrpc": "2.0",
                "id": request_id,
                "error": {
                    "code": -32000,
                    "message": f"Request failed: {str(e)}"
                }
            }
    
    def list_tools(self) -> dict:
        """
        Get list of available tools from the gateway
        
        Returns:
            Tools list response
        """
        logger.info("📋 Requesting tools list...")
        return self.make_mcp_request("tools/list")
    
    def get_application_details(self, asset_id: str) -> dict:
        """
        Get application details for an asset ID
        
        Args:
            asset_id: Application asset ID
            
        Returns:
            Application details response
        """
        # Clean and format asset ID
        clean_asset_id = asset_id.strip()
        if not clean_asset_id.startswith('a') and clean_asset_id.isdigit():
            clean_asset_id = f"a{clean_asset_id}"
        
        logger.info(f"🔍 Getting application details for: {clean_asset_id}")
        
        params = {
            "name": "get_application_details",
            "arguments": {
                "asset_id": clean_asset_id
            }
        }
        
        return self.make_mcp_request("tools/call", params)
    
    def test_connectivity(self) -> bool:
        """
        Test connectivity to the MCP gateway
        
        Returns:
            True if successful, False otherwise
        """
        logger.info("🧪 Testing gateway connectivity...")
        
        response = self.list_tools()
        
        if "error" in response:
            logger.error(f"❌ Connectivity test failed: {response['error']}")
            return False
        elif "result" in response:
            logger.info("✅ Connectivity test successful!")
            if "tools" in response["result"]:
                tools = response["result"]["tools"]
                logger.info(f"📋 Found {len(tools)} tools available")
                for tool in tools:
                    logger.info(f"   • {tool.get('name', 'Unknown')}: {tool.get('description', 'No description')}")
            return True
        else:
            logger.warning("⚠️ Unexpected response format")
            return False
    
    def run_comprehensive_test(self):
        """
        Run comprehensive tests with multiple asset IDs
        """
        print("🧪 Application Details HTTP MCP Client - Comprehensive Test")
        print("=" * 65)
        print(f"Gateway URL: {self.gateway_url}")
        print(f"Region: {self.region}")
        print("")
        
        # Test connectivity first
        print("🔗 Testing connectivity...")
        if not self.test_connectivity():
            print("❌ Connectivity test failed. Aborting comprehensive test.")
            return
        
        print("")
        
        # Test cases
        test_cases = [
            "a12345",
            "12345", 
            "a208194",
            "208194",
            "a100001",
            "999999"
        ]
        
        print("📋 Running application details tests...")
        print("-" * 40)
        
        success_count = 0
        
        for i, asset_id in enumerate(test_cases, 1):
            print(f"\n🔍 Test {i}: Asset ID '{asset_id}'")
            
            response = self.get_application_details(asset_id)
            
            if "error" in response:
                print(f"   ❌ Error: {response['error']['message']}")
            elif "result" in response:
                print(f"   ✅ Success!")
                result = response["result"]
                if isinstance(result, dict) and "content" in result:
                    content = result["content"]
                    if isinstance(content, list) and len(content) > 0:
                        text_content = content[0].get("text", "No text content")
                        print(f"   📝 Response: {text_content}")
                    else:
                        print(f"   📝 Response: {result}")
                else:
                    print(f"   📝 Response: {result}")
                success_count += 1
            else:
                print(f"   ⚠️ Unexpected response format: {response}")
        
        print("")
        print("📊 Test Summary")
        print("-" * 20)
        print(f"Total tests: {len(test_cases)}")
        print(f"Successful: {success_count}")
        print(f"Failed: {len(test_cases) - success_count}")
        
        if success_count == len(test_cases):
            print("✅ All tests passed!")
        elif success_count > 0:
            print("⚠️ Partial success")
        else:
            print("❌ All tests failed")
    
    def interactive_session(self):
        """
        Start an interactive session for testing
        """
        print("🚀 Application Details HTTP MCP Client - Interactive Mode")
        print("=" * 60)
        print(f"Gateway URL: {self.gateway_url}")
        print("")
        print("📋 Commands:")
        print("  - Enter asset ID (e.g., 'a12345' or '12345')")
        print("  - Type 'tools' to list available tools")
        print("  - Type 'test' to test connectivity")
        print("  - Type 'comprehensive' to run all test cases")
        print("  - Type 'quit' to exit")
        print("=" * 60)
        
        while True:
            try:
                user_input = input("\n🔍 Enter command or asset ID: ").strip()
                
                if user_input.lower() in ['quit', 'exit', 'q']:
                    print("👋 Goodbye!")
                    break
                
                if user_input.lower() == 'test':
                    self.test_connectivity()
                    continue
                
                if user_input.lower() == 'tools':
                    response = self.list_tools()
                    print("\n📋 Tools Response:")
                    print(json.dumps(response, indent=2))
                    continue
                
                if user_input.lower() == 'comprehensive':
                    print("")
                    self.run_comprehensive_test()
                    continue
                
                if not user_input:
                    print("⚠️ Please enter a command or asset ID")
                    continue
                
                # Treat as asset ID
                response = self.get_application_details(user_input)
                
                print("\n📊 Result:")
                print("-" * 30)
                print(json.dumps(response, indent=2))
                print("-" * 30)
                
            except KeyboardInterrupt:
                print("\n\n👋 Session interrupted. Goodbye!")
                break
            except Exception as e:
                print(f"\n❌ Error: {e}")

def main():
    """
    Main function for running the HTTP MCP client
    """
    if len(sys.argv) > 1:
        command = sys.argv[1]
        
        client = ApplicationDetailsHTTPMCPClient()
        
        if command == "tools":
            response = client.list_tools()
            print(json.dumps(response, indent=2))
        elif command == "test":
            client.test_connectivity()
        elif command == "comprehensive":
            client.run_comprehensive_test()
        elif command == "interactive":
            client.interactive_session()
        else:
            # Treat as asset ID
            response = client.get_application_details(command)
            print(json.dumps(response, indent=2))
    else:
        # Interactive mode by default
        client = ApplicationDetailsHTTPMCPClient()
        client.interactive_session()

if __name__ == "__main__":
    main()