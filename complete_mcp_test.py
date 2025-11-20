#!/usr/bin/env python3
"""
Complete MCP Gateway Test - Test all the AI calculator functions
"""

import json
import requests
import boto3
from requests_aws4auth import AWS4Auth

class CompleteMCPTest:
    def __init__(self):
        self.gateway_url = "https://a208194-askjulius-agentcore-gateway-mcp-iam-fvro4phd59.gateway.bedrock-agentcore.us-east-1.amazonaws.com/mcp"
        self.target_name = "target-lambda-direct-ai-calculator-mcp"
        
        # Working authentication pattern
        session = boto3.Session()
        credentials = session.get_credentials()
        
        self.auth = AWS4Auth(
            credentials.access_key,
            credentials.secret_key,
            'us-east-1',
            'bedrock-agentcore',
            session_token=credentials.token
        )
        
        print(f"🚀 Complete MCP Test Initialized")
    
    def call_tool(self, tool_name, arguments):
        """Call a specific tool with arguments"""
        request_id = f"test-{int(__import__('time').time())}"
        
        mcp_request = {
            "jsonrpc": "2.0",
            "id": request_id,
            "method": "tools/call",
            "params": {
                "name": tool_name,
                "arguments": arguments
            }
        }
        
        headers = {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'X-MCP-Target': self.target_name
        }
        
        body = json.dumps(mcp_request)
        
        try:
            response = requests.post(
                self.gateway_url,
                headers=headers,
                data=body,
                auth=self.auth,
                timeout=30
            )
            
            if response.status_code == 200:
                return response.json()
            else:
                print(f"❌ Error: {response.status_code} - {response.text}")
                return None
                
        except Exception as e:
            print(f"❌ Request failed: {e}")
            return None

def main():
    print("🎯 Complete AI Calculator MCP Test")
    print("="*60)
    
    client = CompleteMCPTest()
    
    # Test cases for AI Calculator
    tests = [
        {
            "name": "🧮 Simple Addition",
            "tool": "target-lambda-direct-ai-calculator-mcp___ai_calculate",
            "args": {"query": "What is 25 + 17?"}
        },
        {
            "name": "💰 Percentage Calculation", 
            "tool": "target-lambda-direct-ai-calculator-mcp___ai_calculate",
            "args": {"query": "What is 15% of $50,000?"}
        },
        {
            "name": "📐 Complex Math",
            "tool": "target-lambda-direct-ai-calculator-mcp___ai_calculate", 
            "args": {"query": "Calculate the area of a circle with radius 10"}
        },
        {
            "name": "📚 Explanation",
            "tool": "target-lambda-direct-ai-calculator-mcp___explain_calculation",
            "args": {"calculation": "25 + 17 × 3"}
        },
        {
            "name": "📝 Word Problem",
            "tool": "target-lambda-direct-ai-calculator-mcp___solve_word_problem",
            "args": {"problem": "If a train travels 60 mph for 2.5 hours, how far does it go?"}
        },
        {
            "name": "🏢 Application Details",
            "tool": "target-lambda-direct-application-details-mcp___get_application_details",
            "args": {"asset_id": "a208194"}
        },
        {
            "name": "➕ Basic Calculator",
            "tool": "target-lambda-direct-calculator-mcp___add",
            "args": {"a": 123, "b": 456}
        }
    ]
    
    results = []
    
    for i, test in enumerate(tests, 1):
        print(f"\n{i}. {test['name']}")
        print("-" * 40)
        
        result = client.call_tool(test['tool'], test['args'])
        
        if result:
            if 'result' in result:
                # Check for internal error messages
                is_error = False
                error_message = ""
                
                if 'content' in result['result']:
                    for content in result['result']['content']:
                        if content['type'] == 'text':
                            text_content = content['text']
                            # Check for various error patterns
                            if any(error_phrase in text_content.lower() for error_phrase in [
                                'internal error', 'error occurred', 'please retry later', 
                                'unknown tool', 'tool not found', 'invalid request'
                            ]):
                                is_error = True
                                error_message = text_content
                                break
                
                if is_error:
                    print("❌ Failed!")
                    print(f"📋 Error: {error_message}")
                    results.append(False)
                else:
                    print("✅ Success!")
                    # Pretty print the result
                    if 'content' in result['result']:
                        for content in result['result']['content']:
                            if content['type'] == 'text':
                                print(f"📋 Result: {content['text']}")
                    else:
                        print(f"📋 Result: {json.dumps(result['result'], indent=2)}")
                    results.append(True)
            elif 'error' in result:
                print("❌ Failed!")
                print(f"📋 MCP Error: {result['error']}")
                results.append(False)
            else:
                print("❌ Failed!")
                print(f"📋 Unexpected response: {result}")
                results.append(False)
        else:
            print("❌ No response!")
            results.append(False)
    
    # Summary
    print("\n" + "="*60)
    print("📊 TEST SUMMARY")
    print("="*60)
    
    passed = sum(results)
    total = len(results)
    
    for i, (test, result) in enumerate(zip(tests, results), 1):
        status = "✅ PASS" if result else "❌ FAIL"
        print(f"{i}. {test['name']:<25} {status}")
    
    print(f"\n🎯 Overall: {passed}/{total} tests passed ({(passed/total)*100:.1f}%)")
    
    if passed == total:
        print("🎉 ALL TESTS PASSED! The MCP Gateway is fully operational!")
    elif passed > 0:
        print("⚠️ Some tests passed. The gateway is working but some functions have issues.")
        print("💡 Check individual test results above for specific error details.")
    else:
        print("❌ All tests failed. Check the gateway configuration.")
        print("🔍 Common issues:")
        print("   • Tools not registered in gateway (check target configuration)")
        print("   • Lambda function errors (check CloudWatch logs)")
        print("   • IAM permission issues")
        print("   • Target not properly configured or in wrong state")

if __name__ == "__main__":
    main()