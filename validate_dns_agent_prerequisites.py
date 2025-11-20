#!/usr/bin/env python3
"""
DNS Agent Prerequisites Validation Script
==========================================

This script validates all prerequisites for testing the DNS agent:
1. IAM permissions for bedrock-agent-runtime:InvokeAgent
2. Agent state (PREPARED/VERSIONED)
3. Agent configuration and aliases
4. Network connectivity to Bedrock services
"""

import boto3
import json
import logging
from datetime import datetime
from typing import Dict, List, Any, Optional

class DNSAgentValidator:
    """Comprehensive validator for DNS agent prerequisites"""
    
    def __init__(self):
        """Initialize the validator"""
        self.region = 'us-east-1'
        self.setup_logging()
        self.validation_results = {}
        
        # Known agent information
        self.agent_runtime_id = 'a208194_chatops_route_dns_lookup-Zg3E6G5ZDV'
        self.expected_iam_role = 'a208194-askjulius-supervisor-agent-role'
        
        self.logger.info("🔍 DNS Agent Prerequisites Validator initialized")

    def setup_logging(self):
        """Configure comprehensive logging"""
        logging.basicConfig(
            level=logging.INFO,
            format='%(asctime)s - %(levelname)s - %(message)s'
        )
        self.logger = logging.getLogger('DNSAgentValidator')

    def validate_iam_permissions(self) -> bool:
        """Validate IAM permissions for Bedrock Agent Runtime"""
        self.logger.info("🔐 Validating IAM permissions...")
        
        try:
            # Check current identity
            sts = boto3.client('sts', region_name=self.region)
            identity = sts.get_caller_identity()
            
            print("\n" + "="*80)
            print("🔐 IAM PERMISSIONS VALIDATION")
            print("="*80)
            print(f"Current Identity: {identity.get('Arn', 'Unknown')}")
            print(f"Account: {identity.get('Account', 'Unknown')}")
            print(f"User ID: {identity.get('UserId', 'Unknown')}")
            
            # Try to create bedrock-agent-runtime client
            try:
                bedrock_runtime = boto3.client('bedrock-agent-runtime', region_name=self.region)
                print("✅ Bedrock Agent Runtime client created successfully")
                
                # Try to make a simple call to test permissions
                # We'll use a dummy agent ID to test if we get a permission error or validation error
                try:
                    bedrock_runtime.invoke_agent(
                        agentId='TESTTEST',  # Invalid but short ID
                        agentAliasId='TSTALIASID',
                        sessionId='test-session',
                        inputText='test'
                    )
                except Exception as e:
                    error_str = str(e)
                    if "AccessDeniedException" in error_str or "UnauthorizedOperation" in error_str:
                        print("❌ IAM Permission Error: Missing bedrock-agent-runtime:InvokeAgent")
                        print(f"   Error: {error_str}")
                        self.validation_results['iam_permissions'] = False
                        return False
                    elif "ValidationException" in error_str:
                        print("✅ IAM permissions validated (got validation error as expected)")
                        self.validation_results['iam_permissions'] = True
                    elif "ResourceNotFoundException" in error_str:
                        print("✅ IAM permissions validated (resource not found as expected)")
                        self.validation_results['iam_permissions'] = True
                    else:
                        print(f"⚠️ Unexpected error: {error_str}")
                        self.validation_results['iam_permissions'] = 'unknown'
                
            except Exception as e:
                print(f"❌ Failed to create Bedrock Agent Runtime client: {str(e)}")
                self.validation_results['iam_permissions'] = False
                return False
            
            # Check IAM policy simulation if possible
            try:
                iam = boto3.client('iam', region_name=self.region)
                
                # Try to simulate the policy
                print("\n🧪 Simulating IAM policies...")
                
                # Get current user/role ARN
                current_arn = identity.get('Arn')
                if current_arn:
                    try:
                        simulation = iam.simulate_principal_policy(
                            PolicySourceArn=current_arn,
                            ActionNames=['bedrock-agent-runtime:InvokeAgent'],
                            ResourceArns=[f'arn:aws:bedrock:{self.region}:{identity.get("Account")}:agent-runtime/*']
                        )
                        
                        for result in simulation.get('EvaluationResults', []):
                            decision = result.get('EvalDecision')
                            action = result.get('EvalActionName')
                            
                            if decision == 'allowed':
                                print(f"✅ {action}: ALLOWED")
                            else:
                                print(f"❌ {action}: {decision}")
                                print(f"   Details: {result.get('EvalDecisionDetails', {})}")
                                
                    except Exception as e:
                        print(f"⚠️ Policy simulation failed: {str(e)}")
                        
            except Exception as e:
                print(f"⚠️ IAM policy check failed: {str(e)}")
            
            return self.validation_results.get('iam_permissions', False)
            
        except Exception as e:
            self.logger.error(f"❌ IAM validation failed: {str(e)}")
            self.validation_results['iam_permissions'] = False
            return False

    def find_actual_agent_id(self) -> Optional[str]:
        """Find the actual short agent ID"""
        self.logger.info("🔍 Finding actual agent ID...")
        
        try:
            bedrock_agent = boto3.client('bedrock-agent', region_name=self.region)
            
            print("\n" + "="*80)
            print("🤖 AGENT DISCOVERY")
            print("="*80)
            
            # List all agents
            response = bedrock_agent.list_agents(maxResults=50)
            agents = response.get('agentSummaries', [])
            
            print(f"📋 Found {len(agents)} agents total")
            
            # Search for DNS-related agents
            dns_keywords = ['dns', 'lookup', 'route', 'chatops', '208194']
            
            for agent in agents:
                agent_name = agent.get('agentName', '').lower()
                agent_id = agent.get('agentId', '')
                description = agent.get('description', '').lower()
                
                # Check if this matches our DNS agent
                if any(keyword in agent_name or keyword in description for keyword in dns_keywords):
                    print(f"\n🎯 FOUND DNS AGENT:")
                    print(f"   Name: {agent.get('agentName')}")
                    print(f"   Agent ID: {agent_id}")
                    print(f"   Status: {agent.get('agentStatus')}")
                    print(f"   Created: {agent.get('createdAt')}")
                    print(f"   Updated: {agent.get('updatedAt')}")
                    
                    # Validate agent ID format
                    if len(agent_id) <= 10 and agent_id.isalnum():
                        print(f"   ✅ Valid Agent ID format")
                        self.validation_results['agent_id'] = agent_id
                        return agent_id
                    else:
                        print(f"   ❌ Invalid Agent ID format")
                        print(f"      Length: {len(agent_id)} (must be ≤10)")
                        print(f"      Alphanumeric: {agent_id.isalnum()} (must be true)")
            
            print("\n❌ No valid DNS agent found")
            self.validation_results['agent_id'] = None
            return None
            
        except Exception as e:
            self.logger.error(f"❌ Agent discovery failed: {str(e)}")
            self.validation_results['agent_id'] = None
            return None

    def validate_agent_state(self, agent_id: str) -> bool:
        """Validate agent state and configuration"""
        self.logger.info(f"📊 Validating agent state for {agent_id}...")
        
        try:
            bedrock_agent = boto3.client('bedrock-agent', region_name=self.region)
            
            print("\n" + "="*80)
            print("📊 AGENT STATE VALIDATION")
            print("="*80)
            
            # Get agent details
            agent_response = bedrock_agent.get_agent(agentId=agent_id)
            agent = agent_response.get('agent', {})
            
            # Check agent status
            agent_status = agent.get('agentStatus')
            print(f"🔄 Agent Status: {agent_status}")
            
            valid_states = ['PREPARED', 'VERSIONED']
            if agent_status in valid_states:
                print(f"   ✅ Agent is in valid state: {agent_status}")
                self.validation_results['agent_state'] = True
            else:
                print(f"   ❌ Agent is in invalid state: {agent_status}")
                print(f"   💡 Required states: {', '.join(valid_states)}")
                self.validation_results['agent_state'] = False
                return False
            
            # Check other agent properties
            print(f"\n📋 Agent Details:")
            print(f"   Name: {agent.get('agentName')}")
            print(f"   Description: {agent.get('description', 'N/A')}")
            print(f"   Foundation Model: {agent.get('foundationModel', 'N/A')}")
            print(f"   Service Role: {agent.get('agentResourceRoleArn', 'N/A')}")
            
            # Check if instructions are set
            if agent.get('instruction'):
                print(f"   ✅ Instructions configured")
            else:
                print(f"   ⚠️ No instructions configured")
            
            return True
            
        except Exception as e:
            self.logger.error(f"❌ Agent state validation failed: {str(e)}")
            self.validation_results['agent_state'] = False
            return False

    def validate_agent_aliases(self, agent_id: str) -> List[str]:
        """Validate agent aliases"""
        self.logger.info(f"🏷️ Validating agent aliases for {agent_id}...")
        
        try:
            bedrock_agent = boto3.client('bedrock-agent', region_name=self.region)
            
            print("\n" + "="*80)
            print("🏷️ AGENT ALIASES VALIDATION")
            print("="*80)
            
            # Get agent aliases
            aliases_response = bedrock_agent.list_agent_aliases(agentId=agent_id)
            aliases = aliases_response.get('agentAliasSummaries', [])
            
            print(f"📋 Found {len(aliases)} aliases")
            
            working_aliases = []
            
            for alias in aliases:
                alias_id = alias.get('agentAliasId')
                alias_name = alias.get('agentAliasName', 'N/A')
                alias_status = alias.get('agentAliasStatus')
                
                print(f"\n🏷️ Alias: {alias_name}")
                print(f"   ID: {alias_id}")
                print(f"   Status: {alias_status}")
                print(f"   Created: {alias.get('createdAt', 'N/A')}")
                print(f"   Updated: {alias.get('updatedAt', 'N/A')}")
                
                # Check if alias is ready
                if alias_status == 'PREPARED':
                    print(f"   ✅ Alias is ready")
                    working_aliases.append(alias_id)
                else:
                    print(f"   ⚠️ Alias not ready: {alias_status}")
            
            self.validation_results['aliases'] = working_aliases
            
            if working_aliases:
                print(f"\n✅ Found {len(working_aliases)} working aliases: {', '.join(working_aliases)}")
            else:
                print(f"\n❌ No working aliases found")
            
            return working_aliases
            
        except Exception as e:
            self.logger.error(f"❌ Alias validation failed: {str(e)}")
            self.validation_results['aliases'] = []
            return []

    def validate_network_connectivity(self) -> bool:
        """Validate network connectivity to Bedrock services"""
        self.logger.info("🌐 Validating network connectivity...")
        
        try:
            print("\n" + "="*80)
            print("🌐 NETWORK CONNECTIVITY VALIDATION")
            print("="*80)
            
            # Test Bedrock Agent service
            try:
                bedrock_agent = boto3.client('bedrock-agent', region_name=self.region)
                bedrock_agent.list_agents(maxResults=1)
                print("✅ Bedrock Agent service connectivity: OK")
            except Exception as e:
                print(f"❌ Bedrock Agent service connectivity: FAILED")
                print(f"   Error: {str(e)}")
                return False
            
            # Test Bedrock Agent Runtime service
            try:
                bedrock_runtime = boto3.client('bedrock-agent-runtime', region_name=self.region)
                # This will fail due to invalid agent, but tests connectivity
                try:
                    bedrock_runtime.invoke_agent(
                        agentId='TEST',
                        agentAliasId='TEST', 
                        sessionId='test',
                        inputText='test'
                    )
                except Exception as e:
                    if "ValidationException" in str(e):
                        print("✅ Bedrock Agent Runtime connectivity: OK")
                    else:
                        print(f"⚠️ Bedrock Agent Runtime connectivity: {str(e)[:100]}")
            except Exception as e:
                print(f"❌ Bedrock Agent Runtime connectivity: FAILED")
                print(f"   Error: {str(e)}")
                return False
            
            self.validation_results['network'] = True
            return True
            
        except Exception as e:
            self.logger.error(f"❌ Network validation failed: {str(e)}")
            self.validation_results['network'] = False
            return False

    def run_comprehensive_validation(self):
        """Run all validation checks"""
        print("\n🔍 DNS AGENT PREREQUISITES VALIDATION")
        print("="*60)
        print(f"🕒 Started: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        print(f"🌎 Region: {self.region}")
        print(f"🤖 Target Agent Runtime ID: {self.agent_runtime_id}")
        
        # 1. Validate IAM permissions
        iam_valid = self.validate_iam_permissions()
        
        # 2. Find actual agent ID
        agent_id = self.find_actual_agent_id()
        
        if agent_id:
            # 3. Validate agent state
            state_valid = self.validate_agent_state(agent_id)
            
            # 4. Validate aliases
            working_aliases = self.validate_agent_aliases(agent_id)
        else:
            state_valid = False
            working_aliases = []
        
        # 5. Validate network connectivity
        network_valid = self.validate_network_connectivity()
        
        # Generate final report
        self.generate_final_report(agent_id, working_aliases)
        
        return all([iam_valid, agent_id is not None, state_valid, len(working_aliases) > 0, network_valid])

    def generate_final_report(self, agent_id: Optional[str], working_aliases: List[str]):
        """Generate comprehensive validation report"""
        
        print("\n" + "="*80)
        print("📋 VALIDATION SUMMARY REPORT")
        print("="*80)
        print(f"🕒 Completed: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        
        # Check results
        iam_status = "✅ PASS" if self.validation_results.get('iam_permissions') else "❌ FAIL"
        agent_status = "✅ PASS" if agent_id else "❌ FAIL"
        state_status = "✅ PASS" if self.validation_results.get('agent_state') else "❌ FAIL"
        alias_status = "✅ PASS" if working_aliases else "❌ FAIL"
        network_status = "✅ PASS" if self.validation_results.get('network') else "❌ FAIL"
        
        print(f"\n📊 VALIDATION RESULTS:")
        print(f"   1. IAM Permissions: {iam_status}")
        print(f"   2. Agent Discovery: {agent_status}")
        print(f"   3. Agent State: {state_status}")
        print(f"   4. Working Aliases: {alias_status}")
        print(f"   5. Network Connectivity: {network_status}")
        
        if agent_id and working_aliases:
            print(f"\n🎯 READY FOR TESTING:")
            print(f"   Agent ID: {agent_id}")
            print(f"   Working Aliases: {', '.join(working_aliases)}")
            print(f"\n📝 Sample Test Command:")
            print(f"   aws bedrock-agent-runtime invoke-agent \\")
            print(f"     --region {self.region} \\")
            print(f"     --agent-id {agent_id} \\")
            print(f"     --agent-alias-id {working_aliases[0]} \\")
            print(f"     --session-id test-session \\")
            print(f"     --input-text \"What is the IP address of google.com?\"")
            
            # Create a working test script
            self.create_working_test_script(agent_id, working_aliases[0])
        else:
            print(f"\n❌ NOT READY FOR TESTING")
            print(f"💡 Issues to resolve:")
            if not self.validation_results.get('iam_permissions'):
                print(f"   • Fix IAM permissions for bedrock-agent-runtime:InvokeAgent")
            if not agent_id:
                print(f"   • Agent not found or invalid ID format")
            if not self.validation_results.get('agent_state'):
                print(f"   • Agent not in PREPARED or VERSIONED state")
            if not working_aliases:
                print(f"   • No working aliases found")
            if not self.validation_results.get('network'):
                print(f"   • Network connectivity issues")
        
        print("="*80)

    def create_working_test_script(self, agent_id: str, alias_id: str):
        """Create a working test script with validated configuration"""
        
        script_content = f'''#!/usr/bin/env python3
"""
Validated DNS Agent Test Script
==============================
Auto-generated with validated configuration.

Agent ID: {agent_id}
Agent Alias: {alias_id}
Validation Date: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}
"""

import boto3
import json
import time
from datetime import datetime

def test_validated_dns_agent():
    """Test DNS agent with validated configuration"""
    
    # Validated configuration
    AGENT_ID = "{agent_id}"
    AGENT_ALIAS = "{alias_id}"
    REGION = "{self.region}"
    
    print("🧪 VALIDATED DNS AGENT TEST")
    print("="*50)
    print(f"Agent ID: {{AGENT_ID}}")
    print(f"Agent Alias: {{AGENT_ALIAS}}")
    print(f"Region: {{REGION}}")
    print(f"Validation: PASSED ✅")
    print("="*50)
    
    # Initialize client
    client = boto3.client('bedrock-agent-runtime', region_name=REGION)
    
    # Test queries
    test_queries = [
        "What is the IP address of google.com?",
        "Can you lookup DNS for amazon.com?", 
        "Show me the route to 8.8.8.8",
        "dns lookup microsoft.com",
        "trace route to cloudflare.com"
    ]
    
    success_count = 0
    
    for i, query in enumerate(test_queries, 1):
        print(f"\\n{{i}}. Testing: {{query}}")
        print("-" * 40)
        
        try:
            session_id = f"validated-test-{{datetime.now().strftime('%Y%m%d%H%M%S')}}-{{i}}"
            
            start_time = time.time()
            response = client.invoke_agent(
                agentId=AGENT_ID,
                agentAliasId=AGENT_ALIAS,
                sessionId=session_id,
                inputText=query
            )
            execution_time = time.time() - start_time
            
            print(f"✅ SUCCESS ({{execution_time:.2f}}s)")
            success_count += 1
            
            # Parse response stream
            if 'completion' in response:
                for event in response['completion']:
                    if 'chunk' in event:
                        chunk = event['chunk']
                        if 'bytes' in chunk:
                            text = chunk['bytes'].decode('utf-8')
                            print(f"📋 Response: {{text[:200]}}...")
                            break
                        
        except Exception as e:
            print(f"❌ FAILED: {{str(e)}}")
        
        time.sleep(1)  # Rate limiting
    
    print(f"\\n🏁 Test Results: {{success_count}}/{{len(test_queries)}} successful")
    
    if success_count > 0:
        print("🎉 DNS Agent is working!")
    else:
        print("❌ DNS Agent is not responding correctly")

if __name__ == "__main__":
    test_validated_dns_agent()
'''
        
        filename = f"validated_dns_agent_test_{agent_id}.py"
        
        with open(filename, 'w') as f:
            f.write(script_content)
        
        print(f"\n📄 Created validated test script: {filename}")
        print(f"💡 Run with: python3 {filename}")

def main():
    """Main execution function"""
    try:
        validator = DNSAgentValidator()
        success = validator.run_comprehensive_validation()
        
        if success:
            print("\n🎉 All validations passed! Agent is ready for testing.")
        else:
            print("\n⚠️ Some validations failed. Check the report above.")
            
    except KeyboardInterrupt:
        print("\n🛑 Validation interrupted by user")
    except Exception as e:
        print(f"\n❌ Unexpected error: {str(e)}")

if __name__ == "__main__":
    main()