#!/usr/bin/env python3
"""
DNS Agent Analysis and Payload Generator
========================================

This script analyzes the DNS agent to understand:
1. What the agent does
2. How to prepare the correct payload
3. How to test through the endpoint
"""

import boto3
import json
import time
from datetime import datetime
from typing import Dict, List, Any, Optional

class DNSAgentAnalyzer:
    """Analyze the DNS agent and generate test payloads"""
    
    def __init__(self):
        """Initialize the analyzer"""
        self.region = 'us-east-1'
        self.runtime_agent = 'a208194_chatops_route_dns_lookup'
        self.endpoint_name = 'chatops_dns_endpoint'
        
        print("🔍 DNS Agent Analyzer initialized")
        print(f"🤖 Runtime Agent: {self.runtime_agent}")
        print(f"🌐 Endpoint: {self.endpoint_name}")
        
        self._init_aws_clients()

    def _init_aws_clients(self):
        """Initialize AWS clients"""
        try:
            # Initialize clients
            self.bedrock_agent_runtime = boto3.client('bedrock-agent-runtime', region_name=self.region)
            self.lambda_client = boto3.client('lambda', region_name=self.region)
            
            # Verify authentication
            sts = boto3.client('sts', region_name=self.region)
            identity = sts.get_caller_identity()
            
            print(f"✅ AWS clients initialized")
            print(f"🔐 Account: {identity.get('Account')}")
            
        except Exception as e:
            print(f"❌ AWS initialization failed: {str(e)}")
            raise

    def analyze_dns_agent_purpose(self):
        """Analyze what the DNS agent is designed to do"""
        
        print("\n" + "="*80)
        print("🎯 DNS AGENT PURPOSE ANALYSIS")
        print("="*80)
        
        print("📋 Based on the agent name 'a208194_chatops_route_dns_lookup':")
        print("   • ChatOps: Designed for chat-based operations")
        print("   • Route: Network routing information") 
        print("   • DNS: Domain Name System lookups")
        print("   • Lookup: Query-based functionality")
        
        print("\n🔧 Expected Capabilities:")
        capabilities = [
            "DNS resolution (domain to IP)",
            "Reverse DNS lookups (IP to domain)",
            "MX record queries (mail servers)",
            "NS record queries (name servers)",
            "Network routing information",
            "Traceroute functionality",
            "Network diagnostic tools",
            "ChatOps-style command interface"
        ]
        
        for i, capability in enumerate(capabilities, 1):
            print(f"   {i}. {capability}")
        
        print("\n💬 Typical ChatOps Commands:")
        chatops_commands = [
            "dns lookup <domain>",
            "nslookup <domain>", 
            "dig <domain>",
            "route to <ip>",
            "traceroute <domain>",
            "whois <domain>",
            "ping <host>",
            "resolve <domain>"
        ]
        
        for cmd in chatops_commands:
            print(f"   • {cmd}")

    def generate_test_payloads(self):
        """Generate proper JSON payloads for testing"""
        
        print("\n" + "="*80)
        print("📝 TEST PAYLOAD GENERATION")
        print("="*80)
        
        # Define test scenarios
        test_scenarios = [
            {
                "name": "Basic DNS Lookup",
                "description": "Simple domain to IP resolution",
                "queries": [
                    "What is the IP address of google.com?",
                    "dns lookup amazon.com",
                    "resolve microsoft.com",
                    "nslookup github.com"
                ]
            },
            {
                "name": "ChatOps Commands", 
                "description": "Command-style queries",
                "queries": [
                    "dns google.com",
                    "lookup facebook.com", 
                    "dig apple.com",
                    "resolve twitter.com"
                ]
            },
            {
                "name": "Route Information",
                "description": "Network routing queries", 
                "queries": [
                    "route to 8.8.8.8",
                    "traceroute google.com",
                    "show route to cloudflare.com",
                    "trace path to aws.amazon.com"
                ]
            },
            {
                "name": "MX Records",
                "description": "Mail server lookups",
                "queries": [
                    "MX records for gmail.com",
                    "mail servers for outlook.com",
                    "email servers for yahoo.com",
                    "mx lookup for company.com"
                ]
            },
            {
                "name": "Advanced Queries",
                "description": "Complex DNS operations",
                "queries": [
                    "NS records for example.com",
                    "name servers for cloudflare.com",
                    "whois information for github.com", 
                    "PTR record for 8.8.8.8"
                ]
            }
        ]
        
        # Generate payloads for each scenario
        all_payloads = []
        
        for scenario in test_scenarios:
            print(f"\n📋 {scenario['name']} Payloads:")
            print(f"   Description: {scenario['description']}")
            print("   " + "-" * 50)
            
            for i, query in enumerate(scenario['queries'], 1):
                # Generate unique session ID
                timestamp = datetime.now().strftime('%Y%m%d%H%M%S')
                session_id = f"test-{timestamp}-{i}"
                
                payload = {
                    "inputText": query,
                    "sessionId": session_id,
                    "sessionAttributes": {},
                    "promptSessionAttributes": {}
                }
                
                all_payloads.append({
                    "scenario": scenario['name'],
                    "query": query,
                    "payload": payload
                })
                
                print(f"   {i}. Query: {query}")
                print(f"      Session: {session_id}")
                print(f"      Payload: {json.dumps(payload, indent=6)}")
                print()
        
        # Save all payloads to file
        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
        filename = f"dns_agent_test_payloads_{timestamp}.json"
        
        with open(filename, 'w') as f:
            json.dump(all_payloads, f, indent=2)
        
        print(f"💾 All payloads saved to: {filename}")
        
        return all_payloads

    def create_quick_test_payloads(self):
        """Create ready-to-use payloads for immediate testing"""
        
        print("\n" + "="*80) 
        print("🚀 QUICK TEST PAYLOADS")
        print("="*80)
        
        # Create simple payloads for immediate copy-paste
        quick_tests = [
            "What is the IP address of google.com?",
            "dns lookup amazon.com", 
            "route to 8.8.8.8",
            "MX records for gmail.com",
            "traceroute cloudflare.com"
        ]
        
        print("📋 Copy-paste ready payloads:")
        print("=" * 40)
        
        for i, query in enumerate(quick_tests, 1):
            timestamp = datetime.now().strftime('%Y%m%d%H%M%S')
            session_id = f"quick-test-{timestamp}-{i}"
            
            payload = {
                "inputText": query,
                "sessionId": session_id,
                "sessionAttributes": {},
                "promptSessionAttributes": {}
            }
            
            print(f"\n{i}. Test: {query}")
            print("   JSON Payload:")
            print(json.dumps(payload, indent=4))
            print("   " + "-" * 50)
        
        # Create a single-line compact version
        print("\n🎯 COMPACT PAYLOADS (single line):")
        print("=" * 40)
        
        for i, query in enumerate(quick_tests, 1):
            timestamp = datetime.now().strftime('%Y%m%d%H%M%S') 
            session_id = f"compact-{timestamp}-{i}"
            
            compact_payload = {
                "inputText": query,
                "sessionId": session_id,
                "sessionAttributes": {},
                "promptSessionAttributes": {}
            }
            
            print(f"{i}. {json.dumps(compact_payload)}")

    def find_dns_lambda_functions(self):
        """Find Lambda functions that might be related to the DNS agent"""
        
        print("\n" + "="*80)
        print("🔍 DNS LAMBDA FUNCTION DISCOVERY") 
        print("="*80)
        
        try:
            # List Lambda functions
            response = self.lambda_client.list_functions()
            functions = response.get('Functions', [])
            
            print(f"📋 Found {len(functions)} total Lambda functions")
            
            # Search for DNS-related functions
            dns_keywords = ['dns', 'route', 'lookup', 'chatops', '208194']
            dns_functions = []
            
            for func in functions:
                func_name = func.get('FunctionName', '').lower()
                description = func.get('Description', '').lower()
                
                if any(keyword in func_name or keyword in description for keyword in dns_keywords):
                    dns_functions.append(func)
            
            if dns_functions:
                print(f"\n🎯 Found {len(dns_functions)} DNS-related functions:")
                
                for i, func in enumerate(dns_functions, 1):
                    print(f"\n   {i}. {func.get('FunctionName')}")
                    print(f"      Runtime: {func.get('Runtime', 'N/A')}")
                    print(f"      Handler: {func.get('Handler', 'N/A')}")
                    print(f"      Description: {func.get('Description', 'N/A')}")
                    print(f"      Last Modified: {func.get('LastModified', 'N/A')}")
                    
                    # Try to get function configuration
                    try:
                        config = self.lambda_client.get_function_configuration(
                            FunctionName=func.get('FunctionName')
                        )
                        print(f"      Environment: {config.get('Environment', {}).get('Variables', {})}")
                    except Exception as e:
                        print(f"      Config Error: {str(e)}")
            else:
                print("\n❌ No DNS-related Lambda functions found")
                
        except Exception as e:
            print(f"❌ Lambda discovery failed: {str(e)}")

    def create_endpoint_test_script(self):
        """Create a script to test the DNS agent through the endpoint"""
        
        print("\n" + "="*80)
        print("📄 ENDPOINT TEST SCRIPT GENERATION")
        print("="*80)
        
        script_content = f'''#!/usr/bin/env python3
"""
DNS Agent Endpoint Test Script
=============================

Test the DNS agent through the Agent Core endpoint.

Agent: {self.runtime_agent}
Endpoint: {self.endpoint_name}
Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}
"""

import boto3
import json
import time
from datetime import datetime

def test_dns_agent_endpoint():
    """Test DNS agent through endpoint"""
    
    # Configuration
    REGION = "{self.region}"
    RUNTIME_AGENT = "{self.runtime_agent}"
    ENDPOINT = "{self.endpoint_name}"
    
    print("🧪 DNS Agent Endpoint Test")
    print("="*50)
    print(f"Runtime Agent: {{RUNTIME_AGENT}}")
    print(f"Endpoint: {{ENDPOINT}}")
    print(f"Region: {{REGION}}")
    print("="*50)
    
    # Initialize client
    client = boto3.client('bedrock-agent-runtime', region_name=REGION)
    
    # Test queries
    test_queries = [
        "What is the IP address of google.com?",
        "dns lookup amazon.com",
        "route to 8.8.8.8", 
        "MX records for gmail.com",
        "traceroute cloudflare.com"
    ]
    
    for i, query in enumerate(test_queries, 1):
        print(f"\\n{{i}}. Testing: {{query}}")
        print("-" * 40)
        
        try:
            # Generate unique session
            timestamp = datetime.now().strftime('%Y%m%d%H%M%S')
            session_id = f"endpoint-test-{{timestamp}}-{{i}}"
            
            # Create payload
            payload = {{
                "inputText": query,
                "sessionId": session_id,
                "sessionAttributes": {{}},
                "promptSessionAttributes": {{}}
            }}
            
            print(f"📝 Payload: {{json.dumps(payload)}}")
            
            # Make the call - Note: This uses a hypothetical endpoint invoke
            # The actual API call may be different for Agent Core endpoints
            start_time = time.time()
            
            # TODO: Replace with actual endpoint invocation method
            print("⚠️ Endpoint invocation method needs to be implemented")
            print("💡 Use the Agent Core console sandbox for now")
            
            execution_time = time.time() - start_time
            print(f"⏱️ Execution time: {{execution_time:.2f}}s")
            
        except Exception as e:
            print(f"❌ FAILED: {{str(e)}}")
        
        time.sleep(1)  # Rate limiting

def create_console_payloads():
    """Generate payloads for console testing"""
    
    print("\\n📋 CONSOLE TEST PAYLOADS")
    print("="*30)
    
    queries = [
        "What is the IP address of google.com?",
        "dns lookup amazon.com",
        "route to 8.8.8.8"
    ]
    
    for i, query in enumerate(queries, 1):
        timestamp = datetime.now().strftime('%Y%m%d%H%M%S')
        session_id = f"console-test-{{timestamp}}-{{i}}"
        
        payload = {{
            "inputText": query,
            "sessionId": session_id,
            "sessionAttributes": {{}},
            "promptSessionAttributes": {{}}
        }}
        
        print(f"\\n{{i}}. {{query}}")
        print(f"{{json.dumps(payload, indent=2)}}")

if __name__ == "__main__":
    test_dns_agent_endpoint()
    create_console_payloads()
'''
        
        filename = f"dns_endpoint_test_{datetime.now().strftime('%Y%m%d_%H%M%S')}.py"
        
        with open(filename, 'w') as f:
            f.write(script_content)
        
        print(f"📄 Endpoint test script created: {filename}")
        print(f"💡 Run with: python3 {filename}")
        
        return filename

    def run_comprehensive_analysis(self):
        """Run complete analysis of the DNS agent"""
        
        print("🔍 DNS AGENT COMPREHENSIVE ANALYSIS")
        print("="*60)
        print(f"🕒 Started: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        print(f"🌎 Region: {self.region}")
        
        # 1. Analyze agent purpose
        self.analyze_dns_agent_purpose()
        
        # 2. Generate test payloads
        payloads = self.generate_test_payloads()
        
        # 3. Create quick test payloads
        self.create_quick_test_payloads()
        
        # 4. Find related Lambda functions
        self.find_dns_lambda_functions()
        
        # 5. Create endpoint test script
        script_file = self.create_endpoint_test_script()
        
        # Final summary
        print("\n" + "="*80)
        print("📋 ANALYSIS SUMMARY")
        print("="*80)
        print(f"🕒 Completed: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        print(f"📊 Generated {len(payloads)} test payloads")
        print(f"📄 Created endpoint test script: {script_file}")
        
        print("\n🎯 NEXT STEPS:")
        print("1. Use the generated payloads in Agent Core console sandbox")
        print("2. Copy-paste JSON payloads from the quick test section")
        print("3. Check CloudWatch logs for detailed error information")
        print("4. Verify the underlying Lambda function is working")
        print("5. Test with different payload formats")
        
        print("\n💡 TROUBLESHOOTING TIPS:")
        print("• Check if the agent runtime is properly configured")
        print("• Verify IAM permissions for the agent execution role")
        print("• Ensure the Lambda function has proper logging enabled")
        print("• Try simpler queries first (e.g., 'dns google.com')")
        print("• Check for any environment variables or dependencies")
        
        print("="*80)

def main():
    """Main execution function"""
    try:
        analyzer = DNSAgentAnalyzer()
        analyzer.run_comprehensive_analysis()
        
    except KeyboardInterrupt:
        print("\\n🛑 Analysis interrupted by user")
    except Exception as e:
        print(f"\\n❌ Unexpected error: {str(e)}")

if __name__ == "__main__":
    main()