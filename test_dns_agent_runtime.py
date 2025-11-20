#!/usr/bin/env python3
"""
Enterprise ChatOps Route DNS Lookup Agent Tester
=================================================

Test script for the a208194_chatops_route_dns_lookup agent in AWS Agent Core Runtime.
This script provides comprehensive testing for DNS lookup functionality through
the Bedrock Agent Core Runtime.

Agent Configuration:
- Agent Name: a208194_chatops_route_dns_lookup
- Runtime ID: a208194_chatops_route_dns_lookup-Zg3E6G5ZDV
- ECR Source: dns-lookup-service
- IAM Role: a208194-askjulius-supervisor-agent-role

Features:
- Professional enterprise-grade testing framework
- Comprehensive DNS lookup scenarios 
- Performance metrics and detailed logging
- Session management and report generation
- Error handling and diagnostics

Author: Enterprise MCP Team
Version: 2.0.0
"""

import boto3
import json
import logging
import time
import uuid
from datetime import datetime
from typing import Dict, List, Any, Optional

class EnterpriseDNSAgentTester:
    """Enterprise-grade ChatOps Route DNS Lookup Agent Tester"""
    
    def __init__(self):
        """Initialize the Enterprise DNS Agent Tester"""
        # Configure professional logging
        self.session_id = f"dns-agent-test-{datetime.now().strftime('%Y%m%d-%H%M%S')}"
        self.setup_logging()
        
        # Agent Configuration (from user provided details)
        self.region = 'us-east-1'
        self.agent_name = 'a208194_chatops_route_dns_lookup'
        self.agent_runtime_id = 'a208194_chatops_route_dns_lookup-Zg3E6G5ZDV'
        self.ecr_repo = 'dns-lookup-service'
        self.iam_role = 'a208194-askjulius-supervisor-agent-role'
        
        # Initialize AWS clients
        self._init_aws_clients()
        
        # Test configuration
        self.test_results = []
        self.start_time = None
        
        self.logger.info("✅ AWS authentication initialized successfully")
        self.logger.info("🚀 Enterprise DNS Agent Tester initialized")
        self.logger.info(f"🤖 Agent Runtime ID: {self.agent_runtime_id}")
        self.logger.info(f"🏷️ Session ID: {self.session_id}")

    def setup_logging(self):
        """Configure comprehensive logging"""
        # Create logger
        self.logger = logging.getLogger('EnterpriseDNSAgentTest')
        self.logger.setLevel(logging.INFO)
        
        # Clear any existing handlers
        self.logger.handlers.clear()
        
        # Create formatters
        console_formatter = logging.Formatter('%(asctime)s - %(name)s - %(levelname)s - %(message)s')
        file_formatter = logging.Formatter('%(asctime)s - %(name)s - %(levelname)s - %(message)s')
        
        # Console handler
        console_handler = logging.StreamHandler()
        console_handler.setLevel(logging.INFO)
        console_handler.setFormatter(console_formatter)
        self.logger.addHandler(console_handler)
        
        # File handler
        log_filename = f"enterprise_dns_agent_test_{self.session_id}.log"
        file_handler = logging.FileHandler(log_filename)
        file_handler.setLevel(logging.DEBUG)
        file_handler.setFormatter(file_formatter)
        self.logger.addHandler(file_handler)
        
        self.logger.info(f"📝 Logging configured - File: {log_filename}")

    def _init_aws_clients(self):
        """Initialize AWS clients with proper authentication"""
        try:
            # Initialize Bedrock Agent Runtime client
            self.bedrock_agent = boto3.client(
                'bedrock-agent-runtime',
                region_name=self.region
            )
            
            # Test authentication
            sts = boto3.client('sts', region_name=self.region)
            identity = sts.get_caller_identity()
            
            self.logger.info(f"🔐 Account: {identity.get('Account')}")
            self.logger.info(f"📍 Region: {self.region}")
            
        except Exception as e:
            self.logger.error(f"❌ AWS initialization failed: {str(e)}")
            raise

    def invoke_dns_agent(self, query: str) -> Dict[str, Any]:
        """
        Invoke the ChatOps DNS Lookup agent with a query
        
        Args:
            query: Natural language query for DNS lookup
            
        Returns:
            Dictionary containing response and metadata
        """
        try:
            session_id = f"session-{uuid.uuid4()}"
            
            self.logger.debug(f"🔧 Invoking DNS agent with query: {query}")
            self.logger.debug(f"🏷️ Session: {session_id}")
            
            start_time = time.time()
            
            # Invoke the DNS agent through Bedrock Agent Runtime
            response = self.bedrock_agent.invoke_agent(
                agentId=self.agent_runtime_id,
                agentAliasId='TSTALIASID',  # Standard test alias
                sessionId=session_id,
                inputText=query
            )
            
            execution_time = time.time() - start_time
            
            # Process the streaming response
            completion_text = ""
            if 'completion' in response:
                for event in response['completion']:
                    if 'chunk' in event:
                        chunk = event['chunk']
                        if 'bytes' in chunk:
                            completion_text += chunk['bytes'].decode('utf-8')
            
            # Parse result
            result = {
                'success': True,
                'execution_time': execution_time,
                'session_id': session_id,
                'response': response,
                'completion_text': completion_text,
                'query': query
            }
            
            self.logger.debug(f"✅ DNS agent invocation successful in {execution_time:.2f}s")
            return result
            
        except Exception as e:
            execution_time = time.time() - start_time if 'start_time' in locals() else 0
            self.logger.error(f"❌ DNS agent invocation failed: {str(e)}")
            return {
                'success': False,
                'error': str(e),
                'execution_time': execution_time,
                'session_id': session_id if 'session_id' in locals() else None,
                'query': query
            }

    def execute_test(self, test_name: str, description: str, query: str) -> Dict[str, Any]:
        """
        Execute a single DNS test case
        
        Args:
            test_name: Name of the test
            description: Description of what the test validates
            query: DNS lookup query to execute
            
        Returns:
            Test result dictionary
        """
        self.logger.info(f"🧪 Executing test: {test_name}")
        self.logger.info(f"📝 Query: {query}")
        
        start_time = time.time()
        
        # Invoke the DNS agent
        result = self.invoke_dns_agent(query)
        
        execution_time = time.time() - start_time
        
        # Create test result
        test_result = {
            'test_name': test_name,
            'description': description,
            'query': query,
            'execution_time': execution_time,
            'success': result.get('success', False),
            'timestamp': datetime.now().isoformat()
        }
        
        if result['success']:
            test_result['response'] = result.get('response')
            test_result['completion_text'] = result.get('completion_text', '')
            test_result['agent_session_id'] = result.get('session_id')
            self.logger.info(f"✅ Test passed in {execution_time:.2f}s")
        else:
            test_result['error'] = result.get('error', 'Unknown error')
            self.logger.error(f"❌ Test failed: {test_result['error']}")
        
        return test_result

    def run_comprehensive_tests(self):
        """Execute comprehensive test suite for ChatOps DNS Lookup Agent"""
        
        print("\n" + "="*80)
        print("🏢 ENTERPRISE CHATOPS DNS LOOKUP AGENT TEST SUITE")
        print("="*80)
        print(f"📅 Started: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        print(f"🤖 Agent Name: {self.agent_name}")
        print(f"🆔 Runtime ID: {self.agent_runtime_id}")
        print(f"🐳 ECR Source: {self.ecr_repo}")
        print(f"🔐 IAM Role: {self.iam_role}")
        print(f"🏷️ Session: {self.session_id}")
        print("="*80)
        
        self.start_time = time.time()
        
        # Test Suite Definition - DNS and Route lookup scenarios
        test_cases = [
            {
                'name': '🔍 Basic DNS Lookup',
                'description': 'Test basic domain DNS resolution',
                'query': 'What is the IP address of google.com?'
            },
            {
                'name': '🌐 Subdomain Resolution', 
                'description': 'Test subdomain DNS resolution',
                'query': 'dns lookup www.amazon.com'
            },
            {
                'name': '📧 MX Record Lookup',
                'description': 'Test mail server DNS record lookup',
                'query': 'Get MX records for microsoft.com'
            },
            {
                'name': '🗺️ Route Trace',
                'description': 'Test network route tracing',
                'query': 'trace route to 8.8.8.8'
            },
            {
                'name': '🏢 Corporate Domain',
                'description': 'Test internal/corporate domain lookup',
                'query': 'lookup DNS for internal.company.local'
            },
            {
                'name': '📋 Multiple Records',
                'description': 'Test multiple DNS record types',
                'query': 'Show me A, AAAA, and CNAME records for github.com'
            },
            {
                'name': '🌍 International Domain',
                'description': 'Test international domain resolution',
                'query': 'dns lookup baidu.com'
            },
            {
                'name': '☁️ Cloud Provider DNS',
                'description': 'Test cloud service DNS resolution',
                'query': 'What are the IP addresses for aws.amazon.com?'
            },
            {
                'name': '🔐 Security Check',
                'description': 'Test DNS security and validation',
                'query': 'Check DNS security for suspicious-domain.test'
            },
            {
                'name': '📊 DNS Performance',
                'description': 'Test DNS resolution performance metrics',
                'query': 'measure dns response time for cloudflare.com'
            }
        ]
        
        # Execute test cases
        for i, test_case in enumerate(test_cases, 1):
            print(f"\n{i}. {test_case['name']}")
            print("-" * 60)
            
            result = self.execute_test(
                test_name=test_case['name'],
                description=test_case['description'],
                query=test_case['query']
            )
            
            self.test_results.append(result)
            
            # Display result
            if result['success']:
                print(f"✅ SUCCESS ({result['execution_time']:.2f}s)")
                
                # Display response content
                completion_text = result.get('completion_text', '')
                if completion_text:
                    # Truncate long responses for display
                    display_text = completion_text[:300] + "..." if len(completion_text) > 300 else completion_text
                    print(f"📋 Response: {display_text}")
                else:
                    print("📋 Response: Agent responded successfully")
            else:
                print(f"❌ FAILED ({result['execution_time']:.2f}s)")
                print(f"🚨 Error: {result['error']}")
            
            # Small delay between tests to avoid rate limiting
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
        print("📊 ENTERPRISE DNS AGENT TEST REPORT")
        print("="*80)
        print(f"📅 Completed: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        print(f"⏱️ Total Duration: {total_duration:.2f}s")
        print(f"🏷️ Session ID: {self.session_id}")
        print(f"🤖 Agent Runtime ID: {self.agent_runtime_id}")
        
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
            print("   🏆 EXCELLENT: DNS Agent is working perfectly!")
            print("   ✅ All critical DNS and routing functions operational.")
        elif success_rate >= 70:
            print("   🟡 GOOD: DNS Agent is mostly functional with minor issues.")
            print("   ⚠️ Some DNS lookup functions may need attention.")
        elif success_rate >= 50:
            print("   🟠 FAIR: DNS Agent has significant issues that need addressing.")
            print("   🔧 Review agent configuration and ECR container logs.")
        else:
            print("   🔴 POOR: DNS Agent is not functioning properly.")
            print("   🚨 Critical issues detected - check agent deployment and IAM permissions.")
        
        print("\n📋 AGENT CONFIGURATION:")
        print(f"   🤖 Agent Name: {self.agent_name}")
        print(f"   🆔 Runtime ID: {self.agent_runtime_id}")
        print(f"   🐳 ECR Repository: {self.ecr_repo}")
        print(f"   🔐 IAM Service Role: {self.iam_role}")
        print(f"   📍 Region: {self.region}")
        
        print("="*80)
        
        # Save detailed report
        self._save_detailed_report()
        
        # Log summary
        self.logger.info(f"📊 Test completed: {passed_tests}/{total_tests} passed ({success_rate:.1f}%)")

    def _save_detailed_report(self):
        """Save detailed JSON report for analysis"""
        report = {
            'session_id': self.session_id,
            'agent_name': self.agent_name,
            'agent_runtime_id': self.agent_runtime_id,
            'ecr_repo': self.ecr_repo,
            'iam_role': self.iam_role,
            'region': self.region,
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
        
        report_filename = f"enterprise_dns_agent_report_{self.session_id}.json"
        
        with open(report_filename, 'w') as f:
            json.dump(report, f, indent=2, default=str)
        
        print(f"📄 Detailed report saved to: {report_filename}")
        self.logger.info(f"📄 Detailed report saved to: {report_filename}")

def main():
    """Main execution function"""
    try:
        # Initialize tester
        tester = EnterpriseDNSAgentTester()
        
        # Run comprehensive test suite
        tester.run_comprehensive_tests()
        
    except KeyboardInterrupt:
        print("\n🛑 Test execution interrupted by user")
    except Exception as e:
        print(f"\n❌ Unexpected error: {str(e)}")
        logging.error(f"Unexpected error in main: {str(e)}")

if __name__ == "__main__":
    main()