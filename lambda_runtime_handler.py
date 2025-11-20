#!/usr/bin/env python3
"""
Lambda Runtime API Container Handler for Agent Core Runtime
Based on AWS Lambda Runtime API specification
"""

import json
import logging
import os
import sys
import time
import requests
from chatops_route_dns_intent import lambda_handler

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

def main():
    """Main entry point for Lambda Runtime API"""
    
    # Lambda Runtime API environment variables
    runtime_api = os.environ.get('AWS_LAMBDA_RUNTIME_API')
    
    if not runtime_api:
        logger.info("AWS_LAMBDA_RUNTIME_API not set, falling back to HTTP server mode")
        # Fall back to HTTP server for testing
        from http.server import HTTPServer
        from container_handler import DNSHandler
        
        server = HTTPServer(('0.0.0.0', 8080), DNSHandler)
        logger.info("Starting HTTP server on port 8080")
        server.serve_forever()
        return
    
    logger.info(f"Starting Lambda Runtime API mode with endpoint: {runtime_api}")
    
    # Lambda Runtime API URLs
    next_invocation_url = f"http://{runtime_api}/2018-06-01/runtime/invocation/next"
    
    while True:
        try:
            logger.info("Polling for next invocation...")
            
            # Get next invocation
            response = requests.get(next_invocation_url, timeout=None)
            response.raise_for_status()
            
            # Extract headers
            request_id = response.headers['Lambda-Runtime-Aws-Request-Id']
            deadline = response.headers.get('Lambda-Runtime-Deadline-Ms')
            
            logger.info(f"Received invocation: {request_id}")
            logger.info(f"Event data: {response.text}")
            
            # Parse event
            event = response.json()
            
            # Create mock context
            class MockContext:
                def __init__(self, request_id, deadline):
                    self.aws_request_id = request_id
                    self.deadline = int(deadline) if deadline else int(time.time() * 1000) + 30000
                    self.function_name = 'dns-lookup'
                    self.function_version = '1.0'
                    self.invoked_function_arn = 'arn:aws:lambda:us-east-1:123456789012:function:dns-lookup'
                    self.memory_limit_in_mb = 512
                    self.remaining_time_in_millis = lambda: max(0, self.deadline - int(time.time() * 1000))
            
            context = MockContext(request_id, deadline)
            
            # Call handler
            result = lambda_handler(event, context)
            
            # Send response
            response_url = f"http://{runtime_api}/2018-06-01/runtime/invocation/{request_id}/response"
            
            response_data = json.dumps(result) if not isinstance(result, str) else result
            
            requests.post(response_url, data=response_data, headers={'Content-Type': 'application/json'})
            
            logger.info(f"Successfully processed invocation: {request_id}")
            
        except requests.exceptions.Timeout:
            logger.warning("Timeout waiting for next invocation")
            continue
            
        except Exception as e:
            logger.error(f"Error processing invocation: {e}")
            
            # Send error response if we have a request ID
            try:
                error_url = f"http://{runtime_api}/2018-06-01/runtime/invocation/{request_id}/error"
                error_response = {
                    "errorMessage": str(e),
                    "errorType": type(e).__name__
                }
                requests.post(error_url, data=json.dumps(error_response))
            except:
                pass

if __name__ == "__main__":
    main()