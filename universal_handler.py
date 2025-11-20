#!/usr/bin/env python3
"""
Universal HTTP Handler - Catches ALL requests to ANY path
"""

import sys
import json
import time
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

class UniversalHandler(BaseHTTPRequestHandler):
    
    def log_message(self, format, *args):
        """Override to use our logger"""
        logger.info("%s - \"%s\" %s", self.address_string(), format % args, "")
    
    def log_request_details(self, method):
        """Log all request details"""
        logger.info(f"=== INCOMING {method} REQUEST ===")
        logger.info(f"Path: {self.path}")
        logger.info(f"Headers: {dict(self.headers)}")
        logger.info(f"Client: {self.client_address}")
        logger.info(f"Command: {self.command}")
        logger.info(f"Request version: {self.request_version}")
        logger.info(f"Raw path: {repr(self.path)}")
        
        # Try to read body for all requests
        content_length = int(self.headers.get('Content-Length', 0))
        if content_length > 0:
            try:
                body = self.rfile.read(content_length)
                logger.info(f"Request body: {body.decode('utf-8', errors='ignore')}")
                # Reset for later use
                self.rfile = type('MockFile', (), {'read': lambda x, n=0: body})()
            except Exception as e:
                logger.error(f"Error reading body: {e}")
        
        logger.info(f"=================================")
    
    def do_GET(self):
        """Handle ALL GET requests"""
        self.log_request_details("GET")
        
        if self.path == '/ping' or self.path == '/health':
            self.send_health_check()
        else:
            # Try to handle as DNS lookup anyway
            self.handle_universal_request()
    
    def do_POST(self):
        """Handle ALL POST requests"""
        self.log_request_details("POST")
        self.handle_universal_request()
    
    def do_PUT(self):
        """Handle ALL PUT requests"""
        self.log_request_details("PUT")
        self.handle_universal_request()
    
    def do_DELETE(self):
        """Handle ALL DELETE requests"""
        self.log_request_details("DELETE")
        self.handle_universal_request()
    
    def do_PATCH(self):
        """Handle ALL PATCH requests"""
        self.log_request_details("PATCH")
        self.handle_universal_request()
    
    def handle_universal_request(self):
        """Universal handler that tries to process any request as DNS lookup"""
        try:
            logger.info("=== UNIVERSAL HANDLER ===")
            
            # Try to extract DNS name from various sources
            dns_name = None
            
            # Check query parameters
            if '?' in self.path:
                parsed = urlparse(self.path)
                params = parse_qs(parsed.query)
                dns_name = params.get('dns_name', [None])[0]
                logger.info(f"Query param dns_name: {dns_name}")
            
            # Try to read request body
            content_length = int(self.headers.get('Content-Length', 0))
            if content_length > 0:
                try:
                    body = self.rfile.read(content_length)
                    body_text = body.decode('utf-8', errors='ignore')
                    logger.info(f"Processing body: {body_text}")
                    
                    # Try to parse as JSON
                    try:
                        data = json.loads(body_text)
                        # Look for dns_name in various locations
                        dns_name = (data.get('dns_name') or 
                                  data.get('input', {}).get('dns_name') or
                                  data.get('parameters', {}).get('dns_name') or
                                  dns_name)
                        logger.info(f"Extracted dns_name from JSON: {dns_name}")
                    except json.JSONDecodeError:
                        logger.info(f"Body is not JSON: {body_text}")
                        
                except Exception as e:
                    logger.error(f"Error reading body: {e}")
            
            # Default if no dns_name found
            if not dns_name:
                dns_name = "microsoft.com"
                logger.info(f"No dns_name found, using default: {dns_name}")
            
            # Create event for lambda handler
            event = {"dns_name": dns_name}
            context = self.create_context()
            
            logger.info(f"Calling lambda_handler with event: {event}")
            
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
            logger.error(f"Error in universal handler: {e}", exc_info=True)
            self.send_error_response(500, f"Universal handler error: {str(e)}")
    
    def send_health_check(self):
        """Health check endpoint"""
        try:
            health_status = {
                "status": "healthy",
                "service": "dns-lookup-service-universal",
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
    
    def send_json_response(self, status_code, data):
        """Send JSON response"""
        response_json = json.dumps(data, indent=2)
        self.send_response(status_code)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Content-Length', str(len(response_json)))
        self.end_headers()
        self.wfile.write(response_json.encode('utf-8'))
    
    def send_error_response(self, status_code, message):
        """Send error response"""
        error_data = {"error": message, "status": status_code}
        self.send_json_response(status_code, error_data)
    
    def create_context(self):
        """Create mock lambda context"""
        class MockContext:
            def __init__(self):
                self.aws_request_id = f"req-{int(time.time())}"
                self.function_name = 'dns-lookup'
                self.function_version = '1.0'
                self.remaining_time_in_millis = lambda: 30000
        
        return MockContext()

def main():
    """Main entry point"""
    logger.info("Starting Universal DNS Lookup Service...")
    logger.info("This handler will log ALL HTTP requests to ANY path")
    
    server = HTTPServer(('0.0.0.0', 8080), UniversalHandler)
    logger.info("Starting Universal HTTP server on 0.0.0.0:8080")
    logger.info("Listening for ALL HTTP methods on ALL paths")
    
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        logger.info("Shutting down server")
        server.shutdown()

if __name__ == "__main__":
    main()