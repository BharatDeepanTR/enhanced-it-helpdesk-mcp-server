#!/usr/bin/env python3
"""
Fixed HTTP DNS Lookup Container Handler
Uses the corrected application logic to prove MCP wasn't necessary
"""

import sys
import os
import json
import time
import signal
import threading
import socket
import logging
from http.server import HTTPServer, BaseHTTPRequestHandler
from urllib.parse import urlparse, parse_qs
from chatops_route_dns_intent import lambda_handler

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

class DNSHandler(BaseHTTPRequestHandler):
    
    def log_message(self, format, *args):
        """Override to use our logger"""
        logger.info("%s - \"%s\" %s", self.address_string(), format % args, "")
    
    def do_GET(self):
        """Handle GET requests - health checks and service info"""
        logger.info(f"=== INCOMING GET REQUEST ===")
        logger.info(f"Path: {self.path}")
        logger.info(f"Headers: {dict(self.headers)}")
        logger.info(f"Client: {self.client_address}")
        logger.info(f"================================")
        
        if self.path in ['/health', '/ping']:
            self.send_health_check()
        elif self.path == '/':
            self.send_service_info()
        else:
            logger.warning(f"GET 404: Path '{self.path}' not found")
            self.send_error(404, "Not Found")

    def do_POST(self):
        """Handle POST requests - DNS lookup invocations"""
        logger.info(f"=== INCOMING POST REQUEST ===")
        logger.info(f"Path: {self.path}")
        logger.info(f"Headers: {dict(self.headers)}")
        logger.info(f"Client: {self.client_address}")
        logger.info(f"=================================")
        
        # Handle Agent Core Runtime invocations
        self.handle_dns_invocation()

    def handle_dns_invocation(self):
        """Handle DNS lookup invocations using fixed lambda handler"""
        try:
            logger.info("=== PROCESSING DNS INVOCATION (HTTP) ===")
            
            # Read request body
            content_length = int(self.headers.get('Content-Length', 0))
            if content_length > 0:
                body = self.rfile.read(content_length)
                logger.info(f"Raw request body ({content_length} bytes): {body.decode('utf-8', errors='ignore')}")
                
                try:
                    # Parse request
                    request_data = json.loads(body.decode('utf-8'))
                    logger.info(f"Parsed request: {request_data}")
                    
                    # Extract dns_name from various possible formats
                    dns_name = None
                    
                    # Direct format
                    if 'dns_name' in request_data:
                        dns_name = request_data['dns_name']
                    # Agent Core Runtime wrapper format
                    elif 'input' in request_data and 'dns_name' in request_data['input']:
                        dns_name = request_data['input']['dns_name']
                    # Bedrock Agent format
                    elif 'parameters' in request_data and 'dns_name' in request_data['parameters']:
                        dns_name = request_data['parameters']['dns_name']
                    # Default for testing
                    else:
                        logger.warning("No dns_name found, using default")
                        dns_name = "microsoft.com"
                    
                    logger.info(f"Extracted dns_name: {dns_name}")
                    
                    # Create event for lambda handler
                    event = {"dns_name": dns_name}
                    
                    # Create mock lambda context
                    context = self.create_context()
                    
                    # Call the FIXED lambda handler
                    logger.info(f"Calling lambda_handler with event: {event}")
                    result = lambda_handler(event, context)
                    logger.info(f"Lambda handler result: {result}")
                    
                    # Return successful HTTP response
                    if isinstance(result, dict) and 'statusCode' in result:
                        # Lambda format response
                        status_code = result.get('statusCode', 200)
                        response_body = result.get('body', '{}')
                        
                        if isinstance(response_body, str):
                            response_data = json.loads(response_body)
                        else:
                            response_data = response_body
                    else:
                        # Direct response format
                        status_code = 200
                        response_data = result
                    
                    self.send_json_response(status_code, response_data)
                    
                except json.JSONDecodeError as e:
                    logger.error(f"Failed to parse request JSON: {e}")
                    error_response = {
                        "success": False,
                        "message": f"Invalid JSON: {e}",
                        "data": None
                    }
                    self.send_json_response(400, error_response)
                    
            else:
                logger.error("No body in request")
                error_response = {
                    "success": False,
                    "message": "Request body is required",
                    "data": None
                }
                self.send_json_response(400, error_response)
                
        except Exception as e:
            logger.error(f"Error processing DNS invocation: {e}")
            logger.error(f"Exception type: {type(e)}")
            import traceback
            logger.error(f"Traceback: {traceback.format_exc()}")
            
            error_response = {
                "success": False,
                "message": f"Internal server error: {str(e)}",
                "data": None
            }
            self.send_json_response(500, error_response)

    def send_health_check(self):
        """Health check endpoint"""
        try:
            # Test if we can import and load the DNS module
            import chatops_route_dns_intent
            health_status = {
                "status": "healthy",
                "service": "dns-lookup-service-http",
                "version": "2.0.0-fixed-logic",
                "protocol": "HTTP",
                "timestamp": time.time(),
                "message": "DNS lookup service operational with fixed application logic"
            }
            self.send_json_response(200, health_status)
        except Exception as e:
            health_status = {
                "status": "unhealthy",
                "error": str(e),
                "timestamp": time.time()
            }
            self.send_json_response(503, health_status)
    
    def send_service_info(self):
        """Service information endpoint"""
        info = {
            "service": "DNS Lookup Service (Fixed HTTP)",
            "version": "2.0.0-fixed-logic",
            "protocol": "HTTP",
            "description": "DNS record lookup service with corrected application logic",
            "architecture": "arm64",
            "endpoints": [
                "/health",
                "/ping", 
                "/" 
            ],
            "supported_formats": [
                {"dns_name": "example.com"},
                {"input": {"dns_name": "example.com"}},
                {"parameters": {"dns_name": "example.com"}}
            ],
            "proof_of_concept": "Testing theory that MCP was unnecessary - HTTP should work fine with fixed app logic"
        }
        self.send_json_response(200, info)

    def send_json_response(self, status_code, data):
        """Send JSON HTTP response"""
        try:
            response_json = json.dumps(data, indent=2)
            logger.info(f"Sending HTTP {status_code} response: {response_json}")
            
            self.send_response(status_code)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Content-Length', str(len(response_json)))
            self.end_headers()
            self.wfile.write(response_json.encode('utf-8'))
            
        except Exception as e:
            logger.error(f"Error sending HTTP response: {e}")

    def create_context(self):
        """Create a mock lambda context"""
        class MockContext:
            def __init__(self):
                self.function_name = "dns_lookup_http"
                self.function_version = "1"
                self.invoked_function_arn = "arn:aws:lambda:us-east-1:123456789012:function:dns_lookup_http"
                self.memory_limit_in_mb = 512
                self.remaining_time_in_millis = lambda: 30000
                self.aws_request_id = "test-http-request-id"
        
        return MockContext()

class DNSLookupHTTPServer:
    def __init__(self, host='0.0.0.0', port=8080):
        self.host = host
        self.port = port
        self.httpd = None
        self.shutdown_event = threading.Event()
    
    def start(self):
        """Start the HTTP DNS lookup server"""
        try:
            self.httpd = HTTPServer((self.host, self.port), DNSHandler)
            logger.info(f"Starting Fixed HTTP DNS Lookup Service on {self.host}:{self.port}")
            logger.info(f"Health check: http://{self.host}:{self.port}/health")
            logger.info(f"Service info: http://{self.host}:{self.port}/")
            logger.info(f"Protocol: HTTP (proving MCP was unnecessary)")
            logger.info(f"Theory: Fixed application logic should work with simple HTTP")
            
            # Start server in background thread
            def server_thread():
                while not self.shutdown_event.is_set():
                    try:
                        self.httpd.handle_request()
                    except Exception as e:
                        if not self.shutdown_event.is_set():
                            logger.error(f"Server error: {e}")
                        break
            
            threading.Thread(target=server_thread, daemon=True).start()
            
            # Wait for shutdown
            while not self.shutdown_event.is_set():
                time.sleep(1)
                
        except KeyboardInterrupt:
            logger.info("Received keyboard interrupt")
        except Exception as e:
            logger.error(f"Server error: {e}")
        finally:
            self.stop()
    
    def stop(self):
        """Stop the server gracefully"""
        logger.info("Stopping Fixed HTTP DNS Lookup Service...")
        if self.httpd:
            self.httpd.server_close()
        self.shutdown_event.set()

def signal_handler(signum, frame):
    """Handle shutdown signals"""
    logger.info(f"Received signal {signum}, shutting down...")
    if hasattr(signal_handler, 'server'):
        signal_handler.server.stop()

def main():
    """Main entry point"""
    # Set up signal handlers for graceful shutdown
    signal.signal(signal.SIGTERM, signal_handler)
    signal.signal(signal.SIGINT, signal_handler)
    
    # Get configuration from environment
    host = os.environ.get('HOST', '0.0.0.0')
    port = int(os.environ.get('PORT', '8080'))
    
    # Validate environment configuration
    required_env_vars = ['ENV']
    missing_vars = [var for var in required_env_vars if var not in os.environ]
    if missing_vars:
        logger.warning(f"Missing environment variables: {missing_vars}")
        # Set defaults for container execution
        os.environ.setdefault('ENV', 'production')
        os.environ.setdefault('APP_CONFIG_PATH', '/a208194/APISECRETS')
    
    # Create and start server
    try:
        server = DNSLookupHTTPServer(host, port)
        signal_handler.server = server  # Store reference for signal handler
        
        logger.info("Fixed HTTP DNS Lookup Service starting...")
        logger.info(f"Environment: {os.environ.get('ENV', 'unknown')}")
        logger.info(f"Config path: {os.environ.get('APP_CONFIG_PATH', 'unknown')}")
        logger.info(f"Protocol: HTTP (testing theory that MCP was unnecessary)")
        logger.info(f"Application Logic: FIXED (proper error handling)")
        
        server.start()
        
    except KeyboardInterrupt:
        logger.info("Received keyboard interrupt")
    except Exception as e:
        logger.error(f"Server startup failed: {e}")
        sys.exit(1)
    finally:
        logger.info("Fixed HTTP DNS Lookup Service stopped")

if __name__ == "__main__":
    main()