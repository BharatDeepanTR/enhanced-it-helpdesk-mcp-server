#!/usr/bin/env python3
"""
Example usage of the DNS lookup lambda function without Lex dependencies.

This demonstrates how to call the lambda function directly with different event formats.
"""

import json
from chatops_route_dns_intent import lambda_handler

def test_direct_format():
    """Test with direct DNS name in event"""
    print("Testing direct format...")
    event = {
        "dns_name": "example.com"
    }
    context = {}
    
    result = lambda_handler(event, context)
    print("Result:", json.dumps(result, indent=2))
    return result

def test_api_gateway_format():
    """Test with API Gateway body format"""
    print("\nTesting API Gateway format...")
    event = {
        "body": json.dumps({
            "dns_name": "test.example.com"
        }),
        "headers": {
            "Content-Type": "application/json"
        }
    }
    context = {}
    
    result = lambda_handler(event, context)
    print("Result:", json.dumps(result, indent=2))
    return result

def test_missing_dns_name():
    """Test error handling when DNS name is missing"""
    print("\nTesting missing DNS name...")
    event = {
        "some_other_field": "value"
    }
    context = {}
    
    result = lambda_handler(event, context)
    print("Result:", json.dumps(result, indent=2))
    return result

def test_legacy_lex_format():
    """Test backward compatibility with Lex format"""
    print("\nTesting legacy Lex format...")
    event = {
        "currentIntent": {
            "name": "RouteDNSLookup",
            "slots": {
                "DNS_record": "legacy.example.com"
            }
        },
        "sessionAttributes": {}
    }
    context = {}
    
    result = lambda_handler(event, context)
    print("Result:", json.dumps(result, indent=2))
    return result

if __name__ == "__main__":
    print("DNS Lookup Lambda - Example Usage")
    print("=" * 50)
    
    # Note: These tests will fail without proper AWS credentials and API access
    # They are provided to show the expected input/output format
    
    try:
        test_direct_format()
        test_api_gateway_format()
        test_missing_dns_name()
        test_legacy_lex_format()
    except Exception as e:
        print(f"Note: Tests failed due to missing dependencies/credentials: {e}")
        print("This is expected in a development environment.")
        
    print("\n" + "=" * 50)
    print("Example completed. Modify the DNS names above to test with real data.")