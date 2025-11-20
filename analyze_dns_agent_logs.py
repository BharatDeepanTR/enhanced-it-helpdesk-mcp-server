#!/usr/bin/env python3
"""
DNS Agent CloudWatch Logs Analyzer
==================================

This script retrieves and analyzes CloudWatch logs for the DNS agent
to diagnose runtime startup issues.
"""

import boto3
import json
import time
from datetime import datetime, timedelta
from typing import List, Dict, Any

def get_lambda_log_groups():
    """Find log groups related to the DNS agent Lambda"""
    
    logs_client = boto3.client('logs', region_name='us-east-1')
    
    # Expected Lambda function name patterns
    lambda_patterns = [
        'dns-lookup-service',
        'a208194_chatops_route_dns_lookup', 
        'chatops_route_dns',
        'dns_lookup'
    ]
    
    print("🔍 Searching for DNS agent log groups...")
    
    # Get all log groups
    paginator = logs_client.get_paginator('describe_log_groups')
    
    matching_groups = []
    
    for page in paginator.paginate():
        for group in page['logGroups']:
            group_name = group['logGroupName']
            
            # Check if this looks like our DNS agent
            for pattern in lambda_patterns:
                if pattern.lower() in group_name.lower():
                    matching_groups.append(group)
                    print(f"✅ Found: {group_name}")
                    break
            
            # Also check for Lambda log groups
            if '/aws/lambda/' in group_name:
                for pattern in lambda_patterns:
                    if pattern.lower() in group_name.lower():
                        matching_groups.append(group)
                        print(f"✅ Found Lambda log: {group_name}")
                        break
    
    if not matching_groups:
        print("❌ No DNS agent log groups found")
        print("\n📋 Available Lambda log groups:")
        
        for page in paginator.paginate():
            for group in page['logGroups']:
                group_name = group['logGroupName']
                if '/aws/lambda/' in group_name and '208194' in group_name:
                    print(f"   {group_name}")
    
    return matching_groups

def get_recent_log_events(log_group_name: str, hours: int = 2) -> List[Dict]:
    """Get recent log events from a log group"""
    
    logs_client = boto3.client('logs', region_name='us-east-1')
    
    # Calculate time range
    end_time = datetime.utcnow()
    start_time = end_time - timedelta(hours=hours)
    
    start_timestamp = int(start_time.timestamp() * 1000)
    end_timestamp = int(end_time.timestamp() * 1000)
    
    print(f"🕒 Retrieving logs from {start_time.strftime('%Y-%m-%d %H:%M:%S')} to {end_time.strftime('%Y-%m-%d %H:%M:%S')}")
    
    try:
        # Get log streams
        streams_response = logs_client.describe_log_streams(
            logGroupName=log_group_name,
            orderBy='LastEventTime',
            descending=True,
            limit=10
        )
        
        all_events = []
        
        for stream in streams_response['logStreams']:
            stream_name = stream['logStreamName']
            
            try:
                # Get events from this stream
                events_response = logs_client.get_log_events(
                    logGroupName=log_group_name,
                    logStreamName=stream_name,
                    startTime=start_timestamp,
                    endTime=end_timestamp
                )
                
                events = events_response['events']
                if events:
                    print(f"📄 Stream: {stream_name} ({len(events)} events)")
                    all_events.extend(events)
                
            except Exception as e:
                print(f"⚠️ Error reading stream {stream_name}: {str(e)}")
        
        # Sort events by timestamp
        all_events.sort(key=lambda x: x['timestamp'])
        
        return all_events
        
    except Exception as e:
        print(f"❌ Error retrieving logs: {str(e)}")
        return []

def analyze_log_events(events: List[Dict]) -> Dict[str, Any]:
    """Analyze log events for common issues"""
    
    analysis = {
        'total_events': len(events),
        'error_events': [],
        'warning_events': [],
        'startup_events': [],
        'runtime_errors': [],
        'import_errors': [],
        'timeout_errors': [],
        'memory_errors': []
    }
    
    error_patterns = {
        'import_errors': ['ImportError', 'ModuleNotFoundError', 'No module named'],
        'runtime_errors': ['RuntimeError', 'Exception', 'Error:', 'Traceback'],
        'timeout_errors': ['Task timed out', 'timeout', 'TIMEOUT'],
        'memory_errors': ['Memory', 'MemoryError', 'out of memory'],
        'startup_events': ['START', 'INIT_START', 'INIT_REPORT'],
        'warnings': ['WARNING', 'WARN']
    }
    
    for event in events:
        message = event.get('message', '')
        timestamp = datetime.fromtimestamp(event['timestamp'] / 1000)
        
        # Check for error patterns
        for category, patterns in error_patterns.items():
            for pattern in patterns:
                if pattern.lower() in message.lower():
                    if category not in analysis:
                        analysis[category] = []
                    analysis[category].append({
                        'timestamp': timestamp,
                        'message': message.strip()
                    })
                    break
    
    return analysis

def print_analysis_report(analysis: Dict[str, Any]):
    """Print a comprehensive analysis report"""
    
    print("\n" + "="*80)
    print("📊 CLOUDWATCH LOGS ANALYSIS REPORT")
    print("="*80)
    
    print(f"📈 Total Events: {analysis['total_events']}")
    
    # Error Summary
    error_categories = ['import_errors', 'runtime_errors', 'timeout_errors', 'memory_errors']
    total_errors = sum(len(analysis.get(cat, [])) for cat in error_categories)
    
    if total_errors > 0:
        print(f"🚨 Total Errors Found: {total_errors}")
        
        for category in error_categories:
            events = analysis.get(category, [])
            if events:
                print(f"\n❌ {category.upper().replace('_', ' ')} ({len(events)}):")
                for event in events[-5:]:  # Show last 5
                    time_str = event['timestamp'].strftime('%H:%M:%S')
                    print(f"   [{time_str}] {event['message'][:100]}...")
    else:
        print("✅ No critical errors found")
    
    # Startup Events
    startup_events = analysis.get('startup_events', [])
    if startup_events:
        print(f"\n🚀 STARTUP EVENTS ({len(startup_events)}):")
        for event in startup_events[-3:]:  # Show last 3
            time_str = event['timestamp'].strftime('%H:%M:%S')
            print(f"   [{time_str}] {event['message'][:100]}...")
    
    # Recent Events (last 10)
    print(f"\n📋 RECENT LOG EVENTS:")
    print("-" * 40)
    
    # Get all events sorted by time
    all_events = []
    for category, events in analysis.items():
        if isinstance(events, list) and events and 'timestamp' in (events[0] if events else {}):
            all_events.extend(events)
    
    # Sort and show recent
    all_events.sort(key=lambda x: x['timestamp'], reverse=True)
    
    for event in all_events[:10]:
        time_str = event['timestamp'].strftime('%Y-%m-%d %H:%M:%S')
        print(f"[{time_str}] {event['message'][:120]}...")

def check_lambda_configuration():
    """Check Lambda function configuration for issues"""
    
    lambda_client = boto3.client('lambda', region_name='us-east-1')
    
    # Try to find the DNS Lambda function
    function_patterns = [
        'a208194-dns-lookup-service',
        'dns-lookup-service', 
        'chatops-route-dns-lookup',
        'a208194_chatops_route_dns_lookup'
    ]
    
    print("\n🔍 Checking Lambda function configuration...")
    
    try:
        # List all functions
        paginator = lambda_client.get_paginator('list_functions')
        
        for page in paginator.paginate():
            for func in page['Functions']:
                func_name = func['FunctionName']
                
                # Check if this matches our DNS function
                for pattern in function_patterns:
                    if pattern.lower() in func_name.lower() or '208194' in func_name:
                        print(f"\n🎯 Found Lambda: {func_name}")
                        
                        # Get detailed configuration
                        try:
                            config = lambda_client.get_function(FunctionName=func_name)
                            func_config = config['Configuration']
                            
                            print(f"   Runtime: {func_config.get('Runtime', 'N/A')}")
                            print(f"   Memory: {func_config.get('MemorySize', 'N/A')} MB")
                            print(f"   Timeout: {func_config.get('Timeout', 'N/A')} seconds")
                            print(f"   Last Modified: {func_config.get('LastModified', 'N/A')}")
                            print(f"   State: {func_config.get('State', 'N/A')}")
                            
                            # Check for issues
                            if func_config.get('State') != 'Active':
                                print(f"   ⚠️ Function state is not Active: {func_config.get('State')}")
                            
                            if func_config.get('MemorySize', 0) < 256:
                                print(f"   ⚠️ Low memory allocation: {func_config.get('MemorySize')} MB")
                            
                            return func_name
                            
                        except Exception as e:
                            print(f"   ❌ Error getting function details: {str(e)}")
        
        print("❌ DNS Lambda function not found")
        return None
        
    except Exception as e:
        print(f"❌ Error listing Lambda functions: {str(e)}")
        return None

def main():
    """Main execution function"""
    
    print("🔍 DNS AGENT CLOUDWATCH LOGS ANALYSIS")
    print("="*50)
    print(f"🕒 Started: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    
    # 1. Check Lambda configuration
    lambda_function = check_lambda_configuration()
    
    # 2. Find log groups
    log_groups = get_lambda_log_groups()
    
    if not log_groups:
        print("\n❌ No relevant log groups found")
        return
    
    # 3. Analyze logs for each group
    for log_group in log_groups:
        group_name = log_group['logGroupName']
        
        print(f"\n📄 Analyzing: {group_name}")
        print("-" * 50)
        
        # Get recent events
        events = get_recent_log_events(group_name, hours=6)  # Last 6 hours
        
        if not events:
            print("📭 No recent events found")
            continue
        
        # Analyze events
        analysis = analyze_log_events(events)
        print_analysis_report(analysis)
    
    # 4. Provide recommendations
    print("\n" + "="*80)
    print("💡 TROUBLESHOOTING RECOMMENDATIONS")
    print("="*80)
    
    print("""
🔧 Common DNS Agent Runtime Issues:

1. **Import Errors**:
   • Missing Python dependencies in Lambda layer
   • Incorrect module paths in the code
   • Missing required libraries for DNS operations

2. **Memory Issues**:
   • Increase Lambda memory allocation to 512MB+
   • Check for memory leaks in DNS lookup operations

3. **Timeout Issues**:
   • Increase Lambda timeout to 30+ seconds
   • DNS lookups can be slow for some domains

4. **Configuration Issues**:
   • Check environment variables
   • Verify IAM permissions for DNS operations
   • Ensure proper Lambda handler configuration

5. **Network Issues**:
   • Check VPC configuration if Lambda is in VPC
   • Verify internet access for DNS queries
   • Check security group rules

🛠️ Next Steps:
1. Check the specific error messages above
2. Review Lambda function code for import issues
3. Test Lambda function directly (not through Agent Core)
4. Check IAM permissions for DNS operations
5. Verify network connectivity
    """)

if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\n🛑 Analysis interrupted by user")
    except Exception as e:
        print(f"\n❌ Unexpected error: {str(e)}")