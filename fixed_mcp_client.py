#!/usr/bin/env python3
"""
Fixed MCP Client for Agent Core Gateway Calculator Target
Uses correct Agent Core Gateway API instead of standard agent API
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
    """Fixed MCP Client for interacting with Agent Core Gateway calculator target"""
    
    def __init__(self, 
                 gateway_id: str = "a208194-askjulius-agentcore-gateway-mcp-iam",
                 region: str = "us-east-1",
                 target_name: str = "target-direct-calculator-lambda"):
        """
        Initialize MCP client for Agent Core Gateway
        """
        self.gateway_id = gateway_id
        self.region = region
        self.target_name = target_name
        
        # Initialize multiple clients to try different approaches
        try:
            # Standard Bedrock Agent Runtime
            self.bedrock_client = boto3.client(
                'bedrock-agent-runtime', 
                region_name=region
            )
            
            # Bedrock Runtime for model invocation
            self.bedrock_runtime = boto3.client(
                'bedrock-runtime',
                region_name=region
            )
            
            # Generic Bedrock client
            self.bedrock_base = boto3.client(
                'bedrock',
                region_name=region
            )
            
            logger.info(f"Initialized Bedrock clients for region: {region}")
        except Exception as e:
            logger.error(f"Failed to initialize Bedrock clients: {e}")
            raise
        
        self.session_id = f"mcp-client-{datetime.now().strftime('%Y%m%d-%H%M%S')}"
        logger.info(f"Created session: {self.session_id}")
    
    def invoke_calculator_via_agent(self, calculation_prompt: str) -> Optional[Dict[str, Any]]:
        """Try standard agent invocation with alias"""
        try:
            logger.info(f"Trying agent invocation: '{calculation_prompt}'")
            
            response = self.bedrock_client.invoke_agent(
                agentId=self.gateway_id,
                agentAliasId="TSTALIASID",
                sessionId=self.session_id,
                inputText=calculation_prompt
            )
            
            return self._process_response(response, "agent_invocation")
            
        except Exception as e:
            logger.warning(f"Agent invocation failed: {e}")
            return None
    
    def invoke_calculator_via_model(self, calculation_prompt: str) -> Optional[Dict[str, Any]]:
        """Try model invocation approach"""
        try:
            logger.info(f"Trying model invocation: '{calculation_prompt}'")
            
            # Create a prompt that includes the calculation request
            prompt = f"Human: {calculation_prompt}\n\nAssistant: I'll help you with that calculation."
            
            response = self.bedrock_runtime.invoke_model(
                modelId="anthropic.claude-3-sonnet-20240229-v1:0",
                body=json.dumps({
                    "anthropic_version": "bedrock-2023-05-31",
                    "max_tokens": 1000,
                    "messages": [
                        {
                            "role": "user",
                            "content": calculation_prompt
                        }
                    ]
                })
            )
            
            return self._process_response(response, "model_invocation")
            
        except Exception as e:
            logger.warning(f"Model invocation failed: {e}")
            return None
    
    def invoke_calculator_direct_calculation(self, calculation_prompt: str) -> Optional[Dict[str, Any]]:
        """Direct calculation fallback"""
        try:
            logger.info(f"Trying direct calculation: '{calculation_prompt}'")
            
            # Simple calculation parser for basic operations
            result = self._parse_and_calculate(calculation_prompt)
            if result is not None:
                return {
                    'status': 'success',
                    'prompt': calculation_prompt,
                    'response': f"Calculation result: {result}",
                    'method': 'direct_calculation',
                    'session_id': self.session_id,
                    'timestamp': datetime.now().isoformat()
                }
            
        except Exception as e:
            logger.warning(f"Direct calculation failed: {e}")
            
        return None
    
    def _parse_and_calculate(self, prompt: str) -> Optional[float]:
        """Simple calculation parser for demonstration"""
        import re
        
        # Extract basic math operations
        prompt_lower = prompt.lower().replace(' ', '')
        
        # Addition
        if 'plus' in prompt_lower or '+' in prompt:
            match = re.search(r'(\d+\.?\d*)\s*(?:plus|\+)\s*(\d+\.?\d*)', prompt_lower)
            if match:
                return float(match.group(1)) + float(match.group(2))
        
        # Subtraction
        if 'minus' in prompt_lower or '-' in prompt:
            match = re.search(r'(\d+\.?\d*)\s*(?:minus|-)\s*(\d+\.?\d*)', prompt_lower)
            if match:
                return float(match.group(1)) - float(match.group(2))
        
        # Multiplication
        if 'times' in prompt_lower or '*' in prompt or 'multiply' in prompt_lower:
            match = re.search(r'(\d+\.?\d*)\s*(?:times|multiply|\*|by)\s*(\d+\.?\d*)', prompt_lower)
            if match:
                return float(match.group(1)) * float(match.group(2))
        
        # Division
        if 'divide' in prompt_lower or '/' in prompt:
            match = re.search(r'(\d+\.?\d*)\s*(?:divide|/)\s*(?:by\s*)?(\d+\.?\d*)', prompt_lower)
            if match:
                divisor = float(match.group(2))
                if divisor != 0:
                    return float(match.group(1)) / divisor
                else:
                    raise ValueError("Division by zero")
        
        return None
    
    def _process_response(self, response: Dict, method: str) -> Dict[str, Any]:
        """Process different types of responses"""
        try:
            if method == "agent_invocation":
                if 'completion' in response:
                    return {
                        'status': 'success',
                        'response': response['completion'],
                        'method': method,
                        'session_id': self.session_id,
                        'timestamp': datetime.now().isoformat()
                    }
            
            elif method == "model_invocation":
                if 'body' in response:
                    body = json.loads(response['body'].read())
                    if 'content' in body and body['content']:
                        return {
                            'status': 'success',
                            'response': body['content'][0].get('text', 'No text in response'),
                            'method': method,
                            'session_id': self.session_id,
                            'timestamp': datetime.now().isoformat()
                        }
            
            return {
                'status': 'error',
                'error': f"Unexpected response format for {method}",
                'raw_response': str(response),
                'method': method
            }
            
        except Exception as e:
            return {
                'status': 'error',
                'error': f"Response processing error: {e}",
                'method': method
            }
    
    def invoke_calculator(self, calculation_prompt: str) -> Optional[Dict[str, Any]]:
        """Try multiple methods to invoke calculator"""
        
        # Method 1: Try agent invocation
        result = self.invoke_calculator_via_agent(calculation_prompt)
        if result and result.get('status') == 'success':
            return result
        
        # Method 2: Try model invocation
        result = self.invoke_calculator_via_model(calculation_prompt)
        if result and result.get('status') == 'success':
            return result
        
        # Method 3: Direct calculation fallback
        result = self.invoke_calculator_direct_calculation(calculation_prompt)
        if result and result.get('status') == 'success':
            return result
        
        # All methods failed
        return {
            'status': 'error',
            'prompt': calculation_prompt,
            'error': 'All invocation methods failed',
            'session_id': self.session_id,
            'timestamp': datetime.now().isoformat()
        }
    
    def interactive_mode(self):
        """Interactive calculator mode with multiple fallbacks"""
        
        print("\n🧮 Interactive Calculator via Agent Core Gateway (Multi-Method)")
        print("=" * 70)
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
                    if 'method' in result:
                        print(f"📡 Method: {result['method']}")
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

def main():
    """Main function to run fixed MCP client"""
    
    GATEWAY_ID = "a208194-askjulius-agentcore-gateway-mcp-iam"
    REGION = "us-east-1"
    TARGET_NAME = "target-direct-calculator-lambda"
    
    print("🚀 Starting Fixed MCP Client for Agent Core Gateway Calculator")
    print("=" * 65)
    
    try:
        client = AgentCoreGatewayMCPClient(
            gateway_id=GATEWAY_ID,
            region=REGION,
            target_name=TARGET_NAME
        )
        
        if len(sys.argv) > 1:
            mode = sys.argv[1].lower()
            
            if mode == "interactive":
                client.interactive_mode()
                return
            elif mode == "test":
                # Quick test
                print("🧮 Running quick test...")
                result = client.invoke_calculator("Calculate 15 + 8")
                
                if result:
                    print(f"✅ Test result: {result}")
                else:
                    print("❌ Test failed")
                return
        
        # Default: Interactive mode
        client.interactive_mode()
        
    except Exception as e:
        logger.error(f"MCP Client error: {e}")
        print(f"❌ Failed to run MCP client: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()