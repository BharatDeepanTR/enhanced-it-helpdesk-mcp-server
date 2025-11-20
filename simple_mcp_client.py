#!/usr/bin/env python3
"""
Simple MCP Client for Agent Core Gateway Calculator Testing
Lightweight version for quick testing
"""

import boto3
import json
import sys
from datetime import datetime

def test_calculator_gateway():
    """Simple test of calculator gateway"""
    
    # Configuration
    GATEWAY_ID = "a208194-askjulius-agentcore-gateway-mcp-iam"
    REGION = "us-east-1"
    
    print(f"🧮 Testing Calculator via Agent Core Gateway")
    print(f"Gateway: {GATEWAY_ID}")
    print(f"Region: {REGION}")
    print("=" * 50)
    
    try:
        # Initialize Bedrock client
        client = boto3.client('bedrock-agent-runtime', region_name=REGION)
        session_id = f"test-{datetime.now().strftime('%H%M%S')}"
        
        # Test cases
        test_cases = [
            "Calculate 7 plus 3",
            "What is 20 divided by 4?",
            "Find the square root of 36",
            "What is 8 times 7?",
            "Calculate 2 to the power of 6"
        ]
        
        print("Running calculation tests...\n")
        
        for i, test_case in enumerate(test_cases, 1):
            print(f"Test {i}: {test_case}")
            
            try:
                response = client.invoke_agent(
                    agentId=GATEWAY_ID,
                    agentAliasId="TSTALIASID",  # Default test alias for Agent Core Gateway
                    sessionId=f"{session_id}-{i}",
                    inputText=test_case
                )
                
                if 'completion' in response:
                    print(f"✅ Result: {response['completion']}")
                else:
                    print(f"⚠️ No completion in response")
                    print(f"Response keys: {list(response.keys())}")
                
            except Exception as e:
                print(f"❌ Error: {e}")
            
            print("-" * 30)
        
        print("\n✅ Test completed!")
        
    except Exception as e:
        print(f"❌ Failed to initialize or run tests: {e}")
        print("\n🔧 Troubleshooting:")
        print("1. Check AWS credentials are configured")
        print("2. Verify gateway exists and is active")
        print("3. Ensure target is configured properly")
        print("4. Check IAM permissions for Bedrock")

def interactive_calculator():
    """Interactive calculator mode"""
    
    GATEWAY_ID = "a208194-askjulius-agentcore-gateway-mcp-iam"
    REGION = "us-east-1"
    
    print("🧮 Interactive Calculator")
    print("=" * 25)
    
    try:
        client = boto3.client('bedrock-agent-runtime', region_name=REGION)
        session_id = f"interactive-{datetime.now().strftime('%H%M%S')}"
        
        print("Type your calculations (or 'quit' to exit):")
        
        while True:
            try:
                user_input = input("\nCalculator> ").strip()
                
                if user_input.lower() in ['quit', 'exit', 'q']:
                    print("Goodbye! 👋")
                    break
                
                if not user_input:
                    continue
                
                print("🔄 Processing...")
                
                response = client.invoke_agent(
                    agentId=GATEWAY_ID,
                    agentAliasId="TSTALIASID",  # Default test alias for Agent Core Gateway
                    sessionId=session_id,
                    inputText=user_input
                )
                
                if 'completion' in response:
                    print(f"📊 {response['completion']}")
                else:
                    print("⚠️ No result returned")
                
            except KeyboardInterrupt:
                print("\n\nGoodbye! 👋")
                break
            except Exception as e:
                print(f"❌ Error: {e}")
    
    except Exception as e:
        print(f"❌ Failed to start interactive mode: {e}")

def quick_test():
    """Quick single calculation test"""
    
    GATEWAY_ID = "a208194-askjulius-agentcore-gateway-mcp-iam"
    REGION = "us-east-1"
    
    print("🚀 Quick Calculator Test")
    
    try:
        client = boto3.client('bedrock-agent-runtime', region_name=REGION)
        
        response = client.invoke_agent(
            agentId=GATEWAY_ID,
            agentAliasId="TSTALIASID",  # Default test alias for Agent Core Gateway
            sessionId="quick-test",
            inputText="Calculate 5 plus 5"
        )
        
        if 'completion' in response:
            print(f"✅ Success: {response['completion']}")
            print("🎯 Gateway integration working!")
        else:
            print(f"⚠️ Unexpected response: {response}")
            
    except Exception as e:
        print(f"❌ Test failed: {e}")

if __name__ == "__main__":
    if len(sys.argv) > 1:
        mode = sys.argv[1].lower()
        
        if mode == "interactive":
            interactive_calculator()
        elif mode == "test":
            test_calculator_gateway()
        elif mode == "quick":
            quick_test()
        else:
            print("Usage:")
            print(f"  {sys.argv[0]} quick        # Quick test")
            print(f"  {sys.argv[0]} test         # Full test suite")  
            print(f"  {sys.argv[0]} interactive  # Interactive mode")
    else:
        quick_test()