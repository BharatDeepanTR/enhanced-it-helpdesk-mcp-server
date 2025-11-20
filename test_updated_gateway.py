import boto3
import json
import requests
from botocore.auth import SigV4Auth
from botocore.awsrequest import AWSRequest

class UpdatedGatewayTester:
    def __init__(self):
        self.session = boto3.Session()
        self.gateway_url = "https://a208194-askjulius-agentcore-gateway-mcp-iam-fvro4phd59.gateway.bedrock-agentcore.us-east-1.amazonaws.com/mcp"
        self.credentials = self.session.get_credentials()
        
    def sign_request(self, method, url, data=None):
        """Sign request with SigV4"""
        request = AWSRequest(method=method, url=url, data=data)
        SigV4Auth(self.credentials, "bedrock-agentcore", "us-east-1").add_auth(request)
        return dict(request.headers)
    
    def test_application_details_mcp(self, asset_id="a208194"):
        """Test the NEW MCP-compatible application details target"""
        print(f"🧪 Testing NEW MCP Application Details Target")
        print(f"Asset ID: {asset_id}")
        print("-" * 50)
        
        try:
            payload = {
                "jsonrpc": "2.0",
                "id": 1,
                "method": "tools/call",
                "params": {
                    "name": "target-lambda-direct-application-details-mcp___get_application_details",
                    "arguments": {
                        "asset_id": asset_id
                    }
                }
            }
            
            headers = self.sign_request('POST', self.gateway_url, json.dumps(payload))
            headers['Content-Type'] = 'application/json'
            
            response = requests.post(self.gateway_url, json=payload, headers=headers)
            
            print(f"Status Code: {response.status_code}")
            result = response.json()
            
            if "result" in result:
                content = result["result"]
                
                if "content" in content and isinstance(content["content"], list):
                    for item in content["content"]:
                        if item.get("type") == "text":
                            print("✅ SUCCESS - MCP Format Response:")
                            print(f"Text: {item['text']}")
                            return True
                else:
                    print("❌ FAILED - No content in response")
                    print(json.dumps(content, indent=2))
                    return False
            else:
                print("❌ FAILED - No result in response")
                print(json.dumps(result, indent=2))
                return False
                
        except Exception as e:
            print(f"❌ ERROR: {e}")
            return False
    
    def test_calculator_mcp(self, a=15, b=3):
        """Test the calculator target"""
        print(f"\n🧮 Testing Calculator Target")
        print(f"Operation: {a} + {b}")
        print("-" * 50)
        
        try:
            payload = {
                "jsonrpc": "2.0",
                "id": 2,
                "method": "tools/call",
                "params": {
                    "name": "target-lambda-direct-calculator-mcp___add",
                    "arguments": {
                        "a": a,
                        "b": b
                    }
                }
            }
            
            headers = self.sign_request('POST', self.gateway_url, json.dumps(payload))
            headers['Content-Type'] = 'application/json'
            
            response = requests.post(self.gateway_url, json=payload, headers=headers)
            
            print(f"Status Code: {response.status_code}")
            result = response.json()
            
            if "result" in result:
                content = result["result"]
                
                if "content" in content and isinstance(content["content"], list):
                    for item in content["content"]:
                        if item.get("type") == "text":
                            print("✅ SUCCESS - Calculator Response:")
                            print(f"Result: {item['text']}")
                            return True
                else:
                    print("❌ FAILED - No content in calculator response")
                    print(json.dumps(content, indent=2))
                    return False
            else:
                print("❌ FAILED - No result in calculator response")
                print(json.dumps(result, indent=2))
                return False
                
        except Exception as e:
            print(f"❌ ERROR: {e}")
            return False
    
    def test_tools_list(self):
        """Test tools/list to see available tools"""
        print(f"\n📋 Testing Tools List")
        print("-" * 50)
        
        try:
            payload = {
                "jsonrpc": "2.0",
                "id": 3,
                "method": "tools/list"
            }
            
            headers = self.sign_request('POST', self.gateway_url, json.dumps(payload))
            headers['Content-Type'] = 'application/json'
            
            response = requests.post(self.gateway_url, json=payload, headers=headers)
            
            print(f"Status Code: {response.status_code}")
            result = response.json()
            
            if "result" in result and "tools" in result["result"]:
                tools = result["result"]["tools"]
                print(f"✅ Found {len(tools)} tools:")
                
                app_details_found = False
                calc_tools_found = 0
                
                for i, tool in enumerate(tools, 1):
                    tool_name = tool['name']
                    print(f"  {i}. {tool_name}")
                    
                    if "application-details-mcp" in tool_name:
                        app_details_found = True
                    if "calculator-mcp" in tool_name:
                        calc_tools_found += 1
                
                print(f"\n📊 Analysis:")
                print(f"  Application Details Tools: {'✅ Found' if app_details_found else '❌ Missing'}")
                print(f"  Calculator Tools: {calc_tools_found} found")
                
                return tools
            else:
                print("❌ No tools found")
                print(json.dumps(result, indent=2))
                return []
                
        except Exception as e:
            print(f"❌ ERROR: {e}")
            return []
    
    def run_comprehensive_test(self):
        """Run all tests"""
        print("=" * 60)
        print("UPDATED GATEWAY COMPREHENSIVE TEST")
        print("=" * 60)
        print(f"Gateway: {self.gateway_url}")
        print("=" * 60)
        
        # Test 1: List all tools
        tools = self.test_tools_list()
        
        # Test 2: Test new application details
        app_success = self.test_application_details_mcp()
        
        # Test 3: Test calculator
        calc_success = self.test_calculator_mcp()
        
        print("\n" + "=" * 60)
        print("FINAL RESULTS")
        print("=" * 60)
        print(f"📋 Tools discovered: {len(tools)}")
        print(f"🔍 Application Details: {'✅ Working' if app_success else '❌ Failed'}")
        print(f"🧮 Calculator: {'✅ Working' if calc_success else '❌ Failed'}")
        
        if app_success and calc_success:
            print("\n🎉 SUCCESS: Both MCP-compatible targets are working!")
            print("Your gateway configuration is ready for production use.")
        elif app_success:
            print("\n✅ Application Details is working with MCP format!")
            print("⚠️  Calculator may need the MCP-compatible version too.")
        else:
            print("\n⚠️  Some issues detected. Check the gateway configuration.")
        
        return {
            "tools_count": len(tools),
            "application_details_working": app_success,
            "calculator_working": calc_success
        }

if __name__ == "__main__":
    tester = UpdatedGatewayTester()
    results = tester.run_comprehensive_test()
    
    print("\n" + "=" * 60)
    print("RECOMMENDATIONS")
    print("=" * 60)
    
    if results["application_details_working"]:
        print("✅ Your MCP-compatible Lambda is working perfectly!")
        print("✅ The 'internal error' issue has been resolved!")
    else:
        print("⚠️  Add the application details target to your gateway")
    
    if not results["calculator_working"]:
        print("⚠️  Consider creating MCP-compatible version of calculator too")
    
    print("\nNext: Test natural language queries with your working MCP setup!")