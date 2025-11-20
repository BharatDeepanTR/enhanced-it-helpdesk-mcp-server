#!/usr/bin/env python3
"""
Quick Sandbox Payload Generator
===============================
Generates the most common JSON payload for the Agent Core sandbox.
"""

import json
from datetime import datetime

# Generate a basic DNS lookup payload
query = "What is the IP address of google.com?"

payload = {
    "inputText": query,
    "sessionId": f"sandbox-test-{datetime.now().strftime('%Y%m%d-%H%M%S')}",
    "sessionAttributes": {},
    "promptSessionAttributes": {}
}

print("🎯 COPY THIS JSON TO THE SANDBOX:")
print("=" * 50)
print(json.dumps(payload, indent=2))
print("=" * 50)
print(f"Runtime agent: a208194_chatops_route_dns_lookup")
print(f"Endpoint: chatops_dns_endpoint")
print(f"Query: {query}")