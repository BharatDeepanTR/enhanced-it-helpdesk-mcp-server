#!/usr/bin/env python3
"""
Agent Discovery and Configuration Comparison
============================================

First discover all available agents, then compare working vs failing agents.
"""

import boto3
import json
import logging
from datetime import datetime
from typing import Dict, List, Any, Optional

class AgentDiscoveryAndComparison:
    """Discover agents and compare configurations"""
    
    def __init__(self):
        """Initialize the discovery tool"""
        self.region = 'us-east-1'
        self.setup_logging()
        
        # Initialize clients
        self.bedrock_agent = boto3.client('bedrock-agent', region_name=self.region)
        self.bedrock_runtime = boto3.client('bedrock-agent-runtime', region_name=self.region)
        
        self.logger.info("🔍 Agent Discovery and Comparison initialized")

    def setup_logging(self):
        """Configure logging"""
        logging.basicConfig(
            level=logging.INFO,
            format='%(asctime)s - %(levelname)s - %(message)s'
        )
        self.logger = logging.getLogger('AgentDiscovery')

    def discover_all_agents(self) -> List[Dict[str, Any]]:
        """Discover all agents and categorize them"""
        try:
            self.logger.info("📋 Discovering all agents...")
            
            response = self.bedrock_agent.list_agents(maxResults=50)
            agents = response.get('agentSummaries', [])
            
            print("\n" + "="*80)
            print("🤖 ALL AVAILABLE AGENTS")
            print("="*80)
            print(f"📋 Found {len(agents)} total agents")
            
            # Categorize agents
            working_agents = []
            dns_agents = []
            other_agents = []
            
            for i, agent in enumerate(agents, 1):
                agent_name = agent.get('agentName', '').lower()
                agent_id = agent.get('agentId', '')
                status = agent.get('agentStatus', '')
                description = agent.get('description', '')
                
                print(f"\n{i}. {agent.get('agentName')}")
                print(f"   ID: {agent_id}")
                print(f"   Status: {status}")
                print(f"   Created: {agent.get('createdAt', 'N/A')}")
                
                if description:
                    print(f"   Description: {description}")
                
                # Test basic connectivity
                connectivity = self.test_agent_connectivity(agent_id)
                print(f"   Connectivity: {connectivity}")
                
                # Categorize
                if 'account' in agent_name or 'details' in agent_name:
                    working_agents.append(agent)
                    print(f"   📝 Category: ACCOUNT DETAILS AGENT (likely working)")
                elif 'dns' in agent_name or 'route' in agent_name or 'lookup' in agent_name:
                    dns_agents.append(agent)
                    print(f"   📝 Category: DNS AGENT (target for fixing)")
                else:
                    other_agents.append(agent)
                    print(f"   📝 Category: OTHER")
            
            return {
                'all_agents': agents,
                'working_agents': working_agents,
                'dns_agents': dns_agents,
                'other_agents': other_agents
            }
            
        except Exception as e:
            self.logger.error(f"❌ Agent discovery failed: {str(e)}")
            return {'all_agents': [], 'working_agents': [], 'dns_agents': [], 'other_agents': []}

    def test_agent_connectivity(self, agent_id: str) -> str:
        """Test basic agent connectivity"""
        try:
            # Test with common aliases
            aliases = ['TSTALIASID', 'DRAFT', 'PROD']
            
            for alias in aliases:
                try:
                    self.bedrock_runtime.invoke_agent(
                        agentId=agent_id,
                        agentAliasId=alias,
                        sessionId=f"test-{datetime.now().strftime('%Y%m%d%H%M%S')}",
                        inputText="Hello"
                    )
                    return f"✅ Working with {alias}"
                except Exception as e:
                    if "ValidationException" not in str(e):
                        continue
            
            return "❌ Failed all aliases"
            
        except Exception as e:
            return f"❌ Error: {str(e)[:50]}..."

    def get_detailed_agent_config(self, agent_id: str) -> Optional[Dict[str, Any]]:
        """Get detailed agent configuration"""
        try:
            # Get agent details
            agent_response = self.bedrock_agent.get_agent(agentId=agent_id)
            agent = agent_response.get('agent', {})
            
            # Get aliases
            aliases_response = self.bedrock_agent.list_agent_aliases(agentId=agent_id)
            aliases = aliases_response.get('agentAliasSummaries', [])
            
            return {
                'agent': agent,
                'aliases': aliases
            }
            
        except Exception as e:
            self.logger.error(f"❌ Failed to get agent config for {agent_id}: {str(e)}")
            return None

    def compare_working_vs_dns_agents(self, categorized_agents: Dict[str, List]):
        """Compare working account details agents vs DNS agents"""
        
        working_agents = categorized_agents['working_agents']
        dns_agents = categorized_agents['dns_agents']
        
        if not working_agents:
            print("\n❌ No working account details agents found")
            return
        
        if not dns_agents:
            print("\n❌ No DNS agents found")
            return
        
        print("\n" + "="*80)
        print("🔍 CONFIGURATION COMPARISON")
        print("="*80)
        
        # Compare first working agent with DNS agents
        working_agent = working_agents[0]
        working_config = self.get_detailed_agent_config(working_agent['agentId'])
        
        for dns_agent in dns_agents:
            dns_config = self.get_detailed_agent_config(dns_agent['agentId'])
            
            print(f"\n📊 COMPARING:")
            print(f"   ✅ Working: {working_agent.get('agentName')} ({working_agent['agentId']})")
            print(f"   ❌ DNS: {dns_agent.get('agentName')} ({dns_agent['agentId']})")
            
            if working_config and dns_config:
                self.compare_configurations(working_config, dns_config)
            else:
                print("   ⚠️ Could not retrieve configurations for comparison")

    def compare_configurations(self, working_config: Dict, dns_config: Dict):
        """Compare two agent configurations in detail"""
        
        working_agent = working_config['agent']
        dns_agent = dns_config['agent']
        
        print(f"\n🔧 CONFIGURATION DIFFERENCES:")
        
        # Compare key fields
        comparison_fields = [
            ('agentStatus', 'Status'),
            ('foundationModel', 'Foundation Model'),
            ('agentResourceRoleArn', 'Service Role ARN'),
            ('instruction', 'Instructions')
        ]
        
        for field, label in comparison_fields:
            working_value = working_agent.get(field, 'N/A')
            dns_value = dns_agent.get(field, 'N/A')
            
            print(f"\n   📋 {label}:")
            print(f"      ✅ Working: {working_value}")
            print(f"      ❌ DNS:     {dns_value}")
            
            if working_value != dns_value:
                print(f"      🚨 DIFFERENCE DETECTED!")
                
                if field == 'agentResourceRoleArn':
                    print(f"      💡 SOLUTION: Update DNS agent role to: {working_value}")
                elif field == 'agentStatus':
                    print(f"      💡 SOLUTION: Update DNS agent status to: {working_value}")
        
        # Compare aliases
        working_aliases = working_config['aliases']
        dns_aliases = dns_config['aliases']
        
        print(f"\n   🏷️ Aliases:")
        print(f"      ✅ Working: {len(working_aliases)} aliases")
        for alias in working_aliases:
            print(f"         • {alias.get('agentAliasName')} ({alias.get('agentAliasStatus')})")
        
        print(f"      ❌ DNS: {len(dns_aliases)} aliases")
        for alias in dns_aliases:
            print(f"         • {alias.get('agentAliasName')} ({alias.get('agentAliasStatus')})")

    def generate_fix_script(self, categorized_agents: Dict[str, List]):
        """Generate a script to fix the DNS agent configuration"""
        
        working_agents = categorized_agents['working_agents']
        dns_agents = categorized_agents['dns_agents']
        
        if not working_agents or not dns_agents:
            return
        
        working_agent = working_agents[0]
        dns_agent = dns_agents[0]
        
        working_config = self.get_detailed_agent_config(working_agent['agentId'])
        
        if not working_config:
            return
        
        working_role_arn = working_config['agent'].get('agentResourceRoleArn')
        
        print(f"\n" + "="*80)
        print("🛠️ DNS AGENT FIX SCRIPT")
        print("="*80)
        
        print(f"""
# AWS CLI commands to fix the DNS agent configuration

# 1. Update the DNS agent to use the same service role as the working agent
aws bedrock-agent update-agent \\
    --agent-id {dns_agent['agentId']} \\
    --agent-name "{dns_agent['agentName']}" \\
    --agent-resource-role-arn "{working_role_arn}"

# 2. Prepare the agent (if needed)
aws bedrock-agent prepare-agent \\
    --agent-id {dns_agent['agentId']}

# 3. Create or update alias
aws bedrock-agent create-agent-alias \\
    --agent-id {dns_agent['agentId']} \\
    --agent-alias-name "PROD" \\
    --description "Production alias for DNS agent"
""")
        
        print(f"\n💡 MANUAL STEPS:")
        print(f"1. Go to AWS Console → Bedrock → Agents")
        print(f"2. Find agent: {dns_agent['agentName']}")
        print(f"3. Update Service Role to: {working_role_arn}")
        print(f"4. Save and Prepare the agent")
        print(f"5. Create/Update aliases to match working agent")

    def run_discovery_and_comparison(self):
        """Run complete discovery and comparison"""
        
        print(f"\n🔍 AGENT DISCOVERY AND COMPARISON")
        print("="*60)
        print(f"🕒 Started: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        print(f"🌎 Region: {self.region}")
        
        # Discover all agents
        categorized_agents = self.discover_all_agents()
        
        # Compare configurations
        self.compare_working_vs_dns_agents(categorized_agents)
        
        # Generate fix script
        self.generate_fix_script(categorized_agents)
        
        print("="*80)

def main():
    """Main execution function"""
    try:
        discovery = AgentDiscoveryAndComparison()
        discovery.run_discovery_and_comparison()
        
    except KeyboardInterrupt:
        print("\n🛑 Discovery interrupted by user")
    except Exception as e:
        print(f"\n❌ Unexpected error: {str(e)}")

if __name__ == "__main__":
    main()