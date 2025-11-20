#!/usr/bin/env python3
"""
MCP Gateway Test Client
Tests the AI Calculator MCP target through the Bedrock Agent Core Gateway
"""

import json
import requests
import boto3
from botocore.auth import SigV4Auth
from botocore.awsrequest import AWSRequest
from urllib.parse import urlparse
import time

class MCPGatewayClient:
    def __init__(self, gateway_url, target_name, region='us-east-1'):
        """
        Initialize MCP Gateway Client
        
        Args:
            gateway_url: Full gateway URL
            target_name: MCP target name 
            region: AWS region
        """
        self.gateway_url = gateway_url
        self.target_name = target_name
        self.region = region
        self.session = boto3.Session()
        self.credentials = self.session.get_credentials()
        
        print(f"🚀 MCP Gateway Client Initialized")
        print(f"   Gateway: {gateway_url}")
        print(f"   Target: {target_name}")
        print(f"   Region: {region}")
    
    def _sign_request(self, method, url, headers, body=None):
        """Sign request with AWS SigV4"""
        parsed_url = urlparse(url)
        
        # Create AWS request
        request = AWSRequest(
            method=method,
            url=url,
            data=body,
            headers=headers
        )
        
        # Sign with SigV4
        SigV4Auth(self.credentials, 'bedrock', self.region).add_auth(request)
        
        return dict(request.headers)
    
    def send_mcp_request(self, method, params=None, request_id=None):
        """
        Send MCP JSON-RPC request to gateway
        
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
        
        # Sign request
        signed_headers = self._sign_request('POST', self.gateway_url, headers, body)
        
        print(f"\n📤 Sending MCP Request:")
        print(f"   Method: {method}")
        print(f"   Target: {self.target_name}")
        print(f"   Request ID: {request_id}")
        if params:
            print(f"   Params: {json.dumps(params, indent=2)}")
        
        try:
            # Send request
            response = requests.post(
                self.gateway_url,
                headers=signed_headers,
                data=body,
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
        """Test MCP initialization"""
        print("\n🔧 Testing MCP Initialize...")
        return self.send_mcp_request("initialize")
    
    def test_tools_list(self):
        """Test tools listing"""
        print("\n📋 Testing Tools List...")
        return self.send_mcp_request("tools/list")
    
    def test_ai_calculate(self, query):
        """Test ai_calculate tool"""
        print(f"\n🧮 Testing AI Calculate: '{query}'...")
        params = {
            "name": "ai_calculate",
            "arguments": {
                "query": query
            }
        }
        return self.send_mcp_request("tools/call", params)
    
    def test_explain_calculation(self, calculation):
        """Test explain_calculation tool"""
        print(f"\n📚 Testing Explain Calculation: '{calculation}'...")
        params = {
            "name": "explain_calculation", 
            "arguments": {
                "calculation": calculation
            }
        }
        return self.send_mcp_request("tools/call", params)
    
    def test_solve_word_problem(self, problem):
        """Test solve_word_problem tool"""
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
    print("🎯 MCP Gateway Test Client")
    print("=" * 50)
    
    # Configuration
    GATEWAY_URL = "https://a208194-askjulius-agentcore-gateway-mcp-iam-fvro4phd59.gateway.bedrock-agentcore.us-east-1.amazonaws.com/mcp"
    TARGET_NAME = "target-lambda-direct-ai-calculator-mcp"
    
    # Create client
    client = MCPGatewayClient(GATEWAY_URL, TARGET_NAME)
    
    # Test suite
    test_results = []
    
    # 1. Test Initialize
    result = client.test_initialize()
    test_results.append(("Initialize", result is not None))
    
    # 2. Test Tools List
    result = client.test_tools_list()
    test_results.append(("Tools List", result is not None))
    
    # 3. Test AI Calculate - Simple
    result = client.test_ai_calculate("What is 25 + 17?")
    test_results.append(("AI Calculate (Simple)", result is not None))
    
    # 4. Test AI Calculate - Complex
    result = client.test_ai_calculate("What is 15% of $50,000?")
    test_results.append(("AI Calculate (Percentage)", result is not None))
    
    # 5. Test Explain Calculation
    result = client.test_explain_calculation("quadratic formula")
    test_results.append(("Explain Calculation", result is not None))
    
    # 6. Test Solve Word Problem
    result = client.test_solve_word_problem("If a train travels 60 mph for 2.5 hours, how far does it go?")
    test_results.append(("Solve Word Problem", result is not None))
    
    # Summary
    print("\n" + "=" * 50)
    print("📊 TEST RESULTS SUMMARY")
    print("=" * 50)
    
    passed = 0
    for test_name, success in test_results:
        status = "✅ PASS" if success else "❌ FAIL"
        print(f"   {test_name:25} {status}")
        if success:
            passed += 1
    
    total = len(test_results)
    print(f"\n🎯 Overall: {passed}/{total} tests passed ({passed/total*100:.1f}%)")
    
    if passed == total:
        print("🎉 ALL TESTS PASSED! AI Calculator MCP is fully functional!")
    else:
        print("⚠️  Some tests failed. Check the details above.")


if __name__ == "__main__":
    main()