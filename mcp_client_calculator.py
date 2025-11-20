#!/usr/bin/env python3
"""
MCP Client for Agent Core Gateway Calculator Target
Tests calculator functionality via Bedrock Agent Core Gateway
"""

import json
import boto3
import logging
import sys
from datetime import datetime
from typing import Dict, Any, Optional

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

class AgentCoreGatewayMCPClient:
    """MCP Client for interacting with Agent Core Gateway calculator target"""
    
    def __init__(self, 
                 gateway_id: str = "a208194-askjulius-agentcore-gateway-mcp-iam",
                 region: str = "us-east-1",
                 target_name: str = "target-direct-calculator-lambda"):
        """
        Initialize MCP client for Agent Core Gateway
        
        Args:
            gateway_id: The Agent Core Gateway identifier
            region: AWS region
            target_name: Name of the calculator target
        """
        self.gateway_id = gateway_id
        self.region = region
        self.target_name = target_name
        
        # Initialize Bedrock Agent Runtime client
        try:
            self.bedrock_client = boto3.client(
                'bedrock-agent-runtime', 
                region_name=region
            )
            logger.info(f"Initialized Bedrock client for region: {region}")
        except Exception as e:
            logger.error(f"Failed to initialize Bedrock client: {e}")
            raise
        
        # Session management
        self.session_id = f"mcp-client-{datetime.now().strftime('%Y%m%d-%H%M%S')}"
        logger.info(f"Created session: {self.session_id}")
    
    def invoke_calculator(self, calculation_prompt: str) -> Optional[Dict[str, Any]]:
        """
        Invoke calculator via Agent Core Gateway using natural language
        
        Args:
            calculation_prompt: Natural language calculation request
            
        Returns:
            Gateway response or None if failed
        """
        try:
            logger.info(f"Sending calculation request: '{calculation_prompt}'")
            
            # For Agent Core Gateway, we need to use invoke_agent with agentAliasId
            # The gateway acts as an agent with a specific alias
            response = self.bedrock_client.invoke_agent(
                agentId=self.gateway_id,
                agentAliasId="TSTALIASID",  # Default test alias for Agent Core Gateway
                sessionId=self.session_id,
                inputText=calculation_prompt
            )
            
            # Extract response content
            if 'completion' in response:
                result = {
                    'status': 'success',
                    'prompt': calculation_prompt,
                    'response': response['completion'],
                    'session_id': self.session_id,
                    'timestamp': datetime.now().isoformat()
                }
                
                # Extract trace information if available
                if 'trace' in response:
                    result['trace'] = response['trace']
                
                logger.info(f"Calculation successful: {response['completion']}")
                return result
            else:
                logger.error(f"No completion in response: {response}")
                return None
                
        except Exception as e:
            logger.error(f"Failed to invoke calculator: {e}")
            return {
                'status': 'error',
                'prompt': calculation_prompt,
                'error': str(e),
                'session_id': self.session_id,
                'timestamp': datetime.now().isoformat()
            }
    
    def test_basic_operations(self) -> Dict[str, Any]:
        """Test basic calculator operations"""
        
        test_cases = [
            "Calculate 15 plus 8",
            "What is 20 minus 7?",
            "Multiply 6 by 9",
            "Divide 48 by 6",
            "What's 2 to the power of 5?",
            "Find the square root of 64",
            "Calculate 5 factorial",
            "What is 25% of 200?",
            "Calculate sine of 30 degrees",
            "Find the mean of numbers: 10, 20, 30, 40, 50"
        ]
        
        results = {
            'test_suite': 'basic_operations',
            'total_tests': len(test_cases),
            'results': [],
            'summary': {'passed': 0, 'failed': 0, 'errors': 0}
        }
        
        logger.info(f"Running {len(test_cases)} basic operation tests...")
        
        for i, test_case in enumerate(test_cases, 1):
            logger.info(f"Test {i}/{len(test_cases)}: {test_case}")
            
            result = self.invoke_calculator(test_case)
            if result:
                if result['status'] == 'success':
                    results['summary']['passed'] += 1
                    logger.info(f"✅ Test {i} passed")
                elif result['status'] == 'error':
                    results['summary']['errors'] += 1
                    logger.warning(f"❌ Test {i} error: {result.get('error', 'Unknown')}")
                else:
                    results['summary']['failed'] += 1
                    logger.warning(f"⚠️ Test {i} failed")
            else:
                results['summary']['failed'] += 1
                logger.warning(f"❌ Test {i} no response")
            
            results['results'].append({
                'test_number': i,
                'prompt': test_case,
                'result': result
            })
        
        return results
    
    def test_error_handling(self) -> Dict[str, Any]:
        """Test error handling capabilities"""
        
        error_test_cases = [
            "Divide 10 by 0",
            "Calculate square root of -16",
            "Find factorial of -5",
            "Calculate 999999999999 factorial",
            "What is sine of invalid input?"
        ]
        
        results = {
            'test_suite': 'error_handling',
            'total_tests': len(error_test_cases),
            'results': [],
            'summary': {'handled': 0, 'unhandled': 0}
        }
        
        logger.info(f"Running {len(error_test_cases)} error handling tests...")
        
        for i, test_case in enumerate(error_test_cases, 1):
            logger.info(f"Error Test {i}/{len(error_test_cases)}: {test_case}")
            
            result = self.invoke_calculator(test_case)
            if result and 'error' in str(result).lower():
                results['summary']['handled'] += 1
                logger.info(f"✅ Error Test {i} - Error properly handled")
            else:
                results['summary']['unhandled'] += 1
                logger.warning(f"⚠️ Error Test {i} - Error not handled properly")
            
            results['results'].append({
                'test_number': i,
                'prompt': test_case,
                'result': result
            })
        
        return results
    
    def interactive_mode(self):
        """Interactive calculator mode"""
        
        print("\n🧮 Interactive Calculator via Agent Core Gateway")
        print("=" * 50)
        print(f"Gateway: {self.gateway_id}")
        print(f"Target: {self.target_name}")
        print(f"Session: {self.session_id}")
        print("\nType your calculation requests in natural language.")
        print("Examples:")
        print("  - Calculate 15 + 8")
        print("  - What is 2^10?")
        print("  - Find square root of 144")
        print("  - Calculate 20% of 150")
        print("\nType 'exit' or 'quit' to stop.\n")
        
        while True:
            try:
                user_input = input("Calculator> ").strip()
                
                if user_input.lower() in ['exit', 'quit', 'q']:
                    print("Goodbye! 👋")
                    break
                
                if not user_input:
                    continue
                
                print(f"\n🔄 Processing: {user_input}")
                result = self.invoke_calculator(user_input)
                
                if result and result['status'] == 'success':
                    print(f"✅ Result: {result['response']}")
                elif result and result['status'] == 'error':
                    print(f"❌ Error: {result['error']}")
                else:
                    print("⚠️ No response received")
                
                print()
                
            except KeyboardInterrupt:
                print("\n\nExiting... 👋")
                break
            except Exception as e:
                print(f"❌ Error: {e}")
    
    def generate_test_report(self, basic_results: Dict, error_results: Dict) -> str:
        """Generate comprehensive test report"""
        
        report = []
        report.append("🧮 MCP Client Test Report for Agent Core Gateway Calculator")
        report.append("=" * 65)
        report.append(f"Gateway ID: {self.gateway_id}")
        report.append(f"Target: {self.target_name}")
        report.append(f"Session: {self.session_id}")
        report.append(f"Test Time: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        report.append("")
        
        # Basic Operations Summary
        report.append("📊 Basic Operations Test Summary:")
        report.append("-" * 35)
        basic_summary = basic_results['summary']
        report.append(f"Total Tests: {basic_results['total_tests']}")
        report.append(f"✅ Passed: {basic_summary['passed']}")
        report.append(f"❌ Failed: {basic_summary['failed']}")
        report.append(f"🚫 Errors: {basic_summary['errors']}")
        
        success_rate = (basic_summary['passed'] / basic_results['total_tests']) * 100
        report.append(f"Success Rate: {success_rate:.1f}%")
        report.append("")
        
        # Error Handling Summary
        report.append("🚫 Error Handling Test Summary:")
        report.append("-" * 35)
        error_summary = error_results['summary']
        report.append(f"Total Tests: {error_results['total_tests']}")
        report.append(f"✅ Properly Handled: {error_summary['handled']}")
        report.append(f"⚠️ Not Handled: {error_summary['unhandled']}")
        
        error_rate = (error_summary['handled'] / error_results['total_tests']) * 100
        report.append(f"Error Handling Rate: {error_rate:.1f}%")
        report.append("")
        
        # Overall Assessment
        overall_success = (basic_summary['passed'] + error_summary['handled']) / \
                         (basic_results['total_tests'] + error_results['total_tests']) * 100
        
        report.append("🎯 Overall Assessment:")
        report.append("-" * 22)
        report.append(f"Overall Success Rate: {overall_success:.1f}%")
        
        if overall_success >= 80:
            report.append("✅ EXCELLENT - Gateway integration working well!")
        elif overall_success >= 60:
            report.append("✅ GOOD - Gateway integration mostly working")
        elif overall_success >= 40:
            report.append("⚠️ FAIR - Gateway integration needs attention")
        else:
            report.append("❌ POOR - Gateway integration has issues")
        
        return "\n".join(report)


def main():
    """Main function to run MCP client tests"""
    
    # Configuration
    GATEWAY_ID = "a208194-askjulius-agentcore-gateway-mcp-iam"
    REGION = "us-east-1"
    TARGET_NAME = "target-direct-calculator-lambda"
    
    print("🚀 Starting MCP Client for Agent Core Gateway Calculator")
    print("=" * 60)
    
    try:
        # Initialize MCP client
        client = AgentCoreGatewayMCPClient(
            gateway_id=GATEWAY_ID,
            region=REGION,
            target_name=TARGET_NAME
        )
        
        # Check command line arguments
        if len(sys.argv) > 1:
            mode = sys.argv[1].lower()
            
            if mode == "interactive":
                client.interactive_mode()
                return
            elif mode == "test":
                # Run automated tests
                print("🧪 Running automated test suite...")
                
                # Basic operations tests
                print("\n1️⃣ Testing basic operations...")
                basic_results = client.test_basic_operations()
                
                # Error handling tests  
                print("\n2️⃣ Testing error handling...")
                error_results = client.test_error_handling()
                
                # Generate and display report
                print("\n📋 Generating test report...")
                report = client.generate_test_report(basic_results, error_results)
                print(f"\n{report}")
                
                # Save detailed results
                timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
                filename = f"mcp_test_results_{timestamp}.json"
                
                with open(filename, 'w') as f:
                    json.dump({
                        'basic_operations': basic_results,
                        'error_handling': error_results,
                        'report': report
                    }, f, indent=2)
                
                print(f"\n💾 Detailed results saved to: {filename}")
                return
        
        # Default: Single calculation test
        print("🧮 Running single calculation test...")
        result = client.invoke_calculator("Calculate 10 plus 15")
        
        if result:
            print(f"✅ Test successful!")
            print(f"Response: {result.get('response', 'No response')}")
        else:
            print("❌ Test failed!")
        
        print(f"\n💡 Usage options:")
        print(f"   python {sys.argv[0]} interactive  # Interactive mode")
        print(f"   python {sys.argv[0]} test        # Full test suite")
        
    except Exception as e:
        logger.error(f"MCP Client error: {e}")
        print(f"❌ Failed to run MCP client: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()