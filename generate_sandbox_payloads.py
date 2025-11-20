#!/usr/bin/env python3
"""
Agent Sandbox Payload Generator
===============================

Generate JSON payloads for testing in the Agent Core sandbox,
matching the format expected by the endpoint testing wizard.
"""

import json
from datetime import datetime

def generate_dns_test_payloads():
    """Generate test payloads for DNS agent testing"""
    
    payloads = [
        {
            "name": "Basic DNS Lookup",
            "description": "Test basic domain name resolution",
            "payload": {
                "inputText": "What is the IP address of google.com?",
                "sessionId": f"test-dns-{datetime.now().strftime('%Y%m%d%H%M%S')}-1"
            }
        },
        {
            "name": "Subdomain Resolution",
            "description": "Test subdomain DNS resolution", 
            "payload": {
                "inputText": "Can you lookup DNS for www.amazon.com?",
                "sessionId": f"test-dns-{datetime.now().strftime('%Y%m%d%H%M%S')}-2"
            }
        },
        {
            "name": "MX Record Query",
            "description": "Test MX record lookup",
            "payload": {
                "inputText": "Show me the MX records for gmail.com",
                "sessionId": f"test-dns-{datetime.now().strftime('%Y%m%d%H%M%S')}-3"
            }
        },
        {
            "name": "Route Information", 
            "description": "Test network route tracing",
            "payload": {
                "inputText": "Show me the route to 8.8.8.8",
                "sessionId": f"test-dns-{datetime.now().strftime('%Y%m%d%H%M%S')}-4"
            }
        },
        {
            "name": "ChatOps DNS Command",
            "description": "Test ChatOps-style DNS command",
            "payload": {
                "inputText": "dns lookup microsoft.com", 
                "sessionId": f"test-dns-{datetime.now().strftime('%Y%m%d%H%M%S')}-5"
            }
        },
        {
            "name": "Route Trace Command",
            "description": "Test route tracing command",
            "payload": {
                "inputText": "trace route to cloudflare.com",
                "sessionId": f"test-dns-{datetime.now().strftime('%Y%m%d%H%M%S')}-6"
            }
        }
    ]
    
    return payloads

def print_sandbox_instructions():
    """Print instructions for using payloads in sandbox"""
    
    print("\n🧪 AGENT CORE SANDBOX TESTING INSTRUCTIONS")
    print("="*60)
    print("Runtime agent: a208194_chatops_route_dns_lookup")
    print("Endpoint: chatops_dns_endpoint")
    print("\n📋 How to use in sandbox:")
    print("1. Copy the JSON payload from below")
    print("2. Paste into the 'Input' section of the sandbox")
    print("3. Click 'Run' to test")
    print("4. Check the 'Output' section for results")
    print("="*60)

def main():
    """Generate and display test payloads"""
    
    print_sandbox_instructions()
    
    payloads = generate_dns_test_payloads()
    
    for i, test in enumerate(payloads, 1):
        print(f"\n{i}. {test['name']}")
        print("-" * 50)
        print(f"Description: {test['description']}")
        print("JSON Payload for sandbox:")
        print(json.dumps(test['payload'], indent=2))
        
        if i < len(payloads):
            input("\nPress Enter for next payload...")
    
    print(f"\n📄 All {len(payloads)} test payloads generated!")
    print("\n💡 Tips:")
    print("• Start with the 'Basic DNS Lookup' test")
    print("• Each payload has a unique sessionId")
    print("• Copy-paste the JSON exactly as shown")
    print("• Check sandbox output for DNS resolution results")

if __name__ == "__main__":
    main()