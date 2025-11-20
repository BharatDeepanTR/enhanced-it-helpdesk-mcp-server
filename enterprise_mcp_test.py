#!/usr/bin/env python3
"""
Enterprise MCP Gateway Test Suite
==================================
Professional testing framework for Bedrock Agent Core Gateway MCP functionality.
Features comprehensive logging, detailed error reporting, and clean output formatting.

Author: Enterprise MCP Team
Version: 2.0
"""

import json
import logging
import requests
import time
from datetime import datetime
from typing import Dict, Any, List, Optional, Tuple
from requests_aws4auth import AWS4Auth
import boto3

# Configure enterprise-grade logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('enterprise_mcp_test.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger('EnterpriseMCPTest')

class EnterpriseMCPTester:
    """Enterprise-grade MCP Gateway testing framework."""
    
    def __init__(self, gateway_url: str, region: str = 'us-east-1'):
        """Initialize the enterprise MCP tester.
        
        Args:
            gateway_url: The Bedrock Agent Core Gateway URL
            region: AWS region for authentication
        """
        self.gateway_url = gateway_url
        self.region = region
        self.session_id = f"enterprise-test-{datetime.now().strftime('%Y%m%d-%H%M%S')}"
        
        # Initialize AWS authentication
        try:
            session = boto3.Session()
            credentials = session.get_credentials()
            self.auth = AWS4Auth(
                credentials.access_key,
                credentials.secret_key,
                region,
                'bedrock-agentcore',
                session_token=credentials.token
            )
            logger.info("✅ AWS authentication initialized successfully")
        except Exception as e:
            logger.error(f"❌ Failed to initialize AWS authentication: {e}")
            raise
        
        # Test configuration
        self.test_results = []
        self.start_time = None
        
        logger.info(f"🚀 Enterprise MCP Tester initialized")
        logger.info(f"📋 Gateway URL: {gateway_url}")
        logger.info(f"🏷️ Session ID: {self.session_id}")
    
    def _make_mcp_request(self, method: str, params: Dict[str, Any] = None) -> Tuple[bool, Dict[str, Any]]:
        """Make a secure MCP request to the gateway.
        
        Args:
            method: MCP method name
            params: Method parameters
            
        Returns:
            Tuple of (success, response_data)
        """
        payload = {
            "jsonrpc": "2.0",
            "id": f"{self.session_id}-{int(time.time() * 1000)}",
            "method": method
        }
        
        if params:
            payload["params"] = params
        
        headers = {
            'Content-Type': 'application/json',
            'User-Agent': f'EnterpriseMCPTester/2.0 ({self.session_id})'
        }
        
        try:
            logger.debug(f"🔄 Making MCP request: {method}")
            response = requests.post(
                self.gateway_url,
                json=payload,
                headers=headers,
                auth=self.auth,
                timeout=30
            )
            
            if response.status_code == 200:
                response_data = response.json()
                if 'error' in response_data:
                    logger.warning(f"⚠️ MCP error in {method}: {response_data['error']}")
                    return False, response_data
                else:
                    logger.debug(f"✅ MCP request {method} successful")
                    return True, response_data
            else:
                logger.error(f"❌ HTTP error {response.status_code} for {method}: {response.text}")
                return False, {
                    'error': {
                        'code': response.status_code,
                        'message': f'HTTP {response.status_code}: {response.text}'
                    }
                }
        except requests.exceptions.Timeout:
            logger.error(f"⏰ Timeout error for {method}")
            return False, {'error': {'code': -1, 'message': 'Request timeout'}}
        except Exception as e:
            logger.error(f"💥 Exception during {method}: {e}")
            return False, {'error': {'code': -2, 'message': f'Exception: {str(e)}'}}
    
    def _execute_tool(self, tool_name: str, arguments: Dict[str, Any]) -> Tuple[bool, Any]:
        """Execute a specific tool through the MCP gateway.
        
        Args:
            tool_name: Name of the tool to execute
            arguments: Tool arguments
            
        Returns:
            Tuple of (success, result)
        """
        params = {
            "name": tool_name,
            "arguments": arguments
        }
        
        success, response = self._make_mcp_request("tools/call", params)
        
        if success and 'result' in response:
            result = response['result']
            if isinstance(result, dict) and 'content' in result:
                # Extract content from MCP response format
                content = result['content']
                if isinstance(content, list) and len(content) > 0:
                    text_content = content[0].get('text', 'No text content')
                    # Check for internal errors in the response
                    if 'internal error' in text_content.lower() or 'retry later' in text_content.lower():
                        return False, f"Internal Error: {text_content}"
                    return True, text_content
                elif isinstance(content, str):
                    # Check for internal errors in string content
                    if 'internal error' in content.lower() or 'retry later' in content.lower():
                        return False, f"Internal Error: {content}"
                    return True, content
                else:
                    content_str = str(content)
                    if 'internal error' in content_str.lower() or 'retry later' in content_str.lower():
                        return False, f"Internal Error: {content_str}"
                    return True, content_str
            else:
                result_str = str(result)
                if 'internal error' in result_str.lower() or 'retry later' in result_str.lower():
                    return False, f"Internal Error: {result_str}"
                return True, result_str
        elif 'error' in response:
            return False, response['error']
        else:
            return False, "Unknown error occurred"
    
    def run_comprehensive_test_suite(self) -> None:
        """Execute the complete enterprise test suite."""
        self.start_time = datetime.now()
        
        print("\n" + "=" * 80)
        print("🏢 ENTERPRISE MCP GATEWAY TEST SUITE")
        print("=" * 80)
        print(f"📅 Started: {self.start_time.strftime('%Y-%m-%d %H:%M:%S')}")
        print(f"🔗 Gateway: {self.gateway_url}")
        print(f"🏷️ Session: {self.session_id}")
        print("=" * 80)
        
        # Test cases with enterprise-grade validation
        test_cases = [
            {
                'category': '🧮 AI Calculator',
                'name': 'Simple Calculation',
                'tool': 'target-lambda-direct-ai-calculator-mcp___ai_calculate',
                'args': {'query': 'What is 25 + 37?'},
                'expected_type': 'calculation'
            },
            {
                'category': '💰 Financial Math',
                'name': 'Percentage Calculation',
                'tool': 'target-lambda-direct-ai-calculator-mcp___ai_calculate',
                'args': {'query': 'What is 15% of $50,000?'},
                'expected_type': 'percentage'
            },
            {
                'category': '📐 Advanced Math',
                'name': 'Complex Calculation',
                'tool': 'target-lambda-direct-ai-calculator-mcp___ai_calculate',
                'args': {'query': 'Calculate the compound interest on $10,000 at 5% annually for 3 years'},
                'expected_type': 'compound_interest'
            },
            {
                'category': '📚 Educational',
                'name': 'Math Explanation',
                'tool': 'target-lambda-direct-ai-calculator-mcp___explain_calculation',
                'args': {'calculation': 'quadratic formula'},
                'expected_type': 'explanation'
            },
            {
                'category': '📝 Problem Solving',
                'name': 'Word Problem',
                'tool': 'target-lambda-direct-ai-calculator-mcp___solve_word_problem',
                'args': {'problem': 'If a train travels 60 miles per hour for 2.5 hours, how far does it go?'},
                'expected_type': 'word_problem'
            },
            {
                'category': '🏢 Application Details',
                'name': 'Asset Information',
                'tool': 'target-lambda-direct-application-details-mcp___get_application_details',
                'args': {'asset_id': 'a208194'},
                'expected_type': 'application_info'
            },
            {
                'category': '➕ Basic Calculator',
                'name': 'Addition Operation',
                'tool': 'target-lambda-direct-calculator-mcp___add',
                'args': {'a': 150, 'b': 250},
                'expected_type': 'arithmetic'
            }
        ]
        
        # Execute test cases
        for i, test_case in enumerate(test_cases, 1):
            self._execute_test_case(i, test_case)
        
        # Generate comprehensive report
        self._generate_enterprise_report()
    
    def _execute_test_case(self, test_number: int, test_case: Dict[str, Any]) -> None:
        """Execute a single test case with enterprise logging."""
        category = test_case['category']
        name = test_case['name']
        tool_name = test_case['tool']
        args = test_case['args']
        
        print(f"\n{test_number}. {category} - {name}")
        print("-" * 60)
        
        logger.info(f"🧪 Executing test {test_number}: {category} - {name}")
        logger.info(f"🔧 Tool: {tool_name}")
        logger.info(f"📝 Args: {args}")
        
        # Execute the test
        start_time = time.time()
        success, result = self._execute_tool(tool_name, args)
        execution_time = time.time() - start_time
        
        # Record test result
        test_result = {
            'test_number': test_number,
            'category': category,
            'name': name,
            'tool': tool_name,
            'args': args,
            'success': success,
            'result': result,
            'execution_time': execution_time,
            'timestamp': datetime.now().isoformat()
        }
        self.test_results.append(test_result)
        
        # Display results
        if success:
            print(f"✅ SUCCESS ({execution_time:.2f}s)")
            print(f"📋 Result: {result}")
            logger.info(f"✅ Test {test_number} passed in {execution_time:.2f}s")
        else:
            print(f"❌ FAILED ({execution_time:.2f}s)")
            if isinstance(result, dict):
                error_code = result.get('code', 'unknown')
                error_message = result.get('message', 'No message')
                print(f"🚨 Error {error_code}: {error_message}")
                logger.error(f"❌ Test {test_number} failed: {error_code} - {error_message}")
            else:
                print(f"🚨 Error: {result}")
                logger.error(f"❌ Test {test_number} failed: {result}")
    
    def _generate_enterprise_report(self) -> None:
        """Generate comprehensive enterprise test report."""
        end_time = datetime.now()
        total_duration = end_time - self.start_time
        
        # Calculate statistics
        total_tests = len(self.test_results)
        passed_tests = sum(1 for r in self.test_results if r['success'])
        failed_tests = total_tests - passed_tests
        success_rate = (passed_tests / total_tests * 100) if total_tests > 0 else 0
        avg_execution_time = sum(r['execution_time'] for r in self.test_results) / total_tests if total_tests > 0 else 0
        
        print("\n" + "=" * 80)
        print("📊 ENTERPRISE TEST REPORT")
        print("=" * 80)
        print(f"📅 Completed: {end_time.strftime('%Y-%m-%d %H:%M:%S')}")
        print(f"⏱️ Total Duration: {total_duration}")
        print(f"🏷️ Session ID: {self.session_id}")
        print()
        print("📈 STATISTICS:")
        print(f"   Total Tests: {total_tests}")
        print(f"   ✅ Passed: {passed_tests}")
        print(f"   ❌ Failed: {failed_tests}")
        print(f"   📊 Success Rate: {success_rate:.1f}%")
        print(f"   ⚡ Avg Execution Time: {avg_execution_time:.2f}s")
        
        # Detailed results
        print("\n📋 DETAILED RESULTS:")
        for result in self.test_results:
            status = "✅ PASS" if result['success'] else "❌ FAIL"
            print(f"   {result['test_number']}. {result['category']} - {result['name']}: {status} ({result['execution_time']:.2f}s)")
        
        # Error analysis
        if failed_tests > 0:
            print("\n🔍 ERROR ANALYSIS:")
            error_summary = {}
            for result in self.test_results:
                if not result['success']:
                    if isinstance(result['result'], dict):
                        error_code = result['result'].get('code', 'unknown')
                        error_summary[error_code] = error_summary.get(error_code, 0) + 1
                    else:
                        error_summary['other'] = error_summary.get('other', 0) + 1
            
            for error_type, count in error_summary.items():
                print(f"   {error_type}: {count} occurrence(s)")
        
        # Overall assessment
        print("\n🎯 OVERALL ASSESSMENT:")
        if success_rate == 100:
            print("   🏆 EXCELLENT: All tests passed successfully!")
            print("   ✅ Gateway is fully operational and ready for production.")
        elif success_rate >= 80:
            print("   🟡 GOOD: Most tests passed with minor issues.")
            print("   ⚠️ Review failed tests and address configuration issues.")
        elif success_rate >= 50:
            print("   🟠 FAIR: Significant issues detected.")
            print("   🔧 Gateway requires configuration fixes before production use.")
        else:
            print("   🔴 CRITICAL: Major issues detected.")
            print("   🚨 Gateway is not operational. Immediate attention required.")
        
        print("=" * 80)
        
        # Save detailed report to file
        report_filename = f"enterprise_mcp_test_report_{self.session_id}.json"
        with open(report_filename, 'w') as f:
            json.dump({
                'session_id': self.session_id,
                'gateway_url': self.gateway_url,
                'start_time': self.start_time.isoformat(),
                'end_time': end_time.isoformat(),
                'total_duration_seconds': total_duration.total_seconds(),
                'statistics': {
                    'total_tests': total_tests,
                    'passed_tests': passed_tests,
                    'failed_tests': failed_tests,
                    'success_rate': success_rate,
                    'avg_execution_time': avg_execution_time
                },
                'test_results': self.test_results
            }, f, indent=2)
        
        logger.info(f"📄 Detailed report saved to: {report_filename}")
        print(f"📄 Detailed report saved to: {report_filename}")

def main():
    """Main execution function."""
    # Gateway configuration
    GATEWAY_URL = "https://a208194-askjulius-agentcore-gateway-mcp-iam-fvro4phd59.gateway.bedrock-agentcore.us-east-1.amazonaws.com/mcp"
    
    try:
        # Initialize and run enterprise test suite
        tester = EnterpriseMCPTester(GATEWAY_URL)
        tester.run_comprehensive_test_suite()
        
    except KeyboardInterrupt:
        print("\n\n⏹️ Test suite interrupted by user")
        logger.info("Test suite interrupted by user")
    except Exception as e:
        print(f"\n\n💥 Enterprise test suite failed: {e}")
        logger.error(f"Enterprise test suite failed: {e}")
        raise

if __name__ == "__main__":
    main()