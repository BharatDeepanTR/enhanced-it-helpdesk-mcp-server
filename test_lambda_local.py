#!/usr/bin/env python3
"""
Test script to isolate lambda_handler execution issues
"""

import json
import os
import sys

# Set up environment for testing
os.environ['ENV'] = 'dev'
os.environ['APP_CONFIG_PATH'] = '/a208194/APISECRETS'

try:
    # Import the lambda handler
    from chatops_route_dns_intent import lambda_handler
    
    # Create a simple test event
    test_event = {"dns_name": "microsoft.com"}
    
    # Mock context class
    class MockContext:
        def __init__(self):
            self.function_name = "test-dns-lookup"
            self.function_version = "1"
            self.aws_request_id = "test-request-123"
    
    context = MockContext()
    
    print("Testing lambda_handler with simple event...")
    print(f"Event: {test_event}")
    
    # Call the lambda handler
    result = lambda_handler(test_event, context)
    
    print(f"Result: {result}")
    print("Lambda handler test completed successfully!")
    
except Exception as e:
    print(f"Lambda handler test failed with error: {e}")
    import traceback
    print(f"Traceback: {traceback.format_exc()}")
    sys.exit(1)