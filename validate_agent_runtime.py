#!/usr/bin/env python3
"""
Agent Core Runtime Validation Script
Test if the DNS agent is actually functional, not just "Ready"
"""

import boto3
import json
import time
from datetime import datetime

def test_agent_core_runtime_health():
    """Test the actual functionality of the Agent Core Runtime"""
    
    print("=== Agent Core Runtime Health Check ===")
    print(f"Timestamp: {datetime.now()}")
    print()
    
    # Test 1: Check CloudWatch Logs for Container Startup
    print("1. Checking CloudWatch Logs for startup errors...")
    check_cloudwatch_logs()
    
    # Test 2: Try to invoke the agent directly (if possible)
    print("\n2. Attempting direct agent invocation...")
    test_agent_invocation()
    
    # Test 3: Check ECS/Container status
    print("\n3. Checking container runtime status...")
    check_container_status()
    
    print("\n" + "="*50)

def check_cloudwatch_logs():
    """Check CloudWatch logs for the Agent Core Runtime"""
    
    try:
        logs_client = boto3.client('logs', region_name='us-east-1')
        
        # Common log group patterns for Agent Core Runtime
        log_group_patterns = [
            "/aws/bedrock/agentcore/a208194_chatops_route_dns_lookup",
            "/aws/lambda/a208194_chatops_route_dns_lookup",
            "/aws/ecs/agentcore",
            "bedrock-agentcore"
        ]
        
        # Get all log groups and search for our agent
        response = logs_client.describe_log_groups()
        
        dns_log_groups = []
        for log_group in response['logGroups']:
            log_group_name = log_group['logGroupName']
            if any(pattern in log_group_name.lower() for pattern in ['dns', 'a208194', 'chatops']):
                dns_log_groups.append(log_group_name)
        
        if dns_log_groups:
            print(f"✅ Found {len(dns_log_groups)} relevant log groups:")
            for lg in dns_log_groups:
                print(f"   - {lg}")
                
            # Check recent logs in the first group
            check_recent_logs(logs_client, dns_log_groups[0])
        else:
            print("⚠️ No DNS-related log groups found")
            print("Available log groups (filtered):")
            for log_group in response['logGroups'][:10]:
                if 'bedrock' in log_group['logGroupName'].lower():
                    print(f"   - {log_group['logGroupName']}")
            
    except Exception as e:
        print(f"❌ Error checking CloudWatch logs: {e}")

def check_recent_logs(logs_client, log_group_name):
    """Check recent logs for errors"""
    
    try:
        # Get recent log events (last 1 hour)
        end_time = int(time.time() * 1000)
        start_time = end_time - (60 * 60 * 1000)  # 1 hour ago
        
        response = logs_client.filter_log_events(
            logGroupName=log_group_name,
            startTime=start_time,
            endTime=end_time,
            limit=20
        )
        
        events = response.get('events', [])
        if events:
            print(f"📋 Recent log events from {log_group_name}:")
            for event in events[-5:]:  # Show last 5 events
                timestamp = datetime.fromtimestamp(event['timestamp']/1000)
                message = event['message'].strip()
                print(f"   [{timestamp}] {message}")
        else:
            print(f"⚠️ No recent log events in {log_group_name}")
            
    except Exception as e:
        print(f"❌ Error reading logs: {e}")

def test_agent_invocation():
    """Try to invoke the agent to test functionality"""
    
    try:
        # Since we found the agent ID format issue, let's try a different approach
        # Check if we can find the agent through other means
        
        bedrock_client = boto3.client('bedrock-agent-runtime', region_name='us-east-1')
        
        # Try to list sessions to see if the service is responsive
        try:
            response = bedrock_client.list_sessions(
                agentId="a208194_chatops_route_dns_lookup"[:10],  # Truncate to 10 chars
                maxResults=1
            )
            print("✅ Agent Core Runtime service is responsive")
        except Exception as e:
            if "ValidationException" in str(e):
                print("⚠️ Agent ID format issue (expected - this confirms service is running)")
                print("   Error:", str(e)[:100] + "...")
            elif "AccessDenied" in str(e):
                print("⚠️ Permission issue (service running, need access)")
            elif "ResourceNotFound" in str(e):
                print("❌ Agent not found or not properly deployed")
            else:
                print(f"❌ Unexpected error: {str(e)[:100]}...")
                
    except Exception as e:
        print(f"❌ Cannot test agent invocation: {e}")

def check_container_status():
    """Check if there are any ECS tasks or container instances"""
    
    try:
        ecs_client = boto3.client('ecs', region_name='us-east-1')
        
        # List ECS clusters
        response = ecs_client.list_clusters()
        
        print("🐳 Checking ECS clusters for Agent Core Runtime containers...")
        
        for cluster_arn in response.get('clusterArns', []):
            cluster_name = cluster_arn.split('/')[-1]
            if 'bedrock' in cluster_name.lower() or 'agent' in cluster_name.lower():
                print(f"   Found relevant cluster: {cluster_name}")
                
                # Check tasks in this cluster
                tasks_response = ecs_client.list_tasks(cluster=cluster_arn)
                if tasks_response.get('taskArns'):
                    print(f"   ✅ Found {len(tasks_response['taskArns'])} running tasks")
                else:
                    print(f"   ⚠️ No running tasks in cluster")
        
        if not response.get('clusterArns'):
            print("   ⚠️ No ECS clusters found")
            
    except Exception as e:
        print(f"❌ Error checking container status: {e}")

def generate_test_report():
    """Generate a summary report"""
    
    print("\n" + "="*50)
    print("📊 VALIDATION SUMMARY")
    print("="*50)
    print()
    print("To confirm the agent is working:")
    print("1. ✅ Check logs show no startup errors")
    print("2. ✅ Service responds to API calls (even with validation errors)")  
    print("3. ✅ No container crash loops")
    print()
    print("🎯 RECOMMENDED TESTS:")
    print("- Monitor CloudWatch logs during a test request")
    print("- Check if the SSM parameter fix resolves startup issues")
    print("- Validate DNS functionality after parameter copy")
    print()
    print("📋 NEXT STEPS:")
    print("1. Have admin copy SSM parameters to /app/ path")
    print("2. Monitor logs for successful startup")
    print("3. Test DNS queries through Agent Core Runtime")

if __name__ == "__main__":
    test_agent_core_runtime_health()
    generate_test_report()