#!/usr/bin/env python3
"""
Agent Core Endpoint DNS Testing Script
======================================

Test the DNS agent using the Agent Core Runtime endpoint approach.
Based on the sandbox configuration:
- Runtime agent: a208194_chatops_route_dns_lookup
- Endpoint: chatops_dns_endpoint

This script will test the agent through the proper endpoint interface.
"""

import boto3
import json
import time
import logging
from datetime import datetime
from typing import Dict, Any, Optional

class AgentCoreEndpointTester:
    """Test DNS agent through Agent Core Runtime endpoint"""
    
    def __init__(self):
        """Initialize the endpoint tester"""
        self.region = 'us-east-1'
        self.setup_logging()
        
        # Configuration from sandbox
        self.runtime_agent = 'a208194_chatops_route_dns_lookup'
        self.endpoint_name = 'chatops_dns_endpoint'
        
        self.logger.info("🚀 Agent Core Endpoint Tester initialized")
        self.logger.info(f"Runtime Agent: {self.runtime_agent}")
        self.logger.info(f"Endpoint: {self.endpoint_name}")

    def setup_logging(self):
        """Configure logging"""
        logging.basicConfig(
            level=logging.INFO,
            format='%(asctime)s - %(levelname)s - %(message)s'
        )
        self.logger = logging.getLogger('EndpointTester')

    def init_clients(self):
        """Initialize AWS clients"""
        try:
            # Initialize Agent Core Runtime client
            self.agent_runtime = boto3.client('bedrock-agent-runtime', region_name=self.region)
            
            # Initialize regular Agent client for discovery
            self.agent_client = boto3.client('bedrock-agent', region_name=self.region)
            
            # Verify authentication
            sts = boto3.client('sts', region_name=self.region)
            identity = sts.get_caller_identity()
            
            self.logger.info("✅ AWS clients initialized")
            self.logger.info(f"Account: {identity.get('Account')}")
            
            return True
            
        except Exception as e:
            self.logger.error(f"❌ Client initialization failed: {str(e)}")
            return False

    def discover_agent_configuration(self):
        """Discover the actual agent configuration"""
        print("\n" + "="*80)
        print("🔍 AGENT CONFIGURATION DISCOVERY")
        print("="*80)
        
        try:
            # List agents to find our DNS agent
            response = self.agent_client.list_agents(maxResults=50)
            agents = response.get('agentSummaries', [])
            
            dns_agent = None
            for agent in agents:
                agent_name = agent.get('agentName', '')
                if self.runtime_agent in agent_name or 'dns' in agent_name.lower():
                    dns_agent = agent
                    break
            
            if dns_agent:
                print(f"✅ Found DNS Agent:")
                print(f"   Name: {dns_agent.get('agentName')}")
                print(f"   ID: {dns_agent.get('agentId')}")
                print(f"   Status: {dns_agent.get('agentStatus')}")
                
                # Get aliases
                agent_id = dns_agent.get('agentId')
                aliases_response = self.agent_client.list_agent_aliases(agentId=agent_id)
                aliases = aliases_response.get('agentAliasSummaries', [])
                
                print(f"\n🏷️ Agent Aliases ({len(aliases)}):")
                for alias in aliases:
                    print(f"   • {alias.get('agentAliasName', 'N/A')} (ID: {alias.get('agentAliasId')}) - {alias.get('agentAliasStatus')}")
                
                return agent_id, aliases
            else:
                print("❌ DNS agent not found in agent list")
                return None, []
                
        except Exception as e:
            print(f"❌ Discovery failed: {str(e)}")
            return None, []

    def test_with_endpoint_approach(self, agent_id: str, aliases: list):
        """Test using the endpoint approach from sandbox"""
        print("\n" + "="*80)
        print("🧪 ENDPOINT-BASED TESTING")
        print("="*80)
        
        # Test queries for DNS functionality
        test_queries = [
            {
                "name": "Basic DNS Lookup",
                "query": "What is the IP address of google.com?"
            },
            {
                "name": "Subdomain Resolution", 
                "query": "Can you lookup DNS for www.amazon.com?"
            },
            {
                "name": "MX Record Query",
                "query": "Show me the MX records for gmail.com"
            },
            {
                "name": "Route Information",
                "query": "Show me the route to 8.8.8.8"
            },
            {
                "name": "ChatOps DNS Command",
                "query": "dns lookup microsoft.com"
            }
        ]
        
        success_count = 0
        
        # Try different aliases
        for alias in aliases:
            alias_id = alias.get('agentAliasId')
            alias_status = alias.get('agentAliasStatus')
            
            if alias_status != 'PREPARED':
                continue
                
            print(f"\n🧪 Testing with alias: {alias_id}")
            print("-" * 50)
            
            for i, test in enumerate(test_queries, 1):
                print(f"\n{i}. {test['name']}")
                print(f"   Query: {test['query']}")
                
                try:
                    session_id = f"endpoint-test-{datetime.now().strftime('%Y%m%d%H%M%S')}-{i}"
                    
                    start_time = time.time()
                    
                    # Invoke agent through runtime
                    response = self.agent_runtime.invoke_agent(
                        agentId=agent_id,
                        agentAliasId=alias_id,
                        sessionId=session_id,
                        inputText=test['query']
                    )
                    
                    execution_time = time.time() - start_time
                    
                    print(f"   ✅ SUCCESS ({execution_time:.2f}s)")
                    success_count += 1
                    
                    # Process response stream
                    self.process_response_stream(response)
                    
                except Exception as e:
                    error_str = str(e)
                    print(f"   ❌ FAILED: {error_str}")
                    
                    if "ValidationException" in error_str:
                        print("      → Validation error (check agent ID format)")
                    elif "ResourceNotFoundException" in error_str:
                        print("      → Resource not found (check agent/alias exists)")
                    elif "AccessDeniedException" in error_str:
                        print("      → Permission denied (check IAM permissions)")
                    
                time.sleep(1)  # Rate limiting
            
            # If we got any successes with this alias, stop trying others
            if success_count > 0:
                break
        
        return success_count, len(test_queries)

    def process_response_stream(self, response: Dict[str, Any]):
        """Process the response stream from agent invocation"""
        try:
            if 'completion' in response:
                completion = response['completion']
                
                # Handle streaming response
                full_text = ""
                for event in completion:
                    if 'chunk' in event:
                        chunk = event['chunk']
                        if 'bytes' in chunk:
                            chunk_text = chunk['bytes'].decode('utf-8')
                            full_text += chunk_text
                
                if full_text:
                    # Truncate for display
                    display_text = full_text[:200] + "..." if len(full_text) > 200 else full_text
                    print(f"   📋 Response: {display_text}")
                else:
                    print("   📋 Response: (Empty response)")
            else:
                print(f"   📋 Response: {str(response)[:200]}...")
                
        except Exception as e:
            print(f"   ⚠️ Response processing error: {str(e)}")

    def test_direct_endpoint_call(self):
        """Test direct endpoint call if endpoint information is available"""
        print("\n" + "="*80)
        print("🔌 DIRECT ENDPOINT TESTING")
        print("="*80)
        
        print(f"Endpoint Name: {self.endpoint_name}")
        print("Note: Direct endpoint testing requires additional endpoint configuration")
        print("This would typically involve HTTP calls to the endpoint URL")
        
        # For now, we'll focus on the agent runtime approach above
        print("Proceeding with agent runtime approach...")

    def run_comprehensive_test(self):
        """Run comprehensive endpoint testing"""
        print("\n🧪 AGENT CORE ENDPOINT COMPREHENSIVE TEST")
        print("="*70)
        print(f"🕒 Started: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        print(f"🤖 Runtime Agent: {self.runtime_agent}")
        print(f"🔌 Endpoint: {self.endpoint_name}")
        print(f"🌎 Region: {self.region}")
        
        # Initialize clients
        if not self.init_clients():
            print("❌ Failed to initialize clients")
            return False
        
        # Discover agent configuration
        agent_id, aliases = self.discover_agent_configuration()
        
        if not agent_id:
            print("❌ Could not find agent configuration")
            return False
        
        # Test with endpoint approach
        success_count, total_tests = self.test_with_endpoint_approach(agent_id, aliases)
        
        # Generate summary
        self.generate_summary(success_count, total_tests, agent_id, aliases)
        
        return success_count > 0

    def generate_summary(self, success_count: int, total_tests: int, agent_id: str, aliases: list):
        """Generate test summary"""
        print("\n" + "="*80)
        print("📊 ENDPOINT TEST SUMMARY")
        print("="*80)
        
        success_rate = (success_count / total_tests * 100) if total_tests > 0 else 0
        
        print(f"🕒 Completed: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        print(f"🤖 Agent ID: {agent_id}")
        print(f"🏷️ Tested Aliases: {len(aliases)}")
        print(f"📊 Success Rate: {success_count}/{total_tests} ({success_rate:.1f}%)")
        
        if success_count > 0:
            print("🎉 DNS Agent is working through Agent Core Runtime!")
            print("\n✅ Confirmed working configuration:")
            print(f"   Agent ID: {agent_id}")
            if aliases:
                working_alias = next((a for a in aliases if a.get('agentAliasStatus') == 'PREPARED'), None)
                if working_alias:
                    print(f"   Working Alias: {working_alias.get('agentAliasId')}")
        else:
            print("❌ DNS Agent is not responding correctly")
            print("\n💡 Troubleshooting suggestions:")
            print("   • Check agent status is PREPARED")
            print("   • Verify agent aliases are PREPARED")
            print("   • Check IAM permissions for bedrock-agent-runtime:InvokeAgent")
            print("   • Verify agent configuration in console")
        
        print("="*80)

def main():
    """Main execution function"""
    try:
        tester = AgentCoreEndpointTester()
        success = tester.run_comprehensive_test()
        
        if success:
            print("\n🎉 Endpoint testing completed successfully!")
        else:
            print("\n⚠️ Endpoint testing encountered issues.")
            
    except KeyboardInterrupt:
        print("\n🛑 Testing interrupted by user")
    except Exception as e:
        print(f"\n❌ Unexpected error: {str(e)}")

if __name__ == "__main__":
    main()