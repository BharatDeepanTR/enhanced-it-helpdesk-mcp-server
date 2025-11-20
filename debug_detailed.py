#!/usr/bin/env python3
"""
Enhanced test with more detailed error tracking
"""

import json
import os
import sys
import logging
import traceback

# Configure logging to see more details
logging.basicConfig(level=logging.DEBUG)
logger = logging.getLogger()

# Set up environment for testing
os.environ['ENV'] = 'dev'
os.environ['APP_CONFIG_PATH'] = '/a208194/APISECRETS'

try:
    # Import the functions we need to test
    from chatops_route_dns_intent import lookup_dns_record, get_route53_records
    
    print("Testing get_route53_records directly...")
    
    # Test get_route53_records first
    route53_records, status_code = get_route53_records()
    print(f"Route53 records type: {type(route53_records)}")
    print(f"Route53 records: {json.dumps(route53_records, indent=2, default=str)}")
    
    print("\nTesting lookup_dns_record...")
    
    # Test lookup_dns_record
    result = lookup_dns_record("microsoft.com")
    print(f"Lookup result: {result}")
    
except Exception as e:
    print(f"Test failed with error: {e}")
    print(f"Traceback: {traceback.format_exc()}")
    sys.exit(1)