#!/usr/bin/env python3
"""
Simple DNS Agent Core Runtime Diagnostic
========================================

Focus on the key issue: Why is the Agent Core Runtime not starting properly?
"""

import boto3
import json
from datetime import datetime, timezone

def simple_diagnostic():
    """Run a simple diagnostic focused on the core issue"""
    
    print("\n🔍 SIMPLE DNS AGENT RUNTIME DIAGNOSTIC")
    print("="*60)
    print(f"🕒 Started: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print(f"🎯 Target: a208194_chatops_route_dns_lookup")
    print(f"🔧 Goal: Fix runtime startup failure")
    
    # Initialize clients
    try:
        logs_client = boto3.client('logs', region_name='us-east-1')
        ecr_client = boto3.client('ecr', region_name='us-east-1')
        bedrock_agent = boto3.client('bedrock-agent', region_name='us-east-1')
        
        print("\n✅ AWS clients initialized")
        
    except Exception as e:
        print(f"❌ Failed to initialize AWS clients: {str(e)}")
        return
    
    # 1. Check Agent Core logs for any startup errors
    print("\n1️⃣ CHECKING RUNTIME LOGS...")
    try:
        log_group = "/aws/vendedlogs/bedrock-agentcore/runtime/APPLICATION_LOGS/a208194_chatops_route_dns_lookup-Zg3E6G5ZDV"
        
        # Get recent log events
        response = logs_client.describe_log_streams(
            logGroupName=log_group,
            orderBy='LastEventTime',
            descending=True,
            limit=1
        )
        
        if response.get('logStreams'):
            stream = response['logStreams'][0]
            print(f"   📄 Log Stream: {stream['logStreamName']}")
            
            # Get recent events
            try:
                events = logs_client.get_log_events(
                    logGroupName=log_group,
                    logStreamName=stream['logStreamName'],
                    limit=10,
                    startFromHead=False
                )
                
                recent_events = events.get('events', [])
                print(f"   📊 Recent Events: {len(recent_events)}")
                
                if recent_events:
                    print("   📋 Latest Log Messages:")
                    for event in recent_events[-3:]:  # Last 3 events
                        timestamp = datetime.fromtimestamp(event['timestamp']/1000)
                        message = event['message'][:100] + "..." if len(event['message']) > 100 else event['message']
                        print(f"      {timestamp}: {message}")
                else:
                    print("   ⚠️ No recent log events - container may not be starting")
                    
            except Exception as e:
                print(f"   ❌ Cannot read log events: {str(e)}")
        else:
            print("   ❌ No log streams found")
            
    except Exception as e:
        print(f"   ❌ Cannot access logs: {str(e)}")
    
    # 2. Check ECR repository status
    print("\n2️⃣ CHECKING ECR CONTAINER...")
    try:
        repo_response = ecr_client.describe_repositories(
            repositoryNames=['dns-lookup-service']
        )
        
        if repo_response.get('repositories'):
            repo = repo_response['repositories'][0]
            print(f"   📦 Repository: {repo['repositoryName']}")
            print(f"   📅 Created: {repo['createdAt']}")
            
            # Check images
            images = ecr_client.describe_images(
                repositoryName='dns-lookup-service',
                maxResults=3
            )
            
            print(f"   🖼️ Available Images: {len(images.get('imageDetails', []))}")
            
            if images.get('imageDetails'):
                latest = images['imageDetails'][0]
                size_mb = latest.get('imageSizeInBytes', 0) / (1024 * 1024)
                print(f"   📊 Latest Image Size: {size_mb:.1f} MB")
                print(f"   🏷️ Tags: {latest.get('imageTags', ['<no-tags>'])}")
                print(f"   ✅ Container image available")
            else:
                print(f"   ❌ No images found in repository")
        else:
            print("   ❌ ECR repository not found")
            
    except Exception as e:
        print(f"   ❌ Cannot access ECR: {str(e)}")
    
    # 3. Check for Agent Core Runtime agent
    print("\n3️⃣ CHECKING AGENT STATUS...")
    try:
        agents = bedrock_agent.list_agents(maxResults=20)
        
        dns_agent = None
        for agent in agents.get('agentSummaries', []):
            if 'dns' in agent.get('agentName', '').lower():
                dns_agent = agent
                break
        
        if dns_agent:
            print(f"   🤖 Agent Found: {dns_agent['agentName']}")
            print(f"   🆔 Agent ID: {dns_agent['agentId']}")
            print(f"   📊 Status: {dns_agent['agentStatus']}")
            
            # Get agent details
            try:
                agent_details = bedrock_agent.get_agent(agentId=dns_agent['agentId'])
                agent_info = agent_details.get('agent', {})
                
                print(f"   🔧 Foundation Model: {agent_info.get('foundationModel', 'N/A')}")
                print(f"   👤 Service Role: {agent_info.get('agentResourceRoleArn', 'N/A')}")
                
                if agent_info.get('agentStatus') == 'PREPARED':
                    print(f"   ✅ Agent is properly configured")
                else:
                    print(f"   ⚠️ Agent status issue: {agent_info.get('agentStatus')}")
                    
            except Exception as e:
                print(f"   ⚠️ Cannot get agent details: {str(e)}")
        else:
            print("   ❌ DNS agent not found in Bedrock Agents")
            
    except Exception as e:
        print(f"   ❌ Cannot check agent status: {str(e)}")
    
    # 4. Provide actionable recommendations
    print("\n4️⃣ RECOMMENDATIONS...")
    print("   Based on the diagnostics:")
    print()
    print("   🔧 PRIMARY ISSUES TO CHECK:")
    print("   1. Container Entry Point - Check if container has correct ENTRYPOINT")
    print("   2. Application Code - Verify Python code runs without errors")
    print("   3. Dependencies - Ensure all required libraries are installed")
    print("   4. IAM Permissions - Check if runtime has proper execution permissions")
    print()
    print("   🎯 NEXT STEPS:")
    print("   1. Test the container locally: docker run <image>")
    print("   2. Check container logs during startup")
    print("   3. Verify the main application entry point")
    print("   4. Compare with working account agent configuration")
    
    print(f"\n✅ Diagnostic completed at {datetime.now().strftime('%H:%M:%S')}")

if __name__ == "__main__":
    try:
        simple_diagnostic()
    except KeyboardInterrupt:
        print("\n🛑 Diagnostic interrupted by user")
    except Exception as e:
        print(f"\n❌ Diagnostic error: {str(e)}")