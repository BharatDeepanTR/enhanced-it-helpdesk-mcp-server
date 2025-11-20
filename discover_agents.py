#!/usr/bin/env python3
"""
Agent Core Runtime Discovery Script
===================================

Script to discover and analyze available agents in AWS Agent Core Runtime.
This will help us understand the exact configuration needed to test the
ChatOps Route DNS Lookup agent.

Features:
- List all available agents
- Get agent details (ID, aliases, description)
- Identify the correct ChatOps DNS agent
- Show expected input format and capabilities
"""

import boto3
import json
import logging
from datetime import datetime
from typing import Dict, List, Any, Optional

class AgentCoreDiscovery:
    """Agent Core Runtime Discovery Tool"""
    
    def __init__(self):
        """Initialize the discovery tool"""
        self.region = 'us-east-1'
        self.setup_logging()
        self._init_aws_clients()
        
        self.logger.info("🔍 Agent Core Discovery initialized")

    def setup_logging(self):
        """Configure logging"""
        logging.basicConfig(
            level=logging.INFO,
            format='%(asctime)s - %(levelname)s - %(message)s'
        )
        self.logger = logging.getLogger('AgentDiscovery')

    def _init_aws_clients(self):
        """Initialize AWS clients"""
        try:
            # Bedrock Agent client for listing agents
            self.bedrock_agent = boto3.client(
                'bedrock-agent',
                region_name=self.region
            )
            
            # Bedrock Agent Runtime client for testing
            self.bedrock_agent_runtime = boto3.client(
                'bedrock-agent-runtime',
                region_name=self.region
            )
            
            # Verify authentication
            sts = boto3.client('sts', region_name=self.region)
            identity = sts.get_caller_identity()
            
            self.logger.info("✅ AWS clients initialized successfully")
            self.logger.info(f"🔐 Account: {identity.get('Account')}")
            
        except Exception as e:
            self.logger.error(f"❌ AWS initialization failed: {str(e)}")
            raise

    def list_all_agents(self) -> List[Dict[str, Any]]:
        """List all agents in Agent Core Runtime"""
        try:
            self.logger.info("📋 Listing all available agents...")
            
            response = self.bedrock_agent.list_agents(maxResults=50)
            agents = response.get('agentSummaries', [])
            
            self.logger.info(f"🎯 Found {len(agents)} agents")
            
            return agents
            
        except Exception as e:
            self.logger.error(f"❌ Failed to list agents: {str(e)}")
            return []

    def get_agent_details(self, agent_id: str) -> Optional[Dict[str, Any]]:
        """Get detailed information about a specific agent"""
        try:
            self.logger.info(f"🔍 Getting details for agent: {agent_id}")
            
            # Get agent details
            agent_response = self.bedrock_agent.get_agent(agentId=agent_id)
            agent_details = agent_response.get('agent', {})
            
            # Get agent aliases
            aliases_response = self.bedrock_agent.list_agent_aliases(agentId=agent_id)
            aliases = aliases_response.get('agentAliasSummaries', [])
            
            # Combine information
            details = {
                'agent': agent_details,
                'aliases': aliases
            }
            
            return details
            
        except Exception as e:
            self.logger.error(f"❌ Failed to get agent details: {str(e)}")
            return None

    def find_dns_agent(self) -> Optional[Dict[str, Any]]:
        """Find the ChatOps Route DNS Lookup agent"""
        self.logger.info("🔍 Searching for ChatOps Route DNS Lookup agent...")
        
        agents = self.list_all_agents()
        
        # Look for DNS-related agents
        dns_keywords = ['dns', 'route', 'chatops', 'lookup', 'a208194']
        
        for agent in agents:
            agent_name = agent.get('agentName', '').lower()
            agent_id = agent.get('agentId', '').lower()
            description = agent.get('description', '').lower()
            
            # Check if this looks like our DNS agent
            if any(keyword in agent_name or keyword in agent_id or keyword in description 
                   for keyword in dns_keywords):
                
                self.logger.info(f"🎯 Potential DNS agent found: {agent.get('agentName')}")
                
                # Get detailed info
                details = self.get_agent_details(agent.get('agentId'))
                if details:
                    details['summary'] = agent
                    return details
        
        self.logger.warning("⚠️ No DNS agent found matching criteria")
        return None

    def display_agent_info(self, agent_info: Dict[str, Any]):
        """Display detailed agent information"""
        summary = agent_info.get('summary', {})
        agent = agent_info.get('agent', {})
        aliases = agent_info.get('aliases', [])
        
        print("\n" + "="*80)
        print("🤖 AGENT INFORMATION")
        print("="*80)
        
        print(f"📛 Agent Name: {agent.get('agentName', 'N/A')}")
        print(f"🆔 Agent ID: {agent.get('agentId', 'N/A')}")
        print(f"📝 Description: {agent.get('description', 'N/A')}")
        print(f"🔄 Status: {agent.get('agentStatus', 'N/A')}")
        print(f"📅 Created: {agent.get('createdAt', 'N/A')}")
        print(f"📅 Updated: {agent.get('updatedAt', 'N/A')}")
        
        if agent.get('instruction'):
            print(f"\n📋 Instructions:")
            print(f"   {agent['instruction']}")
        
        print(f"\n🏷️ ALIASES ({len(aliases)}):")
        if aliases:
            for alias in aliases:
                print(f"   • {alias.get('agentAliasName', 'N/A')} (ID: {alias.get('agentAliasId', 'N/A')})")
                print(f"     Status: {alias.get('agentAliasStatus', 'N/A')}")
        else:
            print("   No aliases found")
        
        # Check for action groups (tools/functions)
        if 'actionGroups' in agent:
            action_groups = agent.get('actionGroups', [])
            print(f"\n⚙️ ACTION GROUPS ({len(action_groups)}):")
            for ag in action_groups:
                print(f"   • {ag.get('actionGroupName', 'N/A')}")
                if ag.get('description'):
                    print(f"     Description: {ag['description']}")
        
        print("="*80)

    def test_agent_connectivity(self, agent_id: str, alias_id: str = 'TSTALIASID') -> bool:
        """Test if we can connect to the agent"""
        try:
            self.logger.info(f"🧪 Testing connectivity to agent {agent_id} with alias {alias_id}")
            
            # Try a simple test query
            test_query = "Hello, can you help me with DNS lookup?"
            
            response = self.bedrock_agent_runtime.invoke_agent(
                agentId=agent_id,
                agentAliasId=alias_id,
                sessionId=f"test-{datetime.now().strftime('%Y%m%d%H%M%S')}",
                inputText=test_query
            )
            
            self.logger.info("✅ Agent connectivity test successful")
            return True
            
        except Exception as e:
            self.logger.warning(f"⚠️ Agent connectivity test failed: {str(e)}")
            return False

    def run_discovery(self):
        """Run complete agent discovery process"""
        print("\n🔍 AGENT CORE RUNTIME DISCOVERY")
        print("="*50)
        
        # First, try to find the DNS agent specifically
        dns_agent = self.find_dns_agent()
        
        if dns_agent:
            print("✅ Found ChatOps Route DNS Lookup agent!")
            self.display_agent_info(dns_agent)
            
            # Test connectivity with different aliases
            agent_id = dns_agent['agent'].get('agentId')
            aliases = dns_agent.get('aliases', [])
            
            if agent_id:
                print(f"\n🧪 CONNECTIVITY TESTS:")
                print("-" * 30)
                
                # Test with standard aliases
                test_aliases = ['TSTALIASID', 'DRAFT']
                
                # Add any found aliases
                for alias in aliases:
                    alias_id = alias.get('agentAliasId')
                    if alias_id and alias_id not in test_aliases:
                        test_aliases.append(alias_id)
                
                for alias_id in test_aliases:
                    connectivity = self.test_agent_connectivity(agent_id, alias_id)
                    status = "✅ Working" if connectivity else "❌ Failed"
                    print(f"   {alias_id}: {status}")
                
                # Provide usage instructions
                print(f"\n📖 USAGE INSTRUCTIONS:")
                print("-" * 30)
                print(f"Agent ID: {agent_id}")
                print(f"Working Alias: Check connectivity results above")
                print(f"Sample Queries:")
                print(f"   • 'What is the IP address of google.com?'")
                print(f"   • 'dns lookup microsoft.com'") 
                print(f"   • 'Show me routing information for 8.8.8.8'")
                print(f"   • 'route trace to amazon.com'")
        else:
            print("❌ ChatOps Route DNS Lookup agent not found")
            print("\n📋 Available agents:")
            
            agents = self.list_all_agents()
            for i, agent in enumerate(agents, 1):
                print(f"   {i}. {agent.get('agentName', 'N/A')} (ID: {agent.get('agentId', 'N/A')})")

def main():
    """Main execution function"""
    try:
        discovery = AgentCoreDiscovery()
        discovery.run_discovery()
        
    except KeyboardInterrupt:
        print("\n🛑 Discovery interrupted by user")
    except Exception as e:
        print(f"\n❌ Unexpected error: {str(e)}")

if __name__ == "__main__":
    main()