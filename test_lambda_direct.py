#!/usr/bin/env python3
"""
Direct Lambda Function Test
Test the AI Calculator Lambda function directly to see its response format
"""

import boto3
import json

def test_lambda_direct():
    """Test Lambda function directly to see what it returns"""
    
    # Initialize Lambda client
    lambda_client = boto3.client('lambda', region_name='us-east-1')
    
    # Test 1: Test with MCP initialize request
    print("🔍 Testing Lambda with MCP initialize request...")
    initialize_payload = {
        "jsonrpc": "2.0",
        "id": 1,
        "method": "initialize",
        "params": {
            "protocolVersion": "2024-11-05",
            "capabilities": {
                "tools": {}
            },
            "clientInfo": {
                "name": "test-client",
                "version": "1.0.0"
            }
        }
    }
    
    try:
        response = lambda_client.invoke(
            FunctionName='a208194-ai-bedrock-calculator-mcp-server',
            InvocationType='RequestResponse',
            Payload=json.dumps(initialize_payload)
        )
        
        # Read the response
        response_payload = response['Payload'].read()
        print(f"Response Status: {response['StatusCode']}")
        print(f"Response Payload: {response_payload.decode('utf-8')}")
        print("-" * 80)
        
    except Exception as e:
        print(f"Error invoking Lambda: {e}")
        return
    
    # Test 2: Test with tools/list request
    print("🔍 Testing Lambda with tools/list request...")
    tools_list_payload = {
        "jsonrpc": "2.0",
        "id": 2,
        "method": "tools/list",
        "params": {}
    }
    
    try:
        response = lambda_client.invoke(
            FunctionName='a208194-ai-bedrock-calculator-mcp-server',
            InvocationType='RequestResponse',
            Payload=json.dumps(tools_list_payload)
        )
        
        # Read the response
        response_payload = response['Payload'].read()
        print(f"Response Status: {response['StatusCode']}")
        print(f"Response Payload: {response_payload.decode('utf-8')}")
        print("-" * 80)
        
    except Exception as e:
        print(f"Error invoking Lambda: {e}")
        return
    
    # Test 3: Test with ai_calculate tool call
    print("🔍 Testing Lambda with ai_calculate tool call...")
    tool_call_payload = {
        "jsonrpc": "2.0",
        "id": 3,
        "method": "tools/call",
        "params": {
            "name": "ai_calculate",
            "arguments": {
                "query": "What is 25 + 17?"
            }
        }
    }
    
    try:
        response = lambda_client.invoke(
            FunctionName='a208194-ai-bedrock-calculator-mcp-server',
            InvocationType='RequestResponse',
            Payload=json.dumps(tool_call_payload)
        )
        
        # Read the response
        response_payload = response['Payload'].read()
        print(f"Response Status: {response['StatusCode']}")
        print(f"Response Payload: {response_payload.decode('utf-8')}")
        print("-" * 80)
        
    except Exception as e:
        print(f"Error invoking Lambda: {e}")
        return

if __name__ == "__main__":
    print("🚀 Testing AI Calculator Lambda function directly...")
    print("This will help us understand the actual response format")
    print("=" * 80)
    test_lambda_direct()
    print("✅ Direct Lambda testing completed")