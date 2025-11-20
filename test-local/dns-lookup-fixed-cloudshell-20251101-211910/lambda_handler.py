#!/usr/bin/env python3
"""
Lambda handler for Agent Core Runtime compatibility
Wraps the existing DNS lookup functionality for Lambda invocation
"""

import json
import os
import sys
from typing import Dict, Any

# Import your existing DNS lookup function
from chatops_route_dns_intent import lookup_dns_record

def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """
    Lambda handler for Agent Core Runtime
    Supports multiple input formats and returns standardized response
    """
    try:
        # Extract domain from various input formats
        domain = None
        
        # Format 1: Direct domain parameter
        if isinstance(event, dict) and 'domain' in event:
            domain = event['domain']
        
        # Format 2: Query string parameters
        elif isinstance(event, dict) and 'queryStringParameters' in event:
            params = event.get('queryStringParameters', {})
            if params and 'domain' in params:
                domain = params['domain']
        
        # Format 3: Body with JSON
        elif isinstance(event, dict) and 'body' in event:
            try:
                if isinstance(event['body'], str):
                    body = json.loads(event['body'])
                else:
                    body = event['body']
                if 'domain' in body:
                    domain = body['domain']
            except (json.JSONDecodeError, TypeError):
                pass
        
        # Format 4: HTTP method with path
        elif isinstance(event, dict) and 'path' in event:
            if event['path'] == '/health':
                return {
                    'statusCode': 200,
                    'body': json.dumps({
                        'status': 'healthy',
                        'service': 'dns-lookup',
                        'mode': 'lambda',
                        'timestamp': '2025-11-01T20:30:00Z'
                    })
                }
        
        # Validate domain
        if not domain:
            return {
                'statusCode': 400,
                'body': json.dumps({
                    'error': 'Missing domain parameter',
                    'message': 'Please provide domain in format: {"domain": "example.com"}',
                    'received_event': event
                })
            }
        
        # Call your existing DNS lookup function
        result = lookup_dns_record(domain)
        
        # Return standardized response
        return {
            'statusCode': 200,
            'body': json.dumps(result) if isinstance(result, dict) else json.dumps({'result': result}),
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            }
        }
        
    except Exception as e:
        # Error handling
        return {
            'statusCode': 500,
            'body': json.dumps({
                'error': 'DNS lookup failed',
                'message': str(e),
                'domain': domain if 'domain' in locals() else 'unknown'
            })
        }

# For testing locally
if __name__ == '__main__':
    # Test with sample event
    test_event = {'domain': 'google.com'}
    response = lambda_handler(test_event, None)
    print(json.dumps(response, indent=2))