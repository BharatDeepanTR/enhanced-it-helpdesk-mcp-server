import boto3
import json
import time
from datetime import datetime
import requests
from botocore.auth import SigV4Auth
from botocore.awsrequest import AWSRequest

class MCPSolutionTester:
    def __init__(self):
        self.session = boto3.Session()
        self.gateway_url = "https://a208194-askjulius-agentcore-gateway-mcp-iam-fvro4phd59.gateway.bedrock-agentcore.us-east-1.amazonaws.com/mcp"
        self.credentials = self.session.get_credentials()
        
    def sign_request(self, method, url, data=None):
        """Sign request with SigV4"""
        request = AWSRequest(method=method, url=url, data=data)
        SigV4Auth(self.credentials, "bedrock-agentcore", "us-east-1").add_auth(request)
        return dict(request.headers)
    
    def test_current_gateway_tools(self):
        """Test current gateway configuration"""
        print("Testing current gateway tools...")
        
        try:
            payload = {
                "jsonrpc": "2.0",
                "id": 1,
                "method": "tools/list"
            }
            
            headers = self.sign_request('POST', self.gateway_url, json.dumps(payload))
            headers['Content-Type'] = 'application/json'
            
            response = requests.post(self.gateway_url, json=payload, headers=headers)
            
            print(f"Status: {response.status_code}")
            result = response.json()
            
            if "result" in result and "tools" in result["result"]:
                tools = result["result"]["tools"]
                print(f"Found {len(tools)} tools:")
                for i, tool in enumerate(tools, 1):
                    print(f"  {i}. {tool['name']} - {tool['description']}")
                return tools
            else:
                print("No tools found or error in response")
                print(json.dumps(result, indent=2))
                return []
                
        except Exception as e:
            print(f"Error testing gateway: {e}")
            return []
    
    def test_application_details_tool(self, asset_id="a123456"):
        """Test the current application details tool"""
        print(f"\nTesting application details tool with asset_id: {asset_id}")
        
        try:
            payload = {
                "jsonrpc": "2.0",
                "id": 2,
                "method": "tools/call",
                "params": {
                    "name": "target-direct-application-details-lambda___get_application_details",
                    "arguments": {
                        "asset_id": asset_id
                    }
                }
            }
            
            headers = self.sign_request('POST', self.gateway_url, json.dumps(payload))
            headers['Content-Type'] = 'application/json'
            
            response = requests.post(self.gateway_url, json=payload, headers=headers)
            
            print(f"Status: {response.status_code}")
            result = response.json()
            
            if "result" in result:
                content = result["result"]
                print("Response content:")
                print(json.dumps(content, indent=2))
                
                # Check if there's an error
                if content.get("isError") or "error" in content:
                    print("❌ Tool returned error")
                    return False
                else:
                    print("✅ Tool executed successfully")
                    return True
            else:
                print("❌ No result in response")
                print(json.dumps(result, indent=2))
                return False
                
        except Exception as e:
            print(f"❌ Error testing application details: {e}")
            return False
    
    def test_calculator_tool(self, operation="add", a=5, b=3):
        """Test calculator tool"""
        print(f"\nTesting calculator tool: {operation}({a}, {b})")
        
        try:
            payload = {
                "jsonrpc": "2.0",
                "id": 3,
                "method": "tools/call",
                "params": {
                    "name": f"target-direct-calculator-lambda___{operation}",
                    "arguments": {
                        "a": a,
                        "b": b
                    }
                }
            }
            
            headers = self.sign_request('POST', self.gateway_url, json.dumps(payload))
            headers['Content-Type'] = 'application/json'
            
            response = requests.post(self.gateway_url, json=payload, headers=headers)
            
            print(f"Status: {response.status_code}")
            result = response.json()
            
            if "result" in result:
                content = result["result"]
                print("Response content:")
                print(json.dumps(content, indent=2))
                
                # Check if there's an error
                if content.get("isError") or "error" in content:
                    print("❌ Calculator tool returned error")
                    return False
                else:
                    print("✅ Calculator tool executed successfully")
                    return True
            else:
                print("❌ No result in response")
                print(json.dumps(result, indent=2))
                return False
                
        except Exception as e:
            print(f"❌ Error testing calculator: {e}")
            return False
    
    def run_comprehensive_test(self):
        """Run comprehensive test suite"""
        print("=" * 60)
        print("MCP SOLUTION TESTER")
        print("=" * 60)
        print(f"Gateway URL: {self.gateway_url}")
        print(f"Test Time: {datetime.now()}")
        print("=" * 60)
        
        # Test 1: List available tools
        tools = self.test_current_gateway_tools()
        
        # Test 2: Test application details (expected to fail with current setup)
        app_success = self.test_application_details_tool()
        
        # Test 3: Test calculator (expected to fail with current setup)
        calc_success = self.test_calculator_tool()
        
        print("\n" + "=" * 60)
        print("SUMMARY")
        print("=" * 60)
        print(f"Tools discovered: {len(tools)}")
        print(f"Application details working: {'✅' if app_success else '❌'}")
        print(f"Calculator working: {'✅' if calc_success else '❌'}")
        
        if not app_success and not calc_success:
            print("\n🔧 DIAGNOSIS:")
            print("Both tools are returning errors, confirming the Lambda response format issue.")
            print("The MCP-compatible solutions should resolve this problem.")
        
        return {
            "tools_count": len(tools),
            "application_details_working": app_success,
            "calculator_working": calc_success
        }

if __name__ == "__main__":
    tester = MCPSolutionTester()
    results = tester.run_comprehensive_test()
    
    print("\n" + "=" * 60)
    print("NEXT STEPS")
    print("=" * 60)
    print("1. Deploy the MCP-compatible Lambda functions")
    print("2. Update gateway configuration to use new targets")
    print("3. Re-test with updated configuration")
    print("4. Validate natural language capabilities work correctly")