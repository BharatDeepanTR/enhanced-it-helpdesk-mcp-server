#!/usr/bin/env python3
"""
Agent Configuration Comparison Script
=====================================

This script compares the working agent "a208194_askjulius_account_details_agent" 
with the failing DNS agent to identify configuration differences and fix the invoke issue.

We'll examine:
1. IAM roles and permissions
2. Agent configuration
3. Runtime settings
4. Lambda function configuration
5. Environment variables
"""

import boto3
import json
import logging
from datetime import datetime
from typing import Dict, List, Any, Optional

class AgentConfigurationComparator:
    """Compare agent configurations to identify differences"""
    
    def __init__(self):
        """Initialize the comparator"""
        self.region = 'us-east-1'
        self.setup_logging()
        
                # Agent configuration
        self.working_agent_name = 'a208194_askjulius_account_details_agent'  # Known working agent - CONFIRMED EXISTS
        self.failing_agent_name = 'a208194_chatops_route_dns_lookup'  # Failing DNS agent
        self.failing_agent_runtime_id = 'a208194_chatops_route_dns_lookup-Zg3E6G5ZDV'
        
        self.logger.info("🔍 Agent Configuration Comparator initialized")

    def setup_logging(self):
        """Configure logging"""
        logging.basicConfig(
            level=logging.INFO,
            format='%(asctime)s - %(levelname)s - %(message)s'
        )
        self.logger = logging.getLogger('AgentComparator')

    def find_agent_by_name(self, agent_name: str) -> Optional[Dict[str, Any]]:
        """Find agent by name"""
        try:
            bedrock_agent = boto3.client('bedrock-agent', region_name=self.region)
            
            # List all agents
            response = bedrock_agent.list_agents(maxResults=50)
            agents = response.get('agentSummaries', [])
            
            for agent in agents:
                if agent_name.lower() in agent.get('agentName', '').lower():
                    agent_id = agent.get('agentId')
                    
                    # Get full agent details
                    agent_response = bedrock_agent.get_agent(agentId=agent_id)
                    return {
                        'summary': agent,
                        'details': agent_response.get('agent', {}),
                        'agent_id': agent_id
                    }
            
            return None
            
        except Exception as e:
            self.logger.error(f"❌ Error finding agent {agent_name}: {str(e)}")
            return None

    def get_agent_aliases(self, agent_id: str) -> List[Dict[str, Any]]:
        """Get agent aliases"""
        try:
            bedrock_agent = boto3.client('bedrock-agent', region_name=self.region)
            response = bedrock_agent.list_agent_aliases(agentId=agent_id)
            return response.get('agentAliasSummaries', [])
        except Exception as e:
            self.logger.error(f"❌ Error getting aliases for {agent_id}: {str(e)}")
            return []

    def get_lambda_config(self, function_name: str) -> Optional[Dict[str, Any]]:
        """Get Lambda function configuration"""
        try:
            lambda_client = boto3.client('lambda', region_name=self.region)
            response = lambda_client.get_function(FunctionName=function_name)
            return response
        except Exception as e:
            self.logger.error(f"❌ Error getting Lambda config for {function_name}: {str(e)}")
            return None

    def get_iam_role_details(self, role_arn: str) -> Optional[Dict[str, Any]]:
        """Get IAM role details"""
        try:
            iam = boto3.client('iam', region_name=self.region)
            role_name = role_arn.split('/')[-1]
            
            # Get role
            role_response = iam.get_role(RoleName=role_name)
            
            # Get attached policies
            policies_response = iam.list_attached_role_policies(RoleName=role_name)
            
            # Get inline policies
            inline_policies_response = iam.list_role_policies(RoleName=role_name)
            
            return {
                'role': role_response.get('Role', {}),
                'attached_policies': policies_response.get('AttachedPolicies', []),
                'inline_policies': inline_policies_response.get('PolicyNames', [])
            }
            
        except Exception as e:
            self.logger.error(f"❌ Error getting IAM role details: {str(e)}")
            return None

    def compare_agents(self):
        """Compare the working and failing agents"""
        print("\n🔍 AGENT CONFIGURATION COMPARISON")
        print("="*80)
        print(f"🕒 Started: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        print(f"✅ Working Agent: {self.working_agent_name}")
        print(f"❌ Failing Agent: {self.failing_agent_name}")
        
        # Find both agents
        working_agent = self.find_agent_by_name(self.working_agent_name)
        failing_agent = self.find_agent_by_name(self.failing_agent_name)
        
        if not working_agent:
            print(f"\n❌ Working agent '{self.working_agent_name}' not found")
            return
            
        if not failing_agent:
            print(f"\n❌ Failing agent '{self.failing_agent_name}' not found")
            return
        
        # Compare basic configuration
        self.compare_basic_config(working_agent, failing_agent)
        
        # Compare IAM roles
        self.compare_iam_roles(working_agent, failing_agent)
        
        # Compare aliases
        self.compare_aliases(working_agent, failing_agent)
        
        # Generate recommendations
        self.generate_recommendations(working_agent, failing_agent)

    def compare_basic_config(self, working_agent: Dict, failing_agent: Dict):
        """Compare basic agent configurations"""
        print("\n📋 BASIC CONFIGURATION COMPARISON")
        print("-" * 50)
        
        working_details = working_agent['details']
        failing_details = failing_agent['details']
        
        configs = [
            ('Agent Name', 'agentName'),
            ('Status', 'agentStatus'),
            ('Foundation Model', 'foundationModel'),
            ('Service Role ARN', 'agentResourceRoleArn'),
            ('Customer Encryption Key', 'customerEncryptionKeyArn'),
            ('Idle Session TTL', 'idleSessionTTLInSeconds')
        ]
        
        for display_name, config_key in configs:
            working_val = working_details.get(config_key, 'N/A')
            failing_val = failing_details.get(config_key, 'N/A')
            
            if working_val == failing_val:
                status = "✅ MATCH"
            else:
                status = "❌ DIFFERENT"
            
            print(f"{display_name}:")
            print(f"   Working: {working_val}")
            print(f"   Failing: {failing_val}")
            print(f"   Status: {status}")
            print()

    def compare_iam_roles(self, working_agent: Dict, failing_agent: Dict):
        """Compare IAM roles and permissions"""
        print("\n🔐 IAM ROLE COMPARISON")
        print("-" * 50)
        
        working_role_arn = working_agent['details'].get('agentResourceRoleArn')
        failing_role_arn = failing_agent['details'].get('agentResourceRoleArn')
        
        if not working_role_arn:
            print("❌ Working agent has no service role ARN")
            return
            
        if not failing_role_arn:
            print("❌ Failing agent has no service role ARN")
            return
        
        print(f"Working Role ARN: {working_role_arn}")
        print(f"Failing Role ARN: {failing_role_arn}")
        
        # Get role details
        working_role = self.get_iam_role_details(working_role_arn)
        failing_role = self.get_iam_role_details(failing_role_arn)
        
        if working_role and failing_role:
            print("\n🔍 Policy Comparison:")
            
            working_policies = set(p['PolicyName'] for p in working_role['attached_policies'])
            failing_policies = set(p['PolicyName'] for p in failing_role['attached_policies'])
            
            print(f"Working Agent Policies: {working_policies}")
            print(f"Failing Agent Policies: {failing_policies}")
            
            missing_policies = working_policies - failing_policies
            if missing_policies:
                print(f"❌ Missing Policies in Failing Agent: {missing_policies}")
            else:
                print("✅ All working agent policies are present")
            
            # Compare trust policies
            working_trust = working_role['role'].get('AssumeRolePolicyDocument')
            failing_trust = failing_role['role'].get('AssumeRolePolicyDocument')
            
            if working_trust == failing_trust:
                print("✅ Trust policies match")
            else:
                print("❌ Trust policies differ")
                print(f"Working Trust Policy: {json.dumps(working_trust, indent=2)}")
                print(f"Failing Trust Policy: {json.dumps(failing_trust, indent=2)}")

    def compare_aliases(self, working_agent: Dict, failing_agent: Dict):
        """Compare agent aliases"""
        print("\n🏷️ ALIAS COMPARISON")
        print("-" * 50)
        
        working_aliases = self.get_agent_aliases(working_agent['agent_id'])
        failing_aliases = self.get_agent_aliases(failing_agent['agent_id'])
        
        print(f"Working Agent Aliases ({len(working_aliases)}):")
        for alias in working_aliases:
            print(f"   • {alias.get('agentAliasName')} (ID: {alias.get('agentAliasId')}, Status: {alias.get('agentAliasStatus')})")
        
        print(f"\nFailing Agent Aliases ({len(failing_aliases)}):")
        for alias in failing_aliases:
            print(f"   • {alias.get('agentAliasName')} (ID: {alias.get('agentAliasId')}, Status: {alias.get('agentAliasStatus')})")
        
        # Check for PREPARED aliases
        working_prepared = [a for a in working_aliases if a.get('agentAliasStatus') == 'PREPARED']
        failing_prepared = [a for a in failing_aliases if a.get('agentAliasStatus') == 'PREPARED']
        
        print(f"\nPREPARED Aliases:")
        print(f"   Working: {len(working_prepared)}")
        print(f"   Failing: {len(failing_prepared)}")
        
        if len(working_prepared) > len(failing_prepared):
            print("❌ Failing agent has fewer PREPARED aliases")

    def generate_recommendations(self, working_agent: Dict, failing_agent: Dict):
        """Generate recommendations to fix the failing agent"""
        print("\n💡 RECOMMENDATIONS TO FIX DNS AGENT")
        print("=" * 60)
        
        working_details = working_agent['details']
        failing_details = failing_agent['details']
        
        recommendations = []
        
        # Check service role
        working_role = working_details.get('agentResourceRoleArn')
        failing_role = failing_details.get('agentResourceRoleArn')
        
        if working_role != failing_role:
            recommendations.append({
                'issue': 'Different service roles',
                'action': f'Update failing agent to use working agent\'s service role',
                'working_value': working_role,
                'failing_value': failing_role,
                'priority': 'HIGH'
            })
        
        # Check foundation model
        working_model = working_details.get('foundationModel')
        failing_model = failing_details.get('foundationModel')
        
        if working_model != failing_model:
            recommendations.append({
                'issue': 'Different foundation models',
                'action': f'Update failing agent to use foundation model: {working_model}',
                'working_value': working_model,
                'failing_value': failing_model,
                'priority': 'MEDIUM'
            })
        
        # Check agent status
        working_status = working_details.get('agentStatus')
        failing_status = failing_details.get('agentStatus')
        
        if failing_status != 'PREPARED':
            recommendations.append({
                'issue': 'Agent not in PREPARED state',
                'action': 'Prepare the failing agent',
                'working_value': working_status,
                'failing_value': failing_status,
                'priority': 'HIGH'
            })
        
        # Display recommendations
        if recommendations:
            for i, rec in enumerate(recommendations, 1):
                print(f"\n{i}. {rec['issue']} ({rec['priority']} PRIORITY)")
                print(f"   Action: {rec['action']}")
                print(f"   Working Value: {rec['working_value']}")
                print(f"   Failing Value: {rec['failing_value']}")
        else:
            print("\n✅ No obvious configuration differences found")
            print("💭 The issue might be in the Lambda function or runtime environment")
        
        # Generate specific fix commands
        self.generate_fix_commands(working_agent, failing_agent)

    def generate_fix_commands(self, working_agent: Dict, failing_agent: Dict):
        """Generate specific AWS CLI commands to fix the configuration"""
        print("\n🛠️ AWS CLI FIX COMMANDS")
        print("-" * 40)
        
        working_details = working_agent['details']
        failing_details = failing_agent['details']
        failing_agent_id = failing_agent['agent_id']
        
        working_role = working_details.get('agentResourceRoleArn')
        working_model = working_details.get('foundationModel')
        
        if working_role and failing_details.get('agentResourceRoleArn') != working_role:
            print(f"# Update service role:")
            print(f"aws bedrock-agent update-agent \\")
            print(f"  --agent-id {failing_agent_id} \\")
            print(f"  --agent-name '{failing_details.get('agentName')}' \\")
            print(f"  --agent-resource-role-arn '{working_role}' \\")
            print(f"  --foundation-model '{working_model or 'anthropic.claude-3-sonnet-20240229-v1:0'}' \\")
            print(f"  --instruction '{failing_details.get('instruction', 'DNS lookup and routing assistant')}' \\")
            print(f"  --region {self.region}")
            print()
        
        print("# Prepare the agent:")
        print(f"aws bedrock-agent prepare-agent \\")
        print(f"  --agent-id {failing_agent_id} \\")
        print(f"  --region {self.region}")
        print()
        
        print("# Create/update agent alias:")
        print(f"aws bedrock-agent create-agent-alias \\")
        print(f"  --agent-id {failing_agent_id} \\")
        print(f"  --agent-alias-name 'working-alias' \\")
        print(f"  --description 'Working alias for DNS agent' \\")
        print(f"  --region {self.region}")

def main():
    """Main execution function"""
    try:
        comparator = AgentConfigurationComparator()
        comparator.compare_agents()
        
    except KeyboardInterrupt:
        print("\n🛑 Comparison interrupted by user")
    except Exception as e:
        print(f"\n❌ Unexpected error: {str(e)}")

if __name__ == "__main__":
    main()