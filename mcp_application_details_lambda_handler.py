import json
import boto3
import os
from typing import Dict, Any, List

def lambda_handler(event, context):
    """
    MCP-Compatible Application Details Lambda Function
    
    Provides application details including name, contact, and regional presence
    in proper MCP format for Agent Core Gateway integration.
    """
    
    try:
        # Check if this is an MCP protocol request
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
                    app_details = get_application_details(asset_id)
                    
                    return {
                        "jsonrpc": "2.0",
                        "result": {
                            "content": [
                                {
                                    "type": "text",
                                    "text": app_details
                                }
                            ],
                            "isError": False
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
        else:
            # Handle direct invocation (backward compatibility)
            asset_id = event.get('asset_id', '')
            if not asset_id:
                return {
                    "statusCode": 400,
                    "body": json.dumps({"error": "asset_id is required"})
                }
            
            app_details = get_application_details(asset_id)
            
            return {
                "statusCode": 200,
                "body": json.dumps({
                    "success": True,
                    "data": app_details
                })
            }
            
    except Exception as e:
        print(f"Lambda error: {str(e)}")
        
        # Return MCP-compatible error if this was an MCP request
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
            return {
                "statusCode": 500,
                "body": json.dumps({"error": str(e)})
            }


def get_application_details(asset_id: str) -> str:
    """
    Retrieve application details for a given asset ID
    
    Args:
        asset_id: Application asset ID (with or without 'a' prefix)
    
    Returns:
        Formatted string with application details
    """
    
    # Normalize asset ID (remove 'a' prefix if present)
    normalized_id = asset_id.lower().replace('a', '') if asset_id.lower().startswith('a') else asset_id
    
    try:
        # Mock data - replace this with your actual data source
        # This could be DynamoDB, RDS, API calls, etc.
        
        application_data = get_application_from_data_source(normalized_id)
        
        if not application_data:
            return f"❌ **Application Not Found**\n\nNo application found with asset ID: {asset_id}"
        
        # Format the response
        result = "✅ **Application Details**\n\n"
        result += f"• **Asset ID**: {asset_id}\n"
        result += f"• **Name**: {application_data.get('name', 'Unknown')}\n"
        
        if 'contact' in application_data:
            contact = application_data['contact']
            if isinstance(contact, dict):
                result += f"• **Contact**: {contact.get('email', '')} ({contact.get('name', '')})\n"
            else:
                result += f"• **Contact**: {contact}\n"
        
        if 'regions' in application_data:
            regions = application_data['regions']
            if isinstance(regions, list):
                regions_str = ', '.join(regions)
            else:
                regions_str = str(regions)
            result += f"• **Regions**: {regions_str}\n"
        
        if 'environment' in application_data:
            result += f"• **Environment**: {application_data['environment']}\n"
        
        if 'description' in application_data:
            result += f"• **Description**: {application_data['description']}\n"
        
        if 'last_updated' in application_data:
            result += f"• **Last Updated**: {application_data['last_updated']}\n"
        
        return result
        
    except Exception as e:
        print(f"Error retrieving application details: {str(e)}")
        return f"❌ **Error**\n\nUnable to retrieve application details: {str(e)}"


def get_application_from_data_source(asset_id: str) -> Dict[str, Any]:
    """
    Retrieve application data from your data source
    
    Replace this implementation with your actual data source logic:
    - DynamoDB table lookup
    - RDS database query
    - External API call
    - S3 configuration file
    - Parameter Store values
    
    Args:
        asset_id: Normalized asset ID
    
    Returns:
        Dictionary with application details or None if not found
    """
    
    # Example implementation using DynamoDB
    # Uncomment and modify based on your data source
    
    """
    try:
        dynamodb = boto3.resource('dynamodb')
        table = dynamodb.Table(os.environ.get('APPLICATIONS_TABLE', 'applications'))
        
        response = table.get_item(Key={'asset_id': asset_id})
        
        if 'Item' in response:
            return dict(response['Item'])
        else:
            return None
            
    except Exception as e:
        print(f"DynamoDB error: {str(e)}")
        return None
    """
    
    # Mock data for demonstration - replace with your actual data source
    mock_applications = {
        "123456": {
            "name": "ChatOps Route DNS Service",
            "contact": {
                "name": "DevOps Team",
                "email": "devops@company.com"
            },
            "regions": ["us-east-1", "us-west-2", "eu-west-1"],
            "environment": "production",
            "description": "DNS routing service for ChatOps operations",
            "last_updated": "2025-11-15T10:30:00Z"
        },
        "234567": {
            "name": "Application Gateway",
            "contact": {
                "name": "Platform Team",
                "email": "platform@company.com"
            },
            "regions": ["us-east-1"],
            "environment": "production",
            "description": "Application gateway for microservices",
            "last_updated": "2025-11-14T15:45:00Z"
        },
        "345678": {
            "name": "Analytics Dashboard",
            "contact": {
                "name": "Data Team",
                "email": "data@company.com"
            },
            "regions": ["us-west-2"],
            "environment": "staging",
            "description": "Real-time analytics and reporting dashboard",
            "last_updated": "2025-11-13T09:15:00Z"
        }
    }
    
    return mock_applications.get(asset_id)


# Additional utility functions for extended functionality
def validate_asset_id(asset_id: str) -> bool:
    """Validate asset ID format"""
    if not asset_id:
        return False
    
    # Remove 'a' prefix if present
    normalized = asset_id.lower().replace('a', '') if asset_id.lower().startswith('a') else asset_id
    
    # Check if remaining part is numeric and reasonable length
    return normalized.isdigit() and len(normalized) >= 3 and len(normalized) <= 10


def get_application_summary(asset_ids: List[str]) -> str:
    """Get summary for multiple applications"""
    summaries = []
    
    for asset_id in asset_ids:
        if validate_asset_id(asset_id):
            details = get_application_details(asset_id)
            summaries.append(details)
        else:
            summaries.append(f"❌ Invalid asset ID: {asset_id}")
    
    return "\n\n" + "="*50 + "\n\n".join(summaries)