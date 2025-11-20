#!/usr/bin/env python3
"""
Test script for Agent Core Runtime DNS agent
"""

import boto3
import json
import time

def test_dns_agent_runtime():
    """Test the DNS agent through Bedrock Agent Runtime"""
    
    # Agent details from the UI
    agent_id = "a208194_chatops_route_dns_lookup"
    agent_alias_id = "TSTALIASID"  # Default test alias
    
    # Create Bedrock Agent Runtime client
    client = boto3.client('bedrock-agent-runtime', region_name='us-east-1')
    
    # Test queries for DNS lookup
    test_queries = [
        "What is the IP address of google.com?",
        "Look up DNS record for microsoft.com",
        "Can you resolve amazon.com?",
        "What DNS information can you find for github.com?"
    ]
    
    print(f"Testing DNS Agent: {agent_id}")
    print(f"Agent Alias: {agent_alias_id}")
    print("=" * 60)
    
    for i, query in enumerate(test_queries, 1):
        print(f"\nTest {i}: {query}")
        print("-" * 40)
        
        try:
            # Start session with the agent
            session_id = f"test-session-{int(time.time())}-{i}"
            
            response = client.invoke_agent(
                agentId=agent_id,
                agentAliasId=agent_alias_id,
                sessionId=session_id,
                inputText=query
            )
            
            # Process the response stream
            if 'completion' in response:
                print("Response received!")
                for event in response['completion']:
                    if 'chunk' in event:
                        chunk = event['chunk']
                        if 'bytes' in chunk:
                            text = chunk['bytes'].decode('utf-8')
                            print(f"Output: {text}")
                        elif 'attribution' in chunk:
                            print(f"Attribution: {chunk['attribution']}")
            else:
                print(f"Unexpected response format: {response}")
                
        except Exception as e:
            print(f"Error: {str(e)}")
            print(f"Error type: {type(e).__name__}")
            
            # Check if it's a runtime startup error
            if "runtime" in str(e).lower():
                print("❌ Runtime startup error detected!")
                print("This confirms the container environment variable issue.")
                return False
                
        print()
        time.sleep(1)  # Brief pause between requests
    
    print("=" * 60)
    print("✅ Agent Runtime test completed!")
    return True

if __name__ == "__main__":
    print("=== Testing DNS Agent Core Runtime ===")
    test_dns_agent_runtime()