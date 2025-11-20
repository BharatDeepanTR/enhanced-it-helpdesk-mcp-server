#!/usr/bin/env python3
"""
ChatOps Route DNS Lookup Agent Runtime Tester
==============================================

Test script for the a208194_chatops_route_dns_lookup agent in AWS Agent Core Runtime.
This agent is a Lambda-based agent (not MCP) that responds to natural language prompts
through the Bedrock Agent Runtime API.

Features:
- Direct Agent Core Runtime testing
- Natural language DNS and routing queries
- Professional logging and reporting
- Session management and response parsing
- Comprehensive test scenarios

Agent Details:
- Agent Name: a208194_chatops_route_dns_lookup
- Runtime ID: a208194_chatops_route_dns_lookup-Zg3E6G5ZDV
- Type: Lambda-based Agent Core Runtime agent
"""

import boto3
import json
import logging
import time
import uuid
from datetime import datetime
from typing import Dict, List, Any, Optional, Generator

class DNSAgentRuntimeTester:
    """Agent Core Runtime DNS Agent Tester"""
    
    def __init__(self):
        """Initialize the DNS Agent Runtime Tester"""
        # Configure logging
        self.session_id = f"dns-runtime-test-{datetime.now().strftime('%Y%m%d-%H%M%S')}"
        self.setup_logging()
        
        # Agent configuration
        self.agent_id = 'a208194_chatops_route_dns_lookup-Zg3E6G5ZDV'
        self.region = 'us-east-1'
        
        # Initialize AWS clients
        self._init_aws_clients()
        
        # Test results
        self.test_results = []
        self.start_time = None
        
        self.logger.info("🚀 DNS Agent Runtime Tester initialized")
        self.logger.info(f"🤖 Agent ID: {self.agent_id}")
        self.logger.info(f"🏷️ Session ID: {self.session_id}")

    def setup_logging(self):
        """Configure comprehensive logging"""
        self.logger = logging.getLogger('DNSAgentRuntimeTest')
        self.logger.setLevel(logging.INFO)
        
        # Clear existing handlers
        self.logger.handlers.clear()
        
        # Console handler
        console_handler = logging.StreamHandler()
        console_handler.setLevel(logging.INFO)
        console_formatter = logging.Formatter('%(asctime)s - %(name)s - %(levelname)s - %(message)s')
        console_handler.setFormatter(console_formatter)
        self.logger.addHandler(console_handler)
        
        # File handler
        log_filename = f"dns_agent_runtime_test_{self.session_id}.log"
        file_handler = logging.FileHandler(log_filename)
        file_handler.setLevel(logging.DEBUG)
        file_formatter = logging.Formatter('%(asctime)s - %(name)s - %(levelname)s - %(message)s')
        file_handler.setFormatter(file_formatter)
        self.logger.addHandler(file_handler)

    def _init_aws_clients(self):
        """Initialize AWS clients"""
        try:
            # Bedrock Agent Runtime client
            self.bedrock_agent_runtime = boto3.client(
                'bedrock-agent-runtime',
                region_name=self.region
            )
            
            # Verify authentication
            sts = boto3.client('sts', region_name=self.region)
            identity = sts.get_caller_identity()
            
            self.logger.info("✅ AWS clients initialized successfully")
            self.logger.info(f"🔐 Account: {identity.get('Account')}")
            
        except Exception as e:
            self.logger.error(f"❌ AWS initialization failed: {str(e)}")
            raise

    def invoke_agent(self, prompt: str, test_session_id: str = None) -> Dict[str, Any]:
        """
        Invoke the DNS agent with a natural language prompt
        
        Args:
            prompt: Natural language prompt for DNS/routing query
            test_session_id: Optional session ID for conversation continuity
            
        Returns:
            Dictionary with response and metadata
        """
        if not test_session_id:
            test_session_id = f"test-{uuid.uuid4().hex[:8]}"
        
        try:
            self.logger.debug(f"🔧 Invoking agent with prompt: {prompt}")
            self.logger.debug(f"🏷️ Test Session: {test_session_id}")
            
            start_time = time.time()
            
            # Test with different alias options
            test_aliases = ['TSTALIASID', 'DRAFT']
            
            for alias in test_aliases:
                try:
                    # Invoke agent through Bedrock Agent Runtime
                    response = self.bedrock_agent_runtime.invoke_agent(
                        agentId=self.agent_id,
                        agentAliasId=alias,
                        sessionId=test_session_id,
                        inputText=prompt
                    )
                    
                    execution_time = time.time() - start_time
                    
                    # Parse response stream
                    response_text = self._parse_agent_response(response)
                    
                    result = {
                        'success': True,
                        'execution_time': execution_time,
                        'session_id': test_session_id,
                        'alias_used': alias,
                        'response_text': response_text,
                        'raw_response': response
                    }
                    
                    self.logger.debug(f"✅ Agent invocation successful with alias {alias} in {execution_time:.2f}s")
                    return result
                    
                except Exception as alias_error:
                    self.logger.debug(f"⚠️ Alias {alias} failed: {str(alias_error)}")
                    continue
            
            # If all aliases failed
            execution_time = time.time() - start_time
            return {
                'success': False,
                'error': 'All agent aliases failed',
                'execution_time': execution_time,
                'session_id': test_session_id
            }
            
        except Exception as e:
            execution_time = time.time() - start_time if 'start_time' in locals() else 0
            self.logger.error(f"❌ Agent invocation failed: {str(e)}")
            return {
                'success': False,
                'error': str(e),
                'execution_time': execution_time,
                'session_id': test_session_id
            }

    def _parse_agent_response(self, response: Dict[str, Any]) -> str:
        """
        Parse the agent response stream to extract the text response
        
        Args:
            response: Raw agent response from invoke_agent
            
        Returns:
            Extracted response text
        """
        try:
            response_text = ""
            
            # Parse the event stream
            if 'completion' in response:
                event_stream = response['completion']
                
                for event in event_stream:
                    if 'chunk' in event:
                        chunk = event['chunk']
                        if 'bytes' in chunk:
                            chunk_text = chunk['bytes'].decode('utf-8')
                            response_text += chunk_text
                    elif 'trace' in event:
                        # Log trace information for debugging
                        trace = event['trace']
                        self.logger.debug(f"🔍 Trace: {trace}")
            
            return response_text.strip() if response_text else "No response content"
            
        except Exception as e:
            self.logger.error(f"❌ Failed to parse agent response: {str(e)}")
            return f"Response parsing error: {str(e)}"

    def execute_test(self, test_name: str, description: str, prompt: str) -> Dict[str, Any]:
        """
        Execute a single test case
        
        Args:
            test_name: Name of the test
            description: Description of the test
            prompt: Natural language prompt to test
            
        Returns:
            Test result dictionary
        """
        self.logger.info(f"🧪 Executing test: {test_name}")
        self.logger.info(f"📝 Prompt: {prompt}")
        
        start_time = time.time()
        
        # Invoke the agent
        result = self.invoke_agent(prompt)
        
        execution_time = time.time() - start_time
        
        # Create test result
        test_result = {
            'test_name': test_name,
            'description': description,
            'prompt': prompt,
            'execution_time': execution_time,
            'success': result.get('success', False),
            'timestamp': datetime.now().isoformat()
        }
        
        if result['success']:
            test_result['response_text'] = result.get('response_text', '')
            test_result['alias_used'] = result.get('alias_used', 'unknown')
            test_result['session_id'] = result.get('session_id', '')
            self.logger.info(f"✅ Test passed in {execution_time:.2f}s")
        else:
            test_result['error'] = result.get('error', 'Unknown error')
            self.logger.error(f"❌ Test failed: {test_result['error']}")
        
        return test_result

    def run_comprehensive_tests(self):
        """Execute comprehensive DNS agent test suite"""
        
        print("\n" + "="*80)
        print("🌐 CHATOPS ROUTE DNS LOOKUP AGENT RUNTIME TEST SUITE")
        print("="*80)
        print(f"📅 Started: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        print(f"🤖 Agent ID: {self.agent_id}")
        print(f"🏷️ Session: {self.session_id}")
        print("="*80)
        
        self.start_time = time.time()
        
        # Test Suite - Natural Language Prompts for DNS/Routing
        test_cases = [
            {
                'name': '🔍 Basic DNS Lookup',
                'description': 'Test basic domain name resolution',
                'prompt': 'What is the IP address of google.com?'
            },
            {
                'name': '🌐 Subdomain Resolution',
                'description': 'Test subdomain DNS lookup',
                'prompt': 'Can you lookup the DNS for www.amazon.com?'
            },
            {
                'name': '📧 MX Record Query',
                'description': 'Test mail server record lookup',
                'prompt': 'Show me the MX records for gmail.com'
            },
            {
                'name': '🛣️ Route Information',
                'description': 'Test network routing information',
                'prompt': 'Show me the route to 8.8.8.8'
            },
            {
                'name': '🔧 ChatOps DNS Command',
                'description': 'Test ChatOps style DNS command',
                'prompt': 'dns lookup microsoft.com'
            },
            {
                'name': '🗺️ Route Trace Request',
                'description': 'Test route tracing functionality',
                'prompt': 'trace route to cloudflare.com'
            },
            {
                'name': '🏢 Corporate Domain',
                'description': 'Test internal domain lookup',
                'prompt': 'lookup the IP for internal.example.com'
            },
            {
                'name': '🌍 International Domain',
                'description': 'Test international domain resolution',
                'prompt': 'What is the IP address of bbc.co.uk?'
            },
            {
                'name': '☁️ Cloud Provider DNS',
                'description': 'Test cloud provider domain lookup',
                'prompt': 'Find the IP address for aws.amazon.com'
            },
            {
                'name': '🔐 DNS Security Check',
                'description': 'Test DNS security related query',
                'prompt': 'Check the DNS configuration for github.com'
            }
        ]
        
        # Execute test cases
        for i, test_case in enumerate(test_cases, 1):
            print(f"\n{i}. {test_case['name']}")
            print("-" * 60)
            
            result = self.execute_test(
                test_name=test_case['name'],
                description=test_case['description'],
                prompt=test_case['prompt']
            )
            
            self.test_results.append(result)
            
            # Display result
            if result['success']:
                print(f"✅ SUCCESS ({result['execution_time']:.2f}s)")
                print(f"🏷️ Alias: {result.get('alias_used', 'unknown')}")
                
                response_text = result.get('response_text', '')
                if len(response_text) > 200:
                    print(f"📋 Response: {response_text[:200]}...")
                else:
                    print(f"📋 Response: {response_text}")
            else:
                print(f"❌ FAILED ({result['execution_time']:.2f}s)")
                print(f"🚨 Error: {result['error']}")
            
            # Small delay between tests
            time.sleep(1)
        
        # Generate final report
        self._generate_final_report()

    def _generate_final_report(self):
        """Generate comprehensive final test report"""
        
        total_duration = time.time() - self.start_time
        passed_tests = sum(1 for r in self.test_results if r['success'])
        total_tests = len(self.test_results)
        success_rate = (passed_tests / total_tests * 100) if total_tests > 0 else 0
        avg_execution_time = sum(r['execution_time'] for r in self.test_results) / total_tests if total_tests > 0 else 0
        
        print("\n" + "="*80)
        print("📊 DNS AGENT RUNTIME TEST REPORT")
        print("="*80)
        print(f"📅 Completed: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        print(f"⏱️ Total Duration: {total_duration:.2f}s")
        print(f"🏷️ Session ID: {self.session_id}")
        print(f"🤖 Agent ID: {self.agent_id}")
        
        print(f"\n📈 STATISTICS:")
        print(f"   Total Tests: {total_tests}")
        print(f"   ✅ Passed: {passed_tests}")
        print(f"   ❌ Failed: {total_tests - passed_tests}")
        print(f"   📊 Success Rate: {success_rate:.1f}%")
        print(f"   ⚡ Avg Execution Time: {avg_execution_time:.2f}s")
        
        print(f"\n📋 DETAILED RESULTS:")
        for i, result in enumerate(self.test_results, 1):
            status = "✅ PASS" if result['success'] else "❌ FAIL"
            print(f"   {i}. {result['test_name']}: {status} ({result['execution_time']:.2f}s)")
        
        # Overall assessment
        print(f"\n🎯 OVERALL ASSESSMENT:")
        if success_rate >= 90:
            print("   🏆 EXCELLENT: DNS agent is working perfectly!")
            print("   ✅ All DNS and routing functions operational.")
        elif success_rate >= 70:
            print("   🟡 GOOD: DNS agent is mostly functional.")
            print("   ⚠️ Some functions may need attention.")
        elif success_rate >= 50:
            print("   🟠 FAIR: DNS agent has significant issues.")
            print("   🔧 Review agent configuration and logs.")
        else:
            print("   🔴 POOR: DNS agent is not functioning properly.")
            print("   🚨 Critical issues detected.")
        
        print("="*80)
        
        # Save detailed report
        self._save_detailed_report()

    def _save_detailed_report(self):
        """Save detailed JSON report"""
        report = {
            'session_id': self.session_id,
            'agent_id': self.agent_id,
            'timestamp': datetime.now().isoformat(),
            'summary': {
                'total_tests': len(self.test_results),
                'passed_tests': sum(1 for r in self.test_results if r['success']),
                'success_rate': sum(1 for r in self.test_results if r['success']) / len(self.test_results) * 100 if self.test_results else 0,
                'total_duration': time.time() - self.start_time,
                'avg_execution_time': sum(r['execution_time'] for r in self.test_results) / len(self.test_results) if self.test_results else 0
            },
            'test_results': self.test_results
        }
        
        report_filename = f"dns_agent_runtime_report_{self.session_id}.json"
        
        with open(report_filename, 'w') as f:
            json.dump(report, f, indent=2, default=str)
        
        print(f"📄 Detailed report saved to: {report_filename}")
        self.logger.info(f"📄 Detailed report saved to: {report_filename}")

def main():
    """Main execution function"""
    try:
        # Initialize tester
        tester = DNSAgentRuntimeTester()
        
        # Run comprehensive test suite
        tester.run_comprehensive_tests()
        
    except KeyboardInterrupt:
        print("\n🛑 Test execution interrupted by user")
    except Exception as e:
        print(f"\n❌ Unexpected error: {str(e)}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    main()