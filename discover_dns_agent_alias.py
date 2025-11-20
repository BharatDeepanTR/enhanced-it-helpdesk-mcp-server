#!/usr/bin/env python3
"""
DNS Agent Alias Discovery Script
===============================

This script discovers the correct alias for the DNS agent in Agent Core Runtime.
It will list all available aliases for the agent and test connectivity with each.

Features:
- Get agent details and aliases from Bedrock Agent
- Test connectivity with each alias
- Identify working aliases for testing
- Provide proper configuration for testing
"""

import boto3
import json
import logging
import time
from datetime import datetime
from typing import Dict, List, Any, Optional
import uuid

class DNSAgentAliasDiscovery:
    """DNS Agent Alias Discovery Tool"""
    
    def __init__(self):
        """Initialize the discovery tool"""
        # Agent configuration from user input
        self.agent_name = 'a208194_chatops_route_dns_lookup'
        self.agent_runtime_id = 'a208194_chatops_route_dns_lookup-Zg3E6G5ZDV'
        self.region = 'us-east-1'
        
        self.setup_logging()
        self._init_aws_clients()
        
        self.logger.info("🔍 DNS Agent Alias Discovery initialized")
        self.logger.info(f"🤖 Agent Name: {self.agent_name}")
        self.logger.info(f"🆔 Runtime ID: {self.agent_runtime_id}")

    def setup_logging(self):
        """Configure logging"""
        logging.basicConfig(
            level=logging.INFO,
            format='%(asctime)s - %(levelname)s - %(message)s'
        )
        self.logger = logging.getLogger('DNSAgentAliasDiscovery')

    def _init_aws_clients(self):
        """Initialize AWS clients"""
        try:
            # Bedrock Agent client for agent management
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

    def find_agent_by_name(self) -> Optional[str]:
        """Find agent ID by name"""
        try:
            self.logger.info("🔍 Searching for DNS agent...")
            
            # List all agents
            response = self.bedrock_agent.list_agents(maxResults=50)
            agents = response.get('agentSummaries', [])
            
            # Look for our agent by name
            for agent in agents:
                agent_name = agent.get('agentName', '')
                agent_id = agent.get('agentId', '')
                
                if (self.agent_name.lower() in agent_name.lower() or 
                    self.agent_runtime_id.lower() == agent_id.lower() or
                    'dns' in agent_name.lower()):
                    
                    self.logger.info(f"🎯 Found matching agent: {agent_name} (ID: {agent_id})")
                    return agent_id
            
            # If not found by name, try the runtime ID directly
            self.logger.warning(f"⚠️ Agent not found by name search, trying runtime ID: {self.agent_runtime_id}")
            return self.agent_runtime_id
            
        except Exception as e:
            self.logger.error(f"❌ Failed to find agent: {str(e)}")
            return self.agent_runtime_id  # Fallback to runtime ID

    def get_agent_aliases(self, agent_id: str) -> List[Dict[str, Any]]:
        """Get all aliases for the agent"""
        try:
            self.logger.info(f"📋 Getting aliases for agent: {agent_id}")
            
            response = self.bedrock_agent.list_agent_aliases(
                agentId=agent_id,
                maxResults=20
            )
            
            aliases = response.get('agentAliasSummaries', [])
            self.logger.info(f"🎯 Found {len(aliases)} aliases")
            
            return aliases
            
        except Exception as e:
            self.logger.error(f"❌ Failed to get agent aliases: {str(e)}")
            return []

    def test_alias_connectivity(self, agent_id: str, alias_id: str) -> Dict[str, Any]:
        """Test connectivity with a specific alias"""
        try:
            test_prompt = "Hello, can you help me with a DNS lookup?"
            session_id = f"test-{uuid.uuid4().hex[:8]}"
            
            start_time = time.time()
            
            response = self.bedrock_agent_runtime.invoke_agent(
                agentId=agent_id,
                agentAliasId=alias_id,
                sessionId=session_id,
                inputText=test_prompt
            )
            
            execution_time = time.time() - start_time
            
            # Try to parse response
            response_text = self._parse_agent_response(response)
            
            return {
                'success': True,
                'execution_time': execution_time,
                'response_length': len(response_text),
                'response_preview': response_text[:100] + '...' if len(response_text) > 100 else response_text
            }
            
        except Exception as e:
            execution_time = time.time() - start_time if 'start_time' in locals() else 0
            return {
                'success': False,
                'error': str(e),
                'execution_time': execution_time
            }

    def _parse_agent_response(self, response: Dict[str, Any]) -> str:
        """Parse agent response stream"""
        try:
            response_text = ""
            
            # Handle EventStream response
            if 'completion' in response:
                event_stream = response['completion']
                for event in event_stream:
                    if 'chunk' in event:
                        chunk = event['chunk']
                        if 'bytes' in chunk:
                            chunk_text = chunk['bytes'].decode('utf-8')
                            response_text += chunk_text
            
            return response_text.strip()
            
        except Exception as e:
            self.logger.debug(f"⚠️ Failed to parse response: {str(e)}")
            return "Response received but could not parse"

    def discover_working_aliases(self):
        """Main discovery process"""
        print("\n" + "="*80)
        print("🔍 DNS AGENT ALIAS DISCOVERY")
        print("="*80)
        print(f"🤖 Agent Name: {self.agent_name}")
        print(f"🆔 Runtime ID: {self.agent_runtime_id}")
        print(f"📍 Region: {self.region}")
        print("="*80)
        
        # Step 1: Find the agent
        agent_id = self.find_agent_by_name()
        if not agent_id:
            print("❌ Could not find agent")
            return
        
        print(f"\n✅ Using Agent ID: {agent_id}")
        
        # Step 2: Get aliases
        aliases = self.get_agent_aliases(agent_id)
        
        if not aliases:
            print("⚠️ No aliases found, testing common alias IDs...")
            # Test common aliases
            test_aliases = [
                {'agentAliasId': 'TSTALIASID', 'agentAliasName': 'Test Alias', 'agentAliasStatus': 'UNKNOWN'},
                {'agentAliasId': 'DRAFT', 'agentAliasName': 'Draft', 'agentAliasStatus': 'UNKNOWN'},
                {'agentAliasId': '$LATEST', 'agentAliasName': 'Latest', 'agentAliasStatus': 'UNKNOWN'},
                {'agentAliasId': 'live', 'agentAliasName': 'Live', 'agentAliasStatus': 'UNKNOWN'},
                {'agentAliasId': 'prod', 'agentAliasName': 'Production', 'agentAliasStatus': 'UNKNOWN'},
                {'agentAliasId': 'test', 'agentAliasName': 'Test', 'agentAliasStatus': 'UNKNOWN'}
            ]
            aliases = test_aliases
        
        print(f"\n📋 DISCOVERED ALIASES ({len(aliases)}):")
        print("-" * 50)
        
        working_aliases = []
        
        # Step 3: Test each alias
        for i, alias in enumerate(aliases, 1):
            alias_id = alias.get('agentAliasId')
            alias_name = alias.get('agentAliasName', 'Unknown')
            alias_status = alias.get('agentAliasStatus', 'Unknown')
            
            print(f"\n{i}. Testing alias: {alias_id}")
            print(f"   Name: {alias_name}")
            print(f"   Status: {alias_status}")
            
            # Test connectivity
            test_result = self.test_alias_connectivity(agent_id, alias_id)
            
            if test_result['success']:
                print(f"   ✅ Working! ({test_result['execution_time']:.2f}s)")
                print(f"   Response: {test_result['response_preview']}")
                working_aliases.append({
                    'alias_id': alias_id,
                    'alias_name': alias_name,
                    'status': alias_status,
                    'test_result': test_result
                })
            else:
                print(f"   ❌ Failed: {test_result['error']}")
        
        # Step 4: Report results
        print("\n" + "="*80)
        print("📊 DISCOVERY RESULTS")
        print("="*80)
        
        if working_aliases:
            print(f"✅ Found {len(working_aliases)} working alias(es):")
            print()
            
            for alias in working_aliases:
                print(f"🎯 WORKING ALIAS:")
                print(f"   Alias ID: {alias['alias_id']}")
                print(f"   Name: {alias['alias_name']}")
                print(f"   Status: {alias['status']}")
                print(f"   Response Time: {alias['test_result']['execution_time']:.2f}s")
                print()
            
            print("📖 USAGE INSTRUCTIONS:")
            print("-" * 30)
            print(f"Agent ID: {agent_id}")
            print(f"Working Alias: {working_aliases[0]['alias_id']}")
            print()
            print("Update your test script with:")
            print(f"self.agent_id = '{agent_id}'")
            print(f"test_aliases = ['{working_aliases[0]['alias_id']}']")
            print()
            print("Sample test prompts:")
            print("• 'What is the IP address of google.com?'")
            print("• 'dns lookup microsoft.com'")
            print("• 'Show me routing information for 8.8.8.8'")
            
        else:
            print("❌ No working aliases found")
            print()
            print("🔧 TROUBLESHOOTING:")
            print("1. Check if the agent is properly deployed")
            print("2. Verify IAM permissions for bedrock-agent-runtime:InvokeAgent")
            print("3. Confirm the agent is in PREPARED or VERSIONED state")
            print("4. Check agent logs in CloudWatch")
        
        print("="*80)

def main():
    """Main execution function"""
    try:
        discovery = DNSAgentAliasDiscovery()
        discovery.discover_working_aliases()
        
    except KeyboardInterrupt:
        print("\n🛑 Discovery interrupted by user")
    except Exception as e:
        print(f"\n❌ Unexpected error: {str(e)}")

if __name__ == "__main__":
    main()