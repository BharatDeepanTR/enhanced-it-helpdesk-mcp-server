#!/usr/bin/env python3
"""
Quick test to discover what the calculator Lambda actually supports
"""

import json
import boto3

def test_calculator_lambda():
    """Test the calculator Lambda directly to see its interface"""
    
    print("🔍 Testing a208194-calculator-mcp-server Lambda...")
    
    # Test with different payloads to discover the interface
    test_payloads = [
        {"jsonrpc": "2.0", "id": 1, "method": "tools/list"},
        {"method": "tools/list"},
        {"action": "list_tools"},
        {"operation": "add", "a": 5, "b": 3},
        {"expression": "2 + 2"},
    ]
    
    lambda_client = boto3.client('lambda', region_name='us-east-1')
    
    for i, payload in enumerate(test_payloads):
        try:
            print(f"\n📤 Test {i+1}: {json.dumps(payload)}")
            
            response = lambda_client.invoke(
                FunctionName="a208194-calculator-mcp-server",
                Payload=json.dumps(payload)
            )
            
            result = json.loads(response['Payload'].read())
            print(f"✅ Response: {json.dumps(result, indent=2)}")
            
            # If this payload works, we found the right interface
            if response['StatusCode'] == 200 and 'errorMessage' not in str(result):
                print(f"🎯 Payload {i+1} seems to work!")
                
        except Exception as e:
            print(f"❌ Test {i+1} failed: {e}")
            
if __name__ == "__main__":
    test_calculator_lambda()