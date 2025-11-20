#!/usr/bin/env python3
"""
DNS Agent Remediation Script
============================

Based on the analysis, this script will:
1. Find and compare the working account agent's IAM role
2. Update DNS agent to use the same role
3. Check and fix Lambda function configuration
4. Verify environment variables
5. Test the fixes

Working Agent: a208194_askjulius_account_details_agent
Failing Agent: a208194_chatops_route_dns_lookup
"""

import boto3
import json
import logging
import time
from datetime import datetime
from typing import Dict, List, Any, Optional

class DNSAgentRemediator:
    """Remediate DNS Agent using working agent configuration"""
    
    def __init__(self):
        """Initialize the remediator"""
        self.region = 'us-east-1'
        self.setup_logging()
        
        # Known function names to check
        self.dns_lambda_candidates = [
            'a208194-dns-lookup-service',
            'a208194-chatops-dns-lookup',
            'a208194-route-dns-lookup',
            'dns-lookup-service',
            'chatops-route-dns',
            'a208194-mcp-dns-server'
        ]
        
        # Known working configuration
        self.working_agent_role = None
        self.working_lambda_config = None
        
        self.logger.info("🛠️ DNS Agent Remediator initialized")

    def setup_logging(self):
        """Configure logging"""
        logging.basicConfig(
            level=logging.INFO,
            format='%(asctime)s - %(levelname)s - %(message)s'
        )
        self.logger = logging.getLogger('DNSRemediator')

    def find_working_agent_role(self) -> Optional[str]:
        """Find the IAM role used by the working account agent"""
        try:
            self.logger.info("🔍 Finding working agent's IAM role...")
            
            # Look for Lambda functions that might belong to the working agent
            lambda_client = boto3.client('lambda', region_name=self.region)
            
            # Search for account details related functions
            account_lambda_candidates = [
                'a208194-account-details',
                'a208194-askjulius-account-details',
                'account-details-agent',
                'a208194-mcp-account-details',
                'askjulius-account-details'
            ]
            
            print("\n🔍 SEARCHING FOR WORKING AGENT LAMBDA FUNCTION")
            print("="*60)
            
            # List all functions and find matches
            paginator = lambda_client.get_paginator('list_functions')
            
            for page in paginator.paginate():
                for func in page['Functions']:
                    func_name = func['FunctionName']
                    
                    # Check if this matches account details pattern
                    for candidate in account_lambda_candidates:
                        if candidate in func_name.lower():
                            print(f"🎯 FOUND POTENTIAL WORKING LAMBDA:")
                            print(f"   Function Name: {func_name}")
                            print(f"   Role: {func['Role']}")
                            print(f"   Runtime: {func['Runtime']}")
                            print(f"   Last Modified: {func['LastModified']}")
                            
                            # Store the working configuration
                            self.working_agent_role = func['Role']
                            self.working_lambda_config = func
                            
                            return func['Role']
            
            # If not found, let's check IAM roles directly
            print("\n🔍 CHECKING IAM ROLES DIRECTLY")
            print("-" * 40)
            
            iam_client = boto3.client('iam', region_name=self.region)
            
            # Look for roles that might belong to the working agent
            paginator = iam_client.get_paginator('list_roles')
            
            for page in paginator.paginate():
                for role in page['Roles']:
                    role_name = role['RoleName']
                    
                    # Check for patterns that match working agent
                    if any(pattern in role_name.lower() for pattern in ['askjulius', 'account', 'supervisor']):
                        print(f"🎯 FOUND POTENTIAL WORKING ROLE:")
                        print(f"   Role Name: {role_name}")
                        print(f"   Role ARN: {role['Arn']}")
                        print(f"   Created: {role['CreateDate']}")
                        
                        # Check role policies
                        try:
                            attached_policies = iam_client.list_attached_role_policies(RoleName=role_name)
                            print(f"   Attached Policies: {len(attached_policies['AttachedPolicies'])}")
                            
                            for policy in attached_policies['AttachedPolicies'][:3]:  # Show first 3
                                print(f"     - {policy['PolicyName']}")
                            
                            # This is likely our working role
                            self.working_agent_role = role['Arn']
                            return role['Arn']
                            
                        except Exception as e:
                            print(f"   ⚠️ Error checking policies: {str(e)}")
            
            print("\n❌ Could not find working agent's IAM role")
            return None
            
        except Exception as e:
            self.logger.error(f"❌ Error finding working agent role: {str(e)}")
            return None

    def find_dns_lambda_function(self) -> Optional[Dict[str, Any]]:
        """Find the DNS Lambda function"""
        try:
            self.logger.info("🔍 Finding DNS Lambda function...")
            
            lambda_client = boto3.client('lambda', region_name=self.region)
            
            print("\n🔍 SEARCHING FOR DNS LAMBDA FUNCTION")
            print("="*50)
            
            # List all functions and find matches
            paginator = lambda_client.get_paginator('list_functions')
            
            for page in paginator.paginate():
                for func in page['Functions']:
                    func_name = func['FunctionName']
                    
                    # Check if this matches DNS pattern
                    for candidate in self.dns_lambda_candidates:
                        if candidate in func_name.lower():
                            print(f"🎯 FOUND DNS LAMBDA:")
                            print(f"   Function Name: {func_name}")
                            print(f"   Role: {func['Role']}")
                            print(f"   Runtime: {func['Runtime']}")
                            print(f"   State: {func.get('State', 'Unknown')}")
                            print(f"   Last Modified: {func['LastModified']}")
                            print(f"   Code Size: {func['CodeSize']} bytes")
                            
                            # Check if it's a container image
                            if func.get('PackageType') == 'Image':
                                print(f"   📦 Package Type: Container Image")
                                print(f"   🐳 Image URI: {func.get('Code', {}).get('ImageUri', 'N/A')}")
                            
                            return func
            
            print("\n❌ DNS Lambda function not found")
            return None
            
        except Exception as e:
            self.logger.error(f"❌ Error finding DNS Lambda: {str(e)}")
            return None

    def compare_configurations(self, working_role: str, dns_lambda: Dict[str, Any]) -> Dict[str, Any]:
        """Compare configurations between working and failing setups"""
        
        print("\n" + "="*80)
        print("📊 CONFIGURATION COMPARISON")
        print("="*80)
        
        comparison = {
            'role_mismatch': False,
            'env_var_issues': [],
            'config_issues': [],
            'recommendations': []
        }
        
        # Compare IAM roles
        dns_role = dns_lambda.get('Role', '')
        print(f"👤 IAM ROLE COMPARISON:")
        print(f"   ✅ Working Agent Role: {working_role}")
        print(f"   {'❌' if dns_role != working_role else '✅'} DNS Agent Role: {dns_role}")
        
        if dns_role != working_role:
            comparison['role_mismatch'] = True
            comparison['recommendations'].append(f"Update DNS Lambda role to: {working_role}")
        
        # Check Lambda state
        lambda_state = dns_lambda.get('State', 'Unknown')
        print(f"\n🔄 LAMBDA STATE:")
        print(f"   State: {lambda_state}")
        
        if lambda_state != 'Active':
            comparison['config_issues'].append(f"Lambda state is '{lambda_state}', should be 'Active'")
        
        # Check timeout and memory
        timeout = dns_lambda.get('Timeout', 0)
        memory = dns_lambda.get('MemorySize', 0)
        
        print(f"\n⚙️ LAMBDA CONFIGURATION:")
        print(f"   Timeout: {timeout} seconds")
        print(f"   Memory: {memory} MB")
        print(f"   Runtime: {dns_lambda.get('Runtime', 'Container')}")
        
        if timeout < 30:
            comparison['config_issues'].append(f"Timeout too low: {timeout}s (recommended: 60s+)")
        if memory < 512:
            comparison['config_issues'].append(f"Memory too low: {memory}MB (recommended: 1024MB+)")
        
        # Check environment variables
        env_vars = dns_lambda.get('Environment', {}).get('Variables', {})
        print(f"\n🌍 ENVIRONMENT VARIABLES:")
        
        if env_vars:
            for key, value in env_vars.items():
                print(f"   {key}: {value}")
        else:
            print("   No environment variables set")
            comparison['env_var_issues'].append("No environment variables configured")
        
        return comparison

    def fix_dns_lambda_configuration(self, dns_lambda: Dict[str, Any], working_role: str) -> bool:
        """Fix DNS Lambda configuration"""
        try:
            lambda_client = boto3.client('lambda', region_name=self.region)
            func_name = dns_lambda['FunctionName']
            
            print(f"\n🛠️ FIXING DNS LAMBDA CONFIGURATION")
            print("="*50)
            
            updates_made = []
            
            # 1. Update IAM role if needed
            current_role = dns_lambda.get('Role', '')
            if current_role != working_role:
                print(f"🔧 Updating IAM role...")
                try:
                    lambda_client.update_function_configuration(
                        FunctionName=func_name,
                        Role=working_role
                    )
                    updates_made.append("IAM role updated")
                    print(f"   ✅ Role updated to: {working_role}")
                except Exception as e:
                    print(f"   ❌ Failed to update role: {str(e)}")
                    return False
            
            # 2. Update timeout and memory if needed
            current_timeout = dns_lambda.get('Timeout', 0)
            current_memory = dns_lambda.get('MemorySize', 0)
            
            if current_timeout < 60 or current_memory < 1024:
                print(f"🔧 Updating timeout and memory...")
                try:
                    lambda_client.update_function_configuration(
                        FunctionName=func_name,
                        Timeout=max(60, current_timeout),
                        MemorySize=max(1024, current_memory)
                    )
                    updates_made.append("Timeout and memory updated")
                    print(f"   ✅ Timeout: {max(60, current_timeout)}s, Memory: {max(1024, current_memory)}MB")
                except Exception as e:
                    print(f"   ❌ Failed to update configuration: {str(e)}")
            
            # 3. Add essential environment variables if missing
            env_vars = dns_lambda.get('Environment', {}).get('Variables', {})
            
            essential_env_vars = {
                'AWS_REGION': self.region,
                'LOG_LEVEL': 'INFO'
            }
            
            updated_env_vars = env_vars.copy()
            env_updated = False
            
            for key, value in essential_env_vars.items():
                if key not in updated_env_vars:
                    updated_env_vars[key] = value
                    env_updated = True
            
            if env_updated:
                print(f"🔧 Adding environment variables...")
                try:
                    lambda_client.update_function_configuration(
                        FunctionName=func_name,
                        Environment={'Variables': updated_env_vars}
                    )
                    updates_made.append("Environment variables updated")
                    print(f"   ✅ Environment variables updated")
                except Exception as e:
                    print(f"   ❌ Failed to update environment variables: {str(e)}")
            
            if updates_made:
                print(f"\n✅ Configuration updates completed:")
                for update in updates_made:
                    print(f"   • {update}")
                
                # Wait for updates to propagate
                print(f"\n⏳ Waiting for configuration to propagate...")
                time.sleep(10)
                
                return True
            else:
                print(f"\n✅ No configuration updates needed")
                return True
            
        except Exception as e:
            self.logger.error(f"❌ Error fixing Lambda configuration: {str(e)}")
            return False

    def test_dns_lambda_directly(self, func_name: str) -> bool:
        """Test DNS Lambda function directly"""
        try:
            print(f"\n🧪 TESTING DNS LAMBDA DIRECTLY")
            print("="*40)
            
            lambda_client = boto3.client('lambda', region_name=self.region)
            
            # Test payload for DNS lookup
            test_payload = {
                "query": "What is the IP address of google.com?",
                "action": "dns_lookup",
                "domain": "google.com"
            }
            
            print(f"🔧 Invoking Lambda function: {func_name}")
            print(f"📝 Test payload: {json.dumps(test_payload, indent=2)}")
            
            response = lambda_client.invoke(
                FunctionName=func_name,
                Payload=json.dumps(test_payload)
            )
            
            # Check response
            status_code = response['StatusCode']
            print(f"📊 Status Code: {status_code}")
            
            if 'Payload' in response:
                payload = response['Payload'].read().decode('utf-8')
                print(f"📋 Response: {payload[:500]}...")
                
                if status_code == 200:
                    print(f"✅ Lambda function is working correctly")
                    return True
                else:
                    print(f"❌ Lambda function returned error")
                    return False
            else:
                print(f"❌ No payload in response")
                return False
            
        except Exception as e:
            print(f"❌ Error testing Lambda: {str(e)}")
            return False

    def run_remediation(self) -> bool:
        """Run complete remediation process"""
        
        print("\n🛠️ DNS AGENT REMEDIATION")
        print("="*40)
        print(f"🕒 Started: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        
        # Step 1: Find working agent role
        working_role = self.find_working_agent_role()
        if not working_role:
            print("\n❌ Cannot proceed without working agent role")
            return False
        
        # Step 2: Find DNS Lambda function
        dns_lambda = self.find_dns_lambda_function()
        if not dns_lambda:
            print("\n❌ Cannot proceed without DNS Lambda function")
            return False
        
        # Step 3: Compare configurations
        comparison = self.compare_configurations(working_role, dns_lambda)
        
        # Step 4: Apply fixes
        if comparison['role_mismatch'] or comparison['config_issues']:
            print(f"\n🔧 Applying fixes...")
            success = self.fix_dns_lambda_configuration(dns_lambda, working_role)
            
            if not success:
                print(f"\n❌ Failed to apply fixes")
                return False
        
        # Step 5: Test Lambda directly
        func_name = dns_lambda['FunctionName']
        lambda_test_success = self.test_dns_lambda_directly(func_name)
        
        # Final report
        print(f"\n" + "="*80)
        print(f"📋 REMEDIATION SUMMARY")
        print(f"="*80)
        print(f"✅ Working agent role found: {working_role}")
        print(f"✅ DNS Lambda function found: {func_name}")
        print(f"{'✅' if lambda_test_success else '❌'} Lambda direct test: {'PASSED' if lambda_test_success else 'FAILED'}")
        
        if lambda_test_success:
            print(f"\n🎉 DNS Lambda is now working!")
            print(f"💡 Try testing the Agent Core Runtime endpoint again")
        else:
            print(f"\n❌ DNS Lambda still has issues")
            print(f"💡 Check CloudWatch logs for detailed error information")
        
        return lambda_test_success

def main():
    """Main execution function"""
    try:
        remediator = DNSAgentRemediator()
        success = remediator.run_remediation()
        
        if success:
            print("\n🎉 Remediation completed successfully!")
        else:
            print("\n⚠️ Remediation encountered issues. Check the logs above.")
            
    except KeyboardInterrupt:
        print("\n🛑 Remediation interrupted by user")
    except Exception as e:
        print(f"\n❌ Unexpected error: {str(e)}")

if __name__ == "__main__":
    main()