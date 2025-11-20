#!/usr/bin/env python3
"""
Debug test to see what get_route53_records returns
"""

import json
import os
import sys
import logging

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger()

# Set up environment for testing
os.environ['ENV'] = 'dev'
os.environ['APP_CONFIG_PATH'] = '/a208194/APISECRETS'

try:
    # Import the functions we need to test
    from chatops_route_dns_intent import get_route53_records
    
    print("Testing get_route53_records()...")
    
    # Call get_route53_records to see what it returns
    route53_records, status_code = get_route53_records()
    
    print(f"Status code: {status_code}")
    print(f"Type of route53_records: {type(route53_records)}")
    print(f"Route53 records structure:")
    print(json.dumps(route53_records, indent=2, default=str))
    
except Exception as e:
    print(f"Test failed with error: {e}")
    import traceback
    print(f"Traceback: {traceback.format_exc()}")
    sys.exit(1)