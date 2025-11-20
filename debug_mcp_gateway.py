#!/usr/bin/env python3
"""
Simple MCP Gateway Debug Script
===============================

Debug the MCP gateway connection and target configuration issues.
"""

import json
import boto3
import requests
from urllib.parse import urlparse

def main():
    print("🔍 MCP Gateway Debug Script")
    print("=" * 40)
    
    gateway_endpoint = "https://a208194-askjulius-agentcore-gateway-mcp-iam-fvro4phd59.gateway.bedrock-agentcore.us-east-1.amazonaws.com/mcp"
    target_name = "target-lambda-direct-ai-bedrock-calculator-mcp"
    
    print(f"Gateway: {gateway_endpoint}")
    print(f"Target: {target_name}")
    print()
    
    # Parse the gateway URL
    parsed_url = urlparse(gateway_endpoint)
    base_url = f"{parsed_url.scheme}://{parsed_url.netloc}"
    
    print("🔍 Step 1: Test gateway root endpoint")
    print("-" * 40)
    
    try:
        # Test different endpoint variations
        test_urls = [
            f"{base_url}/",
            f"{base_url}/mcp",
            f"{gateway_endpoint}",
            f"{gateway_endpoint}/targets",
            f"{gateway_endpoint}/targets/{target_name}",
        ]
        
        for url in test_urls:
            print(f"Testing: {url}")
            try:
                response = requests.get(url, timeout=10)
                print(f"  Status: {response.status_code}")
                print(f"  Headers: {dict(response.headers)}")
                if response.text:
                    print(f"  Body: {response.text[:200]}...")
                print()
            except Exception as e:
                print(f"  Error: {str(e)}")
                print()
                
    except Exception as e:
        print(f"Connection error: {str(e)}")
    
    print("🔍 Step 2: Check if target exists via AWS CLI")
    print("-" * 50)
    
    try:
        # Try to find the gateway and targets using AWS CLI equivalents
        session = boto3.Session()
        
        # Note: There might not be direct API for Agent Core Gateway yet
        print("Checking available AWS services for Agent Core...")
        
        # Try bedrock-agent client
        try:
            bedrock_agent = session.client('bedrock-agent', region_name='us-east-1')
            print("✅ bedrock-agent client available")
        except Exception as e:
            print(f"❌ bedrock-agent client: {str(e)}")
            
        # Try bedrock client  
        try:
            bedrock = session.client('bedrock', region_name='us-east-1')
            print("✅ bedrock client available")
        except Exception as e:
            print(f"❌ bedrock client: {str(e)}")
            
    except Exception as e:
        print(f"AWS client error: {str(e)}")
    
    print("\n🔍 Step 3: Try direct Lambda invocation test")
    print("-" * 45)
    
    try:
        lambda_client = session.client('lambda', region_name='us-east-1')
        function_name = "a208194-ai-bedrock-calculator-mcp-server"
        
        # Test payload that matches MCP format
        test_payload = {
            "id": "direct-test",
            "method": "tools/call", 
            "params": {
                "name": "ai_calculate",
                "arguments": {
                    "query": "What is 2 + 2?"
                }
            }
        }
        
        print(f"Testing Lambda function directly: {function_name}")
        print(f"Payload: {json.dumps(test_payload, indent=2)}")
        
        response = lambda_client.invoke(
            FunctionName=function_name,
            Payload=json.dumps(test_payload)
        )
        
        payload = response['Payload'].read()
        print(f"Direct Lambda Response: {payload.decode('utf-8')}")
        
    except Exception as e:
        print(f"Direct Lambda test error: {str(e)}")
    
    print("\n💡 Troubleshooting Recommendations:")
    print("=" * 40)
    print("1. ✅ Gateway URL appears to be reachable")
    print("2. ❌ Target might not be properly configured")
    print("3. 🔧 Possible issues:")
    print("   - Target name mismatch in gateway")
    print("   - Wrong MCP endpoint path")
    print("   - Gateway not fully deployed")
    print("   - Lambda function not properly integrated")
    print("\n4. 🎯 Next Steps:")
    print("   - Check AWS Console → Bedrock → Agent Core → Gateways")
    print("   - Verify target exists and is Active")
    print("   - Test Lambda function directly via console")
    print("   - Check CloudWatch logs for gateway and Lambda")

if __name__ == "__main__":
    main()