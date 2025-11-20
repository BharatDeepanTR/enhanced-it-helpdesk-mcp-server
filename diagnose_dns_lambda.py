#!/usr/bin/env python3
"""
DNS Lambda Function Diagnostic Script
====================================

This script diagnoses the underlying Lambda function used by the DNS agent
to identify why Agent Core Runtime is failing to start.

Based on the CloudWatch logs:
- Agent Core Runtime receives the request successfully
- Runtime startup fails - likely Lambda function issue
- Need to check Lambda function configuration and execution
"""

import boto3
import json
import logging
from datetime import datetime, timedelta
from typing import Dict, List, Any, Optional

class DNSLambdaDiagnostic:
    """Diagnostic tool for DNS Lambda function issues"""
    
    def __init__(self):
        """Initialize the diagnostic tool"""
        self.region = 'us-east-1'
        self.setup_logging()
        
        # DNS Agent configuration from ECR analysis
        self.expected_lambda_names = [
            'dns-lookup-service',
            'a208194-dns-lookup',
            'a208194-chatops-dns',
            'chatops-route-dns',
            'route-dns-lookup'
        ]
        
        self.agent_runtime_id = 'a208194_chatops_route_dns_lookup-Zg3E6G5ZDV'
        
        self.logger.info("🔍 DNS Lambda Diagnostic initialized")

    def setup_logging(self):
        """Configure logging"""
        logging.basicConfig(
            level=logging.INFO,
            format='%(asctime)s - %(levelname)s - %(message)s'
        )
        self.logger = logging.getLogger('DNSLambdaDiagnostic')

    def find_dns_lambda_functions(self) -> List[Dict[str, Any]]:
        """Find DNS-related Lambda functions"""
        try:
            self.logger.info("🔍 Searching for DNS-related Lambda functions...")
            
            lambda_client = boto3.client('lambda', region_name=self.region)
            
            print("\n" + "="*80)
            print("🔍 DNS LAMBDA FUNCTION DISCOVERY")
            print("="*80)
            
            # List all Lambda functions
            paginator = lambda_client.get_paginator('list_functions')
            dns_functions = []
            
            for page in paginator.paginate():
                functions = page.get('Functions', [])
                
                for func in functions:
                    func_name = func.get('FunctionName', '').lower()
                    description = func.get('Description', '').lower()
                    
                    # Check for DNS-related keywords
                    dns_keywords = ['dns', 'lookup', 'route', 'chatops', '208194']
                    
                    if any(keyword in func_name or keyword in description for keyword in dns_keywords):
                        dns_functions.append(func)
                        
                        print(f"\n🎯 FOUND DNS LAMBDA:")
                        print(f"   Function Name: {func.get('FunctionName')}")
                        print(f"   Runtime: {func.get('Runtime')}")
                        print(f"   Handler: {func.get('Handler')}")
                        print(f"   Last Modified: {func.get('LastModified')}")
                        print(f"   State: {func.get('State', 'Unknown')}")
                        print(f"   State Reason: {func.get('StateReason', 'N/A')}")
                        print(f"   Size: {func.get('CodeSize', 0)} bytes")
                        
                        if func.get('Description'):
                            print(f"   Description: {func['Description']}")
            
            if not dns_functions:
                print("\n❌ No DNS-related Lambda functions found")
                print("\n📋 Showing all functions (first 10):")
                
                all_funcs = []
                for page in paginator.paginate():
                    all_funcs.extend(page.get('Functions', []))
                
                for i, func in enumerate(all_funcs[:10]):
                    print(f"   {i+1}. {func.get('FunctionName')}")
            
            return dns_functions
            
        except Exception as e:
            self.logger.error(f"❌ Lambda discovery failed: {str(e)}")
            return []

    def diagnose_lambda_function(self, function_name: str) -> Dict[str, Any]:
        """Diagnose a specific Lambda function"""
        try:
            self.logger.info(f"🔍 Diagnosing Lambda function: {function_name}")
            
            lambda_client = boto3.client('lambda', region_name=self.region)
            
            print(f"\n" + "="*80)
            print(f"🔍 LAMBDA FUNCTION DIAGNOSIS: {function_name}")
            print("="*80)
            
            # Get function configuration
            config = lambda_client.get_function(FunctionName=function_name)
            
            func_config = config.get('Configuration', {})
            func_code = config.get('Code', {})
            
            # Display configuration details
            print(f"\n📋 FUNCTION CONFIGURATION:")
            print(f"   Function Name: {func_config.get('FunctionName')}")
            print(f"   Runtime: {func_config.get('Runtime')}")
            print(f"   Handler: {func_config.get('Handler')}")
            print(f"   Timeout: {func_config.get('Timeout')} seconds")
            print(f"   Memory: {func_config.get('MemorySize')} MB")
            print(f"   State: {func_config.get('State')}")
            print(f"   Last Update: {func_config.get('LastUpdateStatus')}")
            print(f"   Role: {func_config.get('Role')}")
            
            # Check environment variables
            env_vars = func_config.get('Environment', {}).get('Variables', {})
            if env_vars:
                print(f"\n🌍 ENVIRONMENT VARIABLES:")
                for key, value in env_vars.items():
                    # Hide sensitive values
                    display_value = value if not any(secret in key.lower() for secret in ['key', 'secret', 'token', 'password']) else '***'
                    print(f"   {key}: {display_value}")
            
            # Test function invocation
            self.test_lambda_function(function_name)
            
            # Check CloudWatch logs
            self.check_lambda_logs(function_name)
            
            return config
            
        except Exception as e:
            self.logger.error(f"❌ Lambda diagnosis failed for {function_name}: {str(e)}")
            return {}

    def test_lambda_function(self, function_name: str):
        """Test Lambda function with a simple DNS query"""
        try:
            self.logger.info(f"🧪 Testing Lambda function: {function_name}")
            
            lambda_client = boto3.client('lambda', region_name=self.region)
            
            print(f"\n🧪 FUNCTION TEST:")
            
            # Test payload that might work for DNS lookup
            test_payloads = [
                # Agent Core Runtime format
                {
                    "inputText": "What is the IP address of google.com?",
                    "sessionId": "test-session-123",
                    "sessionAttributes": {},
                    "promptSessionAttributes": {}
                },
                # Simple format
                {
                    "query": "lookup google.com",
                    "domain": "google.com"
                },
                # Direct format
                {
                    "domain": "google.com",
                    "type": "A"
                }
            ]
            
            for i, payload in enumerate(test_payloads, 1):
                print(f"\n   Test {i}: {json.dumps(payload, indent=2)[:100]}...")
                
                try:
                    response = lambda_client.invoke(
                        FunctionName=function_name,
                        Payload=json.dumps(payload),
                        InvocationType='RequestResponse'
                    )
                    
                    status_code = response['StatusCode']
                    
                    if status_code == 200:
                        print(f"   ✅ SUCCESS (Status: {status_code})")
                        
                        # Parse response
                        response_payload = response['Payload'].read()
                        if response_payload:
                            try:
                                result = json.loads(response_payload)
                                print(f"   📋 Response: {json.dumps(result, indent=2)[:200]}...")
                            except:
                                print(f"   📋 Raw Response: {str(response_payload)[:200]}...")
                        
                        # If we get a successful response, we found the right format
                        return True
                        
                    else:
                        print(f"   ⚠️ UNEXPECTED STATUS: {status_code}")
                
                except Exception as e:
                    error_str = str(e)
                    if "does not exist" in error_str:
                        print(f"   ❌ FUNCTION NOT FOUND")
                        return False
                    else:
                        print(f"   ❌ ERROR: {error_str[:100]}")
            
            print(f"   ⚠️ All test payloads failed")
            return False
            
        except Exception as e:
            self.logger.error(f"❌ Lambda test failed: {str(e)}")
            return False

    def check_lambda_logs(self, function_name: str):
        """Check CloudWatch logs for Lambda function errors"""
        try:
            self.logger.info(f"📄 Checking CloudWatch logs for: {function_name}")
            
            logs_client = boto3.client('logs', region_name=self.region)
            
            # CloudWatch log group for Lambda function
            log_group_name = f"/aws/lambda/{function_name}"
            
            print(f"\n📄 CLOUDWATCH LOGS:")
            print(f"   Log Group: {log_group_name}")
            
            try:
                # Get recent log events (last 1 hour)
                end_time = int(datetime.now().timestamp() * 1000)
                start_time = int((datetime.now() - timedelta(hours=1)).timestamp() * 1000)
                
                response = logs_client.filter_log_events(
                    logGroupName=log_group_name,
                    startTime=start_time,
                    endTime=end_time,
                    limit=10
                )
                
                events = response.get('events', [])
                
                if events:
                    print(f"   📋 Recent log events ({len(events)}):")
                    for event in events[-5:]:  # Show last 5 events
                        timestamp = datetime.fromtimestamp(event['timestamp'] / 1000)
                        message = event['message'].strip()
                        print(f"   {timestamp}: {message[:100]}...")
                else:
                    print(f"   ⚠️ No recent log events found")
                    
            except Exception as e:
                if "does not exist" in str(e):
                    print(f"   ❌ Log group does not exist")
                else:
                    print(f"   ❌ Error reading logs: {str(e)}")
            
        except Exception as e:
            self.logger.error(f"❌ Log check failed: {str(e)}")

    def check_agent_core_integration(self):
        """Check how the Lambda integrates with Agent Core"""
        try:
            print(f"\n" + "="*80)
            print("🔗 AGENT CORE INTEGRATION CHECK")
            print("="*80)
            
            print(f"🤖 Agent Runtime ID: {self.agent_runtime_id}")
            
            # Check if there's a specific Lambda function for Agent Core
            # The Docker image we analyzed earlier is from 'dns-lookup-service'
            print(f"\n📦 Expected Integration:")
            print(f"   • Lambda function should be running the dns-lookup-service Docker image")
            print(f"   • Function should accept Agent Core Runtime input format")
            print(f"   • Function should return appropriate DNS lookup results")
            
            print(f"\n💡 Common Issues:")
            print(f"   • Lambda function not deployed or updated")
            print(f"   • Runtime environment issues (Python dependencies)")
            print(f"   • Handler function name mismatch")
            print(f"   • Timeout or memory issues")
            print(f"   • IAM permission issues")
            
        except Exception as e:
            self.logger.error(f"❌ Integration check failed: {str(e)}")

    def run_comprehensive_diagnosis(self):
        """Run complete diagnostic analysis"""
        print("\n🔍 DNS LAMBDA FUNCTION DIAGNOSTIC")
        print("="*60)
        print(f"🕒 Started: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        print(f"🎯 Target: DNS lookup functionality for Agent Core Runtime")
        
        # 1. Find DNS Lambda functions
        dns_functions = self.find_dns_lambda_functions()
        
        if dns_functions:
            print(f"\n✅ Found {len(dns_functions)} DNS Lambda function(s)")
            
            # Diagnose each function
            for func in dns_functions:
                function_name = func.get('FunctionName')
                self.diagnose_lambda_function(function_name)
        else:
            print(f"\n❌ No DNS Lambda functions found")
        
        # 2. Check Agent Core integration
        self.check_agent_core_integration()
        
        # 3. Generate recommendations
        self.generate_recommendations()

    def generate_recommendations(self):
        """Generate diagnostic recommendations"""
        print(f"\n" + "="*80)
        print("💡 DIAGNOSTIC RECOMMENDATIONS")
        print("="*80)
        
        print(f"\n🔧 TROUBLESHOOTING STEPS:")
        print(f"1. ✅ Verify DNS Lambda function exists and is properly deployed")
        print(f"2. ✅ Test Lambda function directly with DNS queries")
        print(f"3. ✅ Check CloudWatch logs for function errors")
        print(f"4. ✅ Verify IAM permissions for Lambda execution")
        print(f"5. ✅ Check Agent Core Runtime configuration")
        
        print(f"\n🚀 NEXT ACTIONS:")
        print(f"• If Lambda function found and working → Check Agent Core configuration")
        print(f"• If Lambda function has errors → Fix function code/configuration")
        print(f"• If Lambda function missing → Deploy from ECR image")
        print(f"• If permissions issues → Update IAM policies")
        
        print(f"\n📝 MANUAL TESTING:")
        print(f"• Test Lambda function directly in AWS Console")
        print(f"• Use payload: {{'inputText': 'lookup google.com', 'sessionId': 'test'}}")
        print(f"• Check function logs immediately after test")

def main():
    """Main execution function"""
    try:
        diagnostic = DNSLambdaDiagnostic()
        diagnostic.run_comprehensive_diagnosis()
        
    except KeyboardInterrupt:
        print("\n🛑 Diagnostic interrupted by user")
    except Exception as e:
        print(f"\n❌ Unexpected error: {str(e)}")

if __name__ == "__main__":
    main()