#!/usr/bin/env python3
"""
Direct Agent Configuration Analysis
===================================

Since we know both agents exist, let's directly check their configurations
and permissions without relying on discovery methods.
"""

import boto3
import json
import logging
from datetime import datetime

def setup_logging():
    """Configure logging"""
    logging.basicConfig(
        level=logging.INFO,
        format='%(asctime)s - %(levelname)s - %(message)s'
    )
    return logging.getLogger('DirectAgentAnalysis')

def check_lambda_functions():
    """Check the underlying Lambda functions that might be used by these agents"""
    logger = setup_logging()
    
    print("\n🔍 LAMBDA FUNCTION ANALYSIS")
    print("="*60)
    
    try:
        lambda_client = boto3.client('lambda', region_name='us-east-1')
        
        # List all Lambda functions
        response = lambda_client.list_functions()
        functions = response.get('Functions', [])
        
        # Look for functions related to our agents
        dns_functions = []
        account_functions = []
        
        for func in functions:
            func_name = func.get('FunctionName', '').lower()
            
            if any(keyword in func_name for keyword in ['dns', 'route', 'lookup', 'chatops']):
                dns_functions.append(func)
            elif any(keyword in func_name for keyword in ['account', 'details']):
                account_functions.append(func)
        
        print(f"\n📋 DNS-related Lambda functions ({len(dns_functions)}):")
        for func in dns_functions:
            print(f"   • {func.get('FunctionName')}")
            print(f"     Runtime: {func.get('Runtime')}")
            print(f"     Role: {func.get('Role')}")
            print(f"     Last Modified: {func.get('LastModified')}")
            
            # Check function configuration
            try:
                config = lambda_client.get_function_configuration(
                    FunctionName=func.get('FunctionName')
                )
                print(f"     State: {config.get('State', 'Unknown')}")
                print(f"     Timeout: {config.get('Timeout', 'Unknown')}s")
                print(f"     Memory: {config.get('MemorySize', 'Unknown')}MB")
                if config.get('Environment', {}).get('Variables'):
                    print(f"     Environment Variables: {len(config.get('Environment', {}).get('Variables', {}))}")
            except Exception as e:
                print(f"     ❌ Error getting config: {str(e)}")
        
        print(f"\n📋 Account-related Lambda functions ({len(account_functions)}):")
        for func in account_functions:
            print(f"   • {func.get('FunctionName')}")
            print(f"     Runtime: {func.get('Runtime')}")
            print(f"     Role: {func.get('Role')}")
            print(f"     Last Modified: {func.get('LastModified')}")
        
        # Test invoke both types
        print(f"\n🧪 TESTING LAMBDA FUNCTIONS:")
        
        for func in dns_functions:
            func_name = func.get('FunctionName')
            print(f"\n   Testing {func_name}:")
            try:
                test_payload = {
                    "inputText": "test dns lookup google.com",
                    "sessionId": "test-session-123"
                }
                
                response = lambda_client.invoke(
                    FunctionName=func_name,
                    InvocationType='RequestResponse',
                    Payload=json.dumps(test_payload)
                )
                
                status_code = response.get('StatusCode')
                if status_code == 200:
                    print(f"     ✅ SUCCESS (Status: {status_code})")
                    
                    # Try to read the response
                    payload = response.get('Payload')
                    if payload:
                        result = json.loads(payload.read().decode('utf-8'))
                        print(f"     📋 Response preview: {str(result)[:100]}...")
                else:
                    print(f"     ⚠️ Non-200 status: {status_code}")
                    
            except Exception as e:
                error_msg = str(e)
                if "AccessDeniedException" in error_msg:
                    print(f"     ❌ PERMISSION ERROR: {error_msg}")
                else:
                    print(f"     ❌ ERROR: {error_msg}")
        
    except Exception as e:
        logger.error(f"❌ Lambda analysis failed: {str(e)}")

def check_iam_roles():
    """Check IAM roles that might be used by the agents"""
    logger = setup_logging()
    
    print("\n🔐 IAM ROLES ANALYSIS")
    print("="*60)
    
    try:
        iam_client = boto3.client('iam', region_name='us-east-1')
        
        # Look for roles related to our agents
        role_keywords = [
            'askjulius',
            'chatops',
            'dns',
            'account',
            'details',
            'supervisor',
            'agent'
        ]
        
        paginator = iam_client.get_paginator('list_roles')
        
        relevant_roles = []
        
        for page in paginator.paginate():
            for role in page.get('Roles', []):
                role_name = role.get('RoleName', '').lower()
                
                if any(keyword in role_name for keyword in role_keywords):
                    relevant_roles.append(role)
        
        print(f"\n📋 Found {len(relevant_roles)} relevant IAM roles:")
        
        for role in relevant_roles:
            role_name = role.get('RoleName')
            print(f"\n   🔑 Role: {role_name}")
            print(f"     ARN: {role.get('Arn')}")
            print(f"     Created: {role.get('CreateDate')}")
            
            # Get attached policies
            try:
                attached_policies = iam_client.list_attached_role_policies(RoleName=role_name)
                policies = attached_policies.get('AttachedPolicies', [])
                
                if policies:
                    print(f"     📎 Attached Policies ({len(policies)}):")
                    for policy in policies:
                        print(f"       • {policy.get('PolicyName')}")
                
                # Get inline policies
                inline_policies = iam_client.list_role_policies(RoleName=role_name)
                inline_policy_names = inline_policies.get('PolicyNames', [])
                
                if inline_policy_names:
                    print(f"     📝 Inline Policies ({len(inline_policy_names)}):")
                    for policy_name in inline_policy_names:
                        print(f"       • {policy_name}")
                        
            except Exception as e:
                print(f"     ❌ Error getting policies: {str(e)}")
    
    except Exception as e:
        logger.error(f"❌ IAM analysis failed: {str(e)}")

def check_agent_core_resources():
    """Check Agent Core related resources"""
    logger = setup_logging()
    
    print("\n🤖 AGENT CORE RESOURCES")
    print("="*60)
    
    try:
        # Check CloudWatch logs for both agents
        logs_client = boto3.client('logs', region_name='us-east-1')
        
        # Look for log groups related to our agents
        log_groups_response = logs_client.describe_log_groups()
        log_groups = log_groups_response.get('logGroups', [])
        
        agent_log_groups = []
        
        for lg in log_groups:
            lg_name = lg.get('logGroupName', '').lower()
            
            if any(keyword in lg_name for keyword in [
                'bedrock',
                'agent',
                'askjulius',
                'chatops',
                'dns',
                'account'
            ]):
                agent_log_groups.append(lg)
        
        print(f"\n📋 Found {len(agent_log_groups)} relevant log groups:")
        
        for lg in agent_log_groups:
            lg_name = lg.get('logGroupName')
            print(f"\n   📊 Log Group: {lg_name}")
            print(f"     Created: {lg.get('creationTime')}")
            print(f"     Retention: {lg.get('retentionInDays', 'Never expire')} days")
            print(f"     Size: {lg.get('storedBytes', 0)} bytes")
            
            # Get recent log streams
            try:
                streams_response = logs_client.describe_log_streams(
                    logGroupName=lg_name,
                    orderBy='LastEventTime',
                    descending=True,
                    limit=3
                )
                
                streams = streams_response.get('logStreams', [])
                if streams:
                    print(f"     📝 Recent streams: {len(streams)}")
                    for stream in streams[:2]:  # Show top 2
                        print(f"       • {stream.get('logStreamName')}")
                        
            except Exception as e:
                print(f"     ❌ Error getting streams: {str(e)}")
    
    except Exception as e:
        logger.error(f"❌ Agent Core resource check failed: {str(e)}")

def generate_recommendations():
    """Generate recommendations based on analysis"""
    
    print("\n💡 RECOMMENDATIONS")
    print("="*60)
    
    recommendations = [
        {
            "title": "Check DNS Lambda Function State",
            "description": "Ensure the DNS lookup Lambda function is in 'Active' state and not 'Pending' or 'Failed'",
            "action": "Review Lambda function configuration and recent deployments"
        },
        {
            "title": "Verify IAM Role Permissions", 
            "description": "Compare IAM roles between working account agent and failing DNS agent",
            "action": "Ensure DNS agent role has same permissions as account agent role"
        },
        {
            "title": "Check Environment Variables",
            "description": "DNS Lambda might be missing required environment variables",
            "action": "Compare environment variables between working and failing Lambda functions"
        },
        {
            "title": "Review Container Image",
            "description": "DNS agent uses ECR container - check if image is properly built and accessible",
            "action": "Verify ECR image exists and Lambda can pull it"
        },
        {
            "title": "Check CloudWatch Logs",
            "description": "Look for specific startup errors in CloudWatch logs",
            "action": "Search for ERROR, INIT_FAIL, or timeout messages in recent logs"
        }
    ]
    
    for i, rec in enumerate(recommendations, 1):
        print(f"\n{i}. {rec['title']}")
        print(f"   📝 {rec['description']}")
        print(f"   🔧 Action: {rec['action']}")
    
    print(f"\n🎯 NEXT STEPS:")
    print(f"1. Copy the exact IAM role ARN from working account agent")
    print(f"2. Update DNS agent to use the same role")
    print(f"3. Compare Lambda function configurations")
    print(f"4. Test DNS Lambda function independently")
    print(f"5. Re-deploy DNS agent if container issues found")

def main():
    """Main execution function"""
    try:
        print("\n🔍 DIRECT AGENT CONFIGURATION ANALYSIS")
        print("="*70)
        print(f"🕒 Started: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        print(f"✅ Working: a208194_askjulius_account_details_agent")
        print(f"❌ Failing: a208194_chatops_route_dns_lookup")
        
        # Run all analysis functions
        check_lambda_functions()
        check_iam_roles()
        check_agent_core_resources()
        generate_recommendations()
        
        print(f"\n✅ Analysis completed!")
        
    except KeyboardInterrupt:
        print("\n🛑 Analysis interrupted by user")
    except Exception as e:
        print(f"\n❌ Unexpected error: {str(e)}")

if __name__ == "__main__":
    main()