#!/usr/bin/env python3
"""
Corrected Application Details MCP Client
Fixes the two critical issues discovered:
1. Agent ID validation error - gateway name != agent ID
2. Bearer token authentication issue - use proper gateway endpoints
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

class CorrectedApplicationDetailsMCPClient:
    """
    Corrected Application Details MCP Client that addresses:
    1. Invalid agent ID format (gateway name vs agent ID)
    2. Bearer token authentication issues
    """
    
    def __init__(self, region: str = "us-east-1"):
        self.region = region
        
        # CORRECTED: Use proper gateway configuration
        self.gateway_name = "a208194-askjulius-agentcore-mcp-gateway"
        self.gateway_url = "https://a208194-askjulius-agentcore-mcp-gateway-dhy8ntpcvu.gateway.bedrock-agentcore.us-east-1.amazonaws.com"
        
        # Different endpoints for different operations
        self.mcp_endpoint = f"{self.gateway_url}/mcp"
        self.invoke_endpoint = f"{self.gateway_url}/invoke"  # Alternative endpoint
        
        # Initialize Bedrock clients
        try:
            # Standard Bedrock client
            self.bedrock_client = boto3.client('bedrock', region_name=region)
            # Agent Core client (if available)
            self.bedrock_agent_client = boto3.client('bedrock-agent', region_name=region)
            logger.info(f"✅ Bedrock clients initialized")
        except Exception as e:
            logger.error(f"❌ Failed to initialize Bedrock clients: {e}")
            self.bedrock_client = None
            self.bedrock_agent_client = None
        
        # Initialize multiple authentication methods
        self.auth_methods = {}
        try:
            session = boto3.Session()
            credentials = session.get_credentials()
            
            if credentials:
                # Method 1: bedrock-agentcore service (original)
                self.auth_methods['bedrock-agentcore'] = AWS4Auth(
                    credentials.access_key,
                    credentials.secret_key,
                    region,
                    'bedrock-agentcore',
                    session_token=credentials.token
                )
                
                # Method 2: bedrock service
                self.auth_methods['bedrock'] = AWS4Auth(
                    credentials.access_key,
                    credentials.secret_key,
                    region,
                    'bedrock',
                    session_token=credentials.token
                )
                
                # Method 3: execute-api service (for API Gateway)
                self.auth_methods['execute-api'] = AWS4Auth(
                    credentials.access_key,
                    credentials.secret_key,
                    region,
                    'execute-api',
                    session_token=credentials.token
                )
                
                logger.info(f"✅ {len(self.auth_methods)} authentication methods initialized")
            else:
                logger.error("❌ No AWS credentials found")
        except Exception as e:
            logger.error(f"❌ Failed to initialize authentication: {e}")
        
        # Session management
        self.session_id = f"app-details-{datetime.now().strftime('%Y%m%d-%H%M%S')}"
        logger.info(f"Session created: {self.session_id}")
    
    def get_application_details_via_gateway_invoke(self, asset_id: str) -> dict:
        """
        Method 1: Use gateway invoke endpoint (not agent API)
        """
        logger.info("🧪 Method 1: Using Gateway Invoke API...")
        
        try:
            # Clean asset ID
            clean_asset_id = asset_id.strip()
            if not clean_asset_id.startswith('a') and clean_asset_id.isdigit():
                clean_asset_id = f"a{clean_asset_id}"
            
            # Try different authentication methods
            for auth_name, auth in self.auth_methods.items():
                logger.info(f"   Trying {auth_name} authentication...")
                
                try:
                    # Construct invoke request
                    invoke_payload = {
                        "targetName": "a208194-application-details-tool-target",
                        "toolName": "get_application_details",
                        "parameters": {
                            "asset_id": clean_asset_id
                        }
                    }
                    
                    headers = {
                        'Content-Type': 'application/json',
                        'Accept': 'application/json'
                    }
                    
                    response = requests.post(
                        self.invoke_endpoint,
                        json=invoke_payload,
                        headers=headers,
                        auth=auth,
                        timeout=30
                    )
                    
                    logger.info(f"   HTTP Status: {response.status_code}")
                    
                    if response.status_code == 200:
                        result = response.json()
                        logger.info(f"   ✅ Success with {auth_name} authentication")
                        
                        return {
                            "success": True,
                            "method": "gateway_invoke",
                            "auth_method": auth_name,
                            "asset_id": clean_asset_id,
                            "response": result,
                            "timestamp": datetime.now().isoformat()
                        }
                    elif response.status_code == 404:
                        logger.warning(f"   ⚠️ Invoke endpoint not found with {auth_name}")
                        break  # Don't try other auth methods if endpoint doesn't exist
                    else:
                        logger.warning(f"   ⚠️ {auth_name} failed: {response.status_code} - {response.text[:200]}")
                        
                except Exception as e:
                    logger.warning(f"   ⚠️ {auth_name} exception: {e}")
                    continue
            
            return {
                "success": False,
                "method": "gateway_invoke",
                "asset_id": clean_asset_id,
                "error": "All authentication methods failed for invoke endpoint"
            }
                
        except Exception as e:
            logger.error(f"❌ Gateway invoke call exception: {e}")
            return {
                "success": False,
                "method": "gateway_invoke",
                "asset_id": asset_id,
                "error": str(e)
            }
    
    def get_application_details_via_mcp_with_bearer(self, asset_id: str) -> dict:
        """
        Method 2: Try MCP endpoint with Bearer token (since gateway expects it)
        """
        logger.info("🧪 Method 2: Using MCP with Bearer token...")
        
        try:
            # Get AWS credentials and create bearer token
            session = boto3.Session()
            credentials = session.get_credentials()
            
            if not credentials:
                return {
                    "success": False,
                    "method": "mcp_bearer",
                    "error": "No AWS credentials available"
                }
            
            # Create bearer token from AWS credentials (different approaches)
            bearer_tokens = [
                credentials.token,  # Session token
                f"{credentials.access_key}:{credentials.secret_key}",  # Access key:Secret
                credentials.access_key,  # Just access key
            ]
            
            # Clean asset ID
            clean_asset_id = asset_id.strip()
            if not clean_asset_id.startswith('a') and clean_asset_id.isdigit():
                clean_asset_id = f"a{clean_asset_id}"
            
            # MCP request payload
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
            
            # Try different bearer token formats
            for i, token in enumerate(bearer_tokens):
                if not token:
                    continue
                    
                logger.info(f"   Trying bearer token format {i+1}...")
                
                headers = {
                    'Content-Type': 'application/json',
                    'Accept': 'application/json',
                    'Authorization': f'Bearer {token}'
                }
                
                try:
                    response = requests.post(
                        self.mcp_endpoint,
                        json=payload,
                        headers=headers,
                        timeout=30
                    )
                    
                    logger.info(f"   HTTP Status: {response.status_code}")
                    
                    if response.status_code == 200:
                        result = response.json()
                        logger.info(f"   ✅ Success with bearer token format {i+1}")
                        
                        return {
                            "success": True,
                            "method": "mcp_bearer",
                            "bearer_format": f"format_{i+1}",
                            "asset_id": clean_asset_id,
                            "response": result,
                            "timestamp": datetime.now().isoformat()
                        }
                    else:
                        logger.warning(f"   ⚠️ Bearer format {i+1} failed: {response.status_code}")
                        
                except Exception as e:
                    logger.warning(f"   ⚠️ Bearer format {i+1} exception: {e}")
                    continue
            
            return {
                "success": False,
                "method": "mcp_bearer",
                "asset_id": clean_asset_id,
                "error": "All bearer token formats failed"
            }
                
        except Exception as e:
            logger.error(f"❌ MCP bearer call exception: {e}")
            return {
                "success": False,
                "method": "mcp_bearer",
                "asset_id": asset_id,
                "error": str(e)
            }
    
    def get_application_details_via_mcp_sigv4(self, asset_id: str) -> dict:
        """
        Method 3: Try MCP endpoint with corrected SigV4 (different service names)
        """
        logger.info("🧪 Method 3: Using MCP with corrected SigV4...")
        
        try:
            # Clean asset ID
            clean_asset_id = asset_id.strip()
            if not clean_asset_id.startswith('a') and clean_asset_id.isdigit():
                clean_asset_id = f"a{clean_asset_id}"
            
            # MCP request payload
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
            
            # Try different SigV4 service names
            for auth_name, auth in self.auth_methods.items():
                logger.info(f"   Trying SigV4 with {auth_name} service...")
                
                headers = {
                    'Content-Type': 'application/json',
                    'Accept': 'application/json'
                }
                
                try:
                    response = requests.post(
                        self.mcp_endpoint,
                        json=payload,
                        headers=headers,
                        auth=auth,
                        timeout=30
                    )
                    
                    logger.info(f"   HTTP Status: {response.status_code}")
                    
                    if response.status_code == 200:
                        result = response.json()
                        logger.info(f"   ✅ Success with {auth_name} service")
                        
                        return {
                            "success": True,
                            "method": "mcp_sigv4",
                            "service_name": auth_name,
                            "asset_id": clean_asset_id,
                            "response": result,
                            "timestamp": datetime.now().isoformat()
                        }
                    else:
                        logger.warning(f"   ⚠️ {auth_name} failed: {response.status_code}")
                        
                except Exception as e:
                    logger.warning(f"   ⚠️ {auth_name} exception: {e}")
                    continue
            
            return {
                "success": False,
                "method": "mcp_sigv4",
                "asset_id": clean_asset_id,
                "error": "All SigV4 service names failed"
            }
                
        except Exception as e:
            logger.error(f"❌ MCP SigV4 call exception: {e}")
            return {
                "success": False,
                "method": "mcp_sigv4",
                "asset_id": asset_id,
                "error": str(e)
            }
    
    def get_gateway_info(self) -> dict:
        """
        Try to get gateway information to understand its configuration
        """
        logger.info("📋 Getting gateway information...")
        
        # Try to get gateway details using Bedrock client
        if self.bedrock_agent_client:
            try:
                # Try different API calls to understand the gateway
                response = self.bedrock_agent_client.list_agent_core_gateways()
                logger.info("✅ Successfully listed gateways")
                return {"success": True, "method": "list_gateways", "response": response}
            except Exception as e:
                logger.warning(f"⚠️ List gateways failed: {e}")
        
        # Try HTTP health check
        try:
            response = requests.get(self.gateway_url, timeout=10)
            logger.info(f"Gateway health check: {response.status_code}")
            return {"success": True, "method": "health_check", "status": response.status_code}
        except Exception as e:
            logger.warning(f"⚠️ Health check failed: {e}")
        
        return {"success": False, "error": "Could not get gateway information"}
    
    def get_application_details(self, asset_id: str) -> dict:
        """
        High-level method that tries all corrected approaches
        """
        logger.info(f"🔍 Getting application details for: {asset_id}")
        
        # Try Method 1: Gateway invoke endpoint
        result1 = self.get_application_details_via_gateway_invoke(asset_id)
        if result1["success"]:
            logger.info("✅ Success via Gateway Invoke API")
            return result1
        
        logger.warning("⚠️ Gateway invoke failed, trying MCP with Bearer...")
        
        # Try Method 2: MCP with Bearer token
        result2 = self.get_application_details_via_mcp_with_bearer(asset_id)
        if result2["success"]:
            logger.info("✅ Success via MCP Bearer")
            return result2
        
        logger.warning("⚠️ MCP Bearer failed, trying corrected SigV4...")
        
        # Try Method 3: MCP with corrected SigV4
        result3 = self.get_application_details_via_mcp_sigv4(asset_id)
        if result3["success"]:
            logger.info("✅ Success via corrected SigV4")
            return result3
        
        logger.error("❌ All methods failed")
        
        return {
            "success": False,
            "asset_id": asset_id,
            "error": "All authentication methods failed",
            "attempts": {
                "gateway_invoke": result1,
                "mcp_bearer": result2,
                "mcp_sigv4": result3
            }
        }
    
    def run_comprehensive_test(self):
        """
        Run comprehensive tests with corrected approaches
        """
        print("🧪 Application Details - Corrected Authentication Test")
        print("=" * 60)
        print(f"Gateway Name: {self.gateway_name}")
        print(f"Gateway URL: {self.gateway_url}")
        print(f"MCP Endpoint: {self.mcp_endpoint}")
        print(f"Invoke Endpoint: {self.invoke_endpoint}")
        print(f"Session: {self.session_id}")
        print("")
        
        # Test 0: Gateway info
        print("📋 Test 0: Gateway information...")
        gateway_info = self.get_gateway_info()
        if gateway_info["success"]:
            print(f"✅ Gateway info: {gateway_info['method']}")
        else:
            print(f"❌ Gateway info failed: {gateway_info['error']}")
        
        print("")
        
        # Test with multiple asset IDs
        test_cases = ["a12345", "a208194"]
        
        print("🔍 Application details tests...")
        success_count = 0
        
        for i, asset_id in enumerate(test_cases, 1):
            print(f"\n   Test {i}: Asset ID '{asset_id}'")
            result = self.get_application_details(asset_id)
            
            if result["success"]:
                print(f"   ✅ Success via {result['method']}")
                if 'auth_method' in result:
                    print(f"      Auth: {result['auth_method']}")
                if 'service_name' in result:
                    print(f"      Service: {result['service_name']}")
                if 'bearer_format' in result:
                    print(f"      Bearer: {result['bearer_format']}")
                success_count += 1
                
                # Show response preview
                if "response" in result:
                    response = result["response"]
                    if isinstance(response, dict):
                        print(f"   💬 Response keys: {list(response.keys())}")
            else:
                print(f"   ❌ All methods failed")
        
        print(f"\n📊 Summary:")
        print(f"   Total tests: {len(test_cases)}")
        print(f"   Successful: {success_count}")
        print(f"   Failed: {len(test_cases) - success_count}")
        
        if success_count > 0:
            print("✅ Found working authentication method!")
        else:
            print("❌ All authentication methods failed - gateway configuration issue")

def main():
    if len(sys.argv) > 1:
        command = sys.argv[1]
        
        client = CorrectedApplicationDetailsMCPClient()
        
        if command == "test":
            client.run_comprehensive_test()
        elif command == "info":
            result = client.get_gateway_info()
            print(json.dumps(result, indent=2, default=str))
        else:
            # Treat as asset ID
            result = client.get_application_details(command)
            print(json.dumps(result, indent=2, default=str))
    else:
        # Run comprehensive test by default
        client = CorrectedApplicationDetailsMCPClient()
        client.run_comprehensive_test()

if __name__ == "__main__":
    main()