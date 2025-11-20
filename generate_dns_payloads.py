#!/usr/bin/env python3
"""
DNS Agent Payload Generator for Agent Core Sandbox
==================================================

This script generates ready-to-use JSON payloads for testing the DNS agent
in the Agent Core sandbox interface.

Usage:
1. Run this script to generate payloads
2. Copy and paste the JSON payloads into the Agent Core sandbox
3. Test different DNS queries to understand agent capabilities
"""

import json
from datetime import datetime

def generate_dns_payloads():
    """Generate various DNS test payloads for sandbox testing"""
    
    timestamp = datetime.now().strftime('%Y%m%d%H%M%S')
    
    # Test scenarios for DNS agent
    test_queries = [
        # Basic DNS lookups
        "What is the IP address of google.com?",
        "lookup the DNS for amazon.com", 
        "dns resolve microsoft.com",
        
        # Route information  
        "show me the route to 8.8.8.8",
        "traceroute to cloudflare.com",
        "routing info for 1.1.1.1",
        
        # DNS record types
        "MX records for gmail.com",
        "NS records for github.com",
        "A records for stackoverflow.com",
        
        # ChatOps style commands
        "dns google.com",
        "route 8.8.8.8", 
        "nslookup amazon.com",
        
        # Troubleshooting queries
        "check DNS for my-domain.com",
        "network path to server.example.com",
        "domain resolution test",
        
        # Corporate/internal queries
        "lookup internal.company.local",
        "route to private server",
        "DNS check for subdomain.test.local"
    ]
    
    print("🧪 DNS AGENT SANDBOX PAYLOAD GENERATOR")
    print("="*60)
    print(f"🕒 Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print(f"🤖 Agent: a208194_chatops_route_dns_lookup")
    print(f"🔗 Endpoint: chatops_dns_endpoint")
    print("="*60)
    print()
    
    # Generate payloads for each query
    for i, query in enumerate(test_queries, 1):
        session_id = f"sandbox-{timestamp}-{i:02d}"
        
        payload = {
            "inputText": query,
            "sessionId": session_id,
            "sessionAttributes": {},
            "promptSessionAttributes": {}
        }
        
        print(f"🔹 Test {i}: {query}")
        print(f"📋 Payload:")
        print(json.dumps(payload, indent=2))
        print()
    
    # Generate a simple test payload for quick copy-paste
    print("="*60)
    print("🚀 QUICK TEST PAYLOAD (Copy this for immediate testing)")
    print("="*60)
    
    quick_payload = {
        "inputText": "What is the IP address of google.com?",
        "sessionId": f"quick-test-{timestamp}",
        "sessionAttributes": {},
        "promptSessionAttributes": {}
    }
    
    print(json.dumps(quick_payload, indent=2))
    
    print("\n" + "="*60)
    print("📖 HOW TO USE IN AGENT CORE SANDBOX")
    print("="*60)
    print("1. Go to Agent Core → Agent sandbox")
    print("2. Select Runtime agent: a208194_chatops_route_dns_lookup") 
    print("3. Select Endpoint: chatops_dns_endpoint")
    print("4. Copy any payload above into the Input field")
    print("5. Click 'Run' to test the agent")
    print("6. Check the Output for DNS results or error messages")
    print()
    print("💡 Tip: Start with the 'QUICK TEST PAYLOAD' above")
    print("💡 If you get runtime errors, check CloudWatch logs")
    print("💡 Try different query formats to see what the agent supports")

def generate_minimal_payloads():
    """Generate minimal payloads for basic testing"""
    
    minimal_tests = [
        "google.com",
        "dns google.com", 
        "What is the IP of google.com?",
        "lookup amazon.com"
    ]
    
    print("\n" + "="*60)
    print("⚡ MINIMAL TEST PAYLOADS")
    print("="*60)
    
    for i, query in enumerate(minimal_tests, 1):
        payload = {
            "inputText": query,
            "sessionId": f"minimal-{i}",
            "sessionAttributes": {},
            "promptSessionAttributes": {}
        }
        
        print(f"\n{i}. {query}")
        print(json.dumps(payload, indent=2))

def generate_debug_payloads():
    """Generate debug payloads to understand agent capabilities"""
    
    debug_queries = [
        "help",
        "what can you do?",
        "available commands",
        "dns help",
        "route help",
        "lookup help"
    ]
    
    print("\n" + "="*60)
    print("🐛 DEBUG/DISCOVERY PAYLOADS")
    print("="*60)
    print("Use these to discover what the agent can do:")
    
    for i, query in enumerate(debug_queries, 1):
        payload = {
            "inputText": query,
            "sessionId": f"debug-{i}",
            "sessionAttributes": {},
            "promptSessionAttributes": {}
        }
        
        print(f"\n{i}. {query}")
        print(json.dumps(payload, indent=2))

def main():
    """Main function"""
    generate_dns_payloads()
    generate_minimal_payloads()
    generate_debug_payloads()
    
    print("\n" + "="*60)
    print("🎯 RECOMMENDED TESTING APPROACH")
    print("="*60)
    print("1. Start with 'help' or 'what can you do?' to understand capabilities")
    print("2. Try simple queries like 'google.com' or 'dns google.com'")
    print("3. Test specific DNS operations: 'MX records for gmail.com'")
    print("4. Try route commands: 'route to 8.8.8.8'")
    print("5. If getting runtime errors, the agent Lambda may have issues")
    print("6. Check CloudWatch logs for detailed error information")
    print("\n💡 Copy any JSON payload above and paste it into the sandbox!")

if __name__ == "__main__":
    main()