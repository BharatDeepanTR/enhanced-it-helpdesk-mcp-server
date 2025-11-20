#!/usr/bin/env python3
"""
Fixed Enhanced Calculator Session MCP Client 
Points to the correct calculator gateway with working target
"""

import json
import boto3
import requests
import uuid
from datetime import datetime
from requests_aws4auth import AWS4Auth
from typing import Dict, List, Any, Optional

class FixedCalculatorSessionClient:
    def __init__(self):
        # FIXED: Use the correct calculator gateway URL
        # This should be the gateway that has the working calculator target
        self.gateway_url = "https://a208194-askjulius-agentcore-gateway-mcp-iam-fvro4phd59.gateway.bedrock-agentcore.us-east-1.amazonaws.com/mcp"
        self.region = "us-east-1"
        
        # Session management
        self.session_id = f"calc-session-{datetime.now().strftime('%Y%m%d-%H%M%S')}-{uuid.uuid4().hex[:8]}"
        self.actor_id = f"user-{uuid.uuid4().hex[:8]}"
        self.short_memory_limit = 10
        self.session_memory = []
        
        # FIXED: Force the correct calculator tool name
        self.calculator_tool_name = "target-calculator___calculate"
        
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
        
        print(f"🚀 Fixed Calculator Session MCP Client")
        print("=" * 60)
        print(f"🔧 Calculator Session Client Initialized")
        print(f"📋 Session ID: {self.session_id}")
        print(f"👤 Actor ID: {self.actor_id}")
        print(f"🧠 Gateway Memory: Enabled")
        print(f"💾 Short Memory Limit: {self.short_memory_limit} interactions")
        print(f"🎯 Target Tool: {self.calculator_tool_name}")
        
        # Test gateway connection
        self._test_connection()

    def _test_connection(self):
        """Test gateway connection and tool availability"""
        try:
            print(f"\n🔍 Testing gateway connection...")
            
            # List available tools
            list_request = {
                "jsonrpc": "2.0",
                "id": 1,
                "method": "tools/list"
            }
            
            response = requests.post(
                self.gateway_url,
                json=list_request,
                auth=self.auth,
                headers={'Content-Type': 'application/json'},
                timeout=10
            )
            
            if response.status_code == 200:
                result = response.json()
                if 'result' in result and 'tools' in result['result']:
                    tools = result['result']['tools']
                    print(f"✅ Gateway connection successful")
                    print(f"📋 Available tools: {[tool.get('name', 'Unknown') for tool in tools]}")
                    
                    # Check if our expected calculator tool is available
                    tool_names = [tool.get('name', '') for tool in tools]
                    if self.calculator_tool_name in tool_names:
                        print(f"✅ Calculator tool found: {self.calculator_tool_name}")
                    else:
                        print(f"⚠️ Calculator tool not found. Available: {tool_names}")
                        # Use the first available tool as fallback
                        if tools:
                            self.calculator_tool_name = tools[0]['name']
                            print(f"📋 Using fallback tool: {self.calculator_tool_name}")
                    
                    print(f"✅ Ready for calculations with session memory!")
                    return True
                else:
                    print(f"⚠️ No tools found in gateway response")
            else:
                print(f"❌ Gateway connection failed: {response.status_code}")
                print(f"Response: {response.text}")
            
            return False
            
        except Exception as e:
            print(f"❌ Connection test failed: {e}")
            return False

    def calculate_with_session(self, expression: str) -> Dict[str, Any]:
        """
        Perform calculation with session context and memory
        """
        try:
            print(f"🔍 Processing with session context: {expression}")
            
            # Prepare session-aware request
            request_data = {
                "jsonrpc": "2.0",
                "id": 2,
                "method": "tools/call",
                "params": {
                    "name": self.calculator_tool_name,
                    "arguments": {
                        "expression": expression
                    }
                },
                # Add session context
                "meta": {
                    "sessionId": self.session_id,
                    "actorId": self.actor_id,
                    "timestamp": datetime.now().isoformat()
                }
            }
            
            response = requests.post(
                self.gateway_url,
                json=request_data,
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
                
                if 'result' in result:
                    if result['result'].get('isError', False):
                        # Handle error response
                        content = result['result'].get('content', [])\n                        error_text = \"Unknown error\"\n                        for item in content:\n                            if item.get('type') == 'text':\n                                error_text = item.get('text', 'Unknown error')\n                                break\n                        \n                        print(f\"❌ Error: {error_text}\")\n                        self.add_to_memory(expression, f\"Error: {error_text}\", \"error\")\n                        \n                        return {\n                            \"success\": False,\n                            \"error\": error_text,\n                            \"session_id\": self.session_id\n                        }\n                    else:\n                        # Handle successful response\n                        content = result['result'].get('content', [])\n                        result_text = \"No result\"\n                        for item in content:\n                            if item.get('type') == 'text':\n                                result_text = item.get('text', 'No result')\n                                break\n                        \n                        print(f\"✅ Result: {result_text}\")\n                        self.add_to_memory(expression, result_text, \"calculation\")\n                        \n                        return {\n                            \"success\": True,\n                            \"result\": result_text,\n                            \"session_id\": self.session_id\n                        }\n                else:\n                    print(f\"❌ Invalid response format\")\n                    return {\n                        \"success\": False,\n                        \"error\": \"Invalid response format\",\n                        \"session_id\": self.session_id\n                    }\n            else:\n                error_msg = f\"HTTP {response.status_code}: {response.text}\"\n                print(f\"❌ Error: {error_msg}\")\n                return {\n                    \"success\": False,\n                    \"error\": error_msg,\n                    \"session_id\": self.session_id\n                }\n                \n        except Exception as e:\n            error_msg = f\"Exception: {str(e)}\"\n            print(f\"❌ Error: {error_msg}\")\n            return {\n                \"success\": False,\n                \"error\": error_msg,\n                \"session_id\": self.session_id\n            }\n\n    def add_to_memory(self, user_input: str, result: str, operation_type: str = \"calculation\"):\n        \"\"\"Add interaction to session memory\"\"\"\n        interaction = {\n            \"timestamp\": datetime.now().isoformat(),\n            \"user_input\": user_input,\n            \"result\": result,\n            \"operation_type\": operation_type,\n            \"session_id\": self.session_id,\n            \"actor_id\": self.actor_id\n        }\n        \n        self.session_memory.append(interaction)\n        \n        # Keep only recent interactions (short memory)\n        if len(self.session_memory) > self.short_memory_limit:\n            self.session_memory = self.session_memory[-self.short_memory_limit:]\n\n    def search_memory(self, search_term: str) -> List[Dict[str, Any]]:\n        \"\"\"Search session memory for specific terms\"\"\"\n        matches = []\n        search_lower = search_term.lower()\n        \n        for interaction in self.session_memory:\n            if (search_lower in interaction['user_input'].lower() or \n                search_lower in interaction['result'].lower()):\n                matches.append(interaction)\n        \n        return matches\n\n    def show_memory(self):\n        \"\"\"Display current session memory\"\"\"\n        print(f\"\\n🧠 Session Memory (Session: {self.session_id})\")\n        print(f\"👤 Actor: {self.actor_id}\")\n        print(\"=\" * 60)\n        \n        if not self.session_memory:\n            print(\"📋 No interactions in current session\")\n            return\n        \n        for i, interaction in enumerate(self.session_memory, 1):\n            timestamp = interaction['timestamp'][:19]  # Remove microseconds\n            print(f\"\\n{i}. [{timestamp}] {interaction['operation_type'].upper()}\")\n            print(f\"   👤 Input: {interaction['user_input']}\")\n            print(f\"   💡 Result: {interaction['result']}\")\n\n    def show_session_info(self):\n        \"\"\"Display current session information\"\"\"\n        print(f\"\\n📋 Session Information\")\n        print(\"=\" * 30)\n        print(f\"🆔 Session ID: {self.session_id}\")\n        print(f\"👤 Actor ID: {self.actor_id}\")\n        print(f\"🌐 Gateway URL: {self.gateway_url}\")\n        print(f\"🎯 Target Tool: {self.calculator_tool_name}\")\n        print(f\"🧠 Memory Entries: {len(self.session_memory)}/{self.short_memory_limit}\")\n        print(f\"⏰ Session Start: {self.session_id.split('-')[2:4]}\")\n\ndef main():\n    \"\"\"Enhanced calculator interface with session memory\"\"\"\n    try:\n        client = FixedCalculatorSessionClient()\n        \n        if not client._test_connection():\n            print(\"❌ Cannot connect to gateway. Exiting.\")\n            return\n        \n        print(\"\\nType mathematical expressions or special commands:\")\n        print(\"📋 Special commands: 'memory', 'search <term>', 'session', 'help', 'exit'\")\n        \n        while True:\n            try:\n                user_input = input(\"\\nFixedCalc> \").strip()\n                \n                if not user_input:\n                    continue\n                    \n                # Handle special commands\n                if user_input.lower() == 'exit':\n                    print(\"👋 Goodbye!\")\n                    break\n                    \n                elif user_input.lower() == 'help':\n                    print(\"\\n📚 Available Commands:\")\n                    print(\"  • Mathematical expressions: '2 + 3 * 4', 'sin(30)', 'sqrt(16)'\")\n                    print(\"  • memory - Show session memory\")\n                    print(\"  • search <term> - Search memory for specific term\")\n                    print(\"  • session - Show session information\")\n                    print(\"  • help - Show this help\")\n                    print(\"  • exit - Quit the calculator\")\n                    continue\n                    \n                elif user_input.lower() == 'memory':\n                    client.show_memory()\n                    continue\n                    \n                elif user_input.lower() == 'session':\n                    client.show_session_info()\n                    continue\n                    \n                elif user_input.lower().startswith('search '):\n                    search_term = user_input[7:].strip()\n                    print(f\"\\n🔍 Searching memory for: '{search_term}'\")\n                    print(\"=\" * 50)\n                    \n                    matches = client.search_memory(search_term)\n                    if matches:\n                        for i, match in enumerate(matches, 1):\n                            timestamp = match['timestamp'][:19]\n                            print(f\"\\n{i}. [{timestamp}]\")\n                            print(f\"   👤 Input: {match['user_input']}\")\n                            print(f\"   💡 Result: {match['result']}\")\n                    else:\n                        print(\"❌ No matches found in memory\")\n                    continue\n                \n                # Process calculation\n                result = client.calculate_with_session(user_input)\n                \n                # Result is already printed by calculate_with_session method\n                \n            except KeyboardInterrupt:\n                print(\"\\n\\n👋 Exiting...\")\n                break\n            except Exception as e:\n                print(f\"❌ Error processing input: {e}\")\n    \n    except Exception as e:\n        print(f\"❌ Failed to initialize client: {e}\")\n\nif __name__ == \"__main__\":\n    main()