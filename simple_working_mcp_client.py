#!/usr/bin/env python3
"""
Simple Working MCP Gateway Test Client
Uses EXACT working pattern from enterprise script that was working
No extra features - just the working authentication
"""

import json
import requests
import boto3
from requests_aws4auth import AWS4Auth

class SimpleWorkingMCPClient:
    def __init__(self, gateway_url, target_name, region='us-east-1'):
        """
        Initialize with EXACT working authentication pattern
        """
        self.gateway_url = gateway_url
        self.target_name = target_name
        self.region = region
        
        # EXACT working pattern from enterprise script
        session = boto3.Session()
        credentials = session.get_credentials()
        
        if not credentials:
            raise Exception("AWS credentials not found")
        
        # WORKING pattern: AWS4Auth with bedrock-agentcore service
        self.auth = AWS4Auth(
            credentials.access_key,
            credentials.secret_key,
            region,
            'bedrock-agentcore',  # EXACT service name that works
            session_token=credentials.token
        )
        
        print(f"🚀 Simple Working MCP Client Initialized")
        print(f"   Gateway: {gateway_url}")
        print(f"   Target: {target_name}")
        print(f"   Auth: AWS4Auth with bedrock-agentcore")
    
    def send_mcp_request(self, method, params=None):
        """Send MCP request with EXACT working pattern"""
        request_id = f"simple-req-{int(__import__('time').time())}"
        
        mcp_request = {
            "jsonrpc": "2.0",
            "id": request_id,
            "method": method
        }
        
        if params:
            mcp_request["params"] = params
        
        headers = {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'X-MCP-Target': self.target_name
        }
        
        body = json.dumps(mcp_request)
        
        print(f"\n📤 {method} -> {self.target_name}")
        
        try:
            # EXACT working pattern: requests.post with auth=self.auth
            response = requests.post(
                self.gateway_url,
                headers=headers,
                data=body,
                auth=self.auth,
                timeout=30
            )
            
            print(f"📥 Status: {response.status_code}")
            
            if response.status_code == 200:
                result = response.json()
                print(f"✅ Success!")
                print(f"Response: {json.dumps(result, indent=2)}")
                return result
            else:
                print(f"❌ Error: {response.status_code}")
                print(f"Response: {response.text}")
                return None
                
        except Exception as e:
            print(f"❌ Request failed: {e}")
            return None
    
    def test_initialize(self):
        """Test initialize"""
        params = {
            "protocolVersion": "2024-11-05",
            "capabilities": {"tools": {}},
            "clientInfo": {"name": "Simple Working Client", "version": "1.0.0"}
        }
        return self.send_mcp_request("initialize", params)
    
    def test_tools_list(self):
        """Test tools/list"""
        return self.send_mcp_request("tools/list")
    
    def test_ai_calculate(self, query):
        """Test ai_calculate tool"""
        params = {
            "name": "ai_calculate",
            "arguments": {"query": query}
        }
        return self.send_mcp_request("tools/call", params)

def main():
    """Run simple test"""
    print("🎯 Simple Working MCP Gateway Test")
    print("="*50)
    
    # Same configuration as working scripts
    GATEWAY_URL = "https://a208194-askjulius-agentcore-gateway-mcp-iam-fvro4phd59.gateway.bedrock-agentcore.us-east-1.amazonaws.com/mcp"
    TARGET_NAME = "target-lambda-direct-ai-calculator-mcp"
    
    try:
        client = SimpleWorkingMCPClient(GATEWAY_URL, TARGET_NAME)
        
        print("\n1. Testing Initialize...")
        client.test_initialize()
        
        print("\n2. Testing Tools List...")
        client.test_tools_list()
        
        print("\n3. Testing AI Calculate...")
        client.test_ai_calculate("What is 25 + 17?")
        
    except Exception as e:
        print(f"❌ Error: {e}")

if __name__ == "__main__":
    main()