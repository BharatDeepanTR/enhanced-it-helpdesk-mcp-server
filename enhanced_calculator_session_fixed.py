#!/usr/bin/env python3
"""
Enhanced Calculator Session Client with Agent Core Gateway Memory
Uses existing gateway: a208194-askjulius-agentcore-gateway-mcp-iam
Target: target-direct-calculator-lambda
Lambda: a208194-calculator-mcp-server
"""

import json
import boto3
import requests
from requests_aws4auth import AWS4Auth
import uuid
from datetime import datetime
import re

class EnhancedCalculatorSessionClient:
    def __init__(self):
        """Initialize with existing gateway configuration"""
        # Use existing gateway - no need to create new one
        self.gateway_url = "https://a208194-askjulius-agentcore-gateway-mcp-iam-fvro4phd59.gateway.bedrock-agentcore.us-east-1.amazonaws.com/mcp"
        self.region = "us-east-1"
        
        # Session management
        self.session_id = f"calc-session-{datetime.now().strftime('%Y%m%d-%H%M%S')}-{str(uuid.uuid4())[:8]}"
        self.actor_id = f"user-{str(uuid.uuid4())[:8]}"
        
        # Initialize AWS authentication
        self._setup_auth()
        
        # Initialize gateway session
        self._init_gateway_session()
        
        # Get available tools from gateway
        self.tool_name = self._discover_calculator_tool()
        
    def _setup_auth(self):
        """Setup AWS SigV4 authentication"""
        session = boto3.Session()
        credentials = session.get_credentials()
        self.auth = AWS4Auth(
            credentials.access_key,
            credentials.secret_key,
            self.region,
            'bedrock-agentcore',
            session_token=credentials.token
        )
        
    def _init_gateway_session(self):
        """Initialize session with Agent Core Gateway"""
        session_request = {
            "jsonrpc": "2.0",
            "id": 1,
            "method": "session/initialize",
            "params": {
                "sessionId": self.session_id,
                "actorId": self.actor_id,
                "capabilities": {
                    "memory": True,
                    "search": True,
                    "contextual": True
                }
            }
        }
        
        try:
            response = requests.post(
                self.gateway_url,
                json=session_request,
                auth=self.auth,
                headers={'Content-Type': 'application/json'},
                timeout=30
            )
            
            if response.status_code == 200:
                print("✅ Gateway session initialized successfully")
            else:
                print(f"⚠️ Session init status: {response.status_code}")
                
        except Exception as e:
            print(f"⚠️ Session initialization: {e}")
            
    def _discover_calculator_tool(self):
        """Discover the correct calculator tool from gateway"""
        list_request = {
            "jsonrpc": "2.0",
            "id": 2,
            "method": "tools/list",
            "params": {
                "sessionId": self.session_id
            }
        }
        
        try:
            response = requests.post(
                self.gateway_url,
                json=list_request,
                auth=self.auth,
                headers={'Content-Type': 'application/json'},
                timeout=30
            )
            
            if response.status_code == 200:
                result = response.json()
                if 'result' in result and 'tools' in result['result']:
                    tools = result['result']['tools']
                    for tool in tools:
                        tool_name = tool.get('name', '')
                        # Look for calculator-related tool
                        if any(keyword in tool_name.lower() for keyword in ['calc', 'math', 'compute', 'target-direct-calculator']):
                            print(f"🔧 Found calculator tool: {tool_name}")
                            return tool_name
                    
                    # If no specific calculator tool, use first available
                    if tools:
                        tool_name = tools[0]['name']
                        print(f"🔧 Using tool: {tool_name}")
                        return tool_name
                        
        except Exception as e:
            print(f"❌ Tool discovery error: {e}")
            
        # Fallback to expected tool name based on your configuration
        fallback_tool = "target-direct-calculator-lambda___calculate"
        print(f"🔧 Using fallback tool: {fallback_tool}")
        return fallback_tool
        
    def calculate(self, expression, operation_type="arithmetic"):
        """Perform calculation using gateway session"""
        calc_request = {
            "jsonrpc": "2.0",
            "id": 3,
            "method": "tools/call",
            "params": {
                "sessionId": self.session_id,
                "name": self.tool_name,
                "arguments": {
                    "expression": expression,
                    "operation": operation_type
                }
            }
        }
        
        try:
            response = requests.post(
                self.gateway_url,
                json=calc_request,
                auth=self.auth,
                headers={'Content-Type': 'application/json'},
                timeout=30
            )
            
            if response.status_code == 200:
                return response.json()
            else:
                return {
                    "error": f"HTTP {response.status_code}: {response.text}"
                }
                
        except Exception as e:
            return {
                "error": f"Request failed: {str(e)}"
            }
            
    def get_session_memory(self):
        """Retrieve session memory from gateway"""
        memory_request = {
            "jsonrpc": "2.0",
            "id": 4,
            "method": "session/memory",
            "params": {
                "sessionId": self.session_id,
                "actorId": self.actor_id
            }
        }
        
        try:
            response = requests.post(
                self.gateway_url,
                json=memory_request,
                auth=self.auth,
                headers={'Content-Type': 'application/json'},
                timeout=30
            )
            
            if response.status_code == 200:
                return response.json()
            else:
                return {"error": f"Memory retrieval failed: {response.status_code}"}
                
        except Exception as e:
            return {"error": f"Memory error: {str(e)}"}
            
    def search_memory(self, query):
        """Search session memory"""
        search_request = {
            "jsonrpc": "2.0",
            "id": 5,
            "method": "session/search",
            "params": {
                "sessionId": self.session_id,
                "query": query,
                "limit": 10
            }
        }
        
        try:
            response = requests.post(
                self.gateway_url,
                json=search_request,
                auth=self.auth,
                headers={'Content-Type': 'application/json'},
                timeout=30
            )
            
            if response.status_code == 200:
                return response.json()
            else:
                return {"error": f"Search failed: {response.status_code}"}
                
        except Exception as e:
            return {"error": f"Search error: {str(e)}"}

def parse_natural_language(user_input):
    """Parse natural language mathematical expressions"""
    lower_input = user_input.lower().strip()
    
    # Detect operation type
    if any(word in lower_input for word in ['sin', 'cos', 'tan', 'degree', 'radian']):
        operation = "trigonometry"
    elif any(word in lower_input for word in ['average', 'mean', 'median', 'sum']):
        operation = "statistics"
    elif any(word in lower_input for word in ['sqrt', 'square root', 'power', '^', '**']):
        operation = "advanced"
    else:
        operation = "arithmetic"
    
    # Extract mathematical expression
    # Handle percentage
    if 'percent' in lower_input or '%' in user_input:
        # Extract numbers for percentage calculations
        numbers = re.findall(r'\d+(?:\.\d+)?', user_input)
        if len(numbers) >= 2:
            if 'of' in lower_input:
                # "What percentage is X of Y?" or "X percent of Y"
                if 'what percentage is' in lower_input:
                    return f"({numbers[0]} / {numbers[1]}) * 100", operation
                else:
                    return f"({numbers[0]} / 100) * {numbers[1]}", operation
    
    # Handle "square root"
    if 'square root' in lower_input:
        numbers = re.findall(r'\d+(?:\.\d+)?', user_input)
        if numbers:
            return f"sqrt({numbers[0]})", "advanced"
    
    # Handle trigonometry
    if any(func in lower_input for func in ['sin', 'cos', 'tan']):
        # Extract function and angle
        for func in ['sin', 'cos', 'tan']:
            if func in lower_input:
                numbers = re.findall(r'\d+(?:\.\d+)?', user_input)
                if numbers:
                    return f"{func}({numbers[0]})", "trigonometry"
    
    # Handle average/mean
    if any(word in lower_input for word in ['average', 'mean']) and 'of' in lower_input:
        # Extract numbers after "of"
        numbers = re.findall(r'\d+(?:\.\d+)?', user_input)
        if len(numbers) >= 2:
            numbers_str = ', '.join(numbers)
            return f"mean([{numbers_str}])", "statistics"
    
    # Default: try to extract mathematical expression as-is
    # Remove common words and keep mathematical content
    expression = user_input
    for word in ['what', 'is', 'the', 'calculate', 'compute', 'find', '?']:
        expression = expression.replace(word, ' ')
    
    expression = expression.strip()
    if expression:
        return expression, operation
    
    return user_input, operation

def main():
    """Enhanced calculator with gateway session management"""
    print("🚀 Enhanced Calculator Session Client with Agent Core Gateway Memory")
    print("=" * 70)
    
    # Initialize client
    try:
        client = EnhancedCalculatorSessionClient()
        print(f"🔧 Enhanced Calculator Session Client Initialized")
        print(f"📋 Session ID: {client.session_id}")
        print(f"👤 Actor ID: {client.actor_id}")
        print(f"🧠 Gateway Memory: Enabled")
        print(f"🔧 Calculator tool: {client.tool_name}")
        print()
        print("✅ Ready for calculations with session memory!")
        print()
    except Exception as e:
        print(f"❌ Initialization failed: {e}")
        return
    
    print("Type mathematical expressions or special commands:")
    print("📋 Special commands: 'memory', 'search <term>', 'session', 'help', 'exit'")
    print()
    
    while True:
        try:
            user_input = input("EnhancedCalc> ").strip()
            
            if not user_input:
                continue
                
            if user_input.lower() == 'exit':
                print("👋 Goodbye!")
                break
                
            elif user_input.lower() == 'help':
                print("📚 Available commands:")
                print("  - Mathematical expressions: '2 + 2', 'sqrt(16)', 'sin(30)'")
                print("  - Natural language: 'What is 25% of 200?', 'Average of 10, 20, 30'")
                print("  - memory: Show session memory")
                print("  - search <term>: Search memory")
                print("  - session: Show session info")
                print("  - exit: Quit")
                continue
                
            elif user_input.lower() == 'session':
                print(f"📋 Session ID: {client.session_id}")
                print(f"👤 Actor ID: {client.actor_id}")
                print(f"🌐 Gateway: {client.gateway_url}")
                continue
                
            elif user_input.lower() == 'memory':
                print("🧠 Retrieving session memory...")
                memory = client.get_session_memory()
                if 'error' in memory:
                    print(f"❌ {memory['error']}")
                else:
                    print("📋 Session memory retrieved successfully")
                    print(json.dumps(memory, indent=2))
                continue
                
            elif user_input.lower().startswith('search '):
                query = user_input[7:].strip()
                if query:
                    print(f"🔍 Searching memory for: '{query}'")
                    results = client.search_memory(query)
                    if 'error' in results:
                        print(f"❌ {results['error']}")
                    else:
                        print("📋 Search results:")
                        print(json.dumps(results, indent=2))
                else:
                    print("❌ Please specify search term")
                continue
            
            # Process calculation
            print(f"🔍 Processing with session context: {user_input}")
            
            # Parse natural language to mathematical expression
            expression, operation = parse_natural_language(user_input)
            
            # Perform calculation
            result = client.calculate(expression, operation)
            
            if 'error' in result:
                print(f"❌ Error: {result['error']}")
            else:
                # Display result
                if 'result' in result:
                    calc_result = result['result']
                    if 'content' in calc_result:
                        for content in calc_result['content']:
                            if content.get('type') == 'text':
                                print(f"📊 Result: {content.get('text')}")
                    else:
                        print(f"📊 Result: {json.dumps(calc_result, indent=2)}")
                else:
                    print(f"📊 Response: {json.dumps(result, indent=2)}")
                    
        except KeyboardInterrupt:
            print("\n👋 Goodbye!")
            break
        except Exception as e:
            print(f"❌ Error: {e}")

if __name__ == "__main__":
    main()