#!/usr/bin/env python3
"""
Gateway vs Lambda Format Comparison
Since Lambda was working earlier but now fails, compare exact request/response formats
"""

import boto3
import json
from requests_aws4auth import AWS4Auth
import requests

def compare_gateway_vs_lambda():
    """Compare exact request/response formats between gateway and direct Lambda calls"""
    
    print("🔍 Gateway vs Lambda Format Comparison")
    print("=" * 70)
    print("🎯 GOAL: Find format mismatch causing 'internal error' despite Lambda working")
    print("")
    
    # Gateway URL (confirmed correct)
    gateway_url = "https://a208194-askjulius-agentcore-gateway-mcp-iam-fvro4phd59.gateway.bedrock-agentcore.us-east-1.amazonaws.com/mcp"
    
    # Get AWS credentials
    session = boto3.Session()
    credentials = session.get_credentials()
    lambda_client = boto3.client('lambda', region_name='us-east-1')
    
    auth = AWS4Auth(
        credentials.access_key,
        credentials.secret_key, 
        'us-east-1',
        'bedrock-agentcore',
        session_token=credentials.token
    )
    
    headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json'
    }
    
    # Test payload for ai_calculate
    test_query = "What is 50 + 25?"
    
    print("📋 PART 1: Direct Lambda Call (Known Working)")
    print("-" * 50)
    
    lambda_payload = {
        "jsonrpc": "2.0",
        "id": 1,
        "method": "tools/call",
        "params": {
            "name": "ai_calculate",
            "arguments": {
                "query": test_query
            }
        }
    }
    
    print(f"Lambda Request: {json.dumps(lambda_payload, indent=2)}")
    
    try:
        lambda_response = lambda_client.invoke(
            FunctionName='a208194-ai-bedrock-calculator-mcp-server',
            InvocationType='RequestResponse',
            Payload=json.dumps(lambda_payload)
        )
        
        lambda_result = json.loads(lambda_response['Payload'].read())
        print(f"Lambda Response: {json.dumps(lambda_result, indent=2)}")
        print(f"Lambda Status: ✅ SUCCESS")
        
    except Exception as e:
        print(f"Lambda Error: {e}")
        return
    
    print("\n" + "=" * 70)
    print("📋 PART 2: Gateway Call (Currently Failing)")
    print("-" * 50)
    
    gateway_payload = {
        "jsonrpc": "2.0",
        "id": 1,
        "method": "tools/call",
        "params": {
            "name": "ai_calculate",
            "arguments": {
                "query": test_query
            }
        }
    }
    
    print(f"Gateway Request: {json.dumps(gateway_payload, indent=2)}")
    
    try:
        gateway_response = requests.post(
            gateway_url, 
            json=gateway_payload, 
            headers=headers, 
            auth=auth,
            timeout=30
        )
        
        print(f"Gateway Response Status: {gateway_response.status_code}")
        print(f"Gateway Response Headers: {dict(gateway_response.headers)}")
        print(f"Gateway Response Body: {gateway_response.text}")
        
        if gateway_response.status_code == 200:
            gateway_result = gateway_response.json()
            if 'error' in gateway_result:
                print(f"Gateway Status: ❌ ERROR - {gateway_result['error']}")
            else:
                print(f"Gateway Status: ✅ SUCCESS")
        else:
            print(f"Gateway Status: ❌ HTTP ERROR - {gateway_response.status_code}")
            
    except Exception as e:
        print(f"Gateway Error: {e}")
        return
    
    print("\n" + "=" * 70)
    print("📋 PART 3: Analysis")
    print("-" * 50)
    
    print("🔍 Possible Issues:")
    print("1. ⚡ Target Configuration: Gateway target schema doesn't match Lambda")
    print("2. 🔄 Request Transformation: Gateway modifies request before sending to Lambda")
    print("3. 📝 Response Processing: Gateway can't process Lambda response format")
    print("4. ⏰ Timeout Issues: Gateway timeout vs Lambda execution time")
    print("5. 🔐 IAM Permissions: Service role can't invoke Lambda properly")
    
    print("\n🎯 NEXT STEPS:")
    print("Since Lambda was working earlier, this is likely:")
    print("- Recent gateway target configuration change")
    print("- Target schema mismatch introduced")
    print("- Service role permission issue")
    
    # Check CloudWatch logs for more details
    print("\n📊 Checking recent CloudWatch logs for timing correlation...")
    try:
        logs_client = boto3.client('logs', region_name='us-east-1')
        
        # Get logs from the last hour
        import time
        end_time = int(time.time() * 1000)
        start_time = end_time - (3600 * 1000)  # 1 hour ago
        
        response = logs_client.filter_log_events(
            logGroupName='/aws/lambda/a208194-ai-bedrock-calculator-mcp-server',
            startTime=start_time,
            endTime=end_time,
            limit=5
        )
        
        recent_events = response.get('events', [])
        print(f"Recent log events found: {len(recent_events)}")
        
        for event in recent_events[-3:]:  # Last 3 events
            timestamp = event['timestamp']
            message = event['message']
            print(f"  {timestamp}: {message}")
            
    except Exception as e:
        print(f"CloudWatch logs check failed: {e}")

if __name__ == "__main__":
    compare_gateway_vs_lambda()