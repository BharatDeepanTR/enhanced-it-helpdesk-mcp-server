#!/usr/bin/env python3
"""
Natural Language Calculator Client - Fixed for Real Calculator Lambda
Works with actual calculator tools: add, subtract, multiply, divide, power, sqrt
"""

import json
import boto3
import requests
from requests_aws4auth import AWS4Auth
import re
import math

class NaturalLanguageCalculatorClient:
    def __init__(self):
        """Initialize with existing gateway"""
        self.gateway_url = "https://a208194-askjulius-agentcore-gateway-mcp-iam-fvro4phd59.gateway.bedrock-agentcore.us-east-1.amazonaws.com/mcp"
        self.region = "us-east-1"
        
        # Setup authentication
        session = boto3.Session()
        credentials = session.get_credentials()
        self.auth = AWS4Auth(
            credentials.access_key,
            credentials.secret_key,
            self.region,
            'bedrock-agentcore',
            session_token=credentials.token
        )
        
        # Available calculator tools
        self.tools = {
            'add': 'target-direct-calculator-lambda___add',
            'subtract': 'target-direct-calculator-lambda___subtract', 
            'multiply': 'target-direct-calculator-lambda___multiply',
            'divide': 'target-direct-calculator-lambda___divide',
            'power': 'target-direct-calculator-lambda___power',
            'sqrt': 'target-direct-calculator-lambda___sqrt'
        }
        
        print("🧮 Natural Language Calculator Client")
        print("=" * 50)
        
    def call_tool(self, tool_name, params):
        """Call a specific calculator tool"""
        full_tool_name = self.tools.get(tool_name)
        if not full_tool_name:
            return {"error": f"Unknown tool: {tool_name}"}
            
        request = {
            "jsonrpc": "2.0",
            "id": 1,
            "method": "tools/call",
            "params": {
                "name": full_tool_name,
                "arguments": params
            }
        }
        
        try:
            response = requests.post(
                self.gateway_url,
                json=request,
                auth=self.auth,
                headers={'Content-Type': 'application/json'},
                timeout=30
            )
            
            if response.status_code == 200:
                return response.json()
            else:
                return {"error": f"HTTP {response.status_code}: {response.text}"}
                
        except Exception as e:
            return {"error": f"Request failed: {str(e)}"}
            
    def parse_natural_language(self, user_input):
        """Parse natural language into calculator operations"""
        text = user_input.lower().strip()
        
        # Extract numbers
        numbers = re.findall(r'-?\d+(?:\.\d+)?', text)
        numbers = [float(n) for n in numbers]
        
        # Handle specific patterns
        
        # Square root
        if any(phrase in text for phrase in ['square root', 'sqrt']):
            if numbers:
                return ('sqrt', {'number': numbers[0]})
                
        # Percentage calculations
        if 'percent' in text or '%' in text:
            if 'of' in text and len(numbers) >= 2:
                if 'what percentage is' in text:
                    # "What percentage is 25 of 200?"
                    result = (numbers[0] / numbers[1]) * 100
                    return ('multiply', {'a': numbers[0]/numbers[1], 'b': 100})
                else:
                    # "15% of 250" 
                    return ('multiply', {'a': numbers[0]/100, 'b': numbers[1]})
                    
        # Power operations
        if any(phrase in text for phrase in ['power', 'raised to', 'to the power', '^', '**']):
            if len(numbers) >= 2:
                return ('power', {'base': numbers[0], 'exponent': numbers[1]})
                
        # Basic arithmetic based on operators and keywords
        if len(numbers) >= 2:
            if any(op in text for op in ['+', 'add', 'plus', 'sum']):
                # Handle multiple numbers for addition
                if len(numbers) > 2:
                    # Add them sequentially using the add tool
                    return ('add_multiple', numbers)
                return ('add', {'a': numbers[0], 'b': numbers[1]})
                
            elif any(op in text for op in ['-', 'subtract', 'minus', 'take away']):
                return ('subtract', {'a': numbers[0], 'b': numbers[1]})
                
            elif any(op in text for op in ['*', 'x', 'multiply', 'times']):
                return ('multiply', {'a': numbers[0], 'b': numbers[1]})
                
            elif any(op in text for op in ['/', '÷', 'divide', 'divided by']):
                return ('divide', {'a': numbers[0], 'b': numbers[1]})
                
        # Average calculation
        if any(word in text for word in ['average', 'mean']) and len(numbers) >= 2:
            # Calculate average using add and divide
            return ('average', numbers)
            
        return None
        
    def calculate_multiple_operations(self, operation_type, numbers):
        """Handle operations that require multiple calls"""
        
        if operation_type == 'add_multiple':
            # Add numbers sequentially
            result = numbers[0]
            for i in range(1, len(numbers)):
                add_result = self.call_tool('add', {'a': result, 'b': numbers[i]})
                if 'result' in add_result and 'content' in add_result['result']:
                    for content in add_result['result']['content']:
                        if content.get('type') == 'text':
                            result = float(content.get('text', '0'))
                            break
            return result
            
        elif operation_type == 'average':
            # Calculate sum then divide by count
            total = self.calculate_multiple_operations('add_multiple', numbers)
            avg_result = self.call_tool('divide', {'a': total, 'b': len(numbers)})
            if 'result' in avg_result and 'content' in avg_result['result']:
                for content in avg_result['result']['content']:
                    if content.get('type') == 'text':
                        return float(content.get('text', '0'))
            return total / len(numbers)  # fallback
            
        return None

    def process_calculation(self, user_input):
        """Process a natural language calculation"""
        print(f"🔍 Processing: {user_input}")
        
        parsed = self.parse_natural_language(user_input)
        
        if not parsed:
            print("❌ Could not understand the calculation")
            return
            
        operation, params = parsed
        
        # Handle multi-step operations
        if operation in ['add_multiple', 'average']:
            result = self.calculate_multiple_operations(operation, params)
            print(f"📊 Result: {result}")
            return result
        
        # Handle single operations
        result = self.call_tool(operation, params)
        
        if 'error' in result:
            print(f"❌ Error: {result['error']}")
            return None
            
        # Extract result from MCP response
        if 'result' in result and 'content' in result['result']:
            for content in result['result']['content']:
                if content.get('type') == 'text':
                    answer = content.get('text')
                    print(f"📊 Result: {answer}")
                    return float(answer) if answer.replace('.','').replace('-','').isdigit() else answer
                    
        print("❌ Could not extract result")
        return None

def main():
    """Natural language calculator interface"""
    client = NaturalLanguageCalculatorClient()
    
    print("\nType mathematical expressions in natural language:")
    print("Examples:")
    print("  - Add 10 and 25")
    print("  - What is the square root of 100?")
    print("  - Find the average of 10, 15, 20, 25, 30") 
    print("  - What percentage is 25 of 200?")
    print("  - 2 raised to the power of 8")
    print("\nSpecial commands: 'help', 'exit'")
    print()
    
    while True:
        try:
            user_input = input("Calculator> ").strip()
            
            if not user_input:
                continue
                
            if user_input.lower() == 'exit':
                print("👋 Goodbye!")
                break
                
            elif user_input.lower() == 'help':
                print("📚 Available operations:")
                print("  - Addition: 'add 5 and 3', '10 + 15 + 20'")
                print("  - Subtraction: 'subtract 8 from 15', '20 - 5'")
                print("  - Multiplication: 'multiply 6 by 7', '4 * 9'")
                print("  - Division: 'divide 100 by 4', '50 / 2'")
                print("  - Power: '2 to the power of 3', '5^2'")
                print("  - Square root: 'square root of 64', 'sqrt 25'")
                print("  - Average: 'average of 10, 20, 30'")
                print("  - Percentage: 'what is 15% of 200?'")
                continue
                
            client.process_calculation(user_input)
            print()
            
        except KeyboardInterrupt:
            print("\n👋 Goodbye!")
            break
        except Exception as e:
            print(f"❌ Error: {e}")

if __name__ == "__main__":
    main()