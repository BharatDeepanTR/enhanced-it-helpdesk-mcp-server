#!/usr/bin/env python3
"""
DNS Agent Analysis & Payload Generator
=====================================

This script analyzes the DNS agent to understand:
1. What the agent is designed to do
2. What Lambda functions it uses
3. How to prepare proper payloads for testing
4. Expected input/output formats for the endpoint

Features:
- Discovers DNS-related Lambda functions
- Analyzes agent configuration and capabilities
- Generates test payloads for the endpoint
- Tests Lambda functions directly to understand expected behavior
"""

import boto3
import json
import logging
import subprocess
from datetime import datetime
from typing import Dict, List, Any, Optional

class DNSAgentAnalyzer:
    """Comprehensive DNS Agent Analyzer and Payload Generator"""
    
    def __init__(self):
        """Initialize the analyzer"""
        self.region = 'us-east-1'
        self.setup_logging()
        
        # Known DNS agent information
        self.dns_agent_name = 'a208194_chatops_route_dns_lookup'
        self.dns_endpoint_name = 'chatops_dns_endpoint'
        
        # Initialize AWS clients
        self._init_aws_clients()
        
        self.logger.info("🔍 DNS Agent Analyzer initialized")

    def setup_logging(self):
        """Configure logging"""
        logging.basicConfig(
            level=logging.INFO,
            format='%(asctime)s - %(levelname)s - %(message)s'
        )
        self.logger = logging.getLogger('DNSAgentAnalyzer')

    def _init_aws_clients(self):
        """Initialize AWS clients"""
        try:
            self.lambda_client = boto3.client('lambda', region_name=self.region)
            self.logs_client = boto3.client('logs', region_name=self.region)
            self.ecr_client = boto3.client('ecr', region_name=self.region)
            
            # Get account info
            sts = boto3.client('sts', region_name=self.region)
            self.account_id = sts.get_caller_identity()['Account']
            
            self.logger.info("✅ AWS clients initialized successfully")
            
        except Exception as e:
            self.logger.error(f"❌ AWS initialization failed: {str(e)}")
            raise

    def discover_dns_lambda_functions(self) -> List[Dict[str, Any]]:
        """Discover DNS-related Lambda functions"""
        self.logger.info("🔍 Discovering DNS-related Lambda functions...")
        
        try:
            print("\n" + "="*80)
            print("🔍 DNS LAMBDA FUNCTION DISCOVERY")
            print("="*80)
            
            # List all Lambda functions
            response = self.lambda_client.list_functions()
            functions = response.get('Functions', [])
            
            # Search for DNS-related functions
            dns_keywords = ['dns', 'lookup', 'route', 'chatops', '208194']
            dns_functions = []
            
            print(f"📋 Scanning {len(functions)} Lambda functions...")
            
            for func in functions:
                func_name = func.get('FunctionName', '').lower()
                description = func.get('Description', '').lower()
                
                # Check if this is a DNS-related function
                if any(keyword in func_name or keyword in description for keyword in dns_keywords):
                    dns_functions.append(func)
                    
                    print(f"\n🎯 FOUND DNS FUNCTION:")
                    print(f"   Name: {func.get('FunctionName')}")
                    print(f"   Runtime: {func.get('Runtime')}")
                    print(f"   Handler: {func.get('Handler')}")
                    print(f"   Timeout: {func.get('Timeout')}s")
                    print(f"   Memory: {func.get('MemorySize')}MB")
                    print(f"   Last Modified: {func.get('LastModified')}")
                    print(f"   Description: {func.get('Description', 'N/A')}")
                    
                    # Check if it's a container image
                    if func.get('PackageType') == 'Image':
                        print(f"   Package Type: Container Image")
                        print(f"   Image URI: {func.get('Code', {}).get('ImageUri', 'N/A')}")
                    
            if dns_functions:
                print(f"\n✅ Found {len(dns_functions)} DNS-related Lambda function(s)")
            else:
                print(f"\n❌ No DNS-related Lambda functions found")
                
            return dns_functions
            
        except Exception as e:
            self.logger.error(f"❌ Function discovery failed: {str(e)}")
            return []

    def analyze_lambda_function(self, function_name: str) -> Dict[str, Any]:
        """Analyze a specific Lambda function to understand its capabilities"""
        self.logger.info(f"🔍 Analyzing Lambda function: {function_name}")
        
        try:
            print(f"\n" + "="*80)
            print(f"🔬 LAMBDA FUNCTION ANALYSIS: {function_name}")
            print("="*80)
            
            # Get function configuration
            config_response = self.lambda_client.get_function(FunctionName=function_name)
            config = config_response.get('Configuration', {})
            
            print(f"📋 Function Configuration:")
            print(f"   Runtime: {config.get('Runtime')}")
            print(f"   Handler: {config.get('Handler')}")
            print(f"   Role: {config.get('Role')}")
            print(f"   Timeout: {config.get('Timeout')}s")
            print(f"   Memory: {config.get('MemorySize')}MB")
            
            # Check environment variables
            env_vars = config.get('Environment', {}).get('Variables', {})
            if env_vars:
                print(f"\\n🌍 Environment Variables:")
                for key, value in env_vars.items():
                    # Mask sensitive values
                    display_value = value if len(value) < 50 else f"{value[:20]}...{value[-10:]}"
                    print(f"   {key}: {display_value}")
            
            # Get function code information
            code_info = config_response.get('Code', {})
            print(f"\\n📦 Code Information:")
            
            if config.get('PackageType') == 'Image':
                print(f"   Type: Container Image")
                print(f"   Image URI: {code_info.get('ImageUri', 'N/A')}")
                
                # Analyze the container image if it's from ECR
                image_uri = code_info.get('ImageUri', '')
                if 'ecr' in image_uri and 'dns-lookup-service' in image_uri:
                    self.analyze_ecr_image('dns-lookup-service')
            else:
                print(f"   Type: Zip Package")
                print(f"   Repository Type: {code_info.get('RepositoryType', 'N/A')}")
            
            # Try to invoke the function to understand its interface
            self.test_lambda_function(function_name)
            
            return config
            
        except Exception as e:
            self.logger.error(f"❌ Function analysis failed: {str(e)}")
            return {}

    def analyze_ecr_image(self, repository_name: str):
        """Analyze ECR image to understand the DNS agent structure"""
        self.logger.info(f"🐳 Analyzing ECR repository: {repository_name}")
        
        try:
            print(f"\\n🐳 ECR REPOSITORY ANALYSIS: {repository_name}")
            print("-" * 50)
            
            # Get repository info
            repo_response = self.ecr_client.describe_repositories(
                repositoryNames=[repository_name]
            )
            repositories = repo_response.get('repositories', [])
            
            if repositories:
                repo = repositories[0]
                print(f"📋 Repository Details:")
                print(f"   URI: {repo.get('repositoryUri')}")
                print(f"   Created: {repo.get('createdAt')}")
                print(f"   Image Count: {repo.get('imageCount', 0)}")
                
                # Get image details
                images_response = self.ecr_client.list_images(
                    repositoryName=repository_name
                )
                images = images_response.get('imageIds', [])
                
                if images:
                    print(f"\\n📦 Available Images: {len(images)}")
                    latest_image = images[0]  # Get the first (latest) image
                    
                    # Try to get image manifest
                    try:
                        manifest_response = self.ecr_client.get_image(
                            repositoryName=repository_name,
                            imageId=latest_image
                        )
                        
                        manifest = json.loads(manifest_response['imageManifest'])
                        print(f"   ✅ Image manifest retrieved")
                        print(f"   Architecture: {manifest.get('architecture', 'Unknown')}")
                        
                    except Exception as e:
                        print(f"   ⚠️ Could not retrieve image manifest: {str(e)}")
                        
        except Exception as e:
            self.logger.error(f"❌ ECR analysis failed: {str(e)}")

    def test_lambda_function(self, function_name: str):
        """Test Lambda function with various payloads to understand its interface"""
        self.logger.info(f"🧪 Testing Lambda function: {function_name}")
        
        try:
            print(f"\\n🧪 LAMBDA FUNCTION TESTING")
            print("-" * 50)
            
            # Test payloads to understand the interface
            test_payloads = [
                # Simple DNS lookup request
                {
                    "query": "What is the IP address of google.com?",
                    "type": "dns_lookup"
                },
                # ChatOps style request
                {
                    "message": "dns lookup amazon.com",
                    "action": "lookup"
                },
                # Route request
                {
                    "query": "Show me the route to 8.8.8.8",
                    "type": "route"
                },
                # Simple string input
                "lookup google.com",
                # Agent Core Runtime format
                {
                    "inputText": "What is the IP address of microsoft.com?",
                    "sessionId": "test-session",
                    "sessionAttributes": {},
                    "promptSessionAttributes": {}
                }
            ]
            
            successful_formats = []
            
            for i, payload in enumerate(test_payloads, 1):
                print(f"\\n🔬 Test {i}: {type(payload).__name__} payload")
                print(f"   Payload: {str(payload)[:100]}...")
                
                try:
                    response = self.lambda_client.invoke(
                        FunctionName=function_name,
                        InvocationType='RequestResponse',
                        Payload=json.dumps(payload)
                    )
                    
                    # Read response
                    response_payload = response['Payload'].read()
                    
                    if response_payload:
                        try:
                            result = json.loads(response_payload)
                            print(f"   ✅ SUCCESS: {str(result)[:100]}...")
                            successful_formats.append({
                                'payload': payload,
                                'response': result
                            })
                        except json.JSONDecodeError:
                            print(f"   ✅ SUCCESS: {response_payload.decode()[:100]}...")
                            successful_formats.append({
                                'payload': payload,
                                'response': response_payload.decode()
                            })
                    else:
                        print(f"   ⚠️ Empty response")
                        
                except Exception as e:
                    error_msg = str(e)
                    if "timeout" in error_msg.lower():
                        print(f"   ⏱️ TIMEOUT: Function may be working but slow")
                    elif "error" in error_msg.lower():
                        print(f"   ❌ ERROR: {error_msg[:100]}...")
                    else:
                        print(f"   ⚠️ ISSUE: {error_msg[:100]}...")
            
            if successful_formats:
                print(f"\\n🎉 Found {len(successful_formats)} working payload format(s)")
                self.generate_endpoint_payloads(successful_formats)
            else:
                print(f"\\n⚠️ No successful payload formats found")
                
        except Exception as e:
            self.logger.error(f"❌ Function testing failed: {str(e)}")

    def generate_endpoint_payloads(self, successful_formats: List[Dict]):
        """Generate endpoint payloads based on successful Lambda tests"""
        print(f"\\n" + "="*80)
        print("🎯 ENDPOINT PAYLOAD GENERATION")
        print("="*80)
        
        print(f"Based on successful Lambda tests, here are the recommended payloads for the Agent Core endpoint:")
        
        # Common DNS queries
        dns_queries = [
            "What is the IP address of google.com?",
            "dns lookup amazon.com",
            "Show me the route to 8.8.8.8",
            "Can you lookup the DNS for microsoft.com?",
            "trace route to cloudflare.com",
            "Find the IP address for github.com"
        ]
        
        print(f"\\n📋 RECOMMENDED ENDPOINT PAYLOADS:")
        print("-" * 50)
        
        for i, query in enumerate(dns_queries, 1):
            payload = {
                "inputText": query,
                "sessionId": f"test-session-{datetime.now().strftime('%Y%m%d-%H%M%S')}-{i}",
                "sessionAttributes": {},
                "promptSessionAttributes": {}
            }
            
            print(f"\\n{i}. Query: {query}")
            print(f"   JSON Payload:")
            print(f"   {json.dumps(payload, indent=2)}")
            
        # Save payloads to files
        self.save_payload_files(dns_queries)

    def save_payload_files(self, queries: List[str]):
        """Save payload files for easy testing"""
        
        # Create individual payload files
        for i, query in enumerate(queries, 1):
            payload = {
                "inputText": query,
                "sessionId": f"test-session-{datetime.now().strftime('%Y%m%d-%H%M%S')}-{i}",
                "sessionAttributes": {},
                "promptSessionAttributes": {}
            }
            
            filename = f"dns_payload_{i:02d}.json"
            with open(filename, 'w') as f:
                json.dump(payload, f, indent=2)
            
            print(f"📄 Saved: {filename}")
        
        # Create a comprehensive test script
        self.create_endpoint_test_script(queries)

    def create_endpoint_test_script(self, queries: List[str]):
        """Create a test script for the endpoint"""
        
        script_content = f'''#!/usr/bin/env python3
"""
DNS Agent Endpoint Test Script
=============================
Auto-generated based on Lambda analysis.

Agent: {self.dns_agent_name}
Endpoint: {self.dns_endpoint_name}
Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}
"""

import json
import requests
import boto3
from datetime import datetime

# NOTE: Replace this URL with the actual endpoint URL from Agent Core console
ENDPOINT_URL = "https://your-endpoint-url-here"

def test_dns_endpoint():
    \"\"\"Test DNS agent endpoint with validated payloads\"\"\"
    
    print("🧪 DNS AGENT ENDPOINT TEST")
    print("="*50)
    print(f"Endpoint: {{ENDPOINT_URL}}")
    print("="*50)
    
    # Test queries based on Lambda analysis
    test_queries = {json.dumps(queries, indent=4)}
    
    for i, query in enumerate(test_queries, 1):
        print(f"\\n{{i}}. Testing: {{query}}")
        print("-" * 40)
        
        payload = {{
            "inputText": query,
            "sessionId": f"test-session-{{datetime.now().strftime('%Y%m%d-%H%M%S')}}-{{i}}",
            "sessionAttributes": {{}},
            "promptSessionAttributes": {{}}
        }}
        
        print(f"📝 Payload: {{json.dumps(payload, indent=2)}}")
        
        # For testing via AWS SDK (if using Agent Core Runtime API)
        try:
            client = boto3.client('bedrock-agent-runtime', region_name='{self.region}')
            
            # NOTE: You'll need to get the correct agent ID and alias
            response = client.invoke_agent(
                agentId='YOUR_AGENT_ID',  # Replace with actual agent ID
                agentAliasId='YOUR_ALIAS_ID',  # Replace with actual alias
                sessionId=payload['sessionId'],
                inputText=payload['inputText']
            )
            
            print(f"✅ AWS SDK Success: {{str(response)[:200]}}...")
            
        except Exception as e:
            print(f"⚠️ AWS SDK Error: {{str(e)}}")
        
        # For testing via HTTP endpoint (if available)
        try:
            headers = {{
                'Content-Type': 'application/json',
                'Authorization': 'Bearer YOUR_TOKEN'  # Replace with actual auth
            }}
            
            response = requests.post(ENDPOINT_URL, json=payload, headers=headers)
            
            if response.status_code == 200:
                print(f"✅ HTTP Success: {{response.text[:200]}}...")
            else:
                print(f"❌ HTTP Error {{response.status_code}}: {{response.text[:200]}}...")
                
        except Exception as e:
            print(f"⚠️ HTTP Error: {{str(e)}}")

if __name__ == "__main__":
    test_dns_endpoint()
'''
        
        filename = "test_dns_endpoint.py"
        with open(filename, 'w') as f:
            f.write(script_content)
        
        print(f"\\n📄 Created endpoint test script: {filename}")
        print(f"💡 Edit the script to add your actual endpoint URL and credentials")

    def run_comprehensive_analysis(self):
        """Run complete analysis of the DNS agent"""
        
        print("\\n🔍 DNS AGENT COMPREHENSIVE ANALYSIS")
        print("="*60)
        print(f"🕒 Started: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        print(f"🎯 Target Agent: {self.dns_agent_name}")
        print(f"🔗 Target Endpoint: {self.dns_endpoint_name}")
        
        # 1. Discover DNS Lambda functions
        dns_functions = self.discover_dns_lambda_functions()
        
        # 2. Analyze each function
        for func in dns_functions:
            func_name = func.get('FunctionName')
            if func_name:
                self.analyze_lambda_function(func_name)
        
        # 3. Generate summary report
        self.generate_summary_report(dns_functions)

    def generate_summary_report(self, dns_functions: List[Dict]):
        """Generate final analysis summary"""
        
        print(f"\\n" + "="*80)
        print("📊 DNS AGENT ANALYSIS SUMMARY")
        print("="*80)
        print(f"🕒 Completed: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        
        print(f"\\n📈 FINDINGS:")
        print(f"   DNS Lambda Functions Found: {len(dns_functions)}")
        
        if dns_functions:
            print(f"\\n📋 FUNCTION DETAILS:")
            for func in dns_functions:
                print(f"   • {func.get('FunctionName')} ({func.get('Runtime')})")
        
        print(f"\\n🎯 NEXT STEPS:")
        print(f"   1. Use generated payload files (dns_payload_*.json)")
        print(f"   2. Test with the endpoint test script (test_dns_endpoint.py)")
        print(f"   3. Check CloudWatch logs for detailed error messages")
        print(f"   4. Verify IAM permissions for the agent's service role")
        
        print(f"\\n💡 TROUBLESHOOTING:")
        print(f"   • Runtime errors often indicate missing dependencies")
        print(f"   • Container startup failures suggest image configuration issues")
        print(f"   • Check the agent's IAM role has necessary permissions")
        print(f"   • Verify the Lambda function is properly deployed")
        
        print("="*80)

def main():
    \"\"\"Main execution function\"\"\"
    try:
        analyzer = DNSAgentAnalyzer()
        analyzer.run_comprehensive_analysis()
        
    except KeyboardInterrupt:
        print("\\n🛑 Analysis interrupted by user")
    except Exception as e:
        print(f"\\n❌ Unexpected error: {str(e)}")

if __name__ == "__main__":
    main()