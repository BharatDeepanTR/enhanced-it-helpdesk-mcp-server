#!/usr/bin/env python3
"""
Test TR URLs and Documentation Links
Verify that the MCP server returns actual Thomson Reuters portal URLs
"""

import json
import boto3

def test_tr_urls():
    """Test that TR tools return actual URLs and documentation"""
    print("🧪 Testing Thomson Reuters URLs and Documentation")
    print("=" * 60)
    
    lambda_client = boto3.client('lambda', region_name='us-east-1')
    function_name = "a208194-it-helpdesk-enhanced-mcp-server"
    
    # Test cases with expected TR URLs
    test_cases = [
        {
            "tool": "reset_password",
            "query": "How do I reset my password?",
            "expected_urls": ["https://myaccount.thomsonreuters.com", "+1-800-328-4880"]
        },
        {
            "tool": "cloud_tool_access", 
            "query": "How do I get cloud tool access?",
            "expected_urls": ["https://tr.service-now.com", "+1-800-328-4880"]
        },
        {
            "tool": "aws_access",
            "query": "How do I get AWS access?", 
            "expected_urls": ["https://tr.service-now.com", "+1-800-328-4880"]
        }
    ]
    
    for i, test_case in enumerate(test_cases, 1):
        print(f"Test {i}: {test_case['tool']}")
        print("-" * 40)
        
        payload = {
            "method": "tools/call",
            "params": {
                "name": test_case["tool"],
                "arguments": {
                    "query": test_case["query"],
                    "session_id": f"test-session-{i}"
                }
            },
            "jsonrpc": "2.0",
            "id": f"test-{i}"
        }
        
        try:
            response = lambda_client.invoke(
                FunctionName=function_name,
                InvocationType='RequestResponse',
                Payload=json.dumps(payload)
            )
            
            result = json.loads(response['Payload'].read())
            
            if "result" in result and "content" in result["result"]:
                content = result["result"]["content"][0]["text"]
                print("✅ Response received:")
                print(content)
                print()
                
                # Check for expected URLs
                found_urls = []
                for expected_url in test_case["expected_urls"]:
                    if expected_url in content:
                        found_urls.append(expected_url)
                
                if found_urls:
                    print(f"✅ Found expected TR URLs: {', '.join(found_urls)}")
                else:
                    print(f"❌ Missing expected TR URLs: {', '.join(test_case['expected_urls'])}")
                
            else:
                print(f"❌ Invalid response format: {result}")
                
        except Exception as e:
            print(f"❌ Test failed: {str(e)}")
        
        print("\n" + "="*60 + "\n")

if __name__ == "__main__":
    test_tr_urls()