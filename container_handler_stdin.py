#!/usr/bin/env python3
"""
Simple stdin/stdout MCP handler for Agent Core Runtime
No HTTP server - just reads JSON-RPC from stdin, writes response to stdout
"""

import sys
import json
import logging
from chatops_route_dns_intent import lambda_handler

# Configure logging to stderr so it doesn't interfere with stdout
logging.basicConfig(
    stream=sys.stderr,
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

def handle_jsonrpc_request(request_data):
    """Handle a single JSON-RPC request"""
    try:
        logger.info(f"=== STDIN JSON-RPC REQUEST ===")
        logger.info(f"Request: {request_data}")
        
        # Validate JSON-RPC format
        if not isinstance(request_data, dict) or request_data.get('jsonrpc') != '2.0':
            return {
                "jsonrpc": "2.0",
                "error": {"code": -32600, "message": "Invalid Request"},
                "id": request_data.get('id') if isinstance(request_data, dict) else None
            }
        
        method = request_data.get('method')
        params = request_data.get('params', {})
        request_id = request_data.get('id')
        
        logger.info(f"Method: {method}")
        logger.info(f"Params: {params}")
        
        # Extract DNS name from various formats
        dns_name = None
        
        if method == 'tools/call':
            # MCP tool call format
            arguments = params.get('arguments', {})
            dns_name = arguments.get('dns_name', arguments.get('domain'))
        elif isinstance(params, dict):
            # Direct parameters
            dns_name = (params.get('dns_name') or 
                       params.get('domain') or 
                       params.get('input', {}).get('dns_name'))
        
        if not dns_name:
            dns_name = 'microsoft.com'  # Default fallback
            
        logger.info(f"Extracted DNS name: {dns_name}")
        
        # Create DNS event
        dns_event = {"dns_name": dns_name}
        
        # Create mock context
        class MockContext:
            function_name = "dns_lookup_stdin"
            aws_request_id = "stdin-request"
            remaining_time_in_millis = lambda: 30000
        
        context = MockContext()
        
        # Call DNS lambda handler
        logger.info(f"Calling lambda_handler with: {dns_event}")
        result = lambda_handler(dns_event, context)
        logger.info(f"Lambda result: {result}")
        
        # Format result for JSON-RPC
        if isinstance(result, dict) and 'body' in result:
            result_data = json.loads(result['body']) if isinstance(result['body'], str) else result['body']
        else:
            result_data = result
        
        response = {
            "jsonrpc": "2.0",
            "result": result_data,
            "id": request_id
        }
        
        logger.info(f"Returning response: {response}")
        return response
        
    except Exception as e:
        logger.error(f"Error handling request: {e}")
        import traceback
        logger.error(f"Traceback: {traceback.format_exc()}")
        
        return {
            "jsonrpc": "2.0",
            "error": {
                "code": -32603,
                "message": f"Internal error: {str(e)}"
            },
            "id": request_data.get('id') if isinstance(request_data, dict) else None
        }

def main():
    """Main loop - read from stdin, process, write to stdout"""
    import os
    
    # Set up environment
    os.environ.setdefault('ENV', 'dev')
    os.environ.setdefault('APP_CONFIG_PATH', '/a208194/APISECRETS')
    
    logger.info("DNS Lookup STDIN Handler starting...")
    logger.info(f"Environment: {os.environ.get('ENV')}")
    logger.info(f"Config path: {os.environ.get('APP_CONFIG_PATH')}")
    
    try:
        # Read from stdin
        for line in sys.stdin:
            line = line.strip()
            if not line:
                continue
                
            logger.info(f"Received stdin line: {line}")
            
            try:
                # Parse JSON
                request_data = json.loads(line)
                
                # Handle request
                response = handle_jsonrpc_request(request_data)
                
                # Write response to stdout
                response_json = json.dumps(response)
                print(response_json)
                sys.stdout.flush()
                
                logger.info(f"Sent stdout response: {response_json}")
                
            except json.JSONDecodeError as e:
                logger.error(f"Invalid JSON in stdin: {e}")
                error_response = {
                    "jsonrpc": "2.0",
                    "error": {"code": -32700, "message": "Parse error"},
                    "id": None
                }
                print(json.dumps(error_response))
                sys.stdout.flush()
                
    except KeyboardInterrupt:
        logger.info("Received interrupt signal")
    except Exception as e:
        logger.error(f"Fatal error: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()