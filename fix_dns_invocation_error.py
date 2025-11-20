#!/usr/bin/env python3
"""
DNS Agent Invocation Error Fix
==============================

This script focuses ONLY on fixing the "runtime startup error" for the DNS agent
without changing its fundamental functionality. We'll identify and fix only the
essential configuration issues that prevent successful invocation.

Target: Fix invocation error for a208194_chatops_route_dns_lookup
Approach: Minimal changes, preserve functionality
"""

import boto3
import json
import logging
from datetime import datetime
from typing import Dict, List, Any, Optional

class DNSAgentInvocationFixer:
    """Focused fixer for DNS agent invocation errors"""
    
    def __init__(self):
        """Initialize the fixer with minimal scope"""
        self.region = 'us-east-1'
        self.setup_logging()
        
        # Target agents (exact runtime names)
        self.working_agent_name = 'a208194_askjulius_account_details_agent'
        self.failing_agent_name = 'a208194_chatops_route_dns_lookup'
        
        # Focus areas for fixing invocation errors
        self.critical_checks = [
            'iam_role_permissions',
            'lambda_function_state', 
            'container_accessibility',
            'runtime_configuration'
        ]
        
        self.logger.info("🔧 DNS Agent Invocation Fixer initialized")
        self.logger.info(f"🎯 Target: {self.failing_agent_name}")
        self.logger.info(f"📋 Reference: {self.working_agent_name}")

    def setup_logging(self):
        """Configure focused logging"""
        logging.basicConfig(
            level=logging.INFO,
            format='%(asctime)s - %(levelname)s - %(message)s'
        )
        self.logger = logging.getLogger('DNSInvocationFixer')

    def check_lambda_function_basic_health(self) -> Dict[str, Any]:
        """Check basic Lambda function health that affects invocation"""
        self.logger.info("🔍 Checking DNS Lambda function basic health...")
        
        try:
            lambda_client = boto3.client('lambda', region_name=self.region)
            
            # Find DNS-related Lambda functions
            response = lambda_client.list_functions()
            dns_functions = []
            
            for func in response['Functions']:
                func_name = func['FunctionName'].lower()
                if any(keyword in func_name for keyword in ['dns', 'route', 'lookup', '208194']):
                    dns_functions.append(func)
            
            print("\n" + "="*80)
            print("🔍 LAMBDA FUNCTION HEALTH CHECK")
            print("="*80)
            
            for func in dns_functions:
                func_name = func['FunctionName']
                state = func.get('State', 'Unknown')
                last_update = func.get('LastUpdateStatus', 'Unknown')
                
                print(f"\n📦 Function: {func_name}")
                print(f"   State: {state}")
                print(f"   Last Update: {last_update}")
                print(f"   Runtime: {func.get('Runtime', 'Unknown')}")
                print(f"   Memory: {func.get('MemorySize', 'Unknown')} MB")
                print(f"   Timeout: {func.get('Timeout', 'Unknown')} seconds")
                
                # Check if this is likely our DNS function
                if 'dns' in func_name.lower() and '208194' in func_name:
                    print(f"   🎯 LIKELY DNS AGENT FUNCTION")
                    
                    # Critical checks for invocation issues
                    issues = []
                    
                    if state != 'Active':
                        issues.append(f"❌ Function state is {state}, should be Active")
                    
                    if last_update != 'Successful':
                        issues.append(f"❌ Last update failed: {last_update}")
                    
                    if func.get('PackageType') == 'Image':
                        # Check container-specific issues
                        print(f"   📦 Package Type: Container Image")
                        image_uri = func.get('Code', {}).get('ImageUri', '')
                        if image_uri:
                            print(f"   🐳 Image URI: {image_uri}")
                        else:
                            issues.append(f"❌ Missing container image URI")
                    
                    # Check role
                    role_arn = func.get('Role', '')
                    if role_arn:
                        print(f"   🔐 Role: {role_arn}")
                        # Extract role name for later comparison
                        role_name = role_arn.split('/')[-1] if '/' in role_arn else role_arn
                        print(f"   📝 Role Name: {role_name}")
                    else:
                        issues.append(f"❌ Missing IAM role")
                    
                    if issues:
                        print(f"   🚨 CRITICAL ISSUES FOUND:")
                        for issue in issues:
                            print(f"      {issue}")
                    else:
                        print(f"   ✅ Basic health checks passed")
                    
                    return {
                        'function_name': func_name,
                        'function_arn': func.get('FunctionArn'),
                        'state': state,
                        'last_update': last_update,
                        'role_arn': role_arn,
                        'issues': issues,
                        'package_type': func.get('PackageType'),
                        'image_uri': func.get('Code', {}).get('ImageUri', ''),
                        'is_healthy': len(issues) == 0
                    }
            
            print("\n❌ No DNS agent Lambda function found")
            return {'error': 'DNS Lambda function not found'}
            
        except Exception as e:
            self.logger.error(f"❌ Lambda health check failed: {str(e)}")
            return {'error': str(e)}

    def compare_iam_roles_minimal(self, dns_role_arn: str) -> Dict[str, Any]:
        """Compare IAM roles focusing only on invocation-critical permissions"""
        self.logger.info("🔐 Comparing IAM roles for invocation-critical permissions...")
        
        try:
            # Extract role names
            dns_role_name = dns_role_arn.split('/')[-1] if '/' in dns_role_arn else dns_role_arn
            working_role_name = 'a208194-askjulius-supervisor-agent-role'  # Known working role
            
            print(f"\n" + "="*80)
            print("🔐 IAM ROLE COMPARISON (INVOCATION-CRITICAL ONLY)")
            print("="*80)
            print(f"DNS Role: {dns_role_name}")
            print(f"Working Role: {working_role_name}")
            
            iam_client = boto3.client('iam', region_name=self.region)
            
            # Get both roles
            try:
                dns_role = iam_client.get_role(RoleName=dns_role_name)
                print(f"✅ DNS role found: {dns_role_name}")
            except Exception as e:
                print(f"❌ DNS role error: {str(e)}")
                return {'error': f'DNS role not accessible: {str(e)}'}
            
            try:
                working_role = iam_client.get_role(RoleName=working_role_name)
                print(f"✅ Working role found: {working_role_name}")
            except Exception as e:
                print(f"⚠️ Working role not found: {str(e)}")
                working_role = None
            
            # Check critical permissions for Lambda invocation
            critical_permissions = [
                'lambda:InvokeFunction',
                'logs:CreateLogGroup',
                'logs:CreateLogStream', 
                'logs:PutLogEvents',
                'ecr:GetAuthorizationToken',  # For container images
                'ecr:BatchCheckLayerAvailability',
                'ecr:GetDownloadUrlForLayer',
                'ecr:BatchGetImage'
            ]
            
            print(f"\n🔍 CRITICAL PERMISSIONS CHECK:")
            
            # Check DNS role policies
            dns_policies = []
            try:
                # Get attached managed policies
                attached = iam_client.list_attached_role_policies(RoleName=dns_role_name)
                for policy in attached['AttachedPolicies']:
                    dns_policies.append(('managed', policy['PolicyName'], policy['PolicyArn']))
                
                # Get inline policies
                inline = iam_client.list_role_policies(RoleName=dns_role_name)
                for policy_name in inline['PolicyNames']:
                    dns_policies.append(('inline', policy_name, None))
                
                print(f"📋 DNS Role Policies ({len(dns_policies)}):")
                for policy_type, policy_name, policy_arn in dns_policies:
                    print(f"   • {policy_type}: {policy_name}")
                
            except Exception as e:
                print(f"❌ Failed to get DNS role policies: {str(e)}")
                return {'error': f'Failed to access DNS role policies: {str(e)}'}
            
            # Recommendation based on findings
            recommendations = []
            
            if len(dns_policies) == 0:
                recommendations.append("❌ CRITICAL: DNS role has no policies attached")
            
            # Simple check for common Lambda execution role
            has_lambda_basic = any('lambda' in policy[1].lower() for policy in dns_policies)
            has_logs = any('log' in policy[1].lower() for policy in dns_policies)
            has_ecr = any('ecr' in policy[1].lower() for policy in dns_policies)
            
            if not has_lambda_basic:
                recommendations.append("⚠️ No Lambda execution policies found")
            
            if not has_logs:
                recommendations.append("⚠️ No CloudWatch logs policies found")
            
            if not has_ecr:
                recommendations.append("⚠️ No ECR access policies found (needed for container images)")
            
            print(f"\n💡 RECOMMENDATIONS:")
            if recommendations:
                for rec in recommendations:
                    print(f"   {rec}")
                print(f"\n🔧 SUGGESTED FIX:")
                print(f"   1. Add AWSLambdaBasicExecutionRole managed policy")
                print(f"   2. Add EC2ContainerRegistryReadOnlyAccess managed policy")
                print(f"   3. Add custom policy for Bedrock and Agent Core permissions")
            else:
                print(f"   ✅ Basic permissions appear to be in place")
            
            return {
                'dns_role_name': dns_role_name,
                'dns_policies_count': len(dns_policies),
                'has_lambda_basic': has_lambda_basic,
                'has_logs': has_logs,
                'has_ecr': has_ecr,
                'recommendations': recommendations,
                'needs_fix': len(recommendations) > 0
            }
            
        except Exception as e:
            self.logger.error(f"❌ IAM role comparison failed: {str(e)}")
            return {'error': str(e)}

    def check_container_accessibility(self, image_uri: str) -> Dict[str, Any]:
        """Check if container image is accessible (critical for startup)"""
        if not image_uri:
            return {'error': 'No image URI provided'}
        
        self.logger.info("🐳 Checking container image accessibility...")
        
        try:
            print(f"\n" + "="*80)
            print("🐳 CONTAINER IMAGE ACCESSIBILITY CHECK")
            print("="*80)
            print(f"Image URI: {image_uri}")
            
            # Extract ECR repository info
            if 'ecr' in image_uri and 'amazonaws.com' in image_uri:
                parts = image_uri.split('/')
                if len(parts) >= 2:
                    repo_name = parts[-1].split(':')[0] if ':' in parts[-1] else parts[-1].split('@')[0]
                    print(f"Repository: {repo_name}")
                    
                    # Check ECR repository
                    ecr_client = boto3.client('ecr', region_name=self.region)
                    
                    try:
                        repo_response = ecr_client.describe_repositories(repositoryNames=[repo_name])
                        repo = repo_response['repositories'][0]
                        print(f"✅ Repository exists: {repo_name}")
                        print(f"   Created: {repo.get('createdAt')}")
                        print(f"   Image Count: {repo.get('imageDetails', 'Unknown')}")
                        
                        # Check images in repository
                        images = ecr_client.describe_images(repositoryName=repo_name)
                        print(f"   Total Images: {len(images.get('imageDetails', []))}")
                        
                        if len(images.get('imageDetails', [])) == 0:
                            return {
                                'accessible': False,
                                'error': 'Repository exists but contains no images',
                                'fix_needed': True
                            }
                        
                        return {
                            'accessible': True,
                            'repository': repo_name,
                            'image_count': len(images.get('imageDetails', [])),
                            'fix_needed': False
                        }
                        
                    except Exception as e:
                        print(f"❌ Repository check failed: {str(e)}")
                        return {
                            'accessible': False,
                            'error': str(e),
                            'fix_needed': True
                        }
            else:
                print(f"⚠️ Not an ECR image or unrecognized format")
                return {'accessible': 'unknown', 'fix_needed': False}
                
        except Exception as e:
            self.logger.error(f"❌ Container check failed: {str(e)}")
            return {'error': str(e)}

    def generate_fix_recommendations(self, lambda_health: Dict, iam_analysis: Dict, container_check: Dict) -> List[str]:
        """Generate specific fix recommendations for invocation errors"""
        
        print(f"\n" + "="*80)
        print("🔧 INVOCATION ERROR FIX RECOMMENDATIONS")
        print("="*80)
        
        fixes = []
        
        # Lambda function issues
        if lambda_health.get('issues'):
            print(f"🚨 LAMBDA FUNCTION ISSUES:")
            for issue in lambda_health['issues']:
                print(f"   {issue}")
                
            if lambda_health.get('state') != 'Active':
                fixes.append(f"1. Fix Lambda function state: Currently {lambda_health.get('state')}, needs to be Active")
                
            if lambda_health.get('last_update') != 'Successful':
                fixes.append(f"2. Fix Lambda deployment: Last update was {lambda_health.get('last_update')}")
        
        # IAM role issues  
        if iam_analysis.get('needs_fix'):
            print(f"\n🔐 IAM PERMISSION ISSUES:")
            for rec in iam_analysis.get('recommendations', []):
                print(f"   {rec}")
                
            fixes.append("3. Fix IAM role permissions:")
            fixes.append("   - Attach AWSLambdaBasicExecutionRole managed policy")
            fixes.append("   - Attach EC2ContainerRegistryReadOnlyAccess managed policy")
            fixes.append("   - Add Bedrock Agent Core specific permissions")
        
        # Container issues
        if container_check.get('fix_needed'):
            print(f"\n🐳 CONTAINER IMAGE ISSUES:")
            print(f"   Error: {container_check.get('error', 'Unknown container issue')}")
            fixes.append("4. Fix container image accessibility:")
            fixes.append("   - Verify ECR repository exists and has images")
            fixes.append("   - Check ECR permissions in IAM role")
            fixes.append("   - Rebuild and push container image if missing")
        
        # Priority fixes for invocation errors
        if not fixes:
            print(f"✅ No obvious configuration issues found")
            print(f"💡 Try these troubleshooting steps:")
            fixes.append("5. Additional troubleshooting:")
            fixes.append("   - Check CloudWatch logs for detailed startup errors")
            fixes.append("   - Test Lambda function independently")
            fixes.append("   - Verify Agent Core runtime configuration")
        
        return fixes

    def run_focused_diagnostic(self):
        """Run focused diagnostic to fix invocation error"""
        print("\n🔧 DNS AGENT INVOCATION ERROR DIAGNOSTIC")
        print("="*60)
        print(f"🕒 Started: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        print(f"🎯 Target: {self.failing_agent_name}")
        print(f"🎯 Goal: Fix runtime startup/invocation error")
        
        # 1. Check Lambda function health
        print(f"\n1️⃣ CHECKING LAMBDA FUNCTION HEALTH...")
        lambda_health = self.check_lambda_function_basic_health()
        
        # 2. Check IAM permissions if Lambda found
        iam_analysis = {}
        if lambda_health and not lambda_health.get('error'):
            print(f"\n2️⃣ CHECKING IAM ROLE PERMISSIONS...")
            role_arn = lambda_health.get('role_arn', '')
            if role_arn:
                iam_analysis = self.compare_iam_roles_minimal(role_arn)
            else:
                iam_analysis = {'error': 'No role ARN found in Lambda function'}
        
        # 3. Check container accessibility if using containers
        container_check = {}
        if lambda_health and lambda_health.get('package_type') == 'Image':
            print(f"\n3️⃣ CHECKING CONTAINER IMAGE ACCESSIBILITY...")
            image_uri = lambda_health.get('image_uri', '')
            container_check = self.check_container_accessibility(image_uri)
        
        # 4. Generate fix recommendations
        print(f"\n4️⃣ GENERATING FIX RECOMMENDATIONS...")
        fixes = self.generate_fix_recommendations(lambda_health, iam_analysis, container_check)
        
        # 5. Summary
        print(f"\n📋 SUMMARY:")
        if fixes:
            print(f"❌ Issues found that may cause invocation errors")
            print(f"🔧 Apply the recommendations above to fix the DNS agent")
        else:
            print(f"✅ No obvious configuration issues found")
            print(f"💡 Issue may be in runtime code or environment variables")
        
        print(f"\n🎯 NEXT STEPS:")
        print(f"1. Apply the fixes above in order")
        print(f"2. Test the DNS agent after each fix")
        print(f"3. Check CloudWatch logs for detailed error messages")
        print(f"4. Compare working vs failing agent configurations manually")
        
        print("="*60)

def main():
    """Main execution function"""
    try:
        fixer = DNSAgentInvocationFixer()
        fixer.run_focused_diagnostic()
        
    except KeyboardInterrupt:
        print("\n🛑 Diagnostic interrupted by user")
    except Exception as e:
        print(f"\n❌ Unexpected error: {str(e)}")

if __name__ == "__main__":
    main()