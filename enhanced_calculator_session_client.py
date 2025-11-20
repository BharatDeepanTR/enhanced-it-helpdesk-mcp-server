#!/usr/bin/env python3
"""
Enhanced Calculator Session MCP Client with Agent Core Gateway Memory
Uses the working calculator Lambda: a208194-calculator-mcp-server
"""

import json
import boto3
import requests
import uuid
from datetime import datetime
from requests_aws4auth import AWS4Auth
from typing import Dict, List, Any, Optional

class EnhancedCalculatorSessionClient:
    def __init__(self):
        # Gateway configuration for working calculator
        self.gateway_url = "https://a208194-askjulius-agentcore-gateway-mcp-iam-fvro4phd59.gateway.bedrock-agentcore.us-east-1.amazonaws.com/mcp"
        self.region = "us-east-1"
        
        # Session management
        timestamp = datetime.now().strftime("%Y%m%d-%H%M%S")
        self.session_id = f"calc-session-{timestamp}-{uuid.uuid4().hex[:8]}"
        self.actor_id = f"user-{uuid.uuid4().hex[:8]}"
        
        # Memory configuration
        self.short_memory_limit = 10
        self.session_memory = []
        
        # Set up AWS authentication
        session = boto3.Session()
        credentials = session.get_credentials()
        self.auth = AWS4Auth(
            credentials.access_key,
            credentials.secret_key,
            self.region,
            'bedrock-agentcore',
            session_token=credentials.token
        )
        
        print(f"🔧 Enhanced Calculator Session MCP Client Initialized")
        print(f"📋 Session ID: {self.session_id}")
        print(f"👤 Actor ID: {self.actor_id}")
        print(f"🧠 Gateway Memory: Enabled")
        print(f"💾 Short Memory Limit: {self.short_memory_limit} interactions")
        
        # Initialize session
        self._initialize_session()

    def _initialize_session(self):
        """Initialize session with gateway"""
        try:
            # Test connection by listing tools
            list_request = {
                "jsonrpc": "2.0",
                "id": 1,
                "method": "tools/list",
                "params": {
                    "sessionId": self.session_id,
                    "actorId": self.actor_id
                }
            }
            
            response = requests.post(
                self.gateway_url,
                json=list_request,
                auth=self.auth,
                headers={
                    'Content-Type': 'application/json',
                    'X-Session-ID': self.session_id,
                    'X-Actor-ID': self.actor_id
                },
                timeout=30
            )
            
            if response.status_code == 200:
                result = response.json()
                if 'result' in result and 'tools' in result['result']:
                    tools = result['result']['tools']
                    if tools:
                        self.calculator_tool_name = tools[0]['name']
                        print(f"✅ Gateway session initialized successfully")
                        print(f"🔧 Calculator tool: {self.calculator_tool_name}")
                        return True
            
            print(f"⚠️ Gateway session initialization warning: {response.status_code}")
            # Fallback to known tool name
            self.calculator_tool_name = "target-calculator___calculate"
            return True
            
        except Exception as e:
            print(f"⚠️ Session initialization error: {e}")
            self.calculator_tool_name = "target-calculator___calculate"
            return False

    def add_to_memory(self, user_input: str, result: str, operation_type: str = "calculation"):
        """Add interaction to session memory"""
        interaction = {
            "timestamp": datetime.now().isoformat(),
            "user_input": user_input,
            "result": result,
            "operation_type": operation_type,
            "session_id": self.session_id,
            "actor_id": self.actor_id
        }
        
        self.session_memory.append(interaction)
        
        # Keep only recent interactions (short memory)
        if len(self.session_memory) > self.short_memory_limit:
            self.session_memory = self.session_memory[-self.short_memory_limit:]

    def search_memory(self, search_term: str) -> List[Dict[str, Any]]:
        """Search session memory for relevant interactions"""
        search_lower = search_term.lower()
        matches = []
        
        for interaction in self.session_memory:
            # Search in user input and results
            if (search_lower in interaction['user_input'].lower() or 
                search_lower in interaction['result'].lower()):
                matches.append(interaction)
        
        return matches

    def get_session_context(self, user_input: str) -> str:
        """Generate session context from recent memory"""
        if not self.session_memory:
            return "New session - no previous context"
        
        # Get last few interactions for context
        recent_interactions = self.session_memory[-3:]
        context_parts = []
        
        for interaction in recent_interactions:
            context_parts.append(f"Previous: {interaction['user_input']} → {interaction['result']}")
        
        return " | ".join(context_parts)

    def calculate_with_session(self, expression: str) -> Dict[str, Any]:
        """Perform calculation with session context"""
        try:
            # Get session context
            context = self.get_session_context(expression)
            
            # Prepare request with session information
            calculate_request = {
                "jsonrpc": "2.0",
                "id": 2,
                "method": "tools/call",
                "params": {
                    "name": self.calculator_tool_name,
                    "arguments": {
                        "expression": expression
                    },
                    "sessionId": self.session_id,
                    "actorId": self.actor_id,
                    "context": context
                }
            }
            
            response = requests.post(
                self.gateway_url,
                json=calculate_request,
                auth=self.auth,
                headers={
                    'Content-Type': 'application/json',
                    'X-Session-ID': self.session_id,
                    'X-Actor-ID': self.actor_id
                },
                timeout=30
            )
            
            if response.status_code == 200:
                result = response.json()
                
                if 'result' in result and not result['result'].get('isError', False):
                    # Extract successful result
                    content = result['result'].get('content', [])
                    for item in content:
                        if item.get('type') == 'text':
                            result_text = item.get('text', 'No result')
                            
                            # Add to session memory
                            self.add_to_memory(expression, result_text, "calculation")
                            
                            return {
                                "success": True,
                                "result": result_text,
                                "session_id": self.session_id,
                                "context_used": context
                            }
                else:
                    # Handle error response
                    content = result.get('result', {}).get('content', [])
                    error_text = "Calculation failed"
                    for item in content:
                        if item.get('type') == 'text':
                            error_text = item.get('text', error_text)
                    
                    self.add_to_memory(expression, f"Error: {error_text}", "error")
                    return {
                        "success": False,
                        "error": error_text,
                        "session_id": self.session_id
                    }
            else:
                error_msg = f"HTTP {response.status_code}: {response.text}"
                self.add_to_memory(expression, f"Error: {error_msg}", "error")
                return {
                    "success": False,
                    "error": error_msg,
                    "session_id": self.session_id
                }
                
        except Exception as e:
            error_msg = f"Request failed: {str(e)}"
            self.add_to_memory(expression, f"Error: {error_msg}", "error")
            return {
                "success": False,
                "error": error_msg,
                "session_id": self.session_id
            }

    def show_memory(self):
        """Display current session memory"""
        print(f"\n🧠 Session Memory (Session: {self.session_id})")
        print(f"👤 Actor: {self.actor_id}")
        print("=" * 60)
        
        if not self.session_memory:
            print("📋 No interactions in current session")
            return
        
        for i, interaction in enumerate(self.session_memory, 1):
            timestamp = interaction['timestamp'][:19]  # Remove microseconds
            print(f"{i}. [{timestamp}] {interaction['operation_type']}")
            print(f"   📥 Input: {interaction['user_input']}")
            print(f"   📤 Result: {interaction['result']}")
            print()

    def show_session_info(self):
        """Display session information"""
        print(f"\n📊 Session Information")
        print("=" * 40)
        print(f"🆔 Session ID: {self.session_id}")
        print(f"👤 Actor ID: {self.actor_id}")
        print(f"🕐 Created: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        print(f"💭 Memory Items: {len(self.session_memory)}")
        print(f"🎯 Target Tool: {getattr(self, 'calculator_tool_name', 'Unknown')}")
        print(f"🌐 Gateway: {self.gateway_url}")
        print()

def main():
    """Enhanced calculator client with session management"""
    print("🚀 Enhanced Calculator Session MCP Client with Agent Core Memory")
    print("=" * 70)
    
    # Initialize client
    try:
        client = EnhancedCalculatorSessionClient()
        print()
    except Exception as e:
        print(f"❌ Failed to initialize client: {e}")
        return
    
    print("✅ Ready for calculations with session memory!")
    print()
    print("Type mathematical expressions or special commands:")
    print("📋 Special commands: 'memory', 'search <term>', 'session', 'help', 'exit'")
    print()
    
    while True:
        try:
            user_input = input("EnhancedCalc> ").strip()
            
            if not user_input:
                continue
                
            # Handle special commands
            if user_input.lower() == 'exit':
                print("👋 Goodbye! Session data preserved for this runtime.")
                break
            elif user_input.lower() == 'help':
                print("\n🆘 Available Commands:")
                print("  memory          - Show session memory")
                print("  search <term>   - Search memory for term")
                print("  session         - Show session info")
                print("  exit            - Exit the client")
                print("  <expression>    - Calculate mathematical expression")
                print("\n📊 Examples:")
                print("  2 + 2")
                print("  sqrt(100)")
                print("  sin(30)")
                print("  15% of 200")
                print()
                continue
            elif user_input.lower() == 'memory':
                client.show_memory()
                continue
            elif user_input.lower() == 'session':
                client.show_session_info()
                continue
            elif user_input.lower().startswith('search '):
                search_term = user_input[7:].strip()
                if search_term:
                    print(f"🔍 Searching memory for: '{search_term}'")
                    print("=" * 50)
                    matches = client.search_memory(search_term)
                    if matches:
                        for i, match in enumerate(matches, 1):
                            timestamp = match['timestamp'][:19]
                            print(f"{i}. [{timestamp}] {match['user_input']}")
                            print(f"   Result: {match['result']}")
                        print()
                    else:
                        print("❌ No matches found in memory")
                        print()
                else:
                    print("❌ Please specify search term: search <term>")
                continue
            
            # Process calculation with session context
            print(f"🔍 Processing with session context: {user_input}")
            result = client.calculate_with_session(user_input)
            
            if result.get('success', False):
                print(f"✅ Result: {result['result']}")
                if result.get('context_used'):
                    print(f"📝 Context: {result['context_used']}")
            else:
                print(f"❌ Error: {result.get('error', 'Unknown error')}")
            print()
            
        except KeyboardInterrupt:
            print("\n👋 Goodbye! Session data preserved for this runtime.")
            break
        except Exception as e:
            print(f"❌ Error: {e}")

if __name__ == "__main__":
    main()