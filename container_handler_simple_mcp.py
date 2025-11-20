#!/usr/bin/env python3
"""
Simplified MCP Lambda-style DNS Lookup Handler
Compatible with AWS Bedrock Agent Core Runtime MCP protocol
"""

import sys
import os
import json
import time
import logging
from chatops_route_dns_intent import lambda_handler

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

def handle_mcp_request(event, context):
    """
    Handle MCP JSON-RPC 2.0 requests in Lambda-style format
    This function will be called by Agent Core Runtime
    """
    try:
        logger.info("=== MCP REQUEST HANDLER ===")
        logger.info(f"Raw event: {event}")
        logger.info(f"Context: {context}")
        
        # Check if this is a JSON-RPC request
        if isinstance(event, dict) and event.get('jsonrpc') == '2.0':
            # Handle JSON-RPC format
            method = event.get('method')
            params = event.get('params', {})
            request_id = event.get('id')
            
            logger.info(f"JSON-RPC method: {method}")
            logger.info(f"JSON-RPC params: {params}")
            
            # Extract DNS name from various MCP parameter formats
            if method == 'tools/call':
                # MCP tool call format
                arguments = params.get('arguments', {})
                dns_name = arguments.get('dns_name', arguments.get('domain', 'microsoft.com'))
            else:
                # Direct parameter access
                dns_name = (params.get('dns_name') or 
                           params.get('domain') or 
                           params.get('input', {}).get('dns_name') or
                           'microsoft.com')
            
            logger.info(f"Extracted DNS name: {dns_name}")
            
            # Create DNS event for lambda handler
            dns_event = {"dns_name": dns_name}
            
            # Call the actual DNS lookup function
            logger.info(f"Calling DNS lambda_handler with: {dns_event}")
            dns_result = lambda_handler(dns_event, context)
            logger.info(f"DNS result: {dns_result}")
            
            # Extract result data
            if isinstance(dns_result, dict) and 'body' in dns_result:
                result_data = json.loads(dns_result['body']) if isinstance(dns_result['body'], str) else dns_result['body']
            else:
                result_data = dns_result
            
            # Return JSON-RPC success response
            response = {
                "jsonrpc": "2.0",
                "result": result_data,
                "id": request_id
            }
            
            logger.info(f"Returning JSON-RPC response: {response}")
            return response
            
        else:
            # Handle direct DNS event format (fallback)
            logger.info("Direct DNS event format detected")
            dns_name = event.get('dns_name', 'microsoft.com')
            logger.info(f"DNS name from direct event: {dns_name}")
            
            dns_event = {"dns_name": dns_name}
            result = lambda_handler(dns_event, context)
            
            logger.info(f"Direct result: {result}")
            return result
            
    except Exception as e:
        logger.error(f"Error in MCP request handler: {e}")
        logger.error(f"Exception type: {type(e)}")
        import traceback
        logger.error(f"Traceback: {traceback.format_exc()}")
        
        # Return JSON-RPC error response
        error_response = {
            "jsonrpc": "2.0",
            "error": {
                "code": -32603,
                "message": f"Internal error: {str(e)}"
            },
            "id": event.get('id') if isinstance(event, dict) else None
        }
        
        logger.info(f"Returning JSON-RPC error: {error_response}")
        return error_response

def main():
    """
    Main entry point - simulate Lambda-style execution
    This will be called by Agent Core Runtime
    """
    logger.info("MCP DNS Lookup Handler starting...")
    logger.info(f"Environment: {os.environ.get('ENV', 'unknown')}")
    logger.info(f"Config path: {os.environ.get('APP_CONFIG_PATH', 'unknown')}")
    
    # Set up environment if not already configured
    if 'ENV' not in os.environ:
        os.environ['ENV'] = 'production'
    if 'APP_CONFIG_PATH' not in os.environ:
        os.environ['APP_CONFIG_PATH'] = '/a208194/APISECRETS'
    
    logger.info("MCP DNS Lookup Handler ready for invocations")
    
    # Keep the process alive for Agent Core Runtime
    try:
        while True:
            time.sleep(10)  # Keep alive
    except KeyboardInterrupt:
        logger.info("MCP DNS Lookup Handler stopped")

if __name__ == "__main__":
    main()

# Export the handler function for Agent Core Runtime
lambda_handler = handle_mcp_request