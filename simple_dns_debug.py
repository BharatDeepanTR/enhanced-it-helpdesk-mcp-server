#!/usr/bin/env python3
"""
Simple DNS Agent Debug Script - Fixed Version
=============================================

Captures CloudWatch logs for the DNS agent runtime failure.
"""

import boto3
import json
import time
from datetime import datetime, timedelta

def capture_dns_agent_logs():
    """Capture and analyze DNS agent logs"""
    
    print("\n🔍 DNS AGENT DEBUG LOG CAPTURE")
    print("="*50)
    print(f"🕒 Started: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    
    # Configuration
    region = 'us-east-1'
    agent_runtime_id = 'a208194_chatops_route_dns_lookup-Zg3E6G5ZDV'
    
    try:
        # Initialize CloudWatch client
        cloudwatch = boto3.client('logs', region_name=region)
        
        # Calculate time range for logs (last 2 hours)
        end_time = datetime.utcnow()
        start_time = end_time - timedelta(hours=2)
        
        start_timestamp = int(start_time.timestamp() * 1000)
        end_timestamp = int(end_time.timestamp() * 1000)
        
        print(f"📅 Time range: {start_time.strftime('%Y-%m-%d %H:%M:%S')} to {end_time.strftime('%Y-%m-%d %H:%M:%S')} UTC")
        
        # Look for Agent Core Runtime logs
        log_groups = [
            '/aws/bedrock/agentcore',
            '/aws/bedrock/agent-core',
            '/aws/bedrock-agentcore',
            f'/aws/lambda/{agent_runtime_id}',
            '/aws/lambda/a208194-dns-lookup',
            '/aws/lambda/dns-lookup-service'
        ]
        
        print(f"\n🔍 Searching log groups...")
        
        found_logs = False
        
        for log_group in log_groups:
            try:
                print(f"\n📋 Checking log group: {log_group}")
                
                # Check if log group exists
                response = cloudwatch.describe_log_groups(
                    logGroupNamePrefix=log_group,
                    limit=1
                )
                
                if response['logGroups']:
                    print(f"   ✅ Log group exists")
                    
                    # Get log events
                    events_response = cloudwatch.filter_log_events(
                        logGroupName=log_group,
                        startTime=start_timestamp,
                        endTime=end_timestamp,
                        limit=100
                    )
                    
                    events = events_response.get('events', [])
                    
                    if events:
                        print(f"   📊 Found {len(events)} log events")
                        found_logs = True
                        
                        # Display recent events
                        print(f"   🔍 Recent events:")
                        for i, event in enumerate(events[-5:], 1):  # Last 5 events
                            timestamp = datetime.fromtimestamp(event['timestamp'] / 1000)
                            message = event['message'][:200] + "..." if len(event['message']) > 200 else event['message']
                            print(f"      {i}. {timestamp}: {message}")
                    else:
                        print(f"   ⚠️ No recent events found")
                else:
                    print(f"   ❌ Log group does not exist")
                    
            except Exception as e:
                error_msg = str(e)
                if "ResourceNotFoundException" in error_msg:
                    print(f"   ❌ Log group not found")
                else:
                    print(f"   ⚠️ Error accessing log group: {error_msg}")
        
        if not found_logs:
            print(f"\n❌ No logs found for the DNS agent")
            print(f"💡 This could indicate:")
            print(f"   • Agent hasn't been invoked recently")
            print(f"   • Logs are in a different log group")
            print(f"   • Agent is not properly configured")
        
        # Search for any Lambda functions that might be related
        print(f"\n🔍 Searching for DNS-related Lambda functions...")
        
        lambda_client = boto3.client('lambda', region_name=region)
        
        try:
            functions = lambda_client.list_functions()['Functions']
            dns_functions = [f for f in functions if any(keyword in f['FunctionName'].lower() 
                           for keyword in ['dns', 'lookup', 'route', '208194'])]
            
            if dns_functions:
                print(f"   📋 Found {len(dns_functions)} DNS-related functions:")
                for func in dns_functions:
                    print(f"      • {func['FunctionName']} (Runtime: {func['Runtime']})")
                    
                    # Check CloudWatch logs for this function
                    func_log_group = f"/aws/lambda/{func['FunctionName']}"
                    try:
                        events_response = cloudwatch.filter_log_events(
                            logGroupName=func_log_group,
                            startTime=start_timestamp,
                            endTime=end_timestamp,
                            limit=10
                        )
                        
                        events = events_response.get('events', [])
                        if events:
                            print(f"        📊 Recent logs: {len(events)} events")
                            for event in events[-3:]:  # Last 3 events
                                timestamp = datetime.fromtimestamp(event['timestamp'] / 1000)
                                message = event['message'][:150] + "..." if len(event['message']) > 150 else event['message']
                                print(f"        {timestamp}: {message}")
                        else:
                            print(f"        ⚠️ No recent logs")
                    except Exception as e:
                        print(f"        ❌ Cannot access logs: {str(e)[:50]}")
            else:
                print(f"   ❌ No DNS-related Lambda functions found")
                
        except Exception as e:
            print(f"   ❌ Error listing Lambda functions: {str(e)}")
        
        # Try to get Agent Core Runtime errors from the agent runtime ID
        print(f"\n🔍 Searching for Agent Core Runtime logs...")
        
        # Try various potential log group patterns
        agentcore_patterns = [
            f'/aws/bedrock/agentcore/{agent_runtime_id}',
            f'/aws/bedrock-agentcore/{agent_runtime_id}',
            '/aws/bedrock/agentcore/runtime',
            '/aws/bedrock-agentcore/runtime'
        ]
        
        for pattern in agentcore_patterns:
            try:
                print(f"   🔍 Checking: {pattern}")
                
                events_response = cloudwatch.filter_log_events(
                    logGroupName=pattern,
                    startTime=start_timestamp,
                    endTime=end_timestamp,
                    filterPattern='"error" OR "Error" OR "ERROR" OR "startup" OR "runtime"',
                    limit=20
                )
                
                events = events_response.get('events', [])
                if events:
                    print(f"      📊 Found {len(events)} error/startup events:")
                    for event in events[-5:]:  # Last 5 events
                        timestamp = datetime.fromtimestamp(event['timestamp'] / 1000)
                        message = event['message'][:300] + "..." if len(event['message']) > 300 else event['message']
                        print(f"      {timestamp}: {message}")
                        
            except Exception as e:
                if "ResourceNotFoundException" not in str(e):
                    print(f"      ❌ Error: {str(e)[:50]}")
        
        print(f"\n✅ Debug log capture completed")
        
        # Create simple payload for testing
        print(f"\n📝 Test payload for sandbox:")
        test_payload = {
            "inputText": "What is the IP address of google.com?",
            "sessionId": f"debug-test-{datetime.now().strftime('%Y%m%d%H%M%S')}",
            "sessionAttributes": {},
            "promptSessionAttributes": {}
        }
        
        print(json.dumps(test_payload, indent=2))
        
        print(f"\n💡 Next steps:")
        print(f"   1. Copy the test payload above")
        print(f"   2. Paste it into the Agent Core sandbox")
        print(f"   3. Check CloudWatch logs immediately after running")
        print(f"   4. Look for any startup errors or runtime failures")
        
    except Exception as e:
        print(f"❌ Error during log capture: {str(e)}")

def main():
    """Main execution function"""
    try:
        capture_dns_agent_logs()
        
    except KeyboardInterrupt:
        print("\n🛑 Debug capture interrupted by user")
    except Exception as e:
        print(f"\n❌ Unexpected error: {str(e)}")

if __name__ == "__main__":
    main()