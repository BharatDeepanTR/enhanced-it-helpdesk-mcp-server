#!/usr/bin/env python3
"""
Enhanced IT Helpdesk MCP Client
Interacts with the a208194-it-helpdesk-enhanced-mcp-server Lambda function
"""

import json
import boto3
import uuid
from datetime import datetime
from typing import Dict, Any, Optional
import argparse
import sys

class MCPClient:
    """Model Context Protocol client for IT Helpdesk server"""
    
    def __init__(self, function_name: str = "a208194-it-helpdesk-enhanced-mcp-server", region: str = "us-east-1"):
        self.function_name = function_name
        self.region = region
        self.lambda_client = boto3.client('lambda', region_name=region)
        self.session_id = str(uuid.uuid4())
        print(f"🔗 MCP Client initialized")
        print(f"   Function: {self.function_name}")
        print(f"   Region: {self.region}")
        print(f"   Session ID: {self.session_id}")
        print()
    
    def invoke_lambda(self, payload: Dict[str, Any]) -> Dict[str, Any]:
        """Invoke the Lambda function with MCP payload"""
        try:
            response = self.lambda_client.invoke(
                FunctionName=self.function_name,
                InvocationType='RequestResponse',
                Payload=json.dumps(payload)
            )
            
            # Read and parse response
            response_payload = response['Payload'].read()
            result = json.loads(response_payload)
            
            return result
            
        except Exception as e:
            return {
                "error": f"Lambda invocation failed: {str(e)}",
                "success": False
            }
    
    def list_tools(self) -> Dict[str, Any]:
        """Get list of available MCP tools"""
        payload = {
            "method": "tools/list",
            "params": {},
            "jsonrpc": "2.0",
            "id": str(uuid.uuid4())
        }
        
        print("🔍 Requesting tools list...")
        return self.invoke_lambda(payload)
    
    def call_tool(self, tool_name: str, arguments: Dict[str, Any]) -> Dict[str, Any]:
        """Call a specific MCP tool"""
        payload = {
            "method": "tools/call",
            "params": {
                "name": tool_name,
                "arguments": arguments
            },
            "jsonrpc": "2.0",
            "id": str(uuid.uuid4())
        }
        
        print(f"🛠️  Calling tool: {tool_name}")
        print(f"   Arguments: {json.dumps(arguments, indent=2)}")
        return self.invoke_lambda(payload)
    
    def enhanced_ai_response(self, question: str) -> Dict[str, Any]:
        """Get enhanced AI response for IT support question"""
        return self.call_tool("enhanced_search_it_support", {
            "question": question,
            "session_id": self.session_id
        })
    
    def session_memory(self, action: str, **kwargs) -> Dict[str, Any]:
        """Interact with session memory"""
        args = {"action": action, "session_id": self.session_id}
        args.update(kwargs)
        return self.call_tool("session_memory", args)
    
    def route_dns_troubleshoot(self, domain: str, issue_type: str = "resolution") -> Dict[str, Any]:
        """Troubleshoot DNS issues"""
        return self.call_tool("route_dns_troubleshoot", {
            "domain": domain,
            "issue_type": issue_type
        })
    
    def network_connectivity_check(self, target: str, check_type: str = "ping") -> Dict[str, Any]:
        """Check network connectivity"""
        return self.call_tool("network_connectivity_check", {
            "target": target,
            "check_type": check_type
        })
    
    def interactive_session(self):
        """Start an enhanced interactive session with the MCP server"""
        print("🚀 Thomson Reuters IT Helpdesk - AI-Powered Support")
        print("=" * 60)
        print("🤖 Enhanced with Claude Sonnet AI | 💾 Session Memory Enabled")
        print(f"📋 Session ID: {self.session_id}")
        print("=" * 60)
        
        while True:
            try:
                self.show_main_menu()
                choice = input("\n🎯 Select an option (1-9, or 'q' to quit): ").strip().lower()
                
                if choice in ['q', 'quit', 'exit']:
                    print("\n👋 Thank you for using TR IT Helpdesk! Have a great day!")
                    break
                
                if choice == '1':
                    self.handle_quick_help()
                elif choice == '2':
                    self.handle_password_issues()
                elif choice == '3':
                    self.handle_cloud_access()
                elif choice == '4':
                    self.handle_network_issues()
                elif choice == '5':
                    self.handle_email_support()
                elif choice == '6':
                    self.handle_software_help()
                elif choice == '7':
                    self.handle_custom_query()
                elif choice == '8':
                    self.show_session_info()
                elif choice == '9':
                    self.show_available_tools()
                elif choice == 'help':
                    self.show_help()
                else:
                    print("❌ Invalid option. Please try again.")
                
                input("\nPress Enter to continue...")
                
            except KeyboardInterrupt:
                print("\n\n👋 Session interrupted. Goodbye!")
                break
            except Exception as e:
                print(f"❌ Error: {str(e)}")
                input("Press Enter to continue...")
    
    def show_main_menu(self):
        """Display the main menu with categories"""
        print("\n" + "="*60)
        print("🔧 THOMSON REUTERS IT HELPDESK - MAIN MENU")
        print("="*60)
        print("📞 QUICK SUPPORT:")
        print("   1️⃣  Quick Help & Search        🔍 Ask any IT question")
        print()
        print("🔐 AUTHENTICATION & ACCESS:")
        print("   2️⃣  Password & Login Issues    🔑 Resets, TEN domain, M accounts")
        print("   3️⃣  Cloud & AWS Access        ☁️  Cloud tools, AWS accounts")
        print()
        print("🌐 CONNECTIVITY & COMMUNICATION:")
        print("   4️⃣  Network & VPN Issues      🌐 VPN, connectivity, DNS")
        print("   5️⃣  Email & Outlook Support   📧 Outlook, Exchange, email issues")
        print()
        print("💻 SOFTWARE & TOOLS:")
        print("   6️⃣  Software Installation     📦 Apps, licensing, installation")
        print()
        print("🛠️  ADVANCED OPTIONS:")
        print("   7️⃣  Custom IT Query           💬 Ask anything (AI-enhanced)")
        print("   8️⃣  Session Information       📊 Memory, preferences, history")
        print("   9️⃣  Available Tools           🔧 List all MCP tools")
        print()
        print("❓ Type 'help' for tips | 'q' to quit")
    
    def handle_quick_help(self):
        """Handle quick help and search"""
        print("\n🔍 QUICK HELP & AI-POWERED SEARCH")
        print("="*50)
        print("Ask me anything about IT support! I'll provide:")
        print("• 🤖 AI-enhanced technical solutions")
        print("• 📋 Step-by-step instructions")
        print("• 🔗 Relevant Thomson Reuters resources")
        print("• 💾 Remember your preferences for future sessions")
        print()
        
        question = input("💬 What IT issue can I help you with? ").strip()
        if question:
            print("\n🤖 Searching knowledge base and enhancing with AI...")
            result = self.call_tool("enhanced_search_it_support", {
                "question": question,
                "session_id": self.session_id
            })
            self.print_formatted_result(result, "AI-Enhanced Search Results")
    
    def handle_password_issues(self):
        """Handle password and authentication issues"""
        print("\n🔑 PASSWORD & AUTHENTICATION SUPPORT")
        print("="*50)
        options = {
            '1': ('Reset TEN Domain Password', 'reset_password'),
            '2': ('M Account Access', 'check_m_account'),
            '3': ('Custom Authentication Query', 'custom')
        }
        
        print("Select your issue:")
        for key, (desc, _) in options.items():
            print(f"   {key}️⃣  {desc}")
        print("   🔙 Back to main menu")
        
        choice = input("\nSelect option (1-3 or 'back'): ").strip()
        
        if choice == 'back':
            return
        elif choice in options:
            desc, tool = options[choice]
            if tool == 'custom':
                query = input(f"💬 Describe your authentication issue: ").strip()
                if query:
                    result = self.call_tool("enhanced_search_it_support", {
                        "question": f"Authentication issue: {query}",
                        "session_id": self.session_id
                    })
                    self.print_formatted_result(result, f"Authentication Support: {desc}")
            else:
                query = input(f"💬 Describe your {desc.lower()} issue (optional): ").strip()
                result = self.call_tool(tool, {
                    "query": query or f"Help with {desc.lower()}",
                    "session_id": self.session_id
                })
                self.print_formatted_result(result, f"Password Support: {desc}")
    
    def handle_cloud_access(self):
        """Handle cloud and AWS access issues"""
        print("\n☁️  CLOUD & AWS ACCESS SUPPORT")
        print("="*50)
        options = {
            '1': ('Cloud Tools Access', 'cloud_tool_access'),
            '2': ('AWS Account Access', 'aws_access'),
            '3': ('Custom Cloud Query', 'custom')
        }
        
        print("Select your issue:")
        for key, (desc, _) in options.items():
            print(f"   {key}️⃣  {desc}")
        print("   🔙 Back to main menu")
        
        choice = input("\nSelect option (1-3 or 'back'): ").strip()
        
        if choice == 'back':
            return
        elif choice in options:
            desc, tool = options[choice]
            if tool == 'custom':
                query = input(f"💬 Describe your cloud access issue: ").strip()
                if query:
                    result = self.call_tool("enhanced_search_it_support", {
                        "question": f"Cloud access: {query}",
                        "session_id": self.session_id
                    })
                    self.print_formatted_result(result, f"Cloud Support: {desc}")
            else:
                query = input(f"💬 Describe your {desc.lower()} issue (optional): ").strip()
                result = self.call_tool(tool, {
                    "query": query or f"Help with {desc.lower()}",
                    "session_id": self.session_id
                })
                self.print_formatted_result(result, f"Cloud Support: {desc}")
    
    def handle_network_issues(self):
        """Handle network and connectivity issues"""
        print("\n🌐 NETWORK & CONNECTIVITY SUPPORT")
        print("="*50)
        options = {
            '1': ('VPN Troubleshooting', 'vpn_troubleshooting'),
            '2': ('DNS Issues', 'dns'),
            '3': ('Network Connectivity Test', 'ping'),
            '4': ('Custom Network Query', 'custom')
        }
        
        print("Select your issue:")
        for key, (desc, _) in options.items():
            print(f"   {key}️⃣  {desc}")
        print("   🔙 Back to main menu")
        
        choice = input("\nSelect option (1-4 or 'back'): ").strip()
        
        if choice == 'back':
            return
        elif choice == '1':
            query = input("💬 Describe your VPN issue (optional): ").strip()
            result = self.call_tool("vpn_troubleshooting", {
                "query": query or "VPN troubleshooting help",
                "session_id": self.session_id
            })
            self.print_formatted_result(result, "VPN Support")
        elif choice == '2':
            domain = input("💬 Enter domain to troubleshoot (or general DNS help): ").strip()
            if domain and not domain.lower().startswith('general'):
                result = self.route_dns_troubleshoot(domain)
            else:
                result = self.call_tool("enhanced_search_it_support", {
                    "question": "DNS troubleshooting help",
                    "session_id": self.session_id
                })
            self.print_formatted_result(result, "DNS Support")
        elif choice == '3':
            target = input("💬 Enter target to test connectivity to: ").strip()
            if target:
                result = self.network_connectivity_check(target)
                self.print_formatted_result(result, "Connectivity Test")
        elif choice == '4':
            query = input("💬 Describe your network issue: ").strip()
            if query:
                result = self.call_tool("enhanced_search_it_support", {
                    "question": f"Network issue: {query}",
                    "session_id": self.session_id
                })
                self.print_formatted_result(result, "Network Support")
    
    def handle_email_support(self):
        """Handle email and Outlook support"""
        print("\n📧 EMAIL & OUTLOOK SUPPORT")
        print("="*50)
        query = input("💬 Describe your email/Outlook issue: ").strip()
        if query:
            result = self.call_tool("email_troubleshooting", {
                "query": query,
                "session_id": self.session_id
            })
            self.print_formatted_result(result, "Email Support")
    
    def handle_software_help(self):
        """Handle software installation and licensing"""
        print("\n💻 SOFTWARE INSTALLATION & LICENSING")
        print("="*50)
        query = input("💬 What software do you need help with? ").strip()
        if query:
            result = self.call_tool("software_installation", {
                "query": query,
                "session_id": self.session_id
            })
            self.print_formatted_result(result, "Software Support")
    
    def handle_custom_query(self):
        """Handle custom IT queries with AI enhancement"""
        print("\n💬 CUSTOM IT QUERY - AI ENHANCED")
        print("="*50)
        print("🤖 Ask me anything about IT! I'll provide:")
        print("   • Detailed technical solutions")
        print("   • Platform-specific commands (Windows/Mac/Linux)")
        print("   • Thomson Reuters specific guidance")
        print("   • Step-by-step troubleshooting")
        print()
        
        question = input("💬 What's your IT question? ").strip()
        if question:
            result = self.call_tool("enhanced_search_it_support", {
                "question": question,
                "session_id": self.session_id
            })
            self.print_formatted_result(result, "AI-Enhanced Custom Support")
    
    def show_session_info(self):
        """Show session information and memory"""
        print("\n📊 SESSION INFORMATION")
        print("="*50)
        print(f"Session ID: {self.session_id}")
        
        result = self.session_memory("get_summary")
        self.print_formatted_result(result, "Session Memory & Preferences")
    
    def show_available_tools(self):
        """Show all available MCP tools"""
        print("\n🔧 AVAILABLE MCP TOOLS")
        print("="*50)
        result = self.list_tools()
        self.print_formatted_result(result, "MCP Tools")
    
    def show_help(self):
        """Show help and tips"""
        print("\n❓ HELP & TIPS")
        print("="*50)
        print("🔍 SEARCH TIPS:")
        print("   • Be specific about your issue")
        print("   • Include error messages if any")
        print("   • Mention your operating system")
        print()
        print("🤖 AI FEATURES:")
        print("   • I learn your preferences over time")
        print("   • I provide platform-specific solutions")
        print("   • I remember our conversation context")
        print()
        print("⌨️  NAVIGATION:")
        print("   • Use numbers to select menu options")
        print("   • Type 'back' to return to previous menu")
        print("   • Type 'q' or 'quit' to exit")
        print("   • Press Ctrl+C to interrupt")
    
    def print_formatted_result(self, result: Dict[str, Any], title: str):
        """Enhanced result printing with better formatting"""
        print(f"\n{'='*60}")
        print(f"📋 {title.upper()}")
        print(f"{'='*60}")
        
        if isinstance(result, dict):
            if "error" in result:
                print(f"❌ Error: {result['error']}")
            elif "result" in result:
                if isinstance(result["result"], dict):
                    if "content" in result["result"]:
                        for item in result["result"]["content"]:
                            if item.get("type") == "text":
                                text = item.get("text", "")
                                # Add some formatting
                                formatted_text = self.format_response_text(text)
                                print(formatted_text)
                    else:
                        print(json.dumps(result["result"], indent=2))
                else:
                    print(result["result"])
                    
                # Show metadata if available
                if "metadata" in result.get("result", {}):
                    metadata = result["result"]["metadata"]
                    print(f"\n📊 Session: {metadata.get('session_id', 'Unknown')}")
                    if metadata.get("enhanced"):
                        print(f"🤖 AI Model: {metadata.get('ai_model', 'Claude')}")
            else:
                print(json.dumps(result, indent=2))
        else:
            print(str(result))
        
        print(f"{'='*60}")
    
    def format_response_text(self, text: str) -> str:
        """Format response text for better readability"""
        if not text:
            return text
        
        # Add some basic formatting improvements
        formatted = text.replace("**", "")  # Remove markdown bold
        formatted = formatted.replace("•", "  •")  # Indent bullet points
        
        # Add spacing around sections
        lines = formatted.split('\n')
        formatted_lines = []
        
        for line in lines:
            if line.strip().endswith(':') and len(line.strip()) < 50:
                # Section headers
                formatted_lines.append(f"\n🔸 {line.strip()}")
            elif line.strip().startswith('•'):
                # Bullet points
                formatted_lines.append(f"  {line.strip()}")
            elif line.strip().startswith('❌') or line.strip().startswith('✅'):
                # Status messages
                formatted_lines.append(f"\n{line.strip()}")
            else:
                formatted_lines.append(line)
        
        return '\n'.join(formatted_lines)
    
    def print_result(self, result: Dict[str, Any]):
        """Pretty print MCP result"""
        print()
        print("📋 Response:")
        print("-" * 30)
        
        if isinstance(result, dict):
            if "error" in result:
                print(f"❌ Error: {result['error']}")
            elif "result" in result:
                # MCP standard response
                result_data = result["result"]
                if isinstance(result_data, dict):
                    if "content" in result_data:
                        # Handle MCP content response
                        for item in result_data["content"]:
                            if item.get("type") == "text":
                                text = item.get("text", "")
                                # Clean up the text and format it nicely
                                if text.startswith("❌ Unknown IT support tool"):
                                    print(f"❌ Tool not found or incorrect tool name")
                                else:
                                    print(text)
                    elif "tools" in result_data:
                        # Handle tools list response
                        tools = result_data["tools"]
                        print(f"Available tools ({len(tools)}):")
                        for i, tool in enumerate(tools, 1):
                            print(f"  {i}. {tool['name']}")
                            print(f"     {tool['description']}")
                            
                        # Show capabilities if available
                        if "capabilities" in result_data:
                            print(f"\nCapabilities: {', '.join(result_data['capabilities'])}")
                            
                        # Show session info if available
                        if "session_info" in result_data:
                            session = result_data["session_info"]
                            print(f"Session: {session.get('session_id', 'unknown')}")
                            print(f"Enhanced AI: {'✅' if session.get('enhanced_ai') else '❌'}")
                            print(f"Context Memory: {'✅' if session.get('context_memory') else '❌'}")
                    else:
                        # Handle other responses
                        print(json.dumps(result_data, indent=2))
                else:
                    print(result_data)
            else:
                print(json.dumps(result, indent=2))
        else:
            print(str(result))
        print()

def main():
    parser = argparse.ArgumentParser(description="Thomson Reuters IT Helpdesk - AI-Enhanced MCP Client")
    parser.add_argument("--function", default="a208194-it-helpdesk-enhanced-mcp-server", 
                       help="Lambda function name")
    parser.add_argument("--region", default="us-east-1", 
                       help="AWS region")
    parser.add_argument("--interactive", "-i", action="store_true", default=True,
                       help="Start interactive session (default)")
    parser.add_argument("--tools", action="store_true",
                       help="List available tools only")
    parser.add_argument("--ask", type=str,
                       help="Ask a single question and exit")
    parser.add_argument("--test", action="store_true",
                       help="Run comprehensive test suite")
    
    args = parser.parse_args()
    
    # Initialize client
    client = MCPClient(function_name=args.function, region=args.region)
    
    if args.tools:
        result = client.list_tools()
        client.print_formatted_result(result, "Available MCP Tools")
    elif args.ask:
        result = client.call_tool("enhanced_search_it_support", {
            "question": args.ask,
            "session_id": client.session_id
        })
        client.print_formatted_result(result, "AI-Enhanced Response")
    elif args.test:
        # Run comprehensive test
        print("🧪 Running comprehensive MCP test suite...")
        print()
        
        # Test 1: List tools
        print("Test 1: Listing available tools")
        result = client.list_tools()
        client.print_formatted_result(result, "Tools List Test")
        
        # Test 2: Ask a question
        print("\nTest 2: Testing AI-enhanced search")
        result = client.call_tool("enhanced_search_it_support", {
            "question": "How do I reset my password?",
            "session_id": client.session_id
        })
        client.print_formatted_result(result, "AI Search Test")
        
        print("✅ Comprehensive test completed!")
    else:
        # Default: Start interactive session
        print("🎯 Starting interactive mode (use --help for other options)")
        print()
        client.interactive_session()

if __name__ == "__main__":
    main()