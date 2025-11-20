#!/usr/bin/env python3
"""
DNS Agent Runtime Startup Diagnostic
====================================

This script diagnoses the "runtime startup error" by checking:
1. Lambda function configuration
2. CloudWatch logs for startup errors
3. ECR container health
4. IAM permissions
5. Network configuration
"""

import boto3
import json
import time
from datetime import datetime, timedelta
from typing import Dict, List, Any, Optional

class DNSRuntimeDiagnostic:
    """Comprehensive diagnostic for DNS agent runtime startup issues"""
    
    def __init__(self):
        """Initialize the diagnostic tool"""
        self.region = 'us-east-1'
        self.account_id = None
        self.agent_runtime_id = 'a208194_chatops_route_dns_lookup-Zg3E6G5ZDV'
        
        # Initialize AWS clients
        self._init_aws_clients()
        
        print("🔍 DNS Agent Runtime Startup Diagnostic")
        print("=" * 60)
        print(f"🕒 Started: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        print(f"🌎 Region: {self.region}")
        print(f"🤖 Agent Runtime ID: {self.agent_runtime_id}")

    def _init_aws_clients(self):
        """Initialize AWS clients"""
        try:
            # Get account ID
            sts = boto3.client('sts', region_name=self.region)
            identity = sts.get_caller_identity()
            self.account_id = identity.get('Account')
            
            # Initialize clients
            self.lambda_client = boto3.client('lambda', region_name=self.region)
            self.logs_client = boto3.client('logs', region_name=self.region)
            self.ecr_client = boto3.client('ecr', region_name=self.region)
            self.iam_client = boto3.client('iam', region_name=self.region)
            
            print(f"✅ AWS clients initialized for account: {self.account_id}")
            
        except Exception as e:
            print(f"❌ Failed to initialize AWS clients: {str(e)}")
            raise

    def find_dns_lambda_function(self) -> Optional[str]:
        """Find the DNS lookup Lambda function"""
        print(f"\n🔍 SEARCHING FOR DNS LAMBDA FUNCTION")
        print("-" * 50)
        
        try:
            # Common patterns for DNS function names
            dns_patterns = [
                'dns-lookup',
                'chatops-dns', 
                'route-dns',
                'a208194',
                'dns_lookup'
            ]
            
            # List all Lambda functions
            paginator = self.lambda_client.get_paginator('list_functions')
            
            found_functions = []
            
            for page in paginator.paginate():
                for function in page['Functions']:
                    function_name = function['FunctionName'].lower()
                    description = function.get('Description', '').lower()
                    
                    # Check if this looks like our DNS function
                    if any(pattern in function_name or pattern in description for pattern in dns_patterns):
                        found_functions.append({
                            'name': function['FunctionName'],
                            'arn': function['FunctionArn'],
                            'runtime': function.get('Runtime', 'N/A'),
                            'package_type': function.get('PackageType', 'N/A'),
                            'image_uri': function.get('Code', {}).get('ImageUri', 'N/A'),
                            'last_modified': function.get('LastModified', 'N/A')
                        })
            
            if found_functions:
                print(f"🎯 Found {len(found_functions)} potential DNS function(s):")
                for i, func in enumerate(found_functions, 1):
                    print(f"\n{i}. {func['name']}")
                    print(f"   ARN: {func['arn']}")
                    print(f"   Runtime: {func['runtime']}")
                    print(f"   Package Type: {func['package_type']}")
                    print(f"   Last Modified: {func['last_modified']}")
                    if func['image_uri'] != 'N/A':
                        print(f"   Image URI: {func['image_uri']}")
                
                # Return the most likely candidate
                return found_functions[0]['name']
            else:
                print("❌ No DNS Lambda functions found")
                return None
                
        except Exception as e:
            print(f"❌ Error finding Lambda function: {str(e)}")
            return None

    def diagnose_lambda_function(self, function_name: str):
        """Diagnose Lambda function configuration and logs"""
        print(f"\n🔧 LAMBDA FUNCTION DIAGNOSTIC")
        print("-" * 50)
        
        try:
            # Get function configuration
            config = self.lambda_client.get_function(FunctionName=function_name)
            function_config = config['Configuration']
            
            print(f"📋 Function Name: {function_config['FunctionName']}")
            print(f"📋 Runtime: {function_config.get('Runtime', 'N/A')}")
            print(f"📋 Package Type: {function_config.get('PackageType', 'N/A')}")
            print(f"📋 State: {function_config.get('State', 'N/A')}")
            print(f"📋 Last Update Status: {function_config.get('LastUpdateStatus', 'N/A')}")
            print(f"📋 Memory: {function_config.get('MemorySize', 'N/A')} MB")
            print(f"📋 Timeout: {function_config.get('Timeout', 'N/A')} seconds")
            
            # Check if it's a container function
            if function_config.get('PackageType') == 'Image':
                image_uri = function_config.get('Code', {}).get('ImageUri', 'N/A')
                print(f"📋 Image URI: {image_uri}")
                
                # Check if this is our DNS service container
                if 'dns-lookup-service' in image_uri:
                    print("✅ This appears to be the DNS lookup container function")
                    return True
            
            # Check environment variables
            env_vars = function_config.get('Environment', {}).get('Variables', {})
            if env_vars:
                print(f"📋 Environment Variables:")
                for key, value in env_vars.items():
                    print(f"   {key}: {value}")
            
            # Check VPC configuration
            vpc_config = function_config.get('VpcConfig', {})
            if vpc_config.get('VpcId'):
                print(f"📋 VPC ID: {vpc_config.get('VpcId')}")
                print(f"📋 Subnets: {vpc_config.get('SubnetIds', [])}")
                print(f"📋 Security Groups: {vpc_config.get('SecurityGroupIds', [])}")
            
            # Check execution role
            role_arn = function_config.get('Role')
            print(f"📋 Execution Role: {role_arn}")
            
            return True
            
        except Exception as e:
            print(f"❌ Error diagnosing Lambda function: {str(e)}")
            return False

    def check_cloudwatch_logs(self, function_name: str):
        """Check CloudWatch logs for startup errors"""
        print(f"\n📊 CLOUDWATCH LOGS ANALYSIS")
        print("-" * 50)
        
        try:
            log_group_name = f"/aws/lambda/{function_name}"
            
            # Check if log group exists
            try:
                self.logs_client.describe_log_groups(logGroupNamePrefix=log_group_name)
                print(f"✅ Log group found: {log_group_name}")
            except Exception as e:
                print(f"❌ Log group not found: {log_group_name}")
                return False
            
            # Get recent log events
            end_time = int(time.time() * 1000)
            start_time = end_time - (30 * 60 * 1000)  # Last 30 minutes
            
            try:
                # Get recent log streams
                streams_response = self.logs_client.describe_log_streams(
                    logGroupName=log_group_name,
                    orderBy='LastEventTime',
                    descending=True,
                    limit=5
                )
                
                log_streams = streams_response.get('logStreams', [])
                
                if not log_streams:
                    print("⚠️ No recent log streams found")
                    return False
                
                print(f"📋 Found {len(log_streams)} recent log streams")
                
                # Analyze the most recent log stream
                latest_stream = log_streams[0]
                stream_name = latest_stream['logStreamName']
                
                print(f"🔍 Analyzing latest stream: {stream_name}")
                
                # Get log events
                events_response = self.logs_client.get_log_events(
                    logGroupName=log_group_name,
                    logStreamName=stream_name,
                    startTime=start_time,
                    endTime=end_time
                )
                
                events = events_response.get('events', [])
                
                if not events:
                    print("⚠️ No recent log events found")
                    return False
                
                print(f"📋 Analyzing {len(events)} log events...")
                
                # Look for errors
                error_patterns = [
                    'ERROR',
                    'Exception',
                    'Traceback',
                    'Failed',
                    'timeout',
                    'memory',
                    'import',
                    'module',
                    'permission'
                ]
                
                errors_found = []
                
                for event in events[-20:]:  # Last 20 events
                    message = event.get('message', '')
                    timestamp = datetime.fromtimestamp(event.get('timestamp', 0) / 1000)
                    
                    # Check for error patterns
                    for pattern in error_patterns:
                        if pattern.lower() in message.lower():
                            errors_found.append({
                                'timestamp': timestamp,
                                'message': message
                            })
                            break
                
                if errors_found:
                    print(f"\n🚨 Found {len(errors_found)} potential errors:")
                    for error in errors_found[-5:]:  # Show last 5 errors
                        print(f"   [{error['timestamp']}] {error['message']}")
                else:
                    print("✅ No obvious errors found in recent logs")
                
                # Show the last few log messages
                print(f"\n📝 Recent log messages:")
                for event in events[-5:]:
                    timestamp = datetime.fromtimestamp(event.get('timestamp', 0) / 1000)
                    message = event.get('message', '').strip()
                    print(f"   [{timestamp}] {message}")
                
                return True
                
            except Exception as e:
                print(f"❌ Error reading log events: {str(e)}")
                return False
                
        except Exception as e:
            print(f"❌ Error checking CloudWatch logs: {str(e)}")
            return False

    def test_direct_lambda_invocation(self, function_name: str):
        """Test direct Lambda function invocation"""
        print(f"\n🧪 DIRECT LAMBDA INVOCATION TEST")
        print("-" * 50)
        
        try:
            # Test payload
            test_payload = {
                "inputText": "What is the IP address of google.com?",
                "sessionId": "direct-test-" + str(int(time.time())),
                "sessionAttributes": {},
                "promptSessionAttributes": {}
            }
            
            print(f"📝 Test payload: {json.dumps(test_payload, indent=2)}")
            
            # Invoke function
            print("🚀 Invoking Lambda function directly...")
            
            response = self.lambda_client.invoke(
                FunctionName=function_name,
                InvocationType='RequestResponse',
                Payload=json.dumps(test_payload)
            )
            
            # Check response
            status_code = response.get('StatusCode')
            print(f"📊 Status Code: {status_code}")
            
            # Read payload
            payload = response.get('Payload')
            if payload:
                result = json.loads(payload.read())
                print(f"📋 Response: {json.dumps(result, indent=2)}")
                
                # Check for errors
                if 'errorMessage' in result:
                    print(f"❌ Lambda Error: {result['errorMessage']}")
                    if 'errorType' in result:
                        print(f"   Error Type: {result['errorType']}")
                    if 'stackTrace' in result:
                        print(f"   Stack Trace: {result['stackTrace']}")
                    return False
                else:
                    print("✅ Direct Lambda invocation successful!")
                    return True
            else:
                print("⚠️ No response payload received")
                return False
                
        except Exception as e:
            print(f"❌ Error testing direct Lambda invocation: {str(e)}")
            return False

    def check_container_image_health(self):
        """Check ECR container image health"""
        print(f"\n🐳 CONTAINER IMAGE HEALTH CHECK")
        print("-" * 50)
        
        try:
            repo_name = 'dns-lookup-service'
            
            # Check repository
            try:
                repo_response = self.ecr_client.describe_repositories(
                    repositoryNames=[repo_name]
                )
                repo = repo_response['repositories'][0]
                print(f"✅ ECR Repository found: {repo_name}")
                print(f"📋 Repository URI: {repo['repositoryUri']}")
                print(f"📋 Created: {repo['createdAt']}")
                
            except Exception as e:
                print(f"❌ ECR Repository not found: {repo_name}")
                return False
            
            # List images
            try:
                images_response = self.ecr_client.list_images(
                    repositoryName=repo_name,
                    maxResults=10
                )
                images = images_response.get('imageIds', [])
                print(f"📋 Found {len(images)} images in repository")
                
                if images:
                    # Get latest image details
                    latest_response = self.ecr_client.describe_images(
                        repositoryName=repo_name,
                        maxResults=1
                    )
                    
                    if latest_response.get('imageDetails'):
                        latest = latest_response['imageDetails'][0]
                        print(f"📋 Latest image pushed: {latest.get('imagePushedAt')}")
                        print(f"📋 Image size: {latest.get('imageSizeInBytes', 0) / 1024 / 1024:.1f} MB")
                        
                        # Check for vulnerabilities
                        if 'imageScanFindingsSummary' in latest:
                            scan_summary = latest['imageScanFindingsSummary']
                            print(f"📋 Security scan: {scan_summary.get('findingCounts', {})}")
                
                return True
                
            except Exception as e:
                print(f"❌ Error listing images: {str(e)}")
                return False
                
        except Exception as e:
            print(f"❌ Error checking container image: {str(e)}")
            return False

    def run_comprehensive_diagnostic(self):
        """Run complete diagnostic suite"""
        print("\n🔍 COMPREHENSIVE RUNTIME STARTUP DIAGNOSTIC")
        print("=" * 60)
        
        # 1. Find DNS Lambda function
        function_name = self.find_dns_lambda_function()
        
        if not function_name:
            print("\n❌ Cannot proceed without finding the DNS Lambda function")
            return False
        
        # 2. Diagnose Lambda configuration
        lambda_ok = self.diagnose_lambda_function(function_name)
        
        # 3. Check CloudWatch logs
        logs_ok = self.check_cloudwatch_logs(function_name)
        
        # 4. Test direct Lambda invocation
        direct_test_ok = self.test_direct_lambda_invocation(function_name)
        
        # 5. Check container image health
        image_ok = self.check_container_image_health()
        
        # Generate summary
        self.generate_diagnostic_summary(function_name, {
            'lambda_config': lambda_ok,
            'cloudwatch_logs': logs_ok,
            'direct_invocation': direct_test_ok,
            'container_image': image_ok
        })
        
        return all([lambda_ok, logs_ok, direct_test_ok, image_ok])

    def generate_diagnostic_summary(self, function_name: str, results: Dict[str, bool]):
        """Generate diagnostic summary report"""
        
        print(f"\n📊 DIAGNOSTIC SUMMARY")
        print("=" * 60)
        print(f"🕒 Completed: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        print(f"🤖 Function: {function_name}")
        
        print(f"\n📈 RESULTS:")
        for check, status in results.items():
            emoji = "✅" if status else "❌"
            print(f"   {emoji} {check.replace('_', ' ').title()}: {'PASS' if status else 'FAIL'}")
        
        overall_status = all(results.values())
        
        if overall_status:
            print(f"\n🎉 OVERALL STATUS: HEALTHY")
            print(f"💡 The Lambda function appears to be working correctly.")
            print(f"🔍 The runtime startup error may be:")
            print(f"   • Agent Core Runtime configuration issue")
            print(f"   • Temporary service issue")
            print(f"   • IAM permissions specific to Agent Core")
        else:
            print(f"\n⚠️ OVERALL STATUS: ISSUES DETECTED")
            print(f"💡 Recommended actions:")
            
            if not results.get('lambda_config'):
                print(f"   • Review Lambda function configuration")
            if not results.get('cloudwatch_logs'):
                print(f"   • Check CloudWatch logs for errors")
            if not results.get('direct_invocation'):
                print(f"   • Fix Lambda function code or permissions")
            if not results.get('container_image'):
                print(f"   • Rebuild and push container image")
        
        print("=" * 60)

def main():
    """Main execution function"""
    try:
        diagnostic = DNSRuntimeDiagnostic()
        success = diagnostic.run_comprehensive_diagnostic()
        
        if success:
            print("\n✅ Diagnostic completed successfully")
        else:
            print("\n⚠️ Diagnostic identified issues")
            
    except KeyboardInterrupt:
        print("\n🛑 Diagnostic interrupted by user")
    except Exception as e:
        print(f"\n❌ Diagnostic failed: {str(e)}")

if __name__ == "__main__":
    main()