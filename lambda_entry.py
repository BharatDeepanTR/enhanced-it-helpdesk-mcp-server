# Lambda handler wrapper for Agent Core Runtime compatibility
# This bridges the HTTP server code to Lambda function interface

import json
import os
from chatops_route_dns_intent import lambda_handler as dns_lambda_handler

def lambda_handler(event, context):
    """
    Lambda handler entry point for Agent Core Runtime
    Converts various input formats to the expected DNS lookup format
    """
    try:
        # Extract domain from different possible input formats
        domain = None
        
        # Format 1: Direct domain in event
        if isinstance(event, dict) and 'domain' in event:
            domain = event['domain']
        
        # Format 2: Query string parameters
        elif isinstance(event, dict) and 'queryStringParameters' in event:
            if event['queryStringParameters'] and 'domain' in event['queryStringParameters']:
                domain = event['queryStringParameters']['domain']
        
        # Format 3: Body with JSON
        elif isinstance(event, dict) and 'body' in event:
            try:
                body = json.loads(event['body']) if isinstance(event['body'], str) else event['body']
                if isinstance(body, dict) and 'domain' in body:
                    domain = body['domain']
            except (json.JSONDecodeError, TypeError):
                pass
        
        # Format 4: Check for path-based routing
        elif isinstance(event, dict) and 'path' in event:
            if event['path'] == '/health':
                return {
                    'statusCode': 200,
                    'body': json.dumps({
                        'status': 'healthy',
                        'service': 'dns-lookup',
                        'timestamp': context.aws_request_id if context else 'test'
                    })
                }
        
        # Default test domain if none provided
        if not domain:
            domain = 'aws.amazon.com'
        
        # Create the expected event format for the original lambda handler
        dns_event = {
            'domain': domain
        }
        
        # Call the original DNS lookup function
        result = dns_lambda_handler(dns_event, context)
        
        # Ensure proper response format
        if isinstance(result, dict):
            return {
                'statusCode': 200,
                'body': json.dumps(result) if not isinstance(result.get('body'), str) else result.get('body', json.dumps(result)),
                'headers': {
                    'Content-Type': 'application/json',
                    'Access-Control-Allow-Origin': '*'
                }
            }
        else:
            return {
                'statusCode': 200,
                'body': json.dumps({'result': str(result)}),
                'headers': {
                    'Content-Type': 'application/json'
                }
            }
            
    except Exception as e:
        # Return error response
        error_response = {
            'statusCode': 500,
            'body': json.dumps({
                'error': str(e),
                'message': 'DNS lookup failed',
                'input_received': str(event)[:200] if event else 'None'
            }),
            'headers': {
                'Content-Type': 'application/json'
            }
        }
        return error_response

# For direct testing
if __name__ == "__main__":
    # Test the handler
    test_event = {"domain": "google.com"}
    result = lambda_handler(test_event, None)
    print(json.dumps(result, indent=2))