#!/usr/bin/env python3
"""
DNS Agent Core Runtime Testing Script
Test the updated agent with the fixed SSM path
"""

import boto3
import json
import time
from datetime import datetime

def test_dns_agent_functionality():
    """Test the DNS agent after the container fix"""
    
    print("=== DNS Agent Core Runtime Testing ===")
    print(f"Testing Time: {datetime.now()}")
    print(f"Container Version: v1.1.0-fixed-arm64")
    print(f"SSM Path Fix: /a208194/APISECRETS")
    print("=" * 60)
    
    # Test 1: Check CloudWatch Logs for Startup Success
    print("\n1. 🔍 Checking CloudWatch Logs for Startup...")
    check_agent_startup_logs()
    
    # Test 2: Validate SSM Parameter Access
    print("\n2. 🔐 Validating SSM Parameter Access...")
    validate_ssm_access()
    
    # Test 3: Test Agent Invocation (if API access available)
    print("\n3. 🚀 Testing Agent Functionality...")
    test_agent_invocation()
    
    print("\n" + "=" * 60)
    print("📊 Test Summary Complete!")

def check_agent_startup_logs():
    """Check CloudWatch logs for DNS agent startup"""
    
    try:
        logs_client = boto3.client('logs', region_name='us-east-1')
        
        # Look for new log groups created after container deployment
        response = logs_client.describe_log_groups()
        
        # Filter for DNS or Agent Core related logs
        relevant_logs = []
        for log_group in response['logGroups']:
            log_name = log_group['logGroupName'].lower()
            if any(keyword in log_name for keyword in ['dns', 'chatops', 'a208194', 'agentcore', 'bedrock']):
                relevant_logs.append({
                    'name': log_group['logGroupName'],
                    'created': log_group.get('creationTime', 0),
                    'size': log_group.get('storedBytes', 0)
                })
        
        if relevant_logs:
            # Sort by creation time (newest first)
            relevant_logs.sort(key=lambda x: x['created'], reverse=True)
            
            print(f"✅ Found {len(relevant_logs)} relevant log group(s):")
            for log in relevant_logs[:3]:  # Show top 3
                created_time = datetime.fromtimestamp(log['created']/1000) if log['created'] else 'Unknown'
                print(f"   📝 {log['name']}")
                print(f"      Created: {created_time}")
                print(f"      Size: {log['size']} bytes")
            
            # Check recent logs from the newest group
            if relevant_logs:
                check_recent_log_events(logs_client, relevant_logs[0]['name'])
        else:
            print("⚠️ No relevant log groups found yet")
            print("   This might mean:")
            print("   - Agent hasn't been invoked yet (logs created on first use)")
            print("   - Log group naming is different than expected")
            print("   - Agent is still starting up")
            
    except Exception as e:
        print(f"❌ Error checking logs: {e}")

def check_recent_log_events(logs_client, log_group_name):
    """Check recent log events for startup success/failure"""
    
    try:
        # Look for events in the last 2 hours
        end_time = int(time.time() * 1000)
        start_time = end_time - (2 * 60 * 60 * 1000)  # 2 hours ago
        
        response = logs_client.filter_log_events(
            logGroupName=log_group_name,
            startTime=start_time,
            endTime=end_time,
            limit=10
        )
        
        events = response.get('events', [])
        if events:
            print(f"\n   📋 Recent events from {log_group_name}:")
            for event in events[-5:]:  # Show last 5 events
                timestamp = datetime.fromtimestamp(event['timestamp']/1000)
                message = event['message'].strip()
                
                # Look for key indicators
                if any(keyword in message.lower() for keyword in ['ssm', 'parameter', 'config', 'error', 'start']):
                    status = "🔍"
                    if 'error' in message.lower():
                        status = "❌"
                    elif any(word in message.lower() for word in ['success', 'loaded', 'ready']):
                        status = "✅"
                    
                    print(f"   {status} [{timestamp.strftime('%H:%M:%S')}] {message[:100]}...")
        else:
            print(f"   📝 No recent events in {log_group_name}")
            
    except Exception as e:
        print(f"   ❌ Error reading recent logs: {e}")

def validate_ssm_access():
    """Verify the SSM parameters are accessible"""
    
    try:
        ssm_client = boto3.client('ssm', region_name='us-east-1')
        
        # Check if parameters exist at the correct path
        required_params = [
            '/a208194/APISECRETS/ACCT_REF_API',
            '/a208194/APISECRETS/MGMT_APP_REF', 
            '/a208194/APISECRETS/API_URL_ROUTE53'
        ]
        
        accessible_params = []
        for param in required_params:
            try:
                response = ssm_client.get_parameter(Name=param, WithDecryption=False)
                accessible_params.append(param)
                print(f"   ✅ {param} - Accessible")
            except ssm_client.exceptions.ParameterNotFound:
                print(f"   ❌ {param} - Not Found")
            except Exception as e:
                print(f"   ⚠️ {param} - Access Error: {str(e)[:50]}...")
        
        if len(accessible_params) == len(required_params):
            print(f"\n✅ All {len(required_params)} SSM parameters are accessible")
            print("   The agent should be able to load configuration successfully")
        else:
            print(f"\n⚠️ {len(accessible_params)}/{len(required_params)} parameters accessible")
            
    except Exception as e:
        print(f"❌ Error validating SSM access: {e}")

def test_agent_invocation():
    """Test agent functionality if possible"""
    
    print("🧪 Agent invocation testing:")
    print("   Note: Direct agent testing requires specific Agent Core Runtime API access")
    print("   Recommended approach:")
    print("   1. Monitor CloudWatch logs during test invocation")
    print("   2. Use Agent Core Runtime console for testing")
    print("   3. Try simple DNS queries like 'What is the IP of google.com?'")
    
    # Provide test queries for manual testing
    test_queries = [
        "What is the IP address of google.com?",
        "Look up DNS records for github.com", 
        "Can you resolve the domain amazon.com?",
        "What DNS information do you have for microsoft.com?"
    ]
    
    print("\n   📝 Suggested test queries for Agent Core Runtime console:")
    for i, query in enumerate(test_queries, 1):
        print(f"   {i}. {query}")

def generate_post_deployment_checklist():
    """Generate checklist for validating the deployment"""
    
    print("\n" + "=" * 60)
    print("📋 POST-DEPLOYMENT VALIDATION CHECKLIST")
    print("=" * 60)
    
    checklist = [
        "☐ CloudWatch logs show successful container startup",
        "☐ No SSM parameter access errors in logs",
        "☐ Agent responds to test DNS queries",
        "☐ Proper JSON responses returned for DNS lookups",
        "☐ No runtime startup errors reported",
        "☐ Agent ready for Supervisor Agent integration"
    ]
    
    for item in checklist:
        print(f"   {item}")
    
    print("\n🎯 SUCCESS CRITERIA:")
    print("   ✅ Agent starts without SSM parameter errors")
    print("   ✅ DNS lookups return proper results")
    print("   ✅ Ready for integration with Supervisor Agent")
    
    print("\n📞 IF ISSUES FOUND:")
    print("   1. Check CloudWatch logs for specific error messages")
    print("   2. Verify SSM parameter access permissions")
    print("   3. Test with simple domains first (google.com, etc.)")

if __name__ == "__main__":
    test_dns_agent_functionality()
    generate_post_deployment_checklist()