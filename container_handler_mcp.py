#!/usr/bin/env python3
"""
MCP/JSON-RPC Compatible DNS Lookup Container Handler
Supports JSON-RPC 2.0 protocol for Agent Core Runtime MCP communication
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

class MCPDNSHandler(BaseHTTPRequestHandler):
    
    def log_message(self, format, *args):
        """Override to use our logger"""
        logger.info("%s - \"%s\" %s", self.address_string(), format % args, "")
    
    def do_GET(self):
        """Handle GET requests - health checks"""
        logger.info(f"=== INCOMING GET REQUEST ===")
        logger.info(f"Path: {self.path}")
        logger.info(f"Headers: {dict(self.headers)}")
        logger.info(f"================================")
        
        if self.path in ['/health', '/ping']:
            self.send_health_check()
        elif self.path == '/':
            self.send_service_info()
        else:
            logger.warning(f"GET 404: Path '{self.path}' not found")
            self.send_error(404, "Not Found")

    def do_POST(self):
        """Handle POST requests - MCP JSON-RPC calls"""
        logger.info(f"=== INCOMING POST REQUEST (MCP/JSON-RPC) ===")
        logger.info(f"Path: {self.path}")
        logger.info(f"Headers: {dict(self.headers)}")
        logger.info(f"Client: {self.client_address}")
        logger.info(f"============================================")
        
        # Handle as MCP JSON-RPC call
        self.handle_jsonrpc_call()
    
    def handle_jsonrpc_call(self):
        """Handle MCP JSON-RPC 2.0 calls"""
        try:
            logger.info("=== MCP JSON-RPC 2.0 CALL ===")
            
            # Read request body
            content_length = int(self.headers.get('Content-Length', 0))
            if content_length > 0:
                body = self.rfile.read(content_length)
                logger.info(f"Raw JSON-RPC body ({content_length} bytes): {body.decode('utf-8', errors='ignore')}")
                
                try:
                    # Parse JSON-RPC request
                    rpc_request = json.loads(body.decode('utf-8'))
                    logger.info(f"Parsed JSON-RPC request: {rpc_request}")
                    
                    # Validate JSON-RPC 2.0 format
                    if not isinstance(rpc_request, dict) or rpc_request.get('jsonrpc') != '2.0':
                        return self.send_jsonrpc_error(-32600, "Invalid Request", rpc_request.get('id'))
                    
                    # Extract method and parameters
                    method = rpc_request.get('method')
                    params = rpc_request.get('params', {})
                    request_id = rpc_request.get('id')
                    
                    logger.info(f"JSON-RPC method: {method}")
                    logger.info(f"JSON-RPC params: {params}")
                    logger.info(f"JSON-RPC id: {request_id}")
                    
                    # Handle different MCP methods
                    if method == 'tools/call':
                        # MCP tool call format
                        tool_name = params.get('name', 'dns_lookup')
                        arguments = params.get('arguments', {})
                        logger.info(f"MCP tool call - name: {tool_name}, arguments: {arguments}")
                        
                        # Extract dns_name from arguments
                        dns_name = arguments.get('dns_name', arguments.get('domain', 'microsoft.com'))
                        event = {"dns_name": dns_name}
                        
                    elif method == 'invoke' or method == 'call':
                        # Direct invocation
                        dns_name = params.get('dns_name', params.get('domain', 'microsoft.com'))
                        event = {"dns_name": dns_name}
                        
                    else:
                        # Try to extract dns_name from any parameter structure
                        if isinstance(params, dict):
                            dns_name = (params.get('dns_name') or 
                                       params.get('domain') or 
                                       params.get('input', {}).get('dns_name') or
                                       'microsoft.com')
                            event = {"dns_name": dns_name}
                        else:
                            event = {"dns_name": "microsoft.com"}
                    
                    logger.info(f"Extracted DNS event: {event}")
                    
                    # Create lambda context
                    context = self.create_context()
                    
                    # Call lambda handler
                    logger.info(f"Calling lambda_handler with event: {event}")
                    result = lambda_handler(event, context)
                    logger.info(f"Lambda handler result: {result}")
                    
                    # Return JSON-RPC 2.0 success response
                    if isinstance(result, dict) and 'body' in result:
                        # Lambda format response
                        body = json.loads(result['body']) if isinstance(result['body'], str) else result['body']
                        response_data = body
                    else:
                        # Direct response
                        response_data = result
                    
                    jsonrpc_response = {
                        "jsonrpc": "2.0",
                        "result": response_data,
                        "id": request_id
                    }
                    
                    self.send_jsonrpc_response(jsonrpc_response)
                    
                except json.JSONDecodeError as e:
                    logger.error(f"Failed to parse JSON-RPC request: {e}")
                    return self.send_jsonrpc_error(-32700, "Parse error", None)
                    
            else:
                logger.error("No body in JSON-RPC request")
                return self.send_jsonrpc_error(-32600, "Invalid Request", None)
                
        except Exception as e:
            logger.error(f"Error in JSON-RPC call: {e}")
            logger.error(f"Exception type: {type(e)}")
            import traceback
            logger.error(f"Traceback: {traceback.format_exc()}")
            
            return self.send_jsonrpc_error(-32603, f"Internal error: {str(e)}", None)
    
    def send_jsonrpc_response(self, response):
        """Send JSON-RPC 2.0 response"""
        try:
            response_json = json.dumps(response)
            logger.info(f"Sending JSON-RPC response: {response_json}")
            
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Content-Length', str(len(response_json)))
            self.end_headers()
            self.wfile.write(response_json.encode('utf-8'))
            
        except Exception as e:
            logger.error(f"Error sending JSON-RPC response: {e}")
    
    def send_jsonrpc_error(self, code, message, request_id):
        """Send JSON-RPC 2.0 error response"""
        try:
            error_response = {
                "jsonrpc": "2.0",
                "error": {
                    "code": code,
                    "message": message
                },
                "id": request_id
            }
            
            response_json = json.dumps(error_response)
            logger.info(f"Sending JSON-RPC error: {response_json}")
            
            self.send_response(200)  # JSON-RPC errors use 200 status
            self.send_header('Content-Type', 'application/json')
            self.send_header('Content-Length', str(len(response_json)))
            self.end_headers()
            self.wfile.write(response_json.encode('utf-8'))
            
        except Exception as e:
            logger.error(f"Error sending JSON-RPC error: {e}")

    def send_health_check(self):
        """Health check endpoint"""
        try:
            # Simple health check - try to import the lambda function
            import chatops_route_dns_intent
            health_status = {
                "status": "healthy",
                "service": "dns-lookup-service-mcp",
                "version": "1.0.0",
                "protocol": "MCP/JSON-RPC 2.0",
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
            "service": "DNS Lookup Service (MCP Compatible)",
            "version": "2.0.0",
            "protocol": "MCP/JSON-RPC 2.0",
            "description": "DNS record lookup service with MCP protocol support",
            "architecture": "arm64",
            "supported_methods": [
                "tools/call",
                "invoke",
                "call"
            ],
            "example_request": {
                "jsonrpc": "2.0",
                "method": "tools/call",
                "params": {
                    "name": "dns_lookup",
                    "arguments": {
                        "dns_name": "example.com"
                    }
                },
                "id": "1"
            }
        }
        self.send_json_response(200, info)

    def send_json_response(self, status_code, data):
        """Send JSON response"""
        try:
            response_json = json.dumps(data)
            self.send_response(status_code)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Content-Length', str(len(response_json)))
            self.end_headers()
            self.wfile.write(response_json.encode('utf-8'))
        except Exception as e:
            logger.error(f"Error sending JSON response: {e}")

    def create_context(self):
        """Create a mock lambda context for testing"""
        class MockContext:
            def __init__(self):
                self.function_name = "dns_lookup_mcp"
                self.function_version = "1"
                self.invoked_function_arn = "arn:aws:lambda:us-east-1:123456789012:function:dns_lookup_mcp"
                self.memory_limit_in_mb = 512
                self.remaining_time_in_millis = lambda: 30000
                self.aws_request_id = "test-request-id"
        
        return MockContext()

class DNSLookupMCPServer:
    def __init__(self, host='0.0.0.0', port=8080):
        self.host = host
        self.port = port
        self.httpd = None
        self.shutdown_event = threading.Event()
    
    def start(self):
        """Start the MCP DNS lookup server"""
        try:
            self.httpd = HTTPServer((self.host, self.port), MCPDNSHandler)
            logger.info(f"Starting MCP DNS Lookup Service on {self.host}:{self.port}")
            logger.info(f"Health check: http://{self.host}:{self.port}/health")
            logger.info(f"Service info: http://{self.host}:{self.port}/")
            logger.info(f"MCP Protocol: JSON-RPC 2.0")
            
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
        logger.info("Stopping MCP DNS Lookup Service...")
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
        server = DNSLookupMCPServer(host, port)
        signal_handler.server = server  # Store reference for signal handler
        
        logger.info("MCP DNS Lookup Service starting...")
        logger.info(f"Environment: {os.environ.get('ENV', 'unknown')}")
        logger.info(f"Config path: {os.environ.get('APP_CONFIG_PATH', 'unknown')}")
        logger.info(f"Protocol: MCP/JSON-RPC 2.0")
        
        server.start()
        
    except KeyboardInterrupt:
        logger.info("Received keyboard interrupt")
    except Exception as e:
        logger.error(f"Server startup failed: {e}")
        sys.exit(1)
    finally:
        logger.info("MCP DNS Lookup Service stopped")

if __name__ == "__main__":
    main()