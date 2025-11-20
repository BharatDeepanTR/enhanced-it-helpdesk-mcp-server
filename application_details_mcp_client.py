#!/usr/bin/env python3
"""
Production MCP Client for Application Details
Incorporates all fixes and learnings:
1. Correct IAM-configured gateway
2. Proper SigV4 authentication with bedrock-agentcore
3. Correct prefixed tool name: target-chatops-application-details___get_application_details
4. Robust error handling and fallback mechanisms
"""

import json
import uuid
import boto3
import requests
from requests_aws4auth import AWS4Auth
from datetime import datetime
import sys
import logging

class ApplicationDetailsMCPClient:
    """
    Production-ready MCP client for Application Details
    """
    
    def __init__(self):
        """Initialize the MCP client with correct gateway and authentication"""
        self.gateway_url = "https://a208194-askjulius-agentcore-gateway-mcp-iam-fvro4phd59.execute-api.us-east-1.amazonaws.com/v1"
        self.target_tool_name = "target-chatops-application-details___get_application_details"
        self.session = requests.Session()
        self.session.verify = True
        
        # Setup logging first
        logging.basicConfig(
            level=logging.INFO,
            format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
        )
        self.logger = logging.getLogger(__name__)
        
        # Initialize authentication
        self._init_authentication()
    
    def _init_authentication(self):
        """Initialize AWS authentication using the working method"""
        try:
            session = boto3.Session()
            credentials = session.get_credentials()
            
            if credentials:
                # Use the WORKING authentication method: SigV4 with bedrock-agentcore
                self.auth = AWS4Auth(
                    credentials.access_key,
                    credentials.secret_key,
                    self.region,
                    'bedrock-agentcore',  # WORKING service name
                    session_token=credentials.token
                )
                self.logger.info("✅ Authentication initialized with bedrock-agentcore")
                return True
            else:
                self.logger.error("❌ No AWS credentials found")
                self.auth = None
                return False
                
        except Exception as e:
            self.logger.error(f"❌ Authentication initialization failed: {e}")
            self.auth = None
            return False
    
    def verify_connectivity(self):
        """Verify gateway connectivity and authentication"""
        self.logger.info("🔍 Verifying gateway connectivity...")
        
        if not self.auth:
            return {"success": False, "error": "No authentication available"}
        
        try:
            # Test with MCP tools/list (lightweight test)
            mcp_request = {
                "jsonrpc": "2.0",
                "method": "tools/list",
                "id": str(uuid.uuid4())
            }
            
            headers = {
                'Content-Type': 'application/json',
                'Accept': 'application/json'
            }
            
            response = requests.post(
                self.mcp_endpoint,
                json=mcp_request,
                headers=headers,
                auth=self.auth,
                timeout=15
            )
            
            if response.status_code == 200:
                result = response.json()
                if "result" in result and "tools" in result["result"]:
                    tools = result["result"]["tools"]
                    
                    # Check if our target tool is available
                    target_tool_found = False
                    for tool in tools:
                        if tool.get("name") == self.tool_name:
                            target_tool_found = True
                            break
                    
                    self.logger.info(f"✅ Gateway connectivity verified")
                    self.logger.info(f"   Found {len(tools)} tools")
                    
                    if target_tool_found:
                        self.logger.info(f"✅ Target tool '{self.tool_name}' found")
                    else:
                        self.logger.warning(f"⚠️ Target tool '{self.tool_name}' not found")
                    
                    return {
                        "success": True,
                        "tools_count": len(tools),
                        "target_tool_found": target_tool_found,
                        "tools": [t.get("name") for t in tools]
                    }
                else:
                    self.logger.error("❌ Unexpected response format")
                    return {"success": False, "error": "Unexpected response format"}
            else:
                self.logger.error(f"❌ Connectivity test failed: {response.status_code}")
                return {
                    "success": False,
                    "error": f"HTTP {response.status_code}: {response.text}"
                }
                
        except Exception as e:
            self.logger.error(f"❌ Connectivity test exception: {e}")
            return {"success": False, "error": str(e)}
    
    def get_application_details(self, asset_id: str):
        """
        Get application details for the given asset ID
        
        Args:
            asset_id (str): Application asset ID (with or without 'a' prefix)
            
        Returns:
            dict: Response containing application details or error information
        """
        self.logger.info(f"🔍 Getting application details for asset: {asset_id}")
        
        if not self.auth:
            return {"success": False, "error": "Authentication not available"}
        
        try:
            # Clean and prepare asset ID
            clean_asset_id = asset_id.strip()
            if not clean_asset_id.startswith('a') and clean_asset_id.isdigit():
                clean_asset_id = f"a{clean_asset_id}"
            
            # Create MCP request with CORRECT tool name
            mcp_request = {
                "jsonrpc": "2.0",
                "method": "tools/call",
                "params": {
                    "name": self.tool_name,  # Use the full prefixed tool name
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
            
            self.logger.info(f"   Making MCP call with tool: {self.tool_name}")
            
            response = requests.post(
                self.mcp_endpoint,
                json=mcp_request,
                headers=headers,
                auth=self.auth,
                timeout=30
            )
            
            self.logger.info(f"   HTTP Status: {response.status_code}")
            
            if response.status_code == 200:
                result = response.json()
                
                # Check for MCP-level errors
                if "error" in result:
                    error_msg = result["error"].get("message", "Unknown MCP error")
                    self.logger.error(f"❌ MCP error: {error_msg}")
                    return {
                        "success": False,
                        "error": f"MCP Error: {error_msg}",
                        "mcp_error": result["error"]
                    }
                
                # Success case
                if "result" in result:
                    self.logger.info("✅ Application details retrieved successfully")
                    
                    return {
                        "success": True,
                        "asset_id": clean_asset_id,
                        "tool_name": self.tool_name,
                        "response": result["result"],
                        "timestamp": datetime.now().isoformat(),
                        "session_id": self.session_id
                    }
                else:
                    self.logger.warning("⚠️ Unexpected response format - no result field")
                    return {
                        "success": False,
                        "error": "Unexpected response format",
                        "raw_response": result
                    }
                    
            else:
                error_text = response.text[:200] if response.text else "No error details"
                self.logger.error(f"❌ HTTP error: {response.status_code} - {error_text}")
                return {
                    "success": False,
                    "error": f"HTTP {response.status_code}: {error_text}",
                    "status_code": response.status_code
                }
                
        except Exception as e:
            self.logger.error(f"❌ Exception during application details call: {e}")
            return {
                "success": False,
                "error": f"Exception: {str(e)}",
                "asset_id": asset_id
            }
    
    def test_multiple_assets(self, asset_ids: list):
        """Test application details for multiple assets"""
        self.logger.info(f"🧪 Testing multiple assets: {asset_ids}")
        
        results = {}
        success_count = 0
        
        for asset_id in asset_ids:
            result = self.get_application_details(asset_id)
            results[asset_id] = result
            
            if result["success"]:
                success_count += 1
                self.logger.info(f"✅ {asset_id}: SUCCESS")
            else:
                self.logger.error(f"❌ {asset_id}: {result['error']}")
        
        return {
            "total_tested": len(asset_ids),
            "successful": success_count,
            "failed": len(asset_ids) - success_count,
            "results": results
        }
    
    def get_configuration_info(self):
        """Get current configuration information"""
        return {
            "gateway_name": self.gateway_name,
            "gateway_id": self.gateway_id,
            "gateway_url": self.gateway_url,
            "mcp_endpoint": self.mcp_endpoint,
            "target_name": self.target_name,
            "tool_name": self.tool_name,
            "lambda_arn": self.lambda_arn,
            "region": self.region,
            "session_id": self.session_id,
            "authentication": "SigV4 with bedrock-agentcore service"
        }

# CLI Interface
def main():
    """Command line interface for the MCP client"""
    
    if len(sys.argv) < 2:
        print("🚀 Production MCP Client for Application Details")
        print("=" * 50)
        print("Usage:")
        print("  python3 application_details_mcp_client.py <command> [args]")
        print("")
        print("Commands:")
        print("  test                 - Run connectivity test")
        print("  get <asset_id>       - Get application details for asset")
        print("  batch <id1,id2,...>  - Test multiple assets")
        print("  config               - Show configuration")
        print("")
        print("Examples:")
        print("  python3 application_details_mcp_client.py test")
        print("  python3 application_details_mcp_client.py get a12345")
        print("  python3 application_details_mcp_client.py batch a12345,a208194,208194")
        sys.exit(1)
    
    command = sys.argv[1].lower()
    client = ApplicationDetailsMCPClient()
    
    if command == "test":
        print("🧪 Running connectivity test...")
        result = client.verify_connectivity()
        print(json.dumps(result, indent=2))
        sys.exit(0 if result["success"] else 1)
        
    elif command == "get":
        if len(sys.argv) < 3:
            print("❌ Error: Please provide an asset ID")
            print("Usage: python3 application_details_mcp_client.py get <asset_id>")
            sys.exit(1)
            
        asset_id = sys.argv[2]
        result = client.get_application_details(asset_id)
        print(json.dumps(result, indent=2))
        sys.exit(0 if result["success"] else 1)
        
    elif command == "batch":
        if len(sys.argv) < 3:
            print("❌ Error: Please provide asset IDs")
            print("Usage: python3 application_details_mcp_client.py batch <id1,id2,id3>")
            sys.exit(1)
            
        asset_ids = [aid.strip() for aid in sys.argv[2].split(",")]
        results = client.test_multiple_assets(asset_ids)
        print(json.dumps(results, indent=2))
        sys.exit(0 if results["successful"] > 0 else 1)
        
    elif command == "config":
        config = client.get_configuration_info()
        print(json.dumps(config, indent=2))
        
    else:
        print(f"❌ Unknown command: {command}")
        print("Use 'test', 'get', 'batch', or 'config'")
        sys.exit(1)

if __name__ == "__main__":
    main()