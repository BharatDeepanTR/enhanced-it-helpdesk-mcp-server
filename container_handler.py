#!/usr/bin/env python3
"""
Enhanced DNS Lookup Container Handler
Supports both HTTP and Lambda-style invocations for Agent Core Runtime
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
        """Handle GET requests"""
        logger.info(f"=== INCOMING GET REQUEST ===")
        logger.info(f"Path: {self.path}")
        logger.info(f"Headers: {dict(self.headers)}")
        logger.info(f"Client: {self.client_address}")
        logger.info(f"Command: {self.command}")
        logger.info(f"Request version: {self.request_version}")
        logger.info(f"================================")
        
        if self.path == '/health' or self.path == '/ping':
            self.send_health_check()
        elif self.path == '/':
            self.send_service_info()
        elif self.path.startswith('/lookup'):
            self.handle_get_lookup()
        elif self.path == '/invoke':
            # Agent Core Runtime might use /invoke endpoint
            self.handle_lambda_style_invoke()
        else:
            logger.warning(f"GET 404: Path '{self.path}' not found")
            self.send_error(404, "Not Found")

    def do_POST(self):
        """Handle POST requests - Accept ANY path"""
        logger.info(f"=== INCOMING POST REQUEST ===")
        logger.info(f"Path: {self.path}")
        logger.info(f"Headers: {dict(self.headers)}")
        logger.info(f"Client: {self.client_address}")
        logger.info(f"Command: {self.command}")
        logger.info(f"Request version: {self.request_version}")
        logger.info(f"=================================")
        
        # Agent Core Runtime might use different paths - handle ALL POST requests
        logger.info(f"DEBUG: Handling POST to '{self.path}' as Agent Core Runtime invocation")
        self.handle_agent_core_runtime_invoke()
    
    def handle_agent_core_runtime_invoke(self):
        """Handle Agent Core Runtime invocation - simplified and robust"""
        try:
            logger.info("=== AGENT CORE RUNTIME INVOCATION ===")
            
            # Read request body
            content_length = int(self.headers.get('Content-Length', 0))
            if content_length > 0:
                body = self.rfile.read(content_length)
                logger.info(f"Raw request body ({content_length} bytes): {body.decode('utf-8', errors='ignore')}")
                
                try:
                    # Try to parse as JSON event
                    event = json.loads(body.decode('utf-8'))
                    logger.info(f"Parsed event: {event}")
                except json.JSONDecodeError as e:
                    logger.error(f"Failed to parse event JSON: {e}")
                    # Agent Core Runtime might send a different format - try to extract dns_name
                    body_str = body.decode('utf-8', errors='ignore')
                    if 'microsoft.com' in body_str:
                        event = {"dns_name": "microsoft.com"}
                    elif 'dns_name' in body_str:
                        # Try to extract dns_name from any format
                        import re
                        match = re.search(r'"dns_name"\s*:\s*"([^"]+)"', body_str)
                        if match:
                            event = {"dns_name": match.group(1)}
                        else:
                            event = {"dns_name": "microsoft.com"}  # Fallback
                    else:
                        event = {"dns_name": "microsoft.com"}  # Default fallback
                        
                    logger.info(f"Using fallback event: {event}")
            else:
                # No body, create default event
                event = {"dns_name": "microsoft.com"}
                logger.info("No body provided, using default event")
            
            # Create lambda context
            context = self.create_context()
            
            # Call lambda handler
            logger.info(f"Calling lambda_handler with event: {event}")
            result = lambda_handler(event, context)
            logger.info(f"Lambda handler result: {result}")
            
            # Return result in the format Agent Core Runtime expects
            if isinstance(result, dict) and 'body' in result:
                # Lambda response format
                body = json.loads(result['body']) if isinstance(result['body'], str) else result['body']
                status_code = result.get('statusCode', 200)
                
                # Send response
                self.send_response(status_code)
                self.send_header('Content-Type', 'application/json')
                self.end_headers()
                self.wfile.write(json.dumps(body).encode('utf-8'))
                logger.info(f"Sent response: {status_code} {json.dumps(body)}")
            else:
                # Direct result format
                self.send_response(200)
                self.send_header('Content-Type', 'application/json')
                self.end_headers()
                self.wfile.write(json.dumps(result).encode('utf-8'))
                logger.info(f"Sent direct response: 200 {json.dumps(result)}")
                
        except Exception as e:
            logger.error(f"Error in Agent Core Runtime invocation: {e}")
            logger.error(f"Exception type: {type(e)}")
            import traceback
            logger.error(f"Traceback: {traceback.format_exc()}")
            
            # Send error response
            self.send_response(500)
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            error_response = {"error": f"Agent Core Runtime invocation error: {str(e)}"}
            self.wfile.write(json.dumps(error_response).encode('utf-8'))
            
    def handle_lambda_style_invoke(self):
        """Handle Lambda-style invocation that Agent Core Runtime might use"""
        try:
            logger.info("=== LAMBDA-STYLE INVOCATION ===")
            
            # Read request body
            content_length = int(self.headers.get('Content-Length', 0))
            if content_length > 0:
                body = self.rfile.read(content_length)
                logger.info(f"Lambda invocation body: {body.decode('utf-8', errors='ignore')}")
                
                try:
                    # Try to parse as JSON event
                    event = json.loads(body.decode('utf-8'))
                    logger.info(f"Parsed event: {event}")
                except json.JSONDecodeError as e:
                    logger.error(f"Failed to parse event JSON: {e}")
                    event = {"dns_name": "microsoft.com"}  # Fallback
            else:
                # No body, create default event
                event = {"dns_name": "microsoft.com"}
                logger.info("No body provided, using default event")
            
            # Create lambda context
            context = self.create_context()
            
            # Call lambda handler
            result = lambda_handler(event, context)
            logger.info(f"Lambda handler result: {result}")
            
            # Return result
            if isinstance(result, dict) and 'body' in result:
                body = json.loads(result['body']) if isinstance(result['body'], str) else result['body']
                status_code = result.get('statusCode', 200)
                self.send_json_response(status_code, body)
            else:
                self.send_json_response(200, result)
                
        except Exception as e:
            logger.error(f"Error in lambda-style invocation: {e}")
            self.send_error_response(500, f"Lambda invocation error: {str(e)}")
            
    def do_PUT(self):
        """Handle PUT requests - log and reject"""
        logger.info(f"=== UNEXPECTED PUT REQUEST ===")
        logger.info(f"Path: {self.path}")
        logger.info(f"Headers: {dict(self.headers)}")
        logger.info(f"===============================")
        self.send_error(405, "Method Not Allowed")
        
    def do_DELETE(self):
        """Handle DELETE requests - log and reject"""
        logger.info(f"=== UNEXPECTED DELETE REQUEST ===")
        logger.info(f"Path: {self.path}")
        logger.info(f"Headers: {dict(self.headers)}")
        logger.info(f"==================================")
        self.send_error(405, "Method Not Allowed")

    def send_health_check(self):
        """Health check endpoint"""
        try:
            # Simple health check - try to import the lambda function
            import chatops_route_dns_intent
            health_status = {
                "status": "healthy",
                "service": "dns-lookup-service",
                "version": "1.0.0",
                "timestamp": time.time()
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
            "service": "DNS Lookup Service",
            "version": "1.0.0",
            "description": "DNS record lookup service without Lex dependencies",
            "architecture": "arm64",
            "endpoints": {
                "/health": "Health check",
                "/lookup": "DNS lookup (POST with JSON body)",
                "/lookup?dns_name=example.com": "DNS lookup (GET with query parameter)"
            },
            "example_request": {
                "method": "POST",
                "url": "/lookup",
                "body": {"dns_name": "example.com"}
            }
        }
        self.send_json_response(200, info)
    
    def handle_get_lookup(self):
        """Handle GET request with query parameter"""
        try:
            parsed_url = urlparse(self.path)
            query_params = parse_qs(parsed_url.query)
            
            dns_name = query_params.get('dns_name', [None])[0]
            if not dns_name:
                self.send_error_response(400, "Missing dns_name parameter")
                return
            
            # Create lambda event format
            event = {"dns_name": dns_name}
            context = self.create_context()
            
            # Call lambda handler
            result = lambda_handler(event, context)
            
            # Extract and return the response
            if isinstance(result, dict) and 'body' in result:
                body = json.loads(result['body']) if isinstance(result['body'], str) else result['body']
                self.send_json_response(result.get('statusCode', 200), body)
            else:
                self.send_json_response(200, result)
                
        except Exception as e:
            logger.error(f"Error handling GET lookup: {e}")
            self.send_error_response(500, f"Internal server error: {str(e)}")
    
    def handle_post_lookup(self):
        """Handle POST request with JSON body"""
        try:
            logger.info(f"=== PROCESSING POST LOOKUP REQUEST ===")
            # Read request body
            content_length = int(self.headers.get('Content-Length', 0))
            logger.info(f"Content-Length: {content_length}")
            
            if content_length > 10000:  # Limit request size
                logger.warning(f"Request too large: {content_length} bytes")
                self.send_error_response(413, "Request too large")
                return

            if content_length == 0:
                logger.warning("Empty request body")
                self.send_error_response(400, "Empty request body")
                return

            body = self.rfile.read(content_length)
            logger.info(f"Raw request body: {body}")
            logger.info(f"Request body (decoded): {body.decode('utf-8')}")

            # Parse JSON
            try:
                request_data = json.loads(body.decode('utf-8'))
                logger.info(f"Parsed JSON request: {request_data}")
            except json.JSONDecodeError as e:
                logger.error(f"JSON decode error: {str(e)}")
                self.send_error_response(400, f"Invalid JSON: {str(e)}")
                return

            # Validate input
            if not isinstance(request_data, dict):
                logger.error(f"Request data is not a dict: {type(request_data)}")
                self.send_error_response(400, "Request body must be a JSON object")
                return

            # Create lambda event
            event = request_data
            logger.info(f"Lambda event created: {event}")
            context = self.create_context()

            # Call lambda handler
            logger.info("Calling lambda_handler...")
            result = lambda_handler(event, context)
            logger.info(f"Lambda handler result: {result}")            # Extract and return the response
            if isinstance(result, dict) and 'body' in result:
                body = json.loads(result['body']) if isinstance(result['body'], str) else result['body']
                self.send_json_response(result.get('statusCode', 200), body)
            else:
                self.send_json_response(200, result)
                
        except Exception as e:
            logger.error(f"Error handling POST lookup: {e}")
            self.send_error_response(500, f"Internal server error: {str(e)}")
    
    def create_context(self):
        """Create a mock AWS Lambda context"""
        class MockContext:
            def __init__(self):
                self.function_name = "dns-lookup-service"
                self.function_version = "1.0.0"
                self.invoked_function_arn = "arn:aws:lambda:container:dns-lookup"
                self.memory_limit_in_mb = "512"
                self.remaining_time_in_millis = lambda: 30000
                self.log_group_name = "/aws/lambda/dns-lookup-service"
                self.log_stream_name = "container-stream"
                self.aws_request_id = f"container-{int(time.time())}"
        
        return MockContext()
    
    def send_json_response(self, status_code, data):
        """Send JSON response"""
        response_body = json.dumps(data, indent=2)
        
        self.send_response(status_code)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Content-Length', str(len(response_body)))
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type')
        self.end_headers()
        
        self.wfile.write(response_body.encode('utf-8'))
    
    def send_error_response(self, status_code, message):
        """Send error response"""
        error_data = {
            "success": False,
            "error": message,
            "status_code": status_code,
            "timestamp": time.time()
        }
        self.send_json_response(status_code, error_data)
    
    def do_OPTIONS(self):
        """Handle CORS preflight requests"""
        self.send_response(200)
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type')
        self.end_headers()

class DNSLookupServer:
    """HTTP server for DNS lookup service"""
    
    def __init__(self, host='0.0.0.0', port=8080):
        self.host = host
        self.port = port
        self.server = None
        self.server_thread = None
        self.shutdown_event = threading.Event()
    
    def start(self):
        """Start the HTTP server"""
        try:
            self.server = HTTPServer((self.host, self.port), DNSHandler)
            logger.info(f"Starting DNS Lookup Service on {self.host}:{self.port}")
            logger.info(f"Health check: http://{self.host}:{self.port}/health")
            logger.info(f"Service info: http://{self.host}:{self.port}/")
            logger.info(f"DNS lookup: http://{self.host}:{self.port}/lookup")
            
            # Start server in a separate thread
            self.server_thread = threading.Thread(target=self._run_server)
            self.server_thread.daemon = True
            self.server_thread.start()
            
            # Wait for shutdown signal
            self.shutdown_event.wait()
            
        except Exception as e:
            logger.error(f"Failed to start server: {e}")
            raise
    
    def _run_server(self):
        """Run the HTTP server"""
        try:
            self.server.serve_forever()
        except Exception as e:
            logger.error(f"Server error: {e}")
        finally:
            logger.info("Server stopped")
    
    def stop(self):
        """Stop the HTTP server"""
        logger.info("Shutting down server...")
        if self.server:
            self.server.shutdown()
            self.server.server_close()
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
        os.environ.setdefault('APP_CONFIG_PATH', '/config')
    
    # Create and start server
    try:
        server = DNSLookupServer(host, port)
        signal_handler.server = server  # Store reference for signal handler
        
        logger.info("DNS Lookup Service starting...")
        logger.info(f"Environment: {os.environ.get('ENV', 'unknown')}")
        logger.info(f"Config path: {os.environ.get('APP_CONFIG_PATH', 'unknown')}")
        
        server.start()
        
    except KeyboardInterrupt:
        logger.info("Received keyboard interrupt")
    except Exception as e:
        logger.error(f"Server startup failed: {e}")
        sys.exit(1)
    finally:
        logger.info("DNS Lookup Service stopped")

if __name__ == "__main__":
    main()