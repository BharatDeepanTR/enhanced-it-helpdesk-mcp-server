#!/usr/bin/env python3
"""
Find Correct Agent ID for DNS Lookup Agent
==========================================

The issue is we're using the wrong agent ID format. The runtime ID 
'a208194_chatops_route_dns_lookup-Zg3E6G5ZDV' is too long and contains 
invalid characters. We need to find the correct short agent ID.
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
    return logging.getLogger('AgentIDFinder')

def find_correct_agent_id():
    """Find the correct agent ID for the DNS lookup agent"""
    logger = setup_logging()
    
    try:
        # Initialize Bedrock Agent client
        bedrock_agent = boto3.client('bedrock-agent', region_name='us-east-1')
        
        logger.info("🔍 Searching for DNS lookup agent...")
        
        # List all agents
        response = bedrock_agent.list_agents(maxResults=50)
        agents = response.get('agentSummaries', [])
        
        logger.info(f"📋 Found {len(agents)} agents total")
        
        # Search for DNS-related agents
        dns_agents = []
        keywords = ['dns', 'lookup', 'route', 'chatops', '208194']
        
        print("\n" + "="*80)
        print("🔍 SEARCHING FOR DNS LOOKUP AGENT")
        print("="*80)
        
        for agent in agents:
            agent_name = agent.get('agentName', '').lower()
            agent_id = agent.get('agentId', '')
            description = agent.get('description', '').lower()
            
            # Check if this matches our DNS agent
            if any(keyword in agent_name or keyword in description for keyword in keywords):
                dns_agents.append(agent)
                
                print(f"\n🎯 POTENTIAL MATCH:")
                print(f"   Agent Name: {agent.get('agentName')}")
                print(f"   Agent ID: {agent_id}")
                print(f"   Status: {agent.get('agentStatus')}")
                print(f"   Created: {agent.get('createdAt')}")
                print(f"   Description: {agent.get('description', 'N/A')}")
                
                # Check agent ID format
                if len(agent_id) <= 10 and agent_id.isalnum():
                    print(f"   ✅ Valid Agent ID format")
                else:
                    print(f"   ❌ Invalid Agent ID format (length: {len(agent_id)}, alphanumeric: {agent_id.isalnum()})")
        
        if not dns_agents:
            print("\n❌ No DNS agents found matching search criteria")
            print("\n📋 ALL AVAILABLE AGENTS:")
            for i, agent in enumerate(agents, 1):
                print(f"   {i}. {agent.get('agentName')} (ID: {agent.get('agentId')})")
        else:
            print(f"\n✅ Found {len(dns_agents)} potential DNS agent(s)")
            
            # Test the most likely candidate
            for agent in dns_agents:
                agent_id = agent.get('agentId')
                if len(agent_id) <= 10 and agent_id.isalnum():
                    print(f"\n🧪 Testing agent ID: {agent_id}")
                    test_agent(agent_id, agent.get('agentName'))
                    break
        
        print("="*80)
        
    except Exception as e:
        logger.error(f"❌ Error finding agent: {str(e)}")

def test_agent(agent_id: str, agent_name: str):
    """Test agent connectivity with the found agent ID"""
    logger = logging.getLogger('AgentIDFinder')
    
    try:
        bedrock_runtime = boto3.client('bedrock-agent-runtime', region_name='us-east-1')
        
        # Test with common aliases
        test_aliases = ['TSTALIASID', 'DRAFT', 'PROD', 'TEST']
        
        print(f"\n🧪 CONNECTIVITY TEST FOR: {agent_name}")
        print(f"Agent ID: {agent_id}")
        print("-" * 50)
        
        working_aliases = []
        
        for alias in test_aliases:
            try:
                session_id = f"test-{datetime.now().strftime('%Y%m%d%H%M%S')}"
                
                response = bedrock_runtime.invoke_agent(
                    agentId=agent_id,
                    agentAliasId=alias,
                    sessionId=session_id,
                    inputText="Hello"
                )
                
                print(f"   {alias}: ✅ Working")
                working_aliases.append(alias)
                
            except Exception as e:
                error_msg = str(e)
                if "ValidationException" in error_msg:
                    print(f"   {alias}: ❌ Validation Error")
                elif "ResourceNotFoundException" in error_msg:
                    print(f"   {alias}: ❌ Not Found")
                else:
                    print(f"   {alias}: ❌ {error_msg[:50]}...")
        
        if working_aliases:
            print(f"\n🎉 SUCCESS! Working configuration found:")
            print(f"   Agent ID: {agent_id}")
            print(f"   Working Aliases: {', '.join(working_aliases)}")
            
            # Create a working test script
            create_working_test_script(agent_id, working_aliases[0], agent_name)
        else:
            print(f"\n⚠️ Agent ID {agent_id} found but no working aliases")
            
    except Exception as e:
        logger.error(f"❌ Error testing agent: {str(e)}")

def create_working_test_script(agent_id: str, alias_id: str, agent_name: str):
    """Create a working test script with the correct agent configuration"""
    
    script_content = f'''#!/usr/bin/env python3
"""
Working DNS Agent Test Script
============================
Generated with correct agent configuration.

Agent ID: {agent_id}
Agent Alias: {alias_id} 
Agent Name: {agent_name}
"""

import boto3
import json
import time
from datetime import datetime

def test_dns_agent():
    """Test the DNS agent with working configuration"""
    
    # Correct agent configuration
    AGENT_ID = "{agent_id}"
    AGENT_ALIAS = "{alias_id}"
    
    print("🧪 DNS Agent Test with Working Configuration")
    print("="*50)
    print(f"Agent ID: {{AGENT_ID}}")
    print(f"Agent Alias: {{AGENT_ALIAS}}")
    print(f"Agent Name: {agent_name}")
    print("="*50)
    
    # Initialize client
    client = boto3.client('bedrock-agent-runtime', region_name='us-east-1')
    
    # Test queries
    test_queries = [
        "What is the IP address of google.com?",
        "Can you lookup DNS for amazon.com?",
        "Show me the route to 8.8.8.8",
        "dns lookup microsoft.com",
        "trace route to cloudflare.com"
    ]
    
    for i, query in enumerate(test_queries, 1):
        print(f"\\n{{i}}. Testing: {{query}}")
        print("-" * 40)
        
        try:
            session_id = f"test-{{datetime.now().strftime('%Y%m%d%H%M%S')}}-{{i}}"
            
            start_time = time.time()
            response = client.invoke_agent(
                agentId=AGENT_ID,
                agentAliasId=AGENT_ALIAS,
                sessionId=session_id,
                inputText=query
            )
            execution_time = time.time() - start_time
            
            print(f"✅ SUCCESS ({{execution_time:.2f}}s)")
            
            # Parse response
            if 'completion' in response:
                completion = response['completion'][:200]
                print(f"📋 Response: {{completion}}...")
            else:
                print(f"📋 Response: {{str(response)[:200]}}")
                
        except Exception as e:
            print(f"❌ FAILED: {{str(e)}}")
        
        time.sleep(1)  # Rate limiting
    
    print("\\n🏁 Test completed!")

if __name__ == "__main__":
    test_dns_agent()
'''
    
    filename = f"working_dns_agent_test_{agent_id}.py"
    
    with open(filename, 'w') as f:
        f.write(script_content)
    
    print(f"\n📄 Created working test script: {filename}")
    print(f"💡 Run with: python3 {filename}")

if __name__ == "__main__":
    find_correct_agent_id()