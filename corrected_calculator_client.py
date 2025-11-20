#!/usr/bin/env python3
"""
Corrected Natural Language Calculator Client
Uses the CORRECT calculator gateway URL with proper tool mappings
"""

import json
import boto3
import requests
from requests_aws4auth import AWS4Auth
import re
import math

class CorrectedCalculatorClient:
    def __init__(self):
        """Initialize with the CORRECT gateway URL"""
        # Using the CORRECT calculator gateway URL
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
        
        print("🔧 Corrected Calculator Client")
        print("=" * 50)
        print(f"Gateway: {self.gateway_url}")
        
        # Discover actual available tools
        self.tools = self.discover_tools()
        
    def discover_tools(self):
        """Discover what tools are actually available"""
        print("\n🔍 Discovering available tools...")
        
        request = {
            "jsonrpc": "2.0",
            "id": 1,
            "method": "tools/list"
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
                result = response.json()
                if 'result' in result and 'tools' in result['result']:
                    tools = result['result']['tools']
                    print(f"✅ Found {len(tools)} tool(s):")
                    
                    tool_map = {}
                    for tool in tools:
                        name = tool.get('name', 'Unknown')
                        description = tool.get('description', 'No description')
                        print(f"  - {name}: {description}")
                        
                        # Map tool names to full tool names
                        if 'add' in name.lower():
                            tool_map['add'] = name
                        elif 'subtract' in name.lower():
                            tool_map['subtract'] = name
                        elif 'multiply' in name.lower():
                            tool_map['multiply'] = name
                        elif 'divide' in name.lower():
                            tool_map['divide'] = name
                        elif 'power' in name.lower():
                            tool_map['power'] = name
                        elif 'sqrt' in name.lower():
                            tool_map['sqrt'] = name
                        elif 'percentage' in name.lower():
                            tool_map['percentage'] = name
                        elif 'trigonometry' in name.lower():
                            tool_map['trigonometry'] = name
                        elif 'statistics' in name.lower():
                            tool_map['statistics'] = name
                        elif 'factorial' in name.lower():
                            tool_map['factorial'] = name
                    
                    print(f"📋 Tool mapping: {tool_map}")
                    return tool_map
                else:
                    print("❌ No tools found in response")
                    print(f"Response: {json.dumps(result, indent=2)}")
            else:
                print(f"❌ Failed to list tools: {response.status_code} - {response.text}")
                
        except Exception as e:
            print(f"❌ Tool discovery error: {e}")
            
        return {}
        
    def call_tool(self, tool_key, params):
        """Call a specific calculator tool"""
        if tool_key not in self.tools:
            return {"error": f"Tool '{tool_key}' not available. Available: {list(self.tools.keys())}"}
            
        full_tool_name = self.tools[tool_key]
        
        request = {
            "jsonrpc": "2.0", 
            "id": 1,
            "method": "tools/call",
            "params": {
                "name": full_tool_name,
                "arguments": params
            }
        }
        
        print(f"🔧 Calling {tool_key} ({full_tool_name}) with {params}")
        
        try:
            response = requests.post(
                self.gateway_url,
                json=request,
                auth=self.auth,
                headers={'Content-Type': 'application/json'},
                timeout=30
            )
            
            if response.status_code == 200:
                result = response.json()
                print(f"📥 Raw response: {json.dumps(result, indent=2)}")
                return result
            else:
                return {"error": f"HTTP {response.status_code}: {response.text}"}
                
        except Exception as e:
            return {"error": f"Request failed: {str(e)}"}
            
    def parse_and_calculate(self, user_input):
        """Parse natural language and perform calculation"""
        text = user_input.lower().strip()
        print(f"🔍 Processing: {user_input}")
        
        # Extract numbers
        numbers = re.findall(r'-?\d+(?:\.\d+)?', text)
        numbers = [float(n) for n in numbers]
        
        if not numbers:
            print("❌ No numbers found in input")
            return None
            
        print(f"📊 Found numbers: {numbers}")
        
        # Handle different operations
        
        # Square root
        if any(phrase in text for phrase in ['square root', 'sqrt']):
            if len(numbers) >= 1:
                return self.call_tool('sqrt', {'number': numbers[0]})
                
        # Addition
        if any(op in text for op in ['+', 'add', 'plus', 'sum']) and len(numbers) >= 2:
            # For multiple numbers, add them sequentially
            result = numbers[0]
            for i in range(1, len(numbers)):
                add_result = self.call_tool('add', {'a': result, 'b': numbers[i]})
                if self.extract_number_from_result(add_result) is not None:
                    result = self.extract_number_from_result(add_result)
                else:
                    print(f"❌ Failed to add {result} + {numbers[i]}")
                    return add_result
            return {"result": {"content": [{"type": "text", "text": str(result)}]}}
            
        # Basic two-number operations
        if len(numbers) >= 2:
            if any(op in text for op in ['-', 'subtract', 'minus']):
                return self.call_tool('subtract', {'a': numbers[0], 'b': numbers[1]})
            elif any(op in text for op in ['*', 'x', 'multiply', 'times']):
                return self.call_tool('multiply', {'a': numbers[0], 'b': numbers[1]})
            elif any(op in text for op in ['/', '÷', 'divide', 'divided by']):
                return self.call_tool('divide', {'a': numbers[0], 'b': numbers[1]})
            elif any(op in text for op in ['^', 'power', 'raised to']):
                return self.call_tool('power', {'base': numbers[0], 'exponent': numbers[1]})
                
        # Average
        if any(word in text for word in ['average', 'mean']) and len(numbers) >= 2:
            # Sum all numbers then divide by count
            total = numbers[0]
            for i in range(1, len(numbers)):
                add_result = self.call_tool('add', {'a': total, 'b': numbers[i]})
                if self.extract_number_from_result(add_result) is not None:
                    total = self.extract_number_from_result(add_result)
                else:
                    return add_result
            
            # Divide by count
            avg_result = self.call_tool('divide', {'a': total, 'b': len(numbers)})
            return avg_result
            
        # Percentage
        if 'percent' in text or '%' in text:
            if 'percentage' in self.tools:
                if 'what percentage is' in text and len(numbers) >= 2:
                    # Use dedicated percentage tool for "What percentage is 25 of 200?"
                    return self.call_tool('percentage', {
                        'part': numbers[0], 
                        'whole': numbers[1],
                        'operation': 'part_of_whole'
                    })
                elif 'of' in text and len(numbers) >= 2:
                    # Use dedicated percentage tool for "15% of 250"
                    return self.call_tool('percentage', {
                        'percentage': numbers[0],
                        'value': numbers[1], 
                        'operation': 'percentage_of_value'
                    })
            else:
                # Fallback to basic arithmetic if percentage tool not available
                if 'of' in text and len(numbers) >= 2:
                    if 'what percentage is' in text:
                        # "What percentage is 25 of 200?" -> (25/200) * 100
                        div_result = self.call_tool('divide', {'a': numbers[0], 'b': numbers[1]})
                        if self.extract_number_from_result(div_result) is not None:
                            ratio = self.extract_number_from_result(div_result)
                            return self.call_tool('multiply', {'a': ratio, 'b': 100})
                    else:
                        # "15% of 250" -> (15/100) * 250
                        div_result = self.call_tool('divide', {'a': numbers[0], 'b': 100})
                        if self.extract_number_from_result(div_result) is not None:
                            percentage = self.extract_number_from_result(div_result)
                            return self.call_tool('multiply', {'a': percentage, 'b': numbers[1]})
        
        # Trigonometry operations
        if any(trig in text.lower() for trig in ['sin', 'cos', 'tan', 'sine', 'cosine', 'tangent']):
            if 'trigonometry' in self.tools and len(numbers) >= 1:
                operation = 'sin'
                if 'cos' in text.lower():
                    operation = 'cos'
                elif 'tan' in text.lower():
                    operation = 'tan'
                return self.call_tool('trigonometry', {
                    'angle': numbers[0],
                    'function': operation,
                    'unit': 'degrees'  # Default to degrees
                })
        
        # Factorial operation
        if 'factorial' in text.lower() or '!' in text:
            if 'factorial' in self.tools and len(numbers) >= 1:
                return self.call_tool('factorial', {'n': int(numbers[0])})
        
        # Statistics operations
        if any(stat in text.lower() for stat in ['mean', 'median', 'mode', 'std', 'variance']):
            if 'statistics' in self.tools and len(numbers) >= 1:
                operation = 'mean'
                if 'median' in text.lower():
                    operation = 'median'
                elif 'mode' in text.lower():
                    operation = 'mode'
                elif 'std' in text.lower() or 'deviation' in text.lower():
                    operation = 'std'
                elif 'variance' in text.lower():
                    operation = 'variance'
                return self.call_tool('statistics', {
                    'data': numbers,
                    'operation': operation
                })
        
        print("❌ Could not understand the operation")
        return {"error": "Could not parse the mathematical expression"}
        
    def extract_number_from_result(self, result):
        """Extract numeric result from MCP response"""
        if 'result' in result and 'content' in result['result']:
            for content in result['result']['content']:
                if content.get('type') == 'text':
                    text = content.get('text', '').strip()
                    try:
                        return float(text)
                    except ValueError:
                        pass
        return None
        
    def display_result(self, result):
        """Display the calculation result"""
        if 'error' in result:
            print(f"❌ Error: {result['error']}")
            return
            
        # Extract and display result
        if 'result' in result and 'content' in result['result']:
            for content in result['result']['content']:
                if content.get('type') == 'text':
                    answer = content.get('text', 'No result')
                    print(f"📊 Result: {answer}")
                    return answer
        
        print(f"❌ Could not extract result from: {json.dumps(result, indent=2)}")
        return None

def main():
    """Main calculator interface"""
    client = CorrectedCalculatorClient()
    
    if not client.tools:
        print("❌ No tools available. Please check gateway configuration.")
        return
        
    print("\n🧮 Natural Language Calculator Ready!")
    print("\nExamples:")
    print("  - Add 10 and 25")
    print("  - What is the square root of 100?") 
    print("  - Find the average of 10, 15, 20, 25, 30")
    print("  - What percentage is 25 of 200?")
    print("\nCommands: 'help', 'tools', 'exit'")
    print()
    
    while True:
        try:
            user_input = input("Calculator> ").strip()
            
            if not user_input:
                continue
                
            if user_input.lower() == 'exit':
                print("👋 Goodbye!")
                break
                
            elif user_input.lower() == 'tools':
                print(f"🔧 Available tools: {list(client.tools.keys())}")
                continue
                
            elif user_input.lower() == 'help':
                print("📚 Usage:")
                print("  - Basic math: 'add 5 and 3', '10 - 5', '6 * 7', '20 / 4'")
                print("  - Advanced: 'sqrt 64', '2 ^ 3', 'average of 10, 20, 30'")
                print("  - Percentage: 'what percentage is 25 of 200?', '15% of 250'")
                continue
            
            # Process calculation
            result = client.parse_and_calculate(user_input)
            if result:
                client.display_result(result)
            print()
            
        except KeyboardInterrupt:
            print("\n👋 Goodbye!")
            break
        except Exception as e:
            print(f"❌ Error: {e}")

if __name__ == "__main__":
    main()