#!/usr/bin/env python3
"""
MCP Client for Application Details Lambda
Interacts with a208194-chatops_application_details_intent via Agent Core Gateway
"""

import json
import uuid
import boto3
import sys
import logging
from datetime import datetime
from typing import Dict, List, Optional, Any

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

class ApplicationDetailsMCPClient:
    """
    MCP Client for Application Details Lambda Function
    
    This client interacts with the a208194-chatops_application_details_intent Lambda
    through the a208194-askjulius-agentcore-gateway-mcp-iam Agent Core Gateway.
    """
    
    def __init__(self, region: str = "us-east-1"):
        """
        Initialize the MCP client
        
        Args:
            region: AWS region where the gateway and Lambda are deployed
        """
        self.region = region
        self.gateway_id = "a208194-askjulius-agentcore-gateway-mcp-iam"
        self.agent_alias_id = "TSTALIASID"  # Test alias ID - may need adjustment
        
        # Initialize AWS client
        try:
            self.bedrock_client = boto3.client('bedrock-agent-runtime', region_name=region)
            logger.info(f"✅ Initialized Bedrock Agent Runtime client for region: {region}")
        except Exception as e:
            logger.error(f"❌ Failed to initialize AWS client: {e}")
            raise
    
    def invoke_tool(self, asset_id: str) -> Dict[str, Any]:
        """
        Invoke the get_application_details tool with an asset ID
        
        Args:
            asset_id: The application asset ID (e.g., 'a12345' or '12345')
            
        Returns:
            Tool invocation response
        """
        try:
            # Prepare MCP tool call request
            tool_request = {
                "jsonrpc": "2.0",
                "method": "tools/call",
                "params": {
                    "name": "get_application_details",
                    "arguments": {
                        "asset_id": asset_id
                    }
                },
                "id": str(uuid.uuid4())
            }
            
            logger.info(f"🔧 Invoking tool for asset ID: {asset_id}")
            logger.debug(f"📤 Request payload: {json.dumps(tool_request, indent=2)}")
            
            # Call Agent Core Gateway
            response = self.bedrock_client.invoke_agent_core_gateway(
                gatewayId=self.gateway_id,
                agentAliasId=self.agent_alias_id,
                sessionId=str(uuid.uuid4()),
                inputText=f"Get application details for asset {asset_id}",
                endSession=False
            )
            
            logger.info("✅ Gateway invocation successful")
            
            # Process response
            if 'completion' in response:
                completion_text = response['completion']
                logger.info(f"📥 Response: {completion_text}")
                return {
                    "success": True,
                    "asset_id": asset_id,
                    "response": completion_text,
                    "timestamp": datetime.now().isoformat()
                }
            else:
                logger.warning("⚠️ No completion text in response")
                return {
                    "success": False,
                    "asset_id": asset_id,
                    "error": "No completion in response",
                    "raw_response": response
                }
                
        except Exception as e:
            logger.error(f"❌ Tool invocation failed: {e}")
            return {
                "success": False,
                "asset_id": asset_id,
                "error": str(e),
                "timestamp": datetime.now().isoformat()
            }
    
    def get_application_details(self, asset_id: str) -> Dict[str, Any]:
        """
        High-level method to get application details
        
        Args:
            asset_id: Application asset ID
            
        Returns:
            Application details response
        """
        # Clean asset ID (ensure proper format)
        clean_asset_id = asset_id.strip()
        if not clean_asset_id.startswith('a') and clean_asset_id.isdigit():
            clean_asset_id = f"a{clean_asset_id}"
        
        logger.info(f"🔍 Getting application details for: {clean_asset_id}")
        
        return self.invoke_tool(clean_asset_id)
    
    def test_connectivity(self) -> bool:
        """
        Test connectivity to the Agent Core Gateway
        
        Returns:
            True if connectivity is successful
        """
        try:
            logger.info("🧪 Testing gateway connectivity...")
            
            # Try to get tools list (if supported)
            list_request = {
                "jsonrpc": "2.0",
                "method": "tools/list",
                "id": str(uuid.uuid4())
            }
            
            response = self.bedrock_client.invoke_agent_core_gateway(
                gatewayId=self.gateway_id,
                agentAliasId=self.agent_alias_id,
                sessionId=str(uuid.uuid4()),
                inputText="List available tools",
                endSession=False
            )
            
            logger.info("✅ Gateway connectivity test successful")
            return True
            
        except Exception as e:
            logger.error(f"❌ Connectivity test failed: {e}")
            return False
    
    def interactive_session(self):
        """
        Start an interactive session for querying application details
        """
        print("🚀 Application Details MCP Client")
        print("=" * 50)
        print("Gateway ID:", self.gateway_id)
        print("Region:", self.region)
        print("\n📋 Commands:")
        print("  - Enter asset ID (e.g., 'a12345' or '12345')")
        print("  - Type 'test' to test connectivity")
        print("  - Type 'quit' to exit")
        print("=" * 50)
        
        while True:
            try:
                user_input = input("\n🔍 Enter asset ID: ").strip()
                
                if user_input.lower() in ['quit', 'exit', 'q']:
                    print("👋 Goodbye!")
                    break
                
                if user_input.lower() == 'test':
                    success = self.test_connectivity()
                    if success:
                        print("✅ Connectivity test passed!")
                    else:
                        print("❌ Connectivity test failed!")
                    continue
                
                if not user_input:
                    print("⚠️ Please enter an asset ID")
                    continue
                
                # Get application details
                result = self.get_application_details(user_input)
                
                print("\n📊 Result:")
                print("-" * 30)
                
                if result['success']:
                    print(f"✅ Asset ID: {result['asset_id']}")
                    print(f"📝 Response: {result['response']}")
                    if 'timestamp' in result:
                        print(f"⏰ Timestamp: {result['timestamp']}")
                else:
                    print(f"❌ Failed for asset ID: {result['asset_id']}")
                    print(f"💬 Error: {result['error']}")
                
                print("-" * 30)
                
            except KeyboardInterrupt:
                print("\n\n👋 Session interrupted. Goodbye!")
                break
            except Exception as e:
                print(f"\n❌ Error: {e}")

def main():
    """
    Main function for running the MCP client
    """
    if len(sys.argv) > 1:
        # Command line mode
        asset_id = sys.argv[1]
        
        client = ApplicationDetailsMCPClient()
        result = client.get_application_details(asset_id)
        
        print(json.dumps(result, indent=2))
    else:
        # Interactive mode
        client = ApplicationDetailsMCPClient()
        client.interactive_session()

if __name__ == "__main__":
    main()