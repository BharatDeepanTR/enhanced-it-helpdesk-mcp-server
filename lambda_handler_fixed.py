#!/usr/bin/env python3
"""
Enhanced Lambda handler for AWS Bedrock Agent Core Runtime
Prevents "Unable to invoke endpoint successfully" errors
"""

import json
import os
import sys
import logging
from typing import Dict, Any, Optional

# Configure logging for CloudWatch
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """
    Enhanced Lambda handler for Agent Core Runtime
    Includes comprehensive error handling and logging to prevent invocation failures
    """
    
    # Log the incoming event for debugging
    logger.info(f"Received event: {json.dumps(event)}")
    logger.info(f"Context: {context}")
    
    try:
        # Initialize response structure
        response = {
            'statusCode': 200,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            'body': ''
        }
        
        # Extract domain from various input formats
        domain = extract_domain_from_event(event)
        
        if not domain:
            logger.warning(f"No domain found in event: {event}")
            response['statusCode'] = 400
            response['body'] = json.dumps({
                'error': 'Missing domain parameter',
                'message': 'Please provide domain in format: {"domain": "example.com"}',
                'accepted_formats': [
                    '{"domain": "example.com"}',
                    '{"queryStringParameters": {"domain": "example.com"}}',
                    '{"body": "{\\"domain\\": \\"example.com\\"}"}'
                ],
                'received_event_keys': list(event.keys()) if isinstance(event, dict) else 'not_dict'
            })
            return response
        
        logger.info(f"Processing DNS lookup for domain: {domain}")
        
        # Import DNS lookup function with error handling
        try:
            from chatops_route_dns_intent import lookup_dns_record
        except ImportError as e:
            logger.error(f"Failed to import lookup_dns_record: {e}")
            response['statusCode'] = 500
            response['body'] = json.dumps({
                'error': 'Service configuration error',
                'message': 'DNS lookup service is not properly configured'
            })
            return response
        
        # Perform DNS lookup
        try:
            result = lookup_dns_record(domain)
            logger.info(f"DNS lookup successful for {domain}")
            
            # Ensure result is in proper format
            if isinstance(result, dict):
                response['body'] = json.dumps(result)
            elif isinstance(result, list):
                response['body'] = json.dumps({'dns_records': result})
            else:
                response['body'] = json.dumps({'result': str(result)})
                
        except Exception as dns_error:
            logger.error(f"DNS lookup failed for {domain}: {dns_error}")
            response['statusCode'] = 500
            response['body'] = json.dumps({
                'error': 'DNS lookup failed',
                'message': str(dns_error),
                'domain': domain,
                'error_type': type(dns_error).__name__
            })
            
        return response
        
    except Exception as e:
        # Catch-all error handler to prevent Lambda invocation failures
        logger.error(f"Unexpected error in lambda_handler: {e}")
        logger.exception("Full exception details:")
        
        return {
            'statusCode': 500,
            'headers': {
                'Content-Type': 'application/json'
            },
            'body': json.dumps({
                'error': 'Internal server error',
                'message': 'An unexpected error occurred',
                'error_type': type(e).__name__,
                'timestamp': context.aws_request_id if context else 'unknown'
            })
        }

def extract_domain_from_event(event: Dict[str, Any]) -> Optional[str]:
    """
    Extract domain from various Agent Core Runtime event formats
    """
    if not isinstance(event, dict):
        return None
    
    # Format 1: Direct domain parameter (most common for Agent Core Runtime)
    if 'domain' in event:
        return event['domain']
    
    # Format 2: Query string parameters
    if 'queryStringParameters' in event:
        params = event.get('queryStringParameters', {})
        if params and isinstance(params, dict) and 'domain' in params:
            return params['domain']
    
    # Format 3: Body with JSON string
    if 'body' in event:
        try:
            body_str = event['body']
            if isinstance(body_str, str):
                body = json.loads(body_str)
                if isinstance(body, dict) and 'domain' in body:
                    return body['domain']
            elif isinstance(body_str, dict) and 'domain' in body_str:
                return body_str['domain']
        except (json.JSONDecodeError, TypeError, AttributeError):
            pass
    
    # Format 4: HTTP path parameters (REST API style)
    if 'pathParameters' in event:
        params = event.get('pathParameters', {})
        if params and isinstance(params, dict) and 'domain' in params:
            return params['domain']
    
    # Format 5: Nested in request context
    if 'requestContext' in event:
        context = event.get('requestContext', {})
        if isinstance(context, dict) and 'domain' in context:
            return context['domain']
    
    return None

def health_check() -> Dict[str, Any]:
    """
    Health check endpoint for container readiness
    """
    return {
        'statusCode': 200,
        'headers': {
            'Content-Type': 'application/json'
        },
        'body': json.dumps({
            'status': 'healthy',
            'service': 'dns-lookup-agent-core-runtime',
            'version': '1.3.0',
            'runtime': 'lambda',
            'timestamp': '2025-11-03T00:00:00Z'
        })
    }

# For local testing and debugging
if __name__ == '__main__':
    # Test with various event formats
    test_events = [
        {'domain': 'google.com'},
        {'queryStringParameters': {'domain': 'aws.amazon.com'}},
        {'body': '{"domain": "github.com"}'},
        {'body': {'domain': 'microsoft.com'}},
        {}  # Empty event to test error handling
    ]
    
    for i, test_event in enumerate(test_events):
        print(f"\n=== Test {i+1} ===")
        print(f"Input: {test_event}")
        
        # Create mock context
        class MockContext:
            aws_request_id = f"test-request-{i+1}"
        
        response = lambda_handler(test_event, MockContext())
        print(f"Response: {json.dumps(response, indent=2)}")