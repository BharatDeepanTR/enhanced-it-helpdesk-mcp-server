#!/usr/bin/env python3
"""
Enterprise MCP Application Details Server
Follows enterprise patterns:
- Single responsibility (application details only)
- MCP-compatible responses
- Proper error handling
- Logging and monitoring
- Clean separation from calculator logic
"""

import json
import logging
import requests
from typing import Dict, List, Any, Optional

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class ApplicationDetailsMCPServer:
    """
    Enterprise MCP Server for Application Details
    Follows single responsibility principle
    """
    
    def __init__(self):
        self.server_info = {
            "name": "application-details-mcp-server",
            "version": "1.0.0",
            "description": "Enterprise application details lookup service"
        }
    
    def get_application_details_from_api(self, app_asset_id: str) -> Dict[str, Any]:
        """
        Get application details from backend API
        Enterprise pattern: Separate data access logic
        """
        try:
            # Remove 'a' prefix if present
            clean_asset_id = app_asset_id.lstrip('a')
            
            # In enterprise: This would call your actual API/database
            # For now, using mock data
            mock_data = {
                "208194": {
                    "application_name": "ChatOps Route DNS",
                    "contact_email": "team-devops@company.com",
                    "environment": "production",
                    "regions": ["us-east-1", "eu-west-1"],
                    "status": "active",
                    "last_updated": "2025-11-15"
                },
                "12345": {
                    "application_name": "Sample Application",
                    "contact_email": "team-sample@company.com", 
                    "environment": "staging",
                    "regions": ["us-west-2"],
                    "status": "active",
                    "last_updated": "2025-11-10"
                }
            }
            
            if clean_asset_id in mock_data:
                return {
                    "success": True,
                    "data": mock_data[clean_asset_id],
                    "asset_id": clean_asset_id
                }
            else:
                return {
                    "success": False,
                    "error": f"Application with asset ID {clean_asset_id} not found",
                    "asset_id": clean_asset_id
                }
                
        except Exception as e:
            logger.error(f"Error fetching application details: {e}")
            return {
                "success": False,
                "error": f"Internal error: {str(e)}",
                "asset_id": app_asset_id
            }
    
    def handle_get_application_details(self, arguments: Dict[str, Any]) -> List[Dict[str, str]]:
        """
        Handle application details request
        Returns MCP-compatible response format
        """
        try:
            asset_id = arguments.get("asset_id", "").strip()
            
            if not asset_id:
                return [
                    {
                        "type": "text",
                        "text": "❌ Error: asset_id parameter is required"
                    }
                ]
            
            logger.info(f"Processing application details request for asset_id: {asset_id}")
            
            # Get application details
            result = self.get_application_details_from_api(asset_id)
            
            if result["success"]:
                data = result["data"]
                response_text = f"""📋 Application Details for Asset ID: {result['asset_id']}

🏷️  Application Name: {data['application_name']}
📧 Contact Email: {data['contact_email']}
🌍 Environment: {data['environment']}
🗺️  Regions: {', '.join(data['regions'])}
📊 Status: {data['status']}
📅 Last Updated: {data['last_updated']}"""
                
                return [
                    {
                        "type": "text",
                        "text": response_text
                    }
                ]
            else:
                return [
                    {
                        "type": "text", 
                        "text": f"❌ {result['error']}"
                    }
                ]
                
        except Exception as e:
            logger.error(f"Error handling application details request: {e}")
            return [
                {
                    "type": "text",
                    "text": f"❌ Internal error processing request: {str(e)}"
                }
            ]

def lambda_handler(event, context):
    """
    AWS Lambda entry point
    Enterprise pattern: Clean separation of AWS Lambda logic from business logic
    """
    try:
        logger.info(f"Received event: {json.dumps(event, default=str)}")
        
        # Initialize MCP server
        mcp_server = ApplicationDetailsMCPServer()
        
        # Handle tools/list request
        if isinstance(event, dict) and event.get("method") == "tools/list":
            return {
                "tools": [
                    {
                        "name": "get_application_details",
                        "description": "Get application details including name, contact, and regional presence for a given asset ID",
                        "inputSchema": {
                            "type": "object",
                            "properties": {
                                "asset_id": {
                                    "type": "string",
                                    "description": "The application asset ID (can include 'a' prefix, e.g., 'a12345' or '12345')"
                                }
                            },
                            "required": ["asset_id"],
                            "additionalProperties": False
                        }
                    }
                ]
            }
        
        # Handle tools/call request
        if isinstance(event, dict) and event.get("method") == "tools/call":
            params = event.get("params", {})
            tool_name = params.get("name", "")
            arguments = params.get("arguments", {})
            
            if tool_name == "get_application_details":
                return mcp_server.handle_get_application_details(arguments)
        
        # Handle direct invocation (for backwards compatibility)
        if isinstance(event, dict) and "asset_id" in event:
            return mcp_server.handle_get_application_details(event)
        
        # Default error response
        return [
            {
                "type": "text",
                "text": "❌ Unsupported request format. Use tools/list or tools/call methods."
            }
        ]
        
    except Exception as e:
        logger.error(f"Lambda handler error: {e}")
        return [
            {
                "type": "text", 
                "text": f"❌ Lambda execution error: {str(e)}"
            }
        ]

# For local testing
if __name__ == "__main__":
    # Test the MCP server locally
    test_events = [
        {"method": "tools/list"},
        {
            "method": "tools/call",
            "params": {
                "name": "get_application_details",
                "arguments": {"asset_id": "a208194"}
            }
        },
        {"asset_id": "208194"}  # Direct invocation
    ]
    
    for i, event in enumerate(test_events, 1):
        print(f"\n{'='*50}")
        print(f"Test {i}: {event}")
        print(f"{'='*50}")
        result = lambda_handler(event, None)
        print(json.dumps(result, indent=2))