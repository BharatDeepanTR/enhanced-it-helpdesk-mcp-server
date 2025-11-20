#!/usr/bin/env python3
"""
DNS Agent Runtime Startup Diagnostic
====================================

Comprehensive diagnostic to identify why the Agent Core Runtime 
is failing to start. The error "An error occurred when starting 
the runtime" indicates a fundamental issue with the Lambda 
container or its configuration.

Common Issues:
1. Lambda function doesn't exist or is misconfigured
2. ECR container image is corrupted or missing dependencies
3. Lambda execution role lacks required permissions
4. Environment variables are missing or incorrect
5. Lambda timeout/memory configuration insufficient
6. Agent Core Runtime configuration mismatch
"""

import boto3
import json
import time
from datetime import datetime, timedelta
import logging

class DNSRuntimeStartupDiagnostic:
    """Comprehensive DNS Agent Runtime Startup Diagnostic"""
    
    def __init__(self):
        self.region = 'us-east-1'
        self.account_id = '818565325759'
        self.runtime_id = 'a208194_chatops_route_dns_lookup-Zg3E6G5ZDV'
        
        # Initialize logging
        logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
        self.logger = logging.getLogger('DNSRuntimeDiagnostic')
        
        # Initialize AWS clients
        self.lambda_client = boto3.client('lambda', region_name=self.region)
        self.ecr_client = boto3.client('ecr', region_name=self.region)
        self.iam_client = boto3.client('iam', region_name=self.region)
        self.logs_client = boto3.client('logs', region_name=self.region)
        
        print("🔍 DNS Agent Runtime Startup Diagnostic Initialized")
        print(f"Runtime ID: {self.runtime_id}")
        print(f"Region: {self.region}")

    def find_dns_lambda_function(self):
        """Find the DNS lookup Lambda function"""
        print("\n" + "="*80)
        print("🔍 STEP 1: FINDING DNS LAMBDA FUNCTION")
        print("="*80)
        
        try:
            # List all Lambda functions
            paginator = self.lambda_client.get_paginator('list_functions')
            
            dns_functions = []
            keywords = ['dns', 'lookup', 'route', 'chatops', '208194']
            
            for page in paginator.paginate():
                for function in page['Functions']:
                    func_name = function['FunctionName'].lower()
                    func_desc = function.get('Description', '').lower()
                    
                    if any(keyword in func_name or keyword in func_desc for keyword in keywords):
                        dns_functions.append(function)
            
            print(f"📋 Found {len(dns_functions)} potential DNS functions")
            
            for func in dns_functions:
                print(f"\n🎯 Function: {func['FunctionName']}")
                print(f"   ARN: {func['FunctionArn']}")
                print(f"   Runtime: {func['Runtime']}")
                print(f"   Handler: {func['Handler']}")
                print(f"   Timeout: {func['Timeout']}s")
                print(f"   Memory: {func['MemorySize']}MB")
                print(f"   Package Type: {func['PackageType']}")
                print(f"   State: {func['State']}")
                print(f"   Last Modified: {func['LastModified']}")
                
                if func['PackageType'] == 'Image':
                    print(f"   Code URI: {func['Code']['ImageUri']}")
                
                # This is likely our DNS function
                if 'dns' in func['FunctionName'].lower():
                    return func
            
            if dns_functions:
                return dns_functions[0]  # Return the first match
            else:
                print("❌ No DNS Lambda functions found")
                return None
                
        except Exception as e:
            print(f"❌ Error finding Lambda function: {str(e)}")
            return None

    def diagnose_lambda_function(self, function_info):
        """Diagnose Lambda function configuration"""
        print("\n" + "="*80)
        print("🔧 STEP 2: LAMBDA FUNCTION DIAGNOSTICS")
        print("="*80)
        
        function_name = function_info['FunctionName']
        
        try:
            # Get detailed function configuration
            response = self.lambda_client.get_function(FunctionName=function_name)
            config = response['Configuration']
            code_info = response['Code']
            
            print(f"📋 Detailed Configuration for {function_name}:")
            print(f"   State: {config['State']}")
            print(f"   State Reason: {config.get('StateReason', 'N/A')}")
            print(f"   State Reason Code: {config.get('StateReasonCode', 'N/A')}")
            print(f"   Last Update Status: {config['LastUpdateStatus']}")
            print(f"   Last Update Status Reason: {config.get('LastUpdateStatusReason', 'N/A')}")
            
            # Check execution role
            role_arn = config['Role']
            print(f"   Execution Role: {role_arn}")
            
            # Check environment variables
            env_vars = config.get('Environment', {}).get('Variables', {})
            print(f"   Environment Variables: {len(env_vars)}")
            for key, value in env_vars.items():
                # Don't print sensitive values
                display_value = value if not any(secret in key.lower() for secret in ['key', 'secret', 'token', 'password']) else '***'
                print(f"     {key}: {display_value}")
            
            # Check VPC configuration
            vpc_config = config.get('VpcConfig')
            if vpc_config and vpc_config.get('VpcId'):
                print(f"   VPC ID: {vpc_config['VpcId']}")
                print(f"   Subnets: {vpc_config.get('SubnetIds', [])}")
                print(f"   Security Groups: {vpc_config.get('SecurityGroupIds', [])}")
            else:
                print("   VPC: Not configured (using default)")
            
            # Check if function is container-based
            if config['PackageType'] == 'Image':
                image_uri = config['Code']['ImageUri']
                print(f"   Container Image: {image_uri}")
                
                # Check if this points to our ECR repository
                if 'dns-lookup-service' in image_uri:
                    print("   ✅ Uses dns-lookup-service ECR repository")
                    self.check_ecr_repository()
                else:
                    print("   ⚠️ Uses different container image")
            
            return config
            
        except Exception as e:
            print(f"❌ Error getting Lambda function details: {str(e)}")
            return None

    def check_ecr_repository(self):
        """Check ECR repository status"""
        print(f"\n🐳 ECR Repository Check:")
        
        try:
            # Get repository information
            repo_response = self.ecr_client.describe_repositories(
                repositoryNames=['dns-lookup-service']
            )
            
            repo = repo_response['repositories'][0]
            print(f"   Repository URI: {repo['repositoryUri']}")
            print(f"   Created: {repo['createdAt']}")
            
            # Get images in repository
            images_response = self.ecr_client.list_images(
                repositoryName='dns-lookup-service'
            )
            
            images = images_response['imageIds']
            print(f"   Total Images: {len(images)}")
            
            # Get latest image details
            if images:
                latest_image = max(images, key=lambda x: x.get('imageTag', '0'))
                print(f"   Latest Image: {latest_image}")
                
                # Check image vulnerabilities (if available)
                try:
                    scan_response = self.ecr_client.describe_image_scan_findings(
                        repositoryName='dns-lookup-service',
                        imageId=latest_image
                    )
                    scan_status = scan_response['imageScanStatus']['status']
                    print(f"   Security Scan Status: {scan_status}")
                except:
                    print(f"   Security Scan: Not available")
            
        except Exception as e:
            print(f"   ❌ ECR repository check failed: {str(e)}")

    def check_lambda_execution_role(self, role_arn):
        """Check Lambda execution role permissions"""
        print("\n" + "="*80)
        print("🔐 STEP 3: EXECUTION ROLE DIAGNOSTICS")
        print("="*80)
        
        try:
            # Extract role name from ARN
            role_name = role_arn.split('/')[-1]
            print(f"Role Name: {role_name}")
            print(f"Role ARN: {role_arn}")
            
            # Get role details
            role_response = self.iam_client.get_role(RoleName=role_name)
            role = role_response['Role']
            
            print(f"Created: {role['CreateDate']}")
            print(f"Trust Policy: {json.dumps(role['AssumeRolePolicyDocument'], indent=2)}")
            
            # Get attached policies
            attached_policies = self.iam_client.list_attached_role_policies(RoleName=role_name)
            print(f"\n📋 Attached Managed Policies ({len(attached_policies['AttachedPolicies'])}):")
            
            required_permissions = [
                'logs:CreateLogGroup',
                'logs:CreateLogStream', 
                'logs:PutLogEvents',
                'ec2:CreateNetworkInterface',  # If VPC enabled
                'ec2:DescribeNetworkInterfaces',
                'ec2:DeleteNetworkInterface'
            ]
            
            for policy in attached_policies['AttachedPolicies']:
                print(f"   • {policy['PolicyName']} ({policy['PolicyArn']})")
            
            # Get inline policies
            inline_policies = self.iam_client.list_role_policies(RoleName=role_name)
            print(f"\n📋 Inline Policies ({len(inline_policies['PolicyNames'])}):")
            
            for policy_name in inline_policies['PolicyNames']:
                print(f"   • {policy_name}")
                
                # Get policy document
                policy_doc = self.iam_client.get_role_policy(
                    RoleName=role_name,
                    PolicyName=policy_name
                )
                print(f"     Document: {json.dumps(policy_doc['PolicyDocument'], indent=6)}")
            
            # Check if role has basic Lambda execution permissions
            basic_policies = ['AWSLambdaBasicExecutionRole', 'AWSLambdaVPCAccessExecutionRole']
            has_basic_execution = any(
                any(bp in policy['PolicyName'] for bp in basic_policies)
                for policy in attached_policies['AttachedPolicies']
            )
            
            if has_basic_execution:
                print("✅ Role has basic Lambda execution permissions")
            else:
                print("⚠️ Role may be missing basic Lambda execution permissions")
                
        except Exception as e:
            print(f"❌ Error checking execution role: {str(e)}")

    def check_cloudwatch_logs(self, function_name):
        """Check CloudWatch logs for errors"""
        print("\n" + "="*80)
        print("📊 STEP 4: CLOUDWATCH LOGS ANALYSIS")
        print("="*80)
        
        log_group_name = f"/aws/lambda/{function_name}"
        
        try:
            # Check if log group exists
            log_groups = self.logs_client.describe_log_groups(
                logGroupNamePrefix=log_group_name
            )
            
            if not log_groups['logGroups']:
                print(f"❌ Log group {log_group_name} not found")
                print("   This suggests the Lambda function has never been invoked")
                return
            
            log_group = log_groups['logGroups'][0]
            print(f"📋 Log Group: {log_group['logGroupName']}")
            print(f"   Created: {log_group['creationTime']}")
            print(f"   Size: {log_group.get('storedBytes', 0)} bytes")
            
            # Get recent log streams
            streams_response = self.logs_client.describe_log_streams(
                logGroupName=log_group_name,
                orderBy='LastEventTime',
                descending=True,
                limit=10
            )
            
            print(f"\n📊 Recent Log Streams ({len(streams_response['logStreams'])}):")
            
            for stream in streams_response['logStreams'][:5]:  # Show top 5
                print(f"   • {stream['logStreamName']}")
                print(f"     Last Event: {stream.get('lastEventTime', 'N/A')}")
                print(f"     Events: {stream.get('storedBytes', 0)} bytes")
            
            # Get recent error logs
            print(f"\n🔍 Recent Error Logs (last 2 hours):")
            
            end_time = int(time.time() * 1000)
            start_time = end_time - (2 * 60 * 60 * 1000)  # 2 hours ago
            
            try:
                logs_response = self.logs_client.filter_log_events(
                    logGroupName=log_group_name,
                    startTime=start_time,
                    endTime=end_time,
                    filterPattern='ERROR'
                )
                
                error_events = logs_response['events']
                print(f"   Found {len(error_events)} error events")
                
                for event in error_events[-10:]:  # Show last 10 errors
                    timestamp = datetime.fromtimestamp(event['timestamp'] / 1000)
                    print(f"   [{timestamp}] {event['message'][:200]}")
                    
                if not error_events:
                    # Check for any recent events
                    recent_logs = self.logs_client.filter_log_events(
                        logGroupName=log_group_name,
                        startTime=start_time,
                        endTime=end_time,
                        limit=10
                    )
                    
                    print(f"   📋 Recent events (any): {len(recent_logs['events'])}")
                    for event in recent_logs['events'][-5:]:
                        timestamp = datetime.fromtimestamp(event['timestamp'] / 1000)
                        print(f"   [{timestamp}] {event['message'][:150]}")
                        
            except Exception as e:
                print(f"   ⚠️ Could not retrieve error logs: {str(e)}")
                
        except Exception as e:
            print(f"❌ Error checking CloudWatch logs: {str(e)}")

    def test_lambda_directly(self, function_name):
        """Test Lambda function directly"""
        print("\n" + "="*80)
        print("🧪 STEP 5: DIRECT LAMBDA TESTING")
        print("="*80)
        
        try:
            # Create a simple test payload
            test_payload = {
                "query": "What is the IP address of google.com?",
                "action": "dns_lookup"
            }
            
            print(f"📋 Testing {function_name} directly...")
            print(f"Payload: {json.dumps(test_payload, indent=2)}")
            
            response = self.lambda_client.invoke(
                FunctionName=function_name,
                InvocationType='RequestResponse',
                Payload=json.dumps(test_payload)
            )
            
            status_code = response['StatusCode']
            print(f"Status Code: {status_code}")
            
            if 'FunctionError' in response:
                print(f"❌ Function Error: {response['FunctionError']}")
            
            # Read response payload
            payload = response['Payload'].read()
            if payload:
                try:
                    result = json.loads(payload)
                    print(f"✅ Response: {json.dumps(result, indent=2)}")
                except:
                    print(f"📋 Raw Response: {payload.decode('utf-8')}")
            
            return status_code == 200 and 'FunctionError' not in response
            
        except Exception as e:
            print(f"❌ Direct Lambda test failed: {str(e)}")
            return False

    def generate_fixes(self, function_info, test_passed):
        """Generate specific fixes based on diagnostic results"""
        print("\n" + "="*80)
        print("🛠️  RECOMMENDED FIXES")
        print("="*80)
        
        fixes = []
        
        if not function_info:
            fixes.append("❌ CRITICAL: DNS Lambda function not found or not accessible")
            fixes.append("   • Verify the function exists in us-east-1 region")
            fixes.append("   • Check IAM permissions to access Lambda")
            
        else:
            state = function_info.get('State', 'Unknown')
            if state != 'Active':
                fixes.append(f"❌ Lambda function state is '{state}' (should be 'Active')")
                fixes.append("   • Wait for function to become active")
                fixes.append("   • Check function deployment status")
            
            if function_info['PackageType'] == 'Image':
                fixes.append("🐳 Container-based function diagnostics:")
                fixes.append("   • Verify ECR image is not corrupted")
                fixes.append("   • Check container entrypoint and CMD")
                fixes.append("   • Ensure container responds to Lambda runtime API")
            
            if not test_passed:
                fixes.append("❌ Direct Lambda invocation failed")
                fixes.append("   • Check function logs for startup errors")
                fixes.append("   • Verify container image compatibility")
                fixes.append("   • Check memory/timeout settings")
        
        # Agent Core specific fixes
        fixes.append("\n🤖 Agent Core Runtime specific fixes:")
        fixes.append("   • Verify Lambda function is compatible with Agent Core Runtime")
        fixes.append("   • Check if function expects specific event format from Agent Core")
        fixes.append("   • Ensure function has proper Agent Core handler")
        fixes.append("   • Verify IAM role has Agent Core permissions")
        
        fixes.append("\n🔧 Next steps to try:")
        fixes.append("   1. Redeploy the Lambda function with latest container image")
        fixes.append("   2. Test Lambda function independently first")
        fixes.append("   3. Check Agent Core documentation for required function format")
        fixes.append("   4. Contact AWS support if Lambda works but Agent Core doesn't")
        
        for fix in fixes:
            print(fix)

    def run_full_diagnostic(self):
        """Run complete diagnostic workflow"""
        print("🚀 Starting DNS Agent Runtime Startup Diagnostic")
        print("="*60)
        
        # Step 1: Find DNS Lambda function
        function_info = self.find_dns_lambda_function()
        
        if function_info:
            # Step 2: Diagnose Lambda configuration
            config = self.diagnose_lambda_function(function_info)
            
            if config:
                # Step 3: Check execution role
                self.check_lambda_execution_role(config['Role'])
                
                # Step 4: Check CloudWatch logs
                self.check_cloudwatch_logs(function_info['FunctionName'])
                
                # Step 5: Test Lambda directly
                test_passed = self.test_lambda_directly(function_info['FunctionName'])
        else:
            test_passed = False
        
        # Generate fixes
        self.generate_fixes(function_info, test_passed)
        
        print(f"\n🏁 Diagnostic Complete")
        print(f"Timestamp: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")

def main():
    """Main execution"""
    try:
        diagnostic = DNSRuntimeStartupDiagnostic()
        diagnostic.run_full_diagnostic()
    except KeyboardInterrupt:
        print("\n🛑 Diagnostic interrupted by user")
    except Exception as e:
        print(f"\n❌ Unexpected error: {str(e)}")

if __name__ == "__main__":
    main()