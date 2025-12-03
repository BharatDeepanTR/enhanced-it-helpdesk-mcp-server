#!/usr/bin/env python3
"""
Enhanced Thomson Reuters IT Helpdesk MCP Client (Gateway Version)
Beautiful, informative interface with proper error handling and user experience
"""

import json
import requests
import uuid
from datetime import datetime
from typing import Dict, Any, Optional
import argparse
import sys
import textwrap
import os
from botocore.auth import SigV4Auth
from botocore.awsrequest import AWSRequest
import boto3

class MCPGatewayClient:
    """Model Context Protocol client for Thomson Reuters IT Helpdesk via AgentCore Gateway"""
    
    def __init__(self, gateway_url: str = "https://a208194-askjulius-agentcore-gateway-mcp-iam-fvro4phd59.gateway.bedrock-agentcore.us-east-1.amazonaws.com/mcp", region: str = "us-east-1"):
        self.gateway_url = gateway_url
        self.region = region
        self.session_id = str(uuid.uuid4())
        
        # Get AWS credentials for signing requests
        session = boto3.Session()
        self.credentials = session.get_credentials()
        
        # Color codes for beautiful terminal output
        self.COLORS = {
            'HEADER': '\033[95m',      # Magenta
            'SUCCESS': '\033[92m',     # Green  
            'INFO': '\033[94m',        # Blue
            'WARNING': '\033[93m',     # Yellow
            'ERROR': '\033[91m',       # Red
            'BOLD': '\033[1m',         # Bold
            'UNDERLINE': '\033[4m',    # Underline
            'RESET': '\033[0m'         # Reset
        }
        
        print(f"{self.COLORS['HEADER']}{self.COLORS['BOLD']}🔗 Thomson Reuters MCP Gateway Client Initialized{self.COLORS['RESET']}")
        print(f"{self.COLORS['INFO']}   🌐 Gateway URL: {self.gateway_url}{self.COLORS['RESET']}")
        print(f"{self.COLORS['INFO']}   📍 Region: {self.region}{self.COLORS['RESET']}")
        print(f"{self.COLORS['INFO']}   🆔 Session ID: {self.session_id}{self.COLORS['RESET']}")
        print()
    
    def _sign_request(self, method: str, url: str, headers: Dict[str, str], body: str) -> Dict[str, str]:
        """Sign HTTP request with AWS SigV4"""
        request = AWSRequest(method=method, url=url, data=body, headers=headers)
        SigV4Auth(self.credentials, "bedrock-agentcore", self.region).add_auth(request)
        return dict(request.headers)
    
    def invoke_gateway(self, payload: Dict[str, Any]) -> Dict[str, Any]:
        """Invoke the AgentCore Gateway with MCP payload"""
        try:
            # Prepare request
            body = json.dumps(payload)
            headers = {
                'Content-Type': 'application/json',
                'Accept': 'application/json'
            }
            
            # Sign the request with AWS credentials
            signed_headers = self._sign_request('POST', self.gateway_url, headers, body)
            
            # Make HTTP request to gateway
            response = requests.post(
                self.gateway_url,
                data=body,
                headers=signed_headers,
                timeout=120
            )
            
            # Parse response
            if response.status_code == 200:
                return response.json()
            else:
                return {
                    "error": f"Gateway returned status {response.status_code}: {response.text}",
                    "success": False
                }
            
        except Exception as e:
            return {
                "error": f"Gateway invocation failed: {str(e)}",
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
        
        print(f"{self.COLORS['INFO']}🔍 Requesting tools list...{self.COLORS['RESET']}")
        return self.invoke_gateway(payload)
    
    def call_tool(self, tool_name: str, arguments: Dict[str, Any]) -> Dict[str, Any]:
        """Call a specific MCP tool"""
        # Map simple tool names to gateway prefixed names (based on actual gateway tools list)
        tool_name_map = {
            "enhanced_search_it_support": "target-lambda-it-helpdesk-enhanced-mcp___it_support_search",
            "it_support_search": "target-lambda-it-helpdesk-enhanced-mcp___it_support_search",
            "reset_password": "target-lambda-it-helpdesk-enhanced-mcp___reset_password", 
            "aws_access": "target-lambda-it-helpdesk-enhanced-mcp___aws_access",
            # Map enhanced_ai_response to the main IT support tool
            "enhanced_ai_response": "target-lambda-it-helpdesk-enhanced-mcp___it_support_search"
        }
        
        # Use mapped name if available, otherwise use original
        actual_tool_name = tool_name_map.get(tool_name, tool_name)
        
        payload = {
            "method": "tools/call",
            "params": {
                "name": actual_tool_name,
                "arguments": arguments
            },
            "jsonrpc": "2.0",
            "id": str(uuid.uuid4())
        }
        
        print(f"{self.COLORS['INFO']}🛠️  Calling tool: {tool_name}{self.COLORS['RESET']}")
        print(f"{self.COLORS['INFO']}   Gateway tool name: {actual_tool_name}{self.COLORS['RESET']}")
        print(f"{self.COLORS['INFO']}   Arguments: {json.dumps(arguments, indent=2)}{self.COLORS['RESET']}")
        return self.invoke_gateway(payload)

    def print_response(self, response: Dict[str, Any], title: str = "Response"):
        """Beautiful, clear response formatting with enhanced visual design"""
        
        # Beautiful header with Thomson Reuters branding
        print(f"\n{self.COLORS['HEADER']}{self.COLORS['BOLD']}{'='*100}{self.COLORS['RESET']}")
        print(f"{self.COLORS['HEADER']}{self.COLORS['BOLD']}🏢 THOMSON REUTERS - Enhanced IT Helpdesk Response{self.COLORS['RESET']}")
        print(f"{self.COLORS['INFO']}{self.COLORS['BOLD']}📋 {title}{self.COLORS['RESET']}")
        print(f"{self.COLORS['HEADER']}{self.COLORS['BOLD']}{'='*100}{self.COLORS['RESET']}\n")
        
        if "error" in response:
            print(f"{self.COLORS['ERROR']}{self.COLORS['BOLD']}❌ ERROR:{self.COLORS['RESET']}")
            print(f"{self.COLORS['ERROR']}   {response['error']}{self.COLORS['RESET']}")
            print(f"\n{self.COLORS['WARNING']}💡 Need Help?{self.COLORS['RESET']}")
            print(f"{self.COLORS['INFO']}   📞 Thomson Reuters Global Service Desk: +1-855-888-8899{self.COLORS['RESET']}")
            print(f"{self.COLORS['INFO']}   🌐 ServiceNow Portal: https://thomsonreuters.service-now.com{self.COLORS['RESET']}")
            return
        
        if "result" in response:
            result = response["result"]
            
            # Handle different result types with beautiful formatting
            if isinstance(result, dict):
                if "content" in result:
                    for content_item in result["content"]:
                        if content_item.get("type") == "text":
                            text = content_item.get("text", "")
                            # Format the text with proper styling
                            formatted_text = self._format_help_text(text)
                            print(formatted_text)
                            
                elif "tools" in result:
                    print(f"{self.COLORS['SUCCESS']}{self.COLORS['BOLD']}✅ Available Tools: {len(result['tools'])}{self.COLORS['RESET']}\n")
                    
                    for idx, tool in enumerate(result['tools'], 1):
                        tool_name = tool.get('name', 'Unknown')
                        description = tool.get('description', 'No description available')
                        
                        # Beautiful tool display
                        print(f"{self.COLORS['BOLD']}{idx:2d}. {self.COLORS['INFO']}{tool_name}{self.COLORS['RESET']}")
                        
                        # Wrap long descriptions
                        wrapped_desc = textwrap.fill(description, width=90, initial_indent="     ", subsequent_indent="     ")
                        print(f"{self.COLORS['INFO']}{wrapped_desc}{self.COLORS['RESET']}")
                        
                        # Show parameters if available
                        if 'inputSchema' in tool and 'properties' in tool['inputSchema']:
                            params = list(tool['inputSchema']['properties'].keys())
                            print(f"     {self.COLORS['WARNING']}📝 Parameters: {', '.join(params)}{self.COLORS['RESET']}")
                        print()
                        
                else:
                    formatted_result = json.dumps(result, indent=2)
                    print(f"{self.COLORS['INFO']}{formatted_result}{self.COLORS['RESET']}")
            else:
                print(f"{self.COLORS['INFO']}{result}{self.COLORS['RESET']}")
                
            # Show session information if available
            if "session_info" in result:
                session_info = result["session_info"]
                print(f"\n{self.COLORS['HEADER']}{self.COLORS['BOLD']}📊 Session Information:{self.COLORS['RESET']}")
                print(f"{self.COLORS['INFO']}   🆔 Session ID: {session_info.get('session_id', 'N/A')}{self.COLORS['RESET']}")
                print(f"{self.COLORS['INFO']}   🤖 AI Enhanced: {session_info.get('enhanced_ai', False)}{self.COLORS['RESET']}")
                print(f"{self.COLORS['INFO']}   🌐 Gateway Compatible: {session_info.get('gateway_compatible', False)}{self.COLORS['RESET']}")
        else:
            formatted_response = json.dumps(response, indent=2)
            print(f"{self.COLORS['INFO']}{formatted_response}{self.COLORS['RESET']}")
        
        # Beautiful footer with Thomson Reuters contact info
        print(f"\n{self.COLORS['HEADER']}{self.COLORS['BOLD']}{'─'*100}{self.COLORS['RESET']}")
        print(f"{self.COLORS['BOLD']}📞 Support: {self.COLORS['SUCCESS']}+1-855-888-8899{self.COLORS['RESET']} | "
              f"{self.COLORS['BOLD']}🌐 Portal: {self.COLORS['INFO']}https://thomsonreuters.service-now.com{self.COLORS['RESET']}")
        print(f"{self.COLORS['HEADER']}{self.COLORS['BOLD']}{'='*100}{self.COLORS['RESET']}\n")

    def _format_help_text(self, text: str) -> str:
        """Format help text with beautiful styling and proper structure"""
        import re
        
        lines = text.split('\n')
        formatted_lines = []
        
        for line in lines:
            line = line.strip()
            if not line:
                formatted_lines.append("")
                continue
                
            # Headers with **text**
            if line.startswith('**') and line.endswith('**'):
                header = line.strip('*')
                formatted_lines.append(f"{self.COLORS['BOLD']}{self.COLORS['HEADER']}{header}{self.COLORS['RESET']}")
                
            # URLs and links
            elif 'http' in line or line.startswith('🌐'):
                formatted_lines.append(f"{self.COLORS['INFO']}{self.COLORS['UNDERLINE']}{line}{self.COLORS['RESET']}")
                
            # Phone numbers and contact info
            elif '📞' in line or '+1-' in line:
                formatted_lines.append(f"{self.COLORS['SUCCESS']}{self.COLORS['BOLD']}{line}{self.COLORS['RESET']}")
                
            # Warning or important info
            elif line.startswith('⚠️') or line.startswith('💡') or line.startswith('🔒'):
                formatted_lines.append(f"{self.COLORS['WARNING']}{self.COLORS['BOLD']}{line}{self.COLORS['RESET']}")
                
            # Steps or numbered lists
            elif re.match(r'^\d+\.', line.strip()) or line.strip().startswith('- '):
                formatted_lines.append(f"   {self.COLORS['INFO']}{line}{self.COLORS['RESET']}")
                
            # Success indicators
            elif '✅' in line or line.startswith('✓'):
                formatted_lines.append(f"{self.COLORS['SUCCESS']}{line}{self.COLORS['RESET']}")
                
            # Error indicators  
            elif '❌' in line or line.startswith('✗'):
                formatted_lines.append(f"{self.COLORS['ERROR']}{line}{self.COLORS['RESET']}")
                
            # Regular text with proper indentation
            else:
                formatted_lines.append(f"{self.COLORS['INFO']}{line}{self.COLORS['RESET']}")
        
        return '\n'.join(formatted_lines)


def interactive_menu():
    """Beautiful, informative interactive menu for testing MCP tools"""
    
    def clear_screen():
        os.system('clear' if os.name == 'posix' else 'cls')
    
    def print_header():
        COLORS = {
            'HEADER': '\033[95m', 'SUCCESS': '\033[92m', 'INFO': '\033[94m', 
            'WARNING': '\033[93m', 'ERROR': '\033[91m', 'BOLD': '\033[1m', 
            'UNDERLINE': '\033[4m', 'RESET': '\033[0m'
        }
        
        print(f"{COLORS['HEADER']}{COLORS['BOLD']}")
        print("╔══════════════════════════════════════════════════════════════════════════════════════════════════╗")
        print("║                                                                                                  ║")
        print("║                       🏢 THOMSON REUTERS - Enhanced IT Helpdesk                                 ║")
        print("║                              🤖 AI-Powered Support System                                       ║")  
        print("║                                                                                                  ║")
        print("╚══════════════════════════════════════════════════════════════════════════════════════════════════╝")
        print(f"{COLORS['RESET']}")
        print(f"{COLORS['INFO']}🌐 Gateway: AgentCore MCP Protocol | 🔒 Secure: AWS IAM Authentication{COLORS['RESET']}")
        print(f"{COLORS['SUCCESS']}✅ Status: Production Ready | 🚀 Enhanced with Claude AI{COLORS['RESET']}\n")
        return COLORS
    
    def print_menu(colors):
        print(f"{colors['BOLD']}{colors['HEADER']}📋 Available IT Support Services:{colors['RESET']}")
        print(f"{colors['BOLD']}{'─'*100}{colors['RESET']}")
        
        menu_items = [
            ("1", "🛠️  List All Available Tools", "View all MCP tools and their descriptions"),
            ("2", "🤖 AI-Enhanced IT Support", "Ask any IT question with Claude AI assistance"),
            ("3", "🌐 DNS Troubleshooting", "Network connectivity and domain resolution"),
            ("4", "🔐 Reset Password", "Windows, email, and VPN password reset"),
            ("5", "☁️  AWS Cloud Access Request", "AWS console and service access"),
            ("6", "🔒 VPN Troubleshooting", "Remote access and connectivity issues"),
            ("7", "📧 Email & Outlook Support", "Exchange, calendar, and email issues"),
            ("8", "🌐 SharePoint Resources", "Digital Accessibility and TR portals"),
            ("0", "🚪 Exit Application", "Close the IT Helpdesk client")
        ]
        
        for num, title, desc in menu_items:
            if num == "0":
                print(f"\n{colors['WARNING']}{colors['BOLD']}{num:>3}. {title:<30}{colors['RESET']}")
            else:
                print(f"{colors['INFO']}{colors['BOLD']}{num:>3}. {title:<30}{colors['RESET']} {colors['INFO']}{desc}{colors['RESET']}")
        
        print(f"\n{colors['BOLD']}{'─'*100}{colors['RESET']}")
        print(f"{colors['SUCCESS']}📞 Global Service Desk: +1-855-888-8899 | 🌐 ServiceNow: thomsonreuters.service-now.com{colors['RESET']}")
        print(f"{colors['BOLD']}{'─'*100}{colors['RESET']}")
    
    # Initialize client
    client = MCPGatewayClient()
    
    while True:
        clear_screen()
        colors = print_header()
        print_menu(colors)
        
        choice = input(f"\n{colors['WARNING']}{colors['BOLD']}🎯 Enter your choice (0-8): {colors['RESET']}").strip()
        
        if choice == "0":
            clear_screen()
            print(f"\n{colors['SUCCESS']}{colors['BOLD']}")
            print("╔══════════════════════════════════════════════════════════════════════════════════════════════════╗")
            print("║                          👋 Thank you for using Thomson Reuters                                  ║")
            print("║                              Enhanced IT Helpdesk System                                        ║")  
            print("║                     For future support, contact Global Service Desk                             ║")
            print("║                            📞 +1-855-888-8899 (24/7 Support)                                    ║")
            print("╚══════════════════════════════════════════════════════════════════════════════════════════════════╝")
            print(f"{colors['RESET']}\n")
            break
        
        elif choice == "1":
            print(f"\n{colors['SUCCESS']}✅ Retrieving all available MCP tools...{colors['RESET']}")
            response = client.list_tools()
            client.print_response(response, "Available MCP Tools")
        
        elif choice == "2":
            question = input(f"\n{colors['INFO']}{colors['BOLD']}💬 Enter your IT support question: {colors['RESET']}").strip()
            if question:
                print(f"{colors['SUCCESS']}✅ Processing your question with AI enhancement...{colors['RESET']}")
                response = client.call_tool("enhanced_ai_response", {"question": question, "session_id": client.session_id})
                client.print_response(response, "AI-Enhanced Support Response")
            else:
                print(f"{colors['ERROR']}❌ Please enter a valid question.{colors['RESET']}")
        
        elif choice == "3":
            domain = input(f"\n{colors['INFO']}{colors['BOLD']}🌐 Enter domain to troubleshoot: {colors['RESET']}").strip()
            if domain:
                print(f"{colors['SUCCESS']}✅ Running DNS diagnostics for {domain}...{colors['RESET']}")
                response = client.call_tool("enhanced_search_it_support", {"question": f"DNS troubleshooting for {domain}", "session_id": client.session_id})
                client.print_response(response, f"DNS Troubleshooting for {domain}")
            else:
                print(f"{colors['ERROR']}❌ Please enter a valid domain name.{colors['RESET']}")
        
        elif choice == "4":
            username = input(f"\n{colors['INFO']}{colors['BOLD']}👤 Enter your Employee ID: {colors['RESET']}").strip()
            if username:
                print(f"{colors['SUCCESS']}✅ Initiating password reset for {username}...{colors['RESET']}")
                response = client.call_tool("reset_password", {"query": f"password reset for employee {username}", "session_id": client.session_id})
                client.print_response(response, f"Password Reset for {username}")
            else:
                print(f"{colors['ERROR']}❌ Please enter a valid Employee ID.{colors['RESET']}")
        
        elif choice == "5":
            print(f"{colors['SUCCESS']}✅ Processing AWS access request...{colors['RESET']}")
            response = client.call_tool("aws_access", {"query": "AWS console access help", "session_id": client.session_id})
            client.print_response(response, "AWS Access Request")
        
        elif choice == "6":
            vpn_issue = input(f"\n{colors['INFO']}{colors['BOLD']}🔒 Describe your VPN issue: {colors['RESET']}").strip()
            if vpn_issue:
                print(f"{colors['SUCCESS']}✅ Diagnosing VPN connectivity...{colors['RESET']}")
                response = client.call_tool("enhanced_search_it_support", {"question": f"VPN troubleshooting {vpn_issue}", "session_id": client.session_id})
                client.print_response(response, "VPN Troubleshooting")
            else:
                print(f"{colors['ERROR']}❌ Please describe the VPN issue.{colors['RESET']}")
        
        elif choice == "7":
            email_issue = input(f"\n{colors['INFO']}{colors['BOLD']}📧 Describe your email issue: {colors['RESET']}").strip()
            if email_issue:
                print(f"{colors['SUCCESS']}✅ Analyzing email configuration...{colors['RESET']}")
                response = client.call_tool("enhanced_search_it_support", {"question": f"email troubleshooting {email_issue}", "session_id": client.session_id})
                client.print_response(response, "Email & Outlook Support")
            else:
                print(f"{colors['ERROR']}❌ Please describe the email issue.{colors['RESET']}")
        
        elif choice == "8":
            print(f"{colors['SUCCESS']}✅ Accessing Thomson Reuters SharePoint resources...{colors['RESET']}")
            response = client.call_tool("enhanced_search_it_support", {"question": "SharePoint Digital Accessibility Center of Excellence resources", "session_id": client.session_id})
            client.print_response(response, "SharePoint Resources")
        
        else:
            print(f"{colors['ERROR']}❌ Invalid choice. Please select a number between 0-8.{colors['RESET']}")
        
        input(f"\n{colors['WARNING']}Press Enter to continue...{colors['RESET']}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Enhanced Thomson Reuters IT Helpdesk MCP Gateway Client")
    parser.add_argument("--interactive", "-i", action="store_true", help="Run in interactive mode")
    parser.add_argument("--list-tools", action="store_true", help="List all available tools")
    parser.add_argument("--tool", "-t", help="Tool name to call")
    parser.add_argument("--args", "-a", help="Tool arguments as JSON string")
    parser.add_argument("--gateway-url", help="Custom gateway URL")
    parser.add_argument("--region", default="us-east-1", help="AWS region")
    
    args = parser.parse_args()
    
    # Initialize client
    kwargs = {}
    if args.gateway_url:
        kwargs['gateway_url'] = args.gateway_url
    if args.region:
        kwargs['region'] = args.region
    
    client = MCPGatewayClient(**kwargs)
    
    if args.interactive:
        interactive_menu()
    elif args.list_tools:
        response = client.list_tools()
        client.print_response(response, "Available MCP Tools")
    elif args.tool:
        tool_args = json.loads(args.args) if args.args else {}
        response = client.call_tool(args.tool, tool_args)
        client.print_response(response, f"Tool: {args.tool}")
    else:
        # Default to interactive mode
        interactive_menu()