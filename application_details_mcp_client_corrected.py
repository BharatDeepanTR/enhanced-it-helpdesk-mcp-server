#!/usr/bin/env python3
"""
Application Details MCP Client - Corrected Version
Interacts with Agent Core Gateway to get application details via MCP protocol
Includes all fixes: authentication, logger initialization, and region attribute
"""

import sys
import json
import logging
import argparse
from typing import Dict, Any, Optional
import requests
import boto3
from requests_aws4auth import AWS4Auth
from botocore.exceptions import ClientError, NoCredentialsError


class ApplicationDetailsMCPClient:
    """MCP client for application details with corrected initialization order"""
    
    def __init__(self):
        """Initialize the MCP client with correct gateway and authentication"""
        self.gateway_url = "https://a208194-askjulius-agentcore-gateway-mcp-iam-fvro4phd59.execute-api.us-east-1.amazonaws.com/v1"
        self.target_tool_name = "target-chatops-application-details___get_application_details"
        self.session = requests.Session()
        self.session.verify = True
        self.region = 'us-east-1'  # Initialize region first
        
        # Setup logging first
        logging.basicConfig(
            level=logging.INFO,
            format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
        )
        self.logger = logging.getLogger(__name__)
        
        # Initialize authentication
        self._init_authentication()
    
    def _init_authentication(self):
        """Initialize AWS SigV4 authentication for bedrock-agentcore service"""
        try:
            # Get AWS credentials
            session = boto3.Session(region_name=self.region)
            credentials = session.get_credentials()
            
            if not credentials:
                raise NoCredentialsError()
            
            # Create AWS4Auth with bedrock-agentcore service (this is the key!)
            self.auth = AWS4Auth(
                credentials.access_key,
                credentials.secret_key,
                self.region,
                'bedrock-agentcore',  # Correct service name for Agent Core Gateway
                session_token=credentials.token
            )
            
            self.logger.info("✅ Authentication initialized with bedrock-agentcore")
            
        except Exception as e:
            self.logger.error(f"❌ Authentication initialization failed: {e}")
            self.auth = None
    
    def _make_mcp_request(self, method: str, params: Optional[Dict] = None) -> Dict[str, Any]:
        """Make an MCP JSON-RPC 2.0 request to the Agent Core Gateway"""
        if not self.auth:
            return {"error": "Authentication not available"}
        
        payload = {
            "jsonrpc": "2.0",
            "id": 1,
            "method": method,
            "params": params or {}
        }
        
        try:
            headers = {
                'Content-Type': 'application/json',
                'Accept': 'application/json'
            }
            
            self.logger.info(f"🌐 Making MCP request to: {self.gateway_url}")
            self.logger.info(f"📋 Method: {method}")
            if params:
                self.logger.info(f"📋 Params: {json.dumps(params, indent=2)}")
            
            response = self.session.post(
                self.gateway_url,
                json=payload,
                headers=headers,
                auth=self.auth,
                timeout=30
            )
            
            self.logger.info(f"   HTTP Status: {response.status_code}")
            
            if response.status_code == 200:
                result = response.json()
                self.logger.info("✅ MCP request successful!")
                return result
            else:
                error_msg = f"HTTP {response.status_code}: {response.text}"
                self.logger.error(f"❌ MCP request failed: {error_msg}")
                return {"error": error_msg}
                
        except Exception as e:
            error_msg = f"Request exception: {str(e)}"
            self.logger.error(f"❌ MCP request exception: {error_msg}")
            return {"error": error_msg}
    
    def list_tools(self) -> Dict[str, Any]:
        """List all available tools in the MCP server"""
        self.logger.info("📋 Listing available tools...")
        return self._make_mcp_request("tools/list")
    
    def get_application_details(self, asset_id: str) -> Dict[str, Any]:
        """Get application details for a specific asset ID using corrected tool name"""
        self.logger.info(f"🎯 Getting application details for asset: {asset_id}")
        self.logger.info(f"   Tool name: {self.target_tool_name}")
        
        # Prepare the tool call parameters
        params = {
            "name": self.target_tool_name,
            "arguments": {
                "asset_id": asset_id
            }
        }
        
        return self._make_mcp_request("tools/call", params)
    
    def test_connectivity(self) -> Dict[str, Any]:
        """Test connectivity to the MCP server"""
        self.logger.info("🧪 Testing MCP server connectivity...")
        
        # First try to list tools
        tools_result = self.list_tools()
        
        if "error" not in tools_result:
            self.logger.info("✅ Connectivity test successful!")
            return {
                "success": True,
                "tools_available": len(tools_result.get("result", {}).get("tools", [])),
                "tools": tools_result
            }
        else:
            self.logger.error("❌ Connectivity test failed")
            return {
                "success": False,
                "error": tools_result["error"]
            }
    
    def batch_get_details(self, asset_ids: list) -> Dict[str, Any]:
        """Get application details for multiple asset IDs"""
        self.logger.info(f"📦 Getting details for {len(asset_ids)} assets...")
        
        results = {}
        for asset_id in asset_ids:
            self.logger.info(f"   Processing asset: {asset_id}")
            result = self.get_application_details(asset_id)
            results[asset_id] = result
        
        return {
            "success": True,
            "count": len(results),
            "results": results
        }


def main():
    """Main function with command-line interface"""
    parser = argparse.ArgumentParser(description='Application Details MCP Client - Corrected Version')
    parser.add_argument('command', choices=['test', 'get', 'batch', 'tools'], 
                       help='Command to execute')
    parser.add_argument('assets', nargs='*', help='Asset IDs to process')
    
    args = parser.parse_args()
    
    # Initialize client
    try:
        client = ApplicationDetailsMCPClient()
    except Exception as e:
        print(f"❌ Failed to initialize client: {e}")
        sys.exit(1)
    
    # Execute command
    if args.command == 'test':
        print("🧪 Testing MCP connectivity...")
        result = client.test_connectivity()
        print(json.dumps(result, indent=2))
        
    elif args.command == 'tools':
        print("📋 Listing available tools...")
        result = client.list_tools()
        print(json.dumps(result, indent=2))
        
    elif args.command == 'get':
        if not args.assets:
            print("❌ Please provide at least one asset ID")
            sys.exit(1)
        
        asset_id = args.assets[0]
        print(f"🔍 Getting details for asset: {asset_id}")
        result = client.get_application_details(asset_id)
        print(json.dumps(result, indent=2))
        
    elif args.command == 'batch':
        if not args.assets:
            print("❌ Please provide at least one asset ID")
            sys.exit(1)
        
        print(f"📦 Processing {len(args.assets)} assets...")
        result = client.batch_get_details(args.assets)
        print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()