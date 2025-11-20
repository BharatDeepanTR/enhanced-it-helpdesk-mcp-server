#!/usr/bin/env python3
"""
Agent Core Sandbox JSON Payload Generator
==========================================

This script generates JSON payloads that match exactly what you would 
paste into the Agent Core sandbox testing interface.

Based on the sandbox screenshot:
- Runtime agent: a208194_chatops_route_dns_lookup
- Endpoint: chatops_dns_endpoint
- Input field expects JSON payload
"""

import json
from datetime import datetime

def generate_dns_lookup_payload(query: str) -> str:
    """Generate JSON payload for DNS lookup queries"""
    
    payload = {
        "inputText": query,
        "sessionId": f"sandbox-test-{datetime.now().strftime('%Y%m%d-%H%M%S')}",
        "sessionAttributes": {},
        "promptSessionAttributes": {}
    }
    
    return json.dumps(payload, indent=2)

def generate_sample_payloads():
    """Generate sample JSON payloads for common DNS queries"""
    
    # Sample DNS queries that the agent should handle
    sample_queries = [
        "What is the IP address of google.com?",
        "Can you lookup DNS for amazon.com?",
        "Show me the route to 8.8.8.8",
        "dns lookup microsoft.com",
        "trace route to cloudflare.com",
        "What are the MX records for gmail.com?",
        "Lookup the nameservers for github.com",
        "Show me DNS records for aws.amazon.com",
        "What is the IP address of bbc.co.uk?",
        "Can you trace the route to 1.1.1.1?"
    ]
    
    print("🎯 AGENT CORE SANDBOX JSON PAYLOADS")
    print("=" * 60)
    print(f"Runtime agent: a208194_chatops_route_dns_lookup")
    print(f"Endpoint: chatops_dns_endpoint")
    print(f"Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print("=" * 60)
    
    for i, query in enumerate(sample_queries, 1):
        print(f"\n{i}. Query: {query}")
        print("-" * 50)
        print("Copy this JSON payload to the sandbox:")
        print()
        print(generate_dns_lookup_payload(query))
        print("-" * 50)

def interactive_payload_generator():
    """Interactive payload generator"""
    
    print("\n🔧 INTERACTIVE PAYLOAD GENERATOR")
    print("=" * 40)
    print("Enter DNS queries and get JSON payloads for the sandbox")
    print("Type 'exit' to quit")
    print()
    
    while True:
        try:
            query = input("Enter DNS query: ").strip()
            
            if query.lower() in ['exit', 'quit', '']:
                print("👋 Goodbye!")
                break
            
            print(f"\n📋 JSON Payload for sandbox:")
            print("-" * 30)
            print(generate_dns_lookup_payload(query))
            print("-" * 30)
            print()
            
        except KeyboardInterrupt:
            print("\n👋 Goodbye!")
            break

def save_payloads_to_files():
    """Save sample payloads to individual JSON files"""
    
    sample_queries = [
        ("basic_dns_lookup", "What is the IP address of google.com?"),
        ("subdomain_lookup", "Can you lookup DNS for www.amazon.com?"),
        ("route_trace", "Show me the route to 8.8.8.8"),
        ("chatops_command", "dns lookup microsoft.com"),
        ("mx_records", "What are the MX records for gmail.com?")
    ]
    
    print("💾 Saving sample payloads to files...")
    
    for filename, query in sample_queries:
        payload = generate_dns_lookup_payload(query)
        
        file_path = f"sandbox_payload_{filename}.json"
        with open(file_path, 'w') as f:
            f.write(payload)
        
        print(f"✅ Saved: {file_path}")
    
    print(f"\n📁 Files saved! You can copy-paste these directly into the sandbox.")

def main():
    """Main function with menu options"""
    
    print("🧪 AGENT CORE SANDBOX PAYLOAD GENERATOR")
    print("=" * 50)
    print("1. Generate sample payloads")
    print("2. Interactive payload generator") 
    print("3. Save sample payloads to files")
    print("4. Exit")
    print("=" * 50)
    
    while True:
        try:
            choice = input("\nSelect option (1-4): ").strip()
            
            if choice == '1':
                generate_sample_payloads()
            elif choice == '2':
                interactive_payload_generator()
            elif choice == '3':
                save_payloads_to_files()
            elif choice == '4':
                print("👋 Goodbye!")
                break
            else:
                print("❌ Invalid choice. Please select 1-4.")
                
        except KeyboardInterrupt:
            print("\n👋 Goodbye!")
            break

if __name__ == "__main__":
    main()