#!/usr/bin/env python3
"""
Simple DNS Handler - Minimal working implementation for Agent Core Runtime
"""

import json
import socket
import logging
from http.server import HTTPServer, BaseHTTPRequestHandler

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class SimpleDNSHandler(BaseHTTPRequestHandler):
    
    def log_message(self, format, *args):
        """Override to use our logger"""
        logger.info("%s - %s", self.address_string(), format % args)
    
    def do_GET(self):
        """Handle GET requests"""
        if self.path in ['/ping', '/health']:
            self.send_health_response()
        else:
            self.send_error_response(404, "Not Found")
    
    def do_POST(self):
        """Handle POST requests - main invocation endpoint"""
        try:
            # Read request body
            content_length = int(self.headers.get('Content-Length', 0))
            if content_length > 0:
                body = self.rfile.read(content_length)
                body_text = body.decode('utf-8')
                logger.info(f"Received POST request: {body_text}")
                
                # Parse JSON
                try:
                    data = json.loads(body_text)
                    dns_name = data.get('dns_name')
                    
                    if dns_name:
                        # Perform DNS lookup
                        result = self.lookup_dns(dns_name)
                        self.send_json_response(200, result)
                    else:
                        self.send_error_response(400, "Missing dns_name parameter")
                        
                except json.JSONDecodeError as e:
                    logger.error(f"JSON decode error: {e}")
                    self.send_error_response(400, f"Invalid JSON: {str(e)}")
            else:
                self.send_error_response(400, "Empty request body")
                
        except Exception as e:
            logger.error(f"Error processing POST request: {e}", exc_info=True)
            self.send_error_response(500, f"Internal error: {str(e)}")
    
    def lookup_dns(self, dns_name):
        """Perform DNS lookup"""
        try:
            logger.info(f"Looking up DNS for: {dns_name}")
            ip_addresses = socket.gethostbyname_ex(dns_name)[2]
            
            result = {
                "domain": dns_name,
                "ip_addresses": ip_addresses,
                "status": "success"
            }
            logger.info(f"DNS lookup result: {result}")
            return result
            
        except socket.gaierror as e:
            logger.error(f"DNS lookup failed for {dns_name}: {e}")
            return {
                "domain": dns_name,
                "error": str(e),
                "status": "failed"
            }
    
    def send_health_response(self):
        """Send health check response"""
        health_data = {
            "status": "healthy",
            "service": "simple-dns-lookup",
            "version": "1.0.0"
        }
        self.send_json_response(200, health_data)
    
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

def main():
    """Main entry point"""
    logger.info("Starting Simple DNS Lookup Service...")
    
    server = HTTPServer(('0.0.0.0', 8080), SimpleDNSHandler)
    logger.info("HTTP server listening on 0.0.0.0:8080")
    
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        logger.info("Shutting down server")
        server.shutdown()

if __name__ == "__main__":
    main()