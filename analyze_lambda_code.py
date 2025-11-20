#!/usr/bin/env python3
"""
Lambda Function Code Analyzer and Test Generator
===============================================

This script analyzes the deployed Lambda function code and generates
appropriate test payloads for the Lambda Test Console.

Lambda ARN: arn:aws:lambda:us-east-1:818565325759:function:a208194_chatops_route_dns_lookup
Function Name: a208194_chatops_route_dns_lookup
"""

import boto3
import json
import zipfile
import os
import tempfile
import logging
from datetime import datetime
from typing import Dict, List, Any, Optional

class LambdaCodeAnalyzer:
    """Analyze Lambda function code and generate test payloads"""
    
    def __init__(self):
        """Initialize the analyzer"""
        self.region = 'us-east-1'
        self.function_name = 'a208194_chatops_route_dns_lookup'
        self.function_arn = f'arn:aws:lambda:us-east-1:818565325759:function:{self.function_name}'
        
        self.setup_logging()
        self._init_aws_clients()
        
        self.logger.info(f"🔍 Lambda Code Analyzer initialized")
        self.logger.info(f"🎯 Target Function: {self.function_name}")

    def setup_logging(self):
        """Configure logging"""
        logging.basicConfig(
            level=logging.INFO,
            format='%(asctime)s - %(levelname)s - %(message)s'
        )
        self.logger = logging.getLogger('LambdaAnalyzer')

    def _init_aws_clients(self):
        """Initialize AWS clients"""
        try:
            self.lambda_client = boto3.client('lambda', region_name=self.region)
            self.logger.info("✅ AWS Lambda client initialized")
        except Exception as e:
            self.logger.error(f"❌ AWS client initialization failed: {str(e)}")
            raise

    def get_function_configuration(self) -> Dict[str, Any]:
        """Get Lambda function configuration"""
        try:
            self.logger.info(f"📋 Getting function configuration...")
            
            response = self.lambda_client.get_function(FunctionName=self.function_name)
            config = response['Configuration']
            code_info = response['Code']
            
            print("\n" + "="*80)
            print("📋 LAMBDA FUNCTION CONFIGURATION")
            print("="*80)
            print(f"Function Name: {config.get('FunctionName')}")
            print(f"Function ARN: {config.get('FunctionArn')}")
            print(f"Runtime: {config.get('Runtime')}")
            print(f"Handler: {config.get('Handler')}")
            print(f"Memory: {config.get('MemorySize')} MB")
            print(f"Timeout: {config.get('Timeout')} seconds")
            print(f"State: {config.get('State')}")
            print(f"Last Modified: {config.get('LastModified')}")
            print(f"Code Size: {config.get('CodeSize')} bytes")
            print(f"Code SHA256: {config.get('CodeSha256')}")
            
            # Environment variables
            env_vars = config.get('Environment', {}).get('Variables', {})
            if env_vars:
                print(f"\n🌍 Environment Variables:")
                for key, value in env_vars.items():
                    print(f"   {key}: {value}")
            else:
                print(f"\n🌍 Environment Variables: None")
            
            # Role and VPC
            print(f"\n🔐 Execution Role: {config.get('Role')}")
            vpc_config = config.get('VpcConfig', {})
            if vpc_config.get('VpcId'):
                print(f"🌐 VPC ID: {vpc_config.get('VpcId')}")
            else:
                print(f"🌐 VPC: No VPC configuration")
            
            return config
            
        except Exception as e:
            self.logger.error(f"❌ Failed to get function configuration: {str(e)}")
            return {}

    def download_and_analyze_code(self) -> Dict[str, Any]:
        """Download and analyze the function code"""
        try:
            self.logger.info(f"📦 Downloading function code...")
            
            response = self.lambda_client.get_function(FunctionName=self.function_name)
            code_location = response['Code']['Location']
            
            print(f"\n📦 Code Location: {code_location}")
            
            # Download the code
            import urllib.request
            with tempfile.NamedTemporaryFile(suffix='.zip', delete=False) as temp_file:
                urllib.request.urlretrieve(code_location, temp_file.name)
                zip_path = temp_file.name
            
            # Extract and analyze
            analysis_results = self.analyze_zip_contents(zip_path)
            
            # Clean up
            os.unlink(zip_path)
            
            return analysis_results
            
        except Exception as e:
            self.logger.error(f"❌ Failed to download/analyze code: {str(e)}")
            return {}

    def analyze_zip_contents(self, zip_path: str) -> Dict[str, Any]:
        """Analyze the contents of the Lambda zip file"""
        try:
            print(f"\n" + "="*80)
            print("📁 LAMBDA CODE ANALYSIS")
            print("="*80)
            
            analysis = {
                'files': [],
                'python_files': [],
                'entry_points': [],
                'dependencies': [],
                'handlers': []
            }
            
            with zipfile.ZipFile(zip_path, 'r') as zip_ref:
                file_list = zip_ref.namelist()
                
                print(f"📁 Total files: {len(file_list)}")
                
                # Analyze files
                for file_name in file_list:
                    analysis['files'].append(file_name)
                    
                    if file_name.endswith('.py'):
                        analysis['python_files'].append(file_name)
                        print(f"🐍 Python file: {file_name}")
                        
                        # Try to read and analyze Python files
                        try:
                            with zip_ref.open(file_name) as f:
                                content = f.read().decode('utf-8', errors='ignore')
                                
                                # Look for handler functions
                                if 'def lambda_handler' in content or 'def handler' in content:
                                    analysis['handlers'].append(file_name)
                                    print(f"   ✅ Handler function found")
                                
                                # Look for specific patterns
                                if 'dns' in content.lower() or 'lookup' in content.lower():
                                    print(f"   🔍 DNS/lookup functionality detected")
                                
                                if 'route' in content.lower() or 'trace' in content.lower():
                                    print(f"   🛣️ Route/trace functionality detected")
                                    
                                # Show first few lines if it's the main file
                                if file_name in ['lambda_function.py', 'main.py', 'handler.py', 'index.py']:
                                    lines = content.split('\n')[:20]
                                    print(f"   📝 Code preview:")
                                    for i, line in enumerate(lines, 1):
                                        if line.strip():
                                            print(f"      {i:2}: {line}")
                                            
                        except Exception as e:
                            print(f"   ⚠️ Could not read file: {str(e)}")
                    
                    elif file_name == 'requirements.txt':
                        try:
                            with zip_ref.open(file_name) as f:
                                content = f.read().decode('utf-8')
                                analysis['dependencies'] = content.strip().split('\n')
                                print(f"📦 Dependencies found: {len(analysis['dependencies'])}")
                                for dep in analysis['dependencies']:
                                    if dep.strip():
                                        print(f"   • {dep.strip()}")
                        except Exception as e:
                            print(f"   ⚠️ Could not read requirements.txt: {str(e)}")
            
            return analysis
            
        except Exception as e:
            self.logger.error(f"❌ Failed to analyze zip contents: {str(e)}")
            return {}

    def generate_test_payloads(self, config: Dict[str, Any], analysis: Dict[str, Any]) -> List[Dict[str, Any]]:
        """Generate test payloads based on function analysis"""
        handler = config.get('Handler', 'lambda_function.lambda_handler')
        
        print(f"\n" + "="*80)
        print("🧪 GENERATED TEST PAYLOADS")
        print("="*80)
        print(f"Handler: {handler}")
        
        # Based on the handler and analysis, generate appropriate test payloads
        test_payloads = []
        
        # Basic DNS lookup test
        dns_test = {
            "test_name": "Basic DNS Lookup",
            "event": {
                "query": "What is the IP address of google.com?",
                "domain": "google.com",
                "query_type": "A"
            }
        }
        test_payloads.append(dns_test)
        
        # Route test
        route_test = {
            "test_name": "Route Information",
            "event": {
                "query": "Show me the route to 8.8.8.8",
                "target": "8.8.8.8",
                "operation": "route"
            }
        }
        test_payloads.append(route_test)
        
        # ChatOps style test
        chatops_test = {
            "test_name": "ChatOps Command",
            "event": {
                "command": "dns lookup amazon.com",
                "user": "test-user",
                "channel": "test-channel"
            }
        }
        test_payloads.append(chatops_test)
        
        # Agent Core Runtime style test (most likely format)
        agentcore_test = {
            "test_name": "Agent Core Runtime Format",
            "event": {
                "inputText": "dns lookup microsoft.com",
                "sessionId": "test-session-123",
                "sessionAttributes": {},
                "promptSessionAttributes": {}
            }
        }
        test_payloads.append(agentcore_test)
        
        # Generic test with minimal payload
        minimal_test = {
            "test_name": "Minimal Test",
            "event": {
                "test": True,
                "message": "Hello DNS agent"
            }
        }
        test_payloads.append(minimal_test)
        
        return test_payloads

    def display_test_instructions(self, test_payloads: List[Dict[str, Any]]):
        """Display instructions for Lambda Test Console"""
        
        print(f"\n" + "="*80)
        print("🧪 LAMBDA TEST CONSOLE INSTRUCTIONS")
        print("="*80)
        print(f"Function: {self.function_name}")
        print(f"Region: {self.region}")
        print("\n📋 Steps:")
        print("1. Go to AWS Lambda Console")
        print("2. Find function: a208194_chatops_route_dns_lookup")
        print("3. Click 'Test' tab")
        print("4. Create new test event")
        print("5. Use the JSON payloads below")
        
        for i, payload in enumerate(test_payloads, 1):
            print(f"\n{i}️⃣ TEST: {payload['test_name']}")
            print("-" * 50)
            print("JSON Payload:")
            print(json.dumps(payload['event'], indent=2))
            
            # Save to file for easy copy-paste
            filename = f"lambda_test_{i}_{payload['test_name'].lower().replace(' ', '_')}.json"
            with open(filename, 'w') as f:
                json.dump(payload['event'], f, indent=2)
            print(f"💾 Saved to: {filename}")

    def test_function_directly(self, test_payloads: List[Dict[str, Any]]):
        """Test the function directly using boto3"""
        
        print(f"\n" + "="*80)
        print("🚀 DIRECT FUNCTION TESTING")
        print("="*80)
        
        for i, payload in enumerate(test_payloads, 1):
            print(f"\n{i}️⃣ Testing: {payload['test_name']}")
            print("-" * 40)
            
            try:
                response = self.lambda_client.invoke(
                    FunctionName=self.function_name,
                    Payload=json.dumps(payload['event'])
                )
                
                # Read response
                response_payload = response['Payload'].read()
                
                print(f"Status Code: {response['StatusCode']}")
                
                if response['StatusCode'] == 200:
                    try:
                        result = json.loads(response_payload.decode('utf-8'))
                        print(f"✅ SUCCESS")
                        print(f"Response: {json.dumps(result, indent=2)[:500]}...")
                    except:
                        print(f"✅ SUCCESS (Raw response)")
                        print(f"Response: {response_payload.decode('utf-8', errors='ignore')[:500]}...")
                else:
                    print(f"❌ FAILED")
                    print(f"Response: {response_payload.decode('utf-8', errors='ignore')}")
                
            except Exception as e:
                print(f"❌ ERROR: {str(e)}")

    def run_complete_analysis(self):
        """Run complete analysis and test generation"""
        print(f"\n🔍 LAMBDA FUNCTION ANALYSIS AND TEST GENERATION")
        print("="*60)
        print(f"🕒 Started: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        print(f"🎯 Function: {self.function_name}")
        
        # 1. Get configuration
        config = self.get_function_configuration()
        
        # 2. Download and analyze code
        analysis = self.download_and_analyze_code()
        
        # 3. Generate test payloads
        test_payloads = self.generate_test_payloads(config, analysis)
        
        # 4. Display test instructions
        self.display_test_instructions(test_payloads)
        
        # 5. Test function directly
        self.test_function_directly(test_payloads)
        
        print(f"\n🏁 Analysis completed!")
        print(f"📁 Test files created for Lambda Test Console")
        print(f"🧪 Direct testing results shown above")

def main():
    """Main execution function"""
    try:
        analyzer = LambdaCodeAnalyzer()
        analyzer.run_complete_analysis()
        
    except KeyboardInterrupt:
        print("\n🛑 Analysis interrupted by user")
    except Exception as e:
        print(f"\n❌ Unexpected error: {str(e)}")

if __name__ == "__main__":
    main()