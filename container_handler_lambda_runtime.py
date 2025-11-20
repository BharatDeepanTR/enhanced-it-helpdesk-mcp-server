#!/usr/bin/env python3
"""
AWS Lambda Runtime API Compatible Handler for Agent Core Runtime
Works with both HTTP and MCP protocols by implementing Lambda Runtime API
"""

import sys
import os
import json
import time
import signal
import logging
import requests
from urllib.parse import unquote
from chatops_route_dns_intent import lambda_handler

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

class LambdaRuntimeAPI:
    def __init__(self):
        self.runtime_api = os.environ.get('AWS_LAMBDA_RUNTIME_API', 'localhost:8080')
        self.function_name = os.environ.get('AWS_LAMBDA_FUNCTION_NAME', 'dns_lookup')
        self.running = True
        
    def start(self):
        """Start the Lambda Runtime API event loop"""
        logger.info(f"Starting Lambda Runtime API on {self.runtime_api}")
        logger.info(f"Function name: {self.function_name}")
        
        while self.running:
            try:
                # Get next invocation
                next_url = f"http://{self.runtime_api}/2018-06-01/runtime/invocation/next"
                logger.info(f"Polling for next invocation: {next_url}")
                
                response = requests.get(next_url, timeout=None)
                
                if response.status_code == 200:
                    request_id = response.headers.get('Lambda-Runtime-Aws-Request-Id')
                    event_data = response.json()
                    
                    logger.info(f"Received invocation: {request_id}")
                    logger.info(f"Event data: {event_data}")
                    
                    # Process the event
                    result = self.handle_event(event_data, request_id)
                    
                    # Send response
                    self.send_response(request_id, result)
                    
                else:
                    logger.warning(f"Failed to get next invocation: {response.status_code}")
                    time.sleep(1)
                    
            except Exception as e:
                logger.error(f"Error in runtime loop: {e}")
                time.sleep(1)
    
    def handle_event(self, event, request_id):
        """Handle the invocation event"""
        try:
            logger.info("=== LAMBDA RUNTIME INVOCATION ===")
            logger.info(f"Request ID: {request_id}")
            logger.info(f"Event: {event}")
            
            # Check if this is a JSON-RPC MCP request
            if isinstance(event, dict) and event.get('jsonrpc') == '2.0':
                return self.handle_jsonrpc(event)
            else:
                return self.handle_direct_dns(event)
                
        except Exception as e:
            logger.error(f"Error handling event: {e}")
            import traceback
            logger.error(f"Traceback: {traceback.format_exc()}")
            return {
                "errorType": "RuntimeError",
                "errorMessage": str(e)
            }
    
    def handle_jsonrpc(self, event):
        """Handle JSON-RPC 2.0 requests from MCP"""
        try:
            method = event.get('method')
            params = event.get('params', {})
            request_id = event.get('id')
            
            logger.info(f"JSON-RPC method: {method}")
            logger.info(f"JSON-RPC params: {params}")
            
            # Extract DNS name from MCP parameters
            if method == 'tools/call':
                arguments = params.get('arguments', {})
                dns_name = arguments.get('dns_name', arguments.get('domain', 'microsoft.com'))
            else:
                dns_name = (params.get('dns_name') or 
                           params.get('domain') or 
                           'microsoft.com')
            
            # Call DNS function
            dns_event = {"dns_name": dns_name}
            context = self.create_context()
            dns_result = lambda_handler(dns_event, context)
            
            # Format as JSON-RPC response
            if isinstance(dns_result, dict) and 'body' in dns_result:
                result_data = json.loads(dns_result['body']) if isinstance(dns_result['body'], str) else dns_result['body']
            else:
                result_data = dns_result
            
            return {
                "jsonrpc": "2.0",
                "result": result_data,
                "id": request_id
            }
            
        except Exception as e:
            logger.error(f"Error in JSON-RPC handling: {e}")
            return {
                "jsonrpc": "2.0",
                "error": {
                    "code": -32603,
                    "message": str(e)
                },
                "id": event.get('id')
            }
    
    def handle_direct_dns(self, event):
        """Handle direct DNS requests"""
        try:
            dns_name = event.get('dns_name', 'microsoft.com')
            dns_event = {"dns_name": dns_name}
            context = self.create_context()
            
            return lambda_handler(dns_event, context)
            
        except Exception as e:
            logger.error(f"Error in direct DNS handling: {e}")
            return {
                "errorType": "RuntimeError",
                "errorMessage": str(e)
            }
    
    def send_response(self, request_id, result):
        """Send response back to Lambda Runtime API"""
        try:
            response_url = f"http://{self.runtime_api}/2018-06-01/runtime/invocation/{request_id}/response"
            
            response = requests.post(
                response_url,
                json=result,
                headers={'Content-Type': 'application/json'}
            )
            
            logger.info(f"Response sent: {response.status_code}")
            
        except Exception as e:
            logger.error(f"Error sending response: {e}")
            # Send error response
            try:
                error_url = f"http://{self.runtime_api}/2018-06-01/runtime/invocation/{request_id}/error"
                requests.post(error_url, json={"errorMessage": str(e)})
            except:
                pass
    
    def create_context(self):
        """Create a mock lambda context"""
        class MockContext:
            def __init__(self):
                self.function_name = "dns_lookup_lambda_runtime"
                self.function_version = "1"
                self.invoked_function_arn = "arn:aws:lambda:us-east-1:123456789012:function:dns_lookup_lambda_runtime"
                self.memory_limit_in_mb = 512
                self.remaining_time_in_millis = lambda: 30000
                self.aws_request_id = "test-request-id"
        
        return MockContext()
    
    def stop(self):
        """Stop the runtime"""
        self.running = False

# Global runtime instance
runtime = None

def signal_handler(signum, frame):
    """Handle shutdown signals"""
    logger.info(f"Received signal {signum}, shutting down...")
    global runtime
    if runtime:
        runtime.stop()

def main():
    """Main entry point"""
    global runtime
    
    # Set up signal handlers
    signal.signal(signal.SIGTERM, signal_handler)
    signal.signal(signal.SIGINT, signal_handler)
    
    # Set up environment
    if 'ENV' not in os.environ:
        os.environ['ENV'] = 'production'
    if 'APP_CONFIG_PATH' not in os.environ:
        os.environ['APP_CONFIG_PATH'] = '/a208194/APISECRETS'
    
    logger.info("AWS Lambda Runtime API DNS Lookup Service starting...")
    logger.info(f"Environment: {os.environ.get('ENV')}")
    logger.info(f"Config path: {os.environ.get('APP_CONFIG_PATH')}")
    logger.info(f"Runtime API: {os.environ.get('AWS_LAMBDA_RUNTIME_API', 'localhost:8080')}")
    
    try:
        runtime = LambdaRuntimeAPI()
        runtime.start()
        
    except KeyboardInterrupt:
        logger.info("Received keyboard interrupt")
    except Exception as e:
        logger.error(f"Runtime error: {e}")
        sys.exit(1)
    finally:
        logger.info("Lambda Runtime API DNS Lookup Service stopped")

if __name__ == "__main__":
    main()