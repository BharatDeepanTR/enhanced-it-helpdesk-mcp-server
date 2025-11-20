#!/usr/bin/env python3
"""
Simple DNS Agent Runtime Fix
============================

Direct approach to fix the "An error occurred when starting the runtime" issue.
Focus on the most common causes without complex analysis.
"""

import boto3
import json
from datetime import datetime, timedelta

def check_basic_permissions():
    """Check basic AWS permissions"""
    print("🔐 CHECKING BASIC AWS PERMISSIONS")
    print("="*50)
    
    try:
        # Check STS identity
        sts = boto3.client('sts')
        identity = sts.get_caller_identity()
        print(f"✅ AWS Identity: {identity.get('Arn', 'Unknown')}")
        print(f"✅ Account: {identity.get('Account', 'Unknown')}")
        
        # Check Bedrock permissions
        bedrock = boto3.client('bedrock-agent-runtime', region_name='us-east-1')
        print("✅ Bedrock Agent Runtime client created")
        
        return True
        
    except Exception as e:
        print(f"❌ Permission check failed: {e}")
        return False

def check_recent_logs():
    """Check recent CloudWatch logs for specific errors"""
    print("\n📊 CHECKING RECENT CLOUDWATCH LOGS")
    print("="*50)
    
    try:
        logs_client = boto3.client('logs', region_name='us-east-1')
        
        # Search for Agent Core Runtime logs
        log_groups = [
            '/aws/bedrock/agentcore',
            '/aws/lambda/a208194-chatops-route-dns-lookup',
            '/aws/lambda/a208194-dns-lookup-service',
            '/aws/lambda/chatops-dns-lookup'
        ]
        
        found_errors = []
        
        for log_group in log_groups:
            try:
                # Check if log group exists
                logs_client.describe_log_groups(logGroupNamePrefix=log_group)
                
                # Get recent logs (last hour)
                end_time = datetime.now()
                start_time = end_time - timedelta(hours=1)
                
                response = logs_client.filter_log_events(
                    logGroupName=log_group,
                    startTime=int(start_time.timestamp() * 1000),
                    endTime=int(end_time.timestamp() * 1000),
                    filterPattern='ERROR'
                )
                
                events = response.get('events', [])
                if events:
                    print(f"📋 Found {len(events)} error events in {log_group}")
                    for event in events[:3]:  # Show first 3 errors
                        timestamp = datetime.fromtimestamp(event['timestamp'] / 1000)
                        message = event['message'][:200]
                        print(f"   {timestamp}: {message}...")
                        found_errors.append(message)
                else:
                    print(f"✅ No errors in {log_group}")
                    
            except Exception as e:
                if "ResourceNotFoundException" not in str(e):
                    print(f"⚠️  Error checking {log_group}: {e}")
        
        return found_errors
        
    except Exception as e:
        print(f"❌ CloudWatch check failed: {e}")
        return []

def suggest_fixes():
    """Suggest specific fixes for common runtime startup issues"""
    print("\n🔧 COMMON FIXES FOR RUNTIME STARTUP ERRORS")
    print("="*60)
    
    fixes = [
        {
            "issue": "Container Image Issues",
            "fix": "Check ECR repository 'dns-lookup-service' has valid images",
            "action": "Rebuild and push container image if corrupted"
        },
        {
            "issue": "IAM Role Missing Permissions", 
            "fix": "Ensure agent service role has bedrock and lambda permissions",
            "action": "Copy IAM role from working account details agent"
        },
        {
            "issue": "Lambda Function Cold Start Timeout",
            "fix": "Increase Lambda timeout and memory allocation",
            "action": "Set timeout to 60s, memory to 512MB minimum"
        },
        {
            "issue": "Environment Variables Missing",
            "fix": "Check if Lambda needs specific environment variables",
            "action": "Compare with working agent's Lambda configuration"
        },
        {
            "issue": "Agent Core Runtime Configuration",
            "fix": "Agent runtime configuration may be corrupted",
            "action": "Delete and recreate the runtime agent"
        }
    ]
    
    for i, fix in enumerate(fixes, 1):
        print(f"{i}. {fix['issue']}")
        print(f"   💡 Fix: {fix['fix']}")
        print(f"   🔧 Action: {fix['action']}")
        print()

def create_test_payload():
    """Create a test payload for manual testing"""
    print("🧪 TEST PAYLOAD FOR MANUAL VERIFICATION")
    print("="*50)
    
    payload = {
        "inputText": "What is the IP address of google.com?",
        "sessionId": f"debug-test-{datetime.now().strftime('%Y%m%d-%H%M%S')}",
        "sessionAttributes": {},
        "promptSessionAttributes": {}
    }
    
    print("Copy this payload to the Agent Core console sandbox:")
    print(json.dumps(payload, indent=2))
    
    return payload

def main():
    """Main diagnostic and fix function"""
    print("🔧 DNS AGENT RUNTIME STARTUP FIX")
    print("="*50)
    print(f"🕒 Started: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print("🎯 Target: a208194_chatops_route_dns_lookup")
    print("🎯 Error: 'An error occurred when starting the runtime'")
    print()
    
    # Step 1: Check basic permissions
    if not check_basic_permissions():
        print("❌ Basic permission check failed. Fix AWS credentials first.")
        return
    
    # Step 2: Check recent logs for specific errors
    errors = check_recent_logs()
    
    # Step 3: Suggest fixes
    suggest_fixes()
    
    # Step 4: Create test payload
    create_test_payload()
    
    print("\n" + "="*80)
    print("📋 QUICK RESOLUTION STEPS")
    print("="*80)
    print("1. 🔍 Check the Agent Core console for the DNS agent status")
    print("2. 📊 Look at CloudWatch logs for specific error messages")
    print("3. 🔄 Try restarting/recreating the runtime agent")
    print("4. 📞 Compare with working account details agent configuration")
    print("5. 🧪 Test with the payload above in the console sandbox")
    print()
    print("💡 Most likely fix: Update the agent's IAM role or recreate the runtime")
    print("="*80)

if __name__ == "__main__":
    main()