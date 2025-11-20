#!/usr/bin/env python3
"""
Fixed MCP Gateway Test Client
Uses the WORKING authentication patterns from enterprise scripts
Key fixes:
1. AWS4Auth instead of SigV4Auth
2. 'bedrock-agentcore' service name instead of 'bedrock'
3. requests-aws4auth library instead of botocore.auth
"""

import json
import requests
import boto3
import time
from requests_aws4auth import AWS4Auth  # WORKING: Use AWS4Auth instead of SigV4Auth
from urllib.parse import urlparse

class FixedMCPGatewayClient:
    def __init__(self, gateway_url, target_name, region='us-east-1'):
        """
        Initialize MCP Gateway Client with WORKING authentication patterns
        
        Args:
            gateway_url: Full gateway URL
            target_name: MCP target name 
            region: AWS region
        """
        self.gateway_url = gateway_url
        self.target_name = target_name
        self.region = region
        
        # Initialize AWS credentials
        session = boto3.Session()
        credentials = session.get_credentials()
        
        if not credentials:
            raise Exception("AWS credentials not found. Please configure AWS credentials.")
        
        # WORKING PATTERN: Use AWS4Auth with 'bedrock-agentcore' service
        self.auth = AWS4Auth(
            credentials.access_key,
            credentials.secret_key,
            region,
            'bedrock-agentcore',  # WORKING: Use 'bedrock-agentcore' instead of 'bedrock'
            session_token=credentials.token
        )
        
        print(f"🚀 Fixed MCP Gateway Client Initialized")
        print(f"   Gateway: {gateway_url}")
        print(f"   Target: {target_name}")
        print(f"   Region: {region}")
        print(f"   Auth: AWS4Auth with 'bedrock-agentcore' service")
    
    def send_mcp_request(self, method, params=None, request_id=None):
        """
        Send MCP JSON-RPC request to gateway with WORKING authentication
        
        Args:
            method: MCP method (e.g., 'initialize', 'tools/list', 'tools/call')
            params: Method parameters
            request_id: Request ID (auto-generated if not provided)
        
        Returns:
            Response JSON
        """
        if request_id is None:
            request_id = f"req-{int(time.time())}"
        
        # Build MCP JSON-RPC request
        mcp_request = {
            "jsonrpc": "2.0",
            "id": request_id,
            "method": method
        }
        
        if params:
            mcp_request["params"] = params
        
        # Prepare HTTP request
        headers = {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'X-MCP-Target': self.target_name
        }
        
        body = json.dumps(mcp_request)
        
        print(f"\n📤 Sending MCP Request:")
        print(f"   Method: {method}")
        print(f"   Target: {self.target_name}")
        print(f"   Request ID: {request_id}")
        if params:
            print(f"   Params: {json.dumps(params, indent=2)}")
        
        try:
            # WORKING: Use requests with AWS4Auth directly
            response = requests.post(
                self.gateway_url,
                headers=headers,
                data=body,
                auth=self.auth,  # WORKING: Direct AWS4Auth usage
                timeout=30
            )
            
            print(f"\n📥 Response Status: {response.status_code}")
            
            if response.status_code == 200:
                response_json = response.json()
                print(f"✅ Success: {json.dumps(response_json, indent=2)}")
                return response_json
            else:
                print(f"❌ Error: {response.status_code} - {response.text}")
                return None
                
        except Exception as e:
            print(f"❌ Request failed: {str(e)}")
            return None
    
    def test_initialize(self):
        """Test MCP initialize method"""
        print("\n🔧 Testing MCP Initialize...")
        
        params = {
            "protocolVersion": "2024-11-05",
            "capabilities": {
                "tools": {}
            },
            "clientInfo": {
                "name": "Fixed MCP Test Client",
                "version": "1.0.0"
            }
        }
        
        return self.send_mcp_request("initialize", params)
    
    def test_tools_list(self):
        """Test MCP tools/list method"""
        print("\n📋 Testing Tools List...")
        return self.send_mcp_request("tools/list")
    
    def test_ai_calculate(self, query):
        """Test AI Calculate tool"""
        print(f"\n🧮 Testing AI Calculate: '{query}'...")
        
        params = {
            "name": "ai_calculate",
            "arguments": {
                "query": query
            }
        }
        
        return self.send_mcp_request("tools/call", params)
    
    def test_explain_calculation(self, calculation):
        """Test Explain Calculation tool"""
        print(f"\n📚 Testing Explain Calculation: '{calculation}'...")
        
        params = {
            "name": "explain_calculation", 
            "arguments": {
                "calculation": calculation
            }
        }
        
        return self.send_mcp_request("tools/call", params)
    
    def test_solve_word_problem(self, problem):
        """Test Solve Word Problem tool"""
        print(f"\n📝 Testing Solve Word Problem: '{problem}'...")
        
        params = {
            "name": "solve_word_problem",
            "arguments": {
                "problem": problem
            }
        }
        
        return self.send_mcp_request("tools/call", params)

def main():
    """Main test function"""
    print("🎯 Fixed MCP Gateway Test Client")
    print("==================================================")
    
    # Configuration - Same as before but with WORKING authentication
    GATEWAY_URL = "https://a208194-askjulius-agentcore-gateway-mcp-iam-fvro4phd59.gateway.bedrock-agentcore.us-east-1.amazonaws.com/mcp"
    TARGET_NAME = "target-lambda-direct-ai-calculator-mcp"
    REGION = "us-east-1"
    
    try:
        # Initialize client with WORKING patterns
        client = FixedMCPGatewayClient(GATEWAY_URL, TARGET_NAME, REGION)
        
        # Test results tracking
        results = []
        
        # Test 1: Initialize
        result = client.test_initialize()
        results.append(("Initialize", result is not None))
        
        # Test 2: Tools List
        result = client.test_tools_list()
        results.append(("Tools List", result is not None))
        
        # Test 3: AI Calculate (Simple)
        result = client.test_ai_calculate("What is 25 + 17?")
        results.append(("AI Calculate (Simple)", result is not None))
        
        # Test 4: AI Calculate (Complex)
        result = client.test_ai_calculate("What is 15% of $50,000?")
        results.append(("AI Calculate (Complex)", result is not None))
        
        # Test 5: Explain Calculation
        result = client.test_explain_calculation("quadratic formula")
        results.append(("Explain Calculation", result is not None))
        
        # Test 6: Solve Word Problem
        result = client.test_solve_word_problem("If a train travels 60 mph for 2.5 hours, how far does it go?")
        results.append(("Solve Word Problem", result is not None))
        
        # Summary
        print("\n==================================================")
        print("📊 TEST RESULTS SUMMARY")
        print("==================================================")
        
        passed = sum(1 for _, success in results if success)
        total = len(results)
        
        for test_name, success in results:
            status = "✅ PASS" if success else "❌ FAIL"
            print(f"   {test_name:<25} {status}")
        
        print(f"\n🎯 Overall: {passed}/{total} tests passed ({(passed/total)*100:.1f}%)")
        
        if passed == total:
            print("🎉 All tests passed! Fixed authentication works!")
        elif passed > 0:
            print("⚠️ Some tests failed. Check the details above.")
        else:
            print("❌ All tests failed. Check authentication and configuration.")
    
    except Exception as e:
        print(f"\n❌ Error: {e}")
        print("\n🔧 Troubleshooting:")
        print("1. Install requests-aws4auth: pip install requests-aws4auth")
        print("2. Ensure you're in AWS CloudShell or have AWS credentials configured")
        print("3. Check AWS credentials: aws sts get-caller-identity")

if __name__ == "__main__":
    main()