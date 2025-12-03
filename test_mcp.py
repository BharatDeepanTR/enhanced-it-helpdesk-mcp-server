#!/usr/bin/env python3
"""
Quick MCP Test Script
Tests basic connectivity to the Enhanced IT Helpdesk MCP server
"""

import json
import boto3

def test_mcp_connection():
    """Test basic MCP connection"""
    print("🧪 Testing MCP Server Connection")
    print("=" * 40)
    
    # Initialize Lambda client
    lambda_client = boto3.client('lambda', region_name='us-east-1')
    function_name = "a208194-it-helpdesk-enhanced-mcp-server"
    
    # Test 1: Tools List
    print("Test 1: Requesting tools list...")
    payload = {
        "method": "tools/list",
        "params": {},
        "jsonrpc": "2.0",
        "id": "test-1"
    }
    
    try:
        response = lambda_client.invoke(
            FunctionName=function_name,
            InvocationType='RequestResponse',
            Payload=json.dumps(payload)
        )
        
        result = json.loads(response['Payload'].read())
        print("✅ Tools list request successful!")
        print(f"Response: {json.dumps(result, indent=2)}")
        print()
        
    except Exception as e:
        print(f"❌ Tools list failed: {str(e)}")
        return False
    
    # Test 2: Enhanced AI Response
    print("Test 2: Testing enhanced AI response...")
    payload = {
        "method": "tools/call",
        "params": {
            "name": "enhanced_ai_response",
            "arguments": {
                "question": "How do I reset my Thomson Reuters password?",
                "session_id": "test-session-123"
            }
        },
        "jsonrpc": "2.0",
        "id": "test-2"
    }
    
    try:
        response = lambda_client.invoke(
            FunctionName=function_name,
            InvocationType='RequestResponse',
            Payload=json.dumps(payload)
        )
        
        result = json.loads(response['Payload'].read())
        print("✅ Enhanced AI response successful!")
        print(f"Response: {json.dumps(result, indent=2)}")
        print()
        
    except Exception as e:
        print(f"❌ Enhanced AI response failed: {str(e)}")
        return False
    
    print("🎉 All tests passed! MCP server is working correctly.")
    return True

if __name__ == "__main__":
    test_mcp_connection()