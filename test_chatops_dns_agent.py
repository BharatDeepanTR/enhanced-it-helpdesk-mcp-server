#!/usr/bin/env python3
"""
Enterprise ChatOps Route DNS Lookup Agent Tester
=================================================

Test script for a208194_chatops_route_dns_lookup agent in AWS Agent Core Runtime.
This script provides comprehensive testing for DNS lookup functionality through
the Bedrock Agent Core Runtime.

Features:
- Professional enterprise-grade testing framework
- Comprehensive DNS lookup scenarios 
- Performance metrics and detailed logging
- Session management and report generation
- Error handling and diagnostics

Author: Enterprise MCP Team
Version: 1.0.0
"""

import boto3
import json
import logging
import time
from datetime import datetime
from typing import Dict, List, Any, Optional
from requests_aws4auth import AWS4Auth
import uuid

class EnterpriseChatOpsDNSTester:
    """Enterprise-grade ChatOps Route DNS Lookup Agent Tester"""
    
    def __init__(self):
        """Initialize the Enterprise ChatOps DNS Tester"""
        # Configure professional logging
        self.session_id = f"dns-test-{datetime.now().strftime('%Y%m%d-%H%M%S')}"
        self.setup_logging()
        
        # AWS Configuration
        self.region = 'us-east-1'
        self.agent_id = 'a208194_chatops_route_dns_lookup'  # Agent ID in runtime
        
        # Initialize AWS clients
        self._init_aws_clients()
        
        # Test configuration
        self.test_results = []
        self.start_time = None
        
        self.logger.info("🚀 Enterprise ChatOps DNS Tester initialized")
        self.logger.info(f"🏷️ Session ID: {self.session_id}")
        self.logger.info(f"🤖 Agent ID: {self.agent_id}")

    def setup_logging(self):
        """Configure comprehensive logging"""
        # Create logger
        self.logger = logging.getLogger('EnterpriseDNSTest')
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
        log_filename = f"enterprise_dns_test_{self.session_id}.log"
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
            
            self.logger.info("✅ AWS authentication initialized successfully")
            self.logger.info(f"🔐 Account: {identity.get('Account')}")
            self.logger.info(f"📍 Region: {self.region}")
            
        except Exception as e:
            self.logger.error(f"❌ AWS initialization failed: {str(e)}")
            raise

    def invoke_agent(self, query: str) -> Dict[str, Any]:
        """
        Invoke the ChatOps DNS Lookup agent with a query
        
        Args:
            query: Natural language query for DNS lookup
            
        Returns:
            Dictionary containing response and metadata
        """
        try:
            session_id = f"session-{uuid.uuid4()}"
            
            self.logger.debug(f"🔧 Invoking agent with query: {query}")
            self.logger.debug(f"🏷️ Session: {session_id}")
            
            start_time = time.time()
            
            # Invoke the agent through Bedrock Agent Runtime
            response = self.bedrock_agent.invoke_agent(
                agentId=self.agent_id,
                agentAliasId='TSTALIASID',  # Standard test alias
                sessionId=session_id,
                inputText=query
            )
            
            execution_time = time.time() - start_time
            
            # Parse response
            result = {
                'success': True,
                'execution_time': execution_time,
                'session_id': session_id,
                'response': response
            }
            
            self.logger.debug(f"✅ Agent invocation successful in {execution_time:.2f}s")
            return result
            
        except Exception as e:
            execution_time = time.time() - start_time if 'start_time' in locals() else 0
            self.logger.error(f"❌ Agent invocation failed: {str(e)}")
            return {
                'success': False,
                'error': str(e),
                'execution_time': execution_time,
                'session_id': session_id if 'session_id' in locals() else None
            }

    def execute_test(self, test_name: str, description: str, query: str) -> Dict[str, Any]:
        """
        Execute a single test case
        
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
        
        # Invoke the agent
        result = self.invoke_agent(query)
        
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
            test_result['agent_session_id'] = result.get('session_id')
            self.logger.info(f"✅ Test passed in {execution_time:.2f}s")
        else:
            test_result['error'] = result.get('error', 'Unknown error')
            self.logger.error(f"❌ Test failed: {test_result['error']}")
        
        return test_result

    def run_comprehensive_tests(self):
        """Execute comprehensive test suite for ChatOps DNS Lookup"""
        
        print("\n" + "="*80)
        print("🏢 ENTERPRISE CHATOPS DNS LOOKUP AGENT TEST SUITE")
        print("="*80)
        print(f"📅 Started: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        print(f"🤖 Agent ID: {self.agent_id}")
        print(f"🏷️ Session: {self.session_id}")
        print("="*80)
        
        self.start_time = time.time()
        
        # Test Suite Definition
        test_cases = [
            {
                'name': 'DNS Resolution - Domain',
                'description': 'Test basic domain DNS resolution',
                'query': 'What is the IP address of google.com?'
            },
            {
                'name': 'DNS Resolution - Subdomain', 
                'description': 'Test subdomain DNS resolution',
                'query': 'Lookup DNS for www.amazon.com'
            },
            {
                'name': 'Route Information',
                'description': 'Test network route information lookup',
                'query': 'Show me routing information for 8.8.8.8'
            },
            {
                'name': 'ChatOps Command - DNS',
                'description': 'Test ChatOps style DNS command',
                'query': 'dns lookup microsoft.com'
            },
            {
                'name': 'ChatOps Command - Route',
                'description': 'Test ChatOps style route command', 
                'query': 'route trace to cloudflare.com'
            },
            {
                'name': 'Multiple DNS Records',
                'description': 'Test multiple DNS record types lookup',
                'query': 'Get A, AAAA, and MX records for github.com'
            },
            {
                'name': 'Internal Domain',
                'description': 'Test internal/corporate domain lookup',
                'query': 'dns lookup internal.company.local'
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
                
                # Try to extract and display response content
                response = result.get('response', {})
                if 'completion' in response:
                    print(f"📋 Response: {response['completion'][:200]}...")
                elif 'output' in response:
                    print(f"📋 Response: {response['output'][:200]}...")
                else:
                    print("📋 Response: Agent responded successfully")
            else:
                print(f"❌ FAILED ({result['execution_time']:.2f}s)")
                print(f"🚨 Error: {result['error']}")
            
            # Small delay between tests
            time.sleep(0.5)
        
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
            print("   🏆 EXCELLENT: Agent is working perfectly!")
            print("   ✅ All critical DNS lookup functions operational.")
        elif success_rate >= 70:
            print("   🟡 GOOD: Agent is mostly functional with minor issues.")
            print("   ⚠️ Some DNS lookup functions may need attention.")
        elif success_rate >= 50:
            print("   🟠 FAIR: Agent has significant issues that need addressing.")
            print("   🔧 Review agent configuration and logs.")
        else:
            print("   🔴 POOR: Agent is not functioning properly.")
            print("   🚨 Critical issues detected - immediate attention required.")
        
        print("="*80)
        
        # Save detailed report
        self._save_detailed_report()
        
        # Log summary
        self.logger.info(f"📊 Test completed: {passed_tests}/{total_tests} passed ({success_rate:.1f}%)")

    def _save_detailed_report(self):
        """Save detailed JSON report for analysis"""
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
        
        report_filename = f"enterprise_dns_test_report_{self.session_id}.json"
        
        with open(report_filename, 'w') as f:
            json.dump(report, f, indent=2, default=str)
        
        print(f"📄 Detailed report saved to: {report_filename}")
        self.logger.info(f"📄 Detailed report saved to: {report_filename}")

def main():
    """Main execution function"""
    try:
        # Initialize tester
        tester = EnterpriseChatOpsDNSTester()
        
        # Run comprehensive test suite
        tester.run_comprehensive_tests()
        
    except KeyboardInterrupt:
        print("\n🛑 Test execution interrupted by user")
    except Exception as e:
        print(f"\n❌ Unexpected error: {str(e)}")
        logging.error(f"Unexpected error in main: {str(e)}")

if __name__ == "__main__":
    main()