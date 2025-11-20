import json
import boto3
import requests
from datetime import datetime

def lambda_handler(event, context):
    """
    MCP-Compatible Application Details Lambda
    Returns responses in MCP format for Agent Core Gateway
    """
    
    try:
        # Extract request details
        if 'method' in event:
            method = event['method']
            request_id = event.get('id', 1)
            
            if method == "tools/list":
                # Return available tools in MCP format
                return {
                    "jsonrpc": "2.0",
                    "result": {
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
                                    "required": ["asset_id"]
                                }
                            }
                        ]
                    },
                    "id": request_id
                }
                
            elif method == "tools/call":
                # Handle tool call
                params = event.get('params', {})
                tool_name = params.get('name', '')
                arguments = params.get('arguments', {})
                
                if tool_name == "get_application_details" or tool_name.endswith("get_application_details"):
                    asset_id = arguments.get('asset_id', '')
                    
                    if not asset_id:
                        return {
                            "jsonrpc": "2.0",
                            "result": {
                                "content": [
                                    {
                                        "type": "text",
                                        "text": "Error: asset_id is required"
                                    }
                                ],
                                "isError": True
                            },
                            "id": request_id
                        }
                    
                    # Get application details
                    app_details = get_application_details_from_api(asset_id)
                    
                    if app_details.get('success', False):
                        # Format success response in MCP format
                        details_text = format_application_details(app_details['data'])
                        return {
                            "jsonrpc": "2.0",
                            "result": {
                                "content": [
                                    {
                                        "type": "text",
                                        "text": details_text
                                    }
                                ],
                                "isError": False
                            },
                            "id": request_id
                        }
                    else:
                        # Format error response in MCP format
                        error_message = app_details.get('error', 'Unknown error occurred')
                        return {
                            "jsonrpc": "2.0",
                            "result": {
                                "content": [
                                    {
                                        "type": "text",
                                        "text": f"Error: {error_message}"
                                    }
                                ],
                                "isError": True
                            },
                            "id": request_id
                        }
                else:
                    return {
                        "jsonrpc": "2.0",
                        "error": {
                            "code": -32601,
                            "message": f"Unknown tool: {tool_name}"
                        },
                        "id": request_id
                    }
            else:
                return {
                    "jsonrpc": "2.0",
                    "error": {
                        "code": -32601,
                        "message": f"Unknown method: {method}"
                    },
                    "id": request_id
                }
        
        # Handle direct invocation (backward compatibility)
        else:
            asset_id = event.get('asset_id', '')
            if not asset_id:
                return {
                    "statusCode": 400,
                    "body": json.dumps({"error": "asset_id is required"})
                }
            
            app_details = get_application_details_from_api(asset_id)
            
            return {
                "statusCode": 200 if app_details.get('success') else 500,
                "body": json.dumps(app_details)
            }
            
    except Exception as e:
        print(f"Lambda error: {str(e)}")
        # Return MCP error format if request has method
        if 'method' in event:
            return {
                "jsonrpc": "2.0",
                "result": {
                    "content": [
                        {
                            "type": "text",
                            "text": f"Internal error: {str(e)}"
                        }
                    ],
                    "isError": True
                },
                "id": event.get('id', 1)
            }
        else:
            # Return traditional Lambda error
            return {
                "statusCode": 500,
                "body": json.dumps({"error": str(e)})
            }


def get_application_details_from_api(app_asset_id):
    """
    Get application details from the actual API
    """
    try:
        # Clean asset ID (remove 'a' prefix if present)
        clean_asset_id = app_asset_id.replace('a', '') if app_asset_id.startswith('a') else app_asset_id
        
        # Mock data for testing - replace with actual API call
        # In production, this would call your actual application details API
        if clean_asset_id == "208194":
            return {
                "success": True,
                "data": {
                    "asset_id": app_asset_id,
                    "application_name": "ChatOps Route DNS Service",
                    "contact": {
                        "primary": "devops-team@company.com",
                        "secondary": "platform-engineering@company.com"
                    },
                    "regions": ["us-east-1", "us-west-2", "eu-west-1"],
                    "environment": "production",
                    "last_updated": datetime.now().isoformat(),
                    "deployment_status": "active",
                    "health_status": "healthy"
                }
            }
        else:
            # Simulate API call for other asset IDs
            return {
                "success": True,
                "data": {
                    "asset_id": app_asset_id,
                    "application_name": f"Application {clean_asset_id}",
                    "contact": {
                        "primary": f"team-{clean_asset_id}@company.com"
                    },
                    "regions": ["us-east-1"],
                    "environment": "unknown",
                    "last_updated": datetime.now().isoformat()
                }
            }
            
    except Exception as e:
        return {
            "success": False,
            "error": f"Failed to fetch application details: {str(e)}"
        }


def format_application_details(data):
    """
    Format application details into a readable text response
    """
    try:
        result = f"**Application Details for {data['asset_id']}**\n\n"
        result += f"• **Name**: {data.get('application_name', 'Unknown')}\n"
        
        if 'contact' in data:
            contact = data['contact']
            if 'primary' in contact:
                result += f"• **Primary Contact**: {contact['primary']}\n"
            if 'secondary' in contact:
                result += f"• **Secondary Contact**: {contact['secondary']}\n"
        
        if 'regions' in data:
            regions = ', '.join(data['regions'])
            result += f"• **Regions**: {regions}\n"
            
        if 'environment' in data:
            result += f"• **Environment**: {data['environment']}\n"
            
        if 'deployment_status' in data:
            result += f"• **Status**: {data['deployment_status']}\n"
            
        if 'health_status' in data:
            result += f"• **Health**: {data['health_status']}\n"
            
        if 'last_updated' in data:
            result += f"• **Last Updated**: {data['last_updated']}\n"
            
        return result
        
    except Exception as e:
        return f"Error formatting details: {str(e)}"