#!/usr/bin/env python3
"""
Enhanced MCP Client with Bedrock Agent Core Gateway Session Management
Utilizes Agent Core's built-in memory, session management, and actor tracking
"""

import json
import boto3
import requests
from requests_aws4auth import AWS4Auth
from datetime import datetime
import uuid
import re
from typing import Dict, Any, List, Optional

class EnhancedSessionMCPClient:
    """
    Enhanced MCP Client leveraging Bedrock Agent Core Gateway's:
    - Session Management
    - Actor ID tracking  
    - Short-term memory
    - Long-term memory
    - Context persistence
    """
    
    def __init__(self):
        # Gateway configuration
        self.gateway_url = "https://a208194-askjulius-agentcore-gateway-mcp-iam-fvro4phd59.gateway.bedrock-agentcore.us-east-1.amazonaws.com"
        self.mcp_url = f"{self.gateway_url}/mcp"
        self.region = "us-east-1"
        
        # Session management
        self.session_id = f"enhanced-session-{datetime.now().strftime('%Y%m%d-%H%M%S')}-{str(uuid.uuid4())[:8]}"
        self.actor_id = f"user-{str(uuid.uuid4())[:8]}"
        self.conversation_context = []
        
        # Memory configuration
        self.short_memory_limit = 10  # Last 10 interactions
        self.use_gateway_memory = True  # Use Agent Core's built-in memory
        
        # Initialize AWS session and authentication
        session = boto3.Session()
        credentials = session.get_credentials()
        self.auth = AWS4Auth(
            credentials.access_key,
            credentials.secret_key,
            self.region,
            'bedrock-agentcore',
            session_token=credentials.token
        )
        
        # Agent Core Gateway client for session management
        self.bedrock_agent = boto3.client('bedrock-agent-runtime', region_name=self.region)
        
        print(f"🔧 Enhanced Session MCP Client Initialized")
        print(f"📋 Session ID: {self.session_id}")
        print(f"👤 Actor ID: {self.actor_id}")
        print(f"🧠 Gateway Memory: {'Enabled' if self.use_gateway_memory else 'Disabled'}")
        print(f"💾 Short Memory Limit: {self.short_memory_limit} interactions")
        print()
        
        # Initialize session with gateway
        self._initialize_gateway_session()
    
    def _initialize_gateway_session(self):
        """Initialize session with Agent Core Gateway"""
        try:
            # Test gateway connectivity and session creation
            test_request = {
                "jsonrpc": "2.0",
                "id": 1,
                "method": "initialize",
                "params": {
                    "sessionId": self.session_id,
                    "actorId": self.actor_id,
                    "capabilities": {
                        "memory": True,
                        "context": True,
                        "tools": True
                    }
                }
            }
            
            headers = {
                'Content-Type': 'application/json',
                'X-Session-ID': self.session_id,
                'X-Actor-ID': self.actor_id
            }
            
            response = requests.post(
                self.mcp_url,
                json=test_request,
                auth=self.auth,
                headers=headers,
                timeout=30
            )
            
            if response.status_code == 200:
                print(f"✅ Gateway session initialized successfully")
            else:
                print(f"⚠️  Gateway session initialization returned: {response.status_code}")
                
        except Exception as e:
            print(f"⚠️  Gateway session initialization failed: {e}")
    
    def _add_to_memory(self, user_input: str, response: str, operation_type: str = "calculation"):
        """Add interaction to both local and gateway memory"""
        interaction = {
            "timestamp": datetime.now().isoformat(),
            "sessionId": self.session_id,
            "actorId": self.actor_id,
            "input": user_input,
            "output": response,
            "type": operation_type
        }
        
        # Local short-term memory
        self.conversation_context.append(interaction)
        if len(self.conversation_context) > self.short_memory_limit:
            self.conversation_context.pop(0)
        
        # Send to gateway memory if enabled
        if self.use_gateway_memory:
            self._store_in_gateway_memory(interaction)
    
    def _store_in_gateway_memory(self, interaction: Dict[str, Any]):
        """Store interaction in Agent Core Gateway's memory system"""
        try:
            memory_request = {
                "jsonrpc": "2.0",
                "id": f"mem-{datetime.now().timestamp()}",
                "method": "memory/store",
                "params": {
                    "sessionId": self.session_id,
                    "actorId": self.actor_id,
                    "memoryType": "short",  # or "long" for persistent memory
                    "content": interaction,
                    "tags": [interaction["type"], "calculation", "session"]
                }
            }
            
            headers = {
                'Content-Type': 'application/json',
                'X-Session-ID': self.session_id,
                'X-Actor-ID': self.actor_id
            }
            
            requests.post(
                self.mcp_url,
                json=memory_request,
                auth=self.auth,
                headers=headers,
                timeout=10
            )
            
        except Exception as e:
            print(f"⚠️  Memory storage failed: {e}")
    
    def _retrieve_from_gateway_memory(self, query: str) -> List[Dict[str, Any]]:
        """Retrieve relevant memories from Agent Core Gateway"""
        try:
            memory_request = {
                "jsonrpc": "2.0",
                "id": f"retrieve-{datetime.now().timestamp()}",
                "method": "memory/retrieve",
                "params": {
                    "sessionId": self.session_id,
                    "actorId": self.actor_id,
                    "query": query,
                    "limit": 5,
                    "memoryTypes": ["short", "long"]
                }
            }
            
            headers = {
                'Content-Type': 'application/json',
                'X-Session-ID': self.session_id,
                'X-Actor-ID': self.actor_id
            }
            
            response = requests.post(
                self.mcp_url,
                json=memory_request,
                auth=self.auth,
                headers=headers,
                timeout=10
            )
            
            if response.status_code == 200:
                result = response.json()
                if 'result' in result and 'memories' in result['result']:
                    return result['result']['memories']
            
        except Exception as e:
            print(f"⚠️  Memory retrieval failed: {e}")
        
        return []
    
    def _make_mcp_request_with_session(self, method: str, params: Dict[str, Any]) -> Dict[str, Any]:
        """Make MCP request with session context and memory"""
        request_id = f"{method}-{datetime.now().timestamp()}"
        
        # Add session context to params
        enhanced_params = {
            **params,
            "sessionContext": {
                "sessionId": self.session_id,
                "actorId": self.actor_id,
                "conversationHistory": self.conversation_context[-3:],  # Last 3 interactions
                "timestamp": datetime.now().isoformat()
            }
        }
        
        request_data = {
            "jsonrpc": "2.0",
            "id": request_id,
            "method": method,
            "params": enhanced_params
        }
        
        headers = {
            'Content-Type': 'application/json',
            'X-Session-ID': self.session_id,
            'X-Actor-ID': self.actor_id,
            'X-Request-Context': 'enhanced-session'
        }
        
        try:
            response = requests.post(
                self.mcp_url,
                json=request_data,
                auth=self.auth,
                headers=headers,
                timeout=30
            )
            
            if response.status_code == 200:
                return {
                    "success": True,
                    "response": response.json()
                }
            else:
                return {
                    "success": False,
                    "error": f"HTTP {response.status_code}: {response.text}"
                }
                
        except Exception as e:
            return {
                "success": False,
                "error": str(e)
            }
    
    def calculate(self, expression: str) -> Dict[str, Any]:
        """Perform calculation using calculator MCP server with session context"""
        print(f"🔍 Processing with session context: {expression}")
        
        # Check memory for similar calculations
        if self.use_gateway_memory:
            memories = self._retrieve_from_gateway_memory(expression)
            if memories:
                print(f"💭 Found {len(memories)} relevant memories")
        
        # Make calculation request
        tool_name = "target-calculator___calculate"
        params = {
            "name": tool_name,
            "arguments": {"expression": expression}
        }
        
        result = self._make_mcp_request_with_session("tools/call", params)
        
        if result["success"]:
            response_data = result["response"]
            if "result" in response_data:
                content = response_data["result"].get("content", [])
                if content and isinstance(content, list):
                    for item in content:
                        if item.get("type") == "text":
                            calc_result = item.get("text", "No result")
                            print(f"✅ Result: {calc_result}")
                            
                            # Store in memory
                            self._add_to_memory(expression, calc_result, "calculation")
                            
                            return {
                                "success": True,
                                "result": calc_result,
                                "sessionId": self.session_id
                            }
        
        error_msg = result.get("error", "Unknown error")
        print(f"❌ Error: {error_msg}")
        self._add_to_memory(expression, f"Error: {error_msg}", "error")
        
        return {
            "success": False,
            "error": error_msg,
            "sessionId": self.session_id
        }
    
    def show_memory(self) -> None:
        """Display current session memory"""
        print(f"\n🧠 Session Memory (Session: {self.session_id})")
        print(f"👤 Actor: {self.actor_id}")
        print("=" * 60)
        
        if not self.conversation_context:
            print("📋 No interactions in current session")
            return
        
        for i, interaction in enumerate(self.conversation_context, 1):
            timestamp = interaction["timestamp"]
            input_text = interaction["input"]
            output_text = interaction["output"]
            op_type = interaction["type"]
            
            print(f"{i}. [{timestamp[:19]}] ({op_type})")
            print(f"   Input:  {input_text}")
            print(f"   Output: {output_text}")
            print()
    
    def search_memory(self, query: str) -> None:
        """Search both local and gateway memory"""
        print(f"🔍 Searching memory for: '{query}'")
        print("=" * 50)
        
        # Search local memory
        local_matches = []
        for interaction in self.conversation_context:
            if query.lower() in interaction["input"].lower() or query.lower() in interaction["output"].lower():
                local_matches.append(interaction)
        
        if local_matches:
            print(f"📋 Local Memory ({len(local_matches)} matches):")
            for match in local_matches:
                print(f"   {match['timestamp'][:19]} - {match['input']} → {match['output']}")
        
        # Search gateway memory
        if self.use_gateway_memory:
            gateway_memories = self._retrieve_from_gateway_memory(query)
            if gateway_memories:
                print(f"\n🌐 Gateway Memory ({len(gateway_memories)} matches):")
                for memory in gateway_memories:
                    print(f"   {memory.get('timestamp', 'N/A')[:19]} - {memory.get('content', {}).get('input', 'N/A')}")
        
        if not local_matches and (not self.use_gateway_memory or not gateway_memories):
            print("❌ No matches found in memory")

def main():
    """Enhanced session-based natural language calculator"""
    print("🚀 Enhanced Session MCP Client with Agent Core Memory")
    print("=" * 70)
    
    try:
        client = EnhancedSessionMCPClient()
        
        print("\nType mathematical expressions or special commands:")
        print("📋 Special commands: 'memory', 'search <term>', 'session', 'help', 'exit'")
        print()
        
        while True:
            try:
                user_input = input("EnhancedMCP> ").strip()
                
                if not user_input:
                    continue
                
                if user_input.lower() == "exit":
                    print("👋 Goodbye!")
                    break
                
                elif user_input.lower() == "memory":
                    client.show_memory()
                
                elif user_input.lower().startswith("search "):
                    search_term = user_input[7:].strip()
                    client.search_memory(search_term)
                
                elif user_input.lower() == "session":
                    print(f"📋 Current Session: {client.session_id}")
                    print(f"👤 Actor ID: {client.actor_id}")
                    print(f"🧠 Memory Items: {len(client.conversation_context)}")
                    print(f"🌐 Gateway Memory: {'Enabled' if client.use_gateway_memory else 'Disabled'}")
                
                elif user_input.lower() == "help":
                    print("📋 Available commands:")
                    print("   memory       - Show conversation history")
                    print("   search <term> - Search memory for term")
                    print("   session      - Show session information")
                    print("   help         - Show this help")
                    print("   exit         - Exit the program")
                    print("\n🔢 Math examples:")
                    print("   2 + 3 * 4")
                    print("   sqrt(16) + 5")
                    print("   sin(30) + cos(60)")
                
                else:
                    # Mathematical calculation
                    result = client.calculate(user_input)
                
            except KeyboardInterrupt:
                print("\n👋 Goodbye!")
                break
            except Exception as e:
                print(f"❌ Error: {e}")
                
    except Exception as e:
        print(f"❌ Failed to initialize client: {e}")

if __name__ == "__main__":
    main()