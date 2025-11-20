import json
import boto3

def lambda_handler(event, context):
    """
    MCP Wrapper for Existing Application Details Lambda
    Converts traditional Lambda responses to MCP format
    """
    
    try:
        # Initialize Lambda client
        lambda_client = boto3.client('lambda')
        
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
                # Handle tool call by wrapping existing Lambda
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
                    
                    # Call the existing Lambda function
                    try:
                        existing_response = call_existing_lambda(lambda_client, asset_id)
                        
                        # Convert response to MCP format
                        return convert_to_mcp_format(existing_response, request_id)
                        
                    except Exception as e:
                        return {
                            "jsonrpc": "2.0",
                            "result": {
                                "content": [
                                    {
                                        "type": "text",
                                        "text": f"Error calling application details service: {str(e)}"
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
        else:
            # Handle direct invocation (pass through to existing Lambda)
            return call_existing_lambda(lambda_client, event.get('asset_id', ''))
            
    except Exception as e:
        print(f"Wrapper error: {str(e)}")
        if 'method' in event:
            return {
                "jsonrpc": "2.0",
                "result": {
                    "content": [
                        {
                            "type": "text",
                            "text": f"Internal wrapper error: {str(e)}"
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


def call_existing_lambda(lambda_client, asset_id):
    """
    Call the existing application details Lambda
    """
    try:
        # Prepare payload for existing Lambda
        payload = {"asset_id": asset_id}
        
        # Invoke the existing Lambda function
        response = lambda_client.invoke(
            FunctionName="a208194-chatops_application_details_intent",
            Payload=json.dumps(payload)
        )
        
        # Parse response
        response_payload = json.loads(response['Payload'].read())
        
        return response_payload
        
    except Exception as e:
        print(f"Error calling existing Lambda: {str(e)}")
        raise e


def convert_to_mcp_format(lambda_response, request_id):
    """
    Convert traditional Lambda response to MCP format
    """
    try:
        # Handle different response formats
        
        # Case 1: Lambda returned successful response with body
        if 'body' in lambda_response:
            status_code = lambda_response.get('statusCode', 500)
            
            if status_code == 200:
                # Parse body
                try:
                    body = json.loads(lambda_response['body'])
                    response_text = format_response_body(body)
                    
                    return {
                        "jsonrpc": "2.0",
                        "result": {
                            "content": [
                                {
                                    "type": "text",
                                    "text": response_text
                                }
                            ],
                            "isError": False
                        },
                        "id": request_id
                    }
                except:
                    # Body is not JSON, use as string
                    return {
                        "jsonrpc": "2.0",
                        "result": {
                            "content": [
                                {
                                    "type": "text",
                                    "text": str(lambda_response['body'])
                                }
                            ],
                            "isError": False
                        },
                        "id": request_id
                    }
            else:
                # Error response
                try:
                    body = json.loads(lambda_response['body'])
                    error_text = body.get('error', f"HTTP {status_code} error")
                except:
                    error_text = f"HTTP {status_code}: {lambda_response.get('body', 'Unknown error')}"
                
                return {
                    "jsonrpc": "2.0",
                    "result": {
                        "content": [
                            {
                                "type": "text",
                                "text": f"Error: {error_text}"
                            }
                        ],
                        "isError": True
                    },
                    "id": request_id
                }
        
        # Case 2: Lambda returned error
        elif 'errorMessage' in lambda_response:
            return {
                "jsonrpc": "2.0",
                "result": {
                    "content": [
                        {
                            "type": "text",
                            "text": f"Lambda error: {lambda_response['errorMessage']}"
                        }
                    ],
                    "isError": True
                },
                "id": request_id
            }
        
        # Case 3: Direct response (no body wrapper)
        else:
            response_text = format_response_body(lambda_response)
            return {
                "jsonrpc": "2.0",
                "result": {
                    "content": [
                        {
                            "type": "text",
                            "text": response_text
                        }
                    ],
                    "isError": False
                },
                "id": request_id
            }
            
    except Exception as e:
        return {
            "jsonrpc": "2.0",
            "result": {
                "content": [
                    {
                        "type": "text",
                        "text": f"Error converting response: {str(e)}"
                    }
                ],
                "isError": True
            },
            "id": request_id
        }


def format_response_body(body):
    """
    Format response body into readable text
    """
    try:
        if isinstance(body, dict):
            # Check for common application details fields
            if 'application_name' in body:
                result = f"**Application Details**\n\n"
                result += f"• **Name**: {body.get('application_name', 'Unknown')}\n"
                
                if 'contact' in body:
                    result += f"• **Contact**: {body['contact']}\n"
                
                if 'regions' in body:
                    if isinstance(body['regions'], list):
                        regions = ', '.join(body['regions'])
                    else:
                        regions = str(body['regions'])
                    result += f"• **Regions**: {regions}\n"
                
                if 'environment' in body:
                    result += f"• **Environment**: {body['environment']}\n"
                
                return result
            
            # Check for success/error structure
            elif 'success' in body:
                if body['success']:
                    if 'data' in body:
                        return format_response_body(body['data'])
                    else:
                        return "Operation completed successfully"
                else:
                    error_msg = body.get('error', 'Unknown error')
                    return f"Error: {error_msg}"
            
            # Generic dict formatting
            else:
                result = ""
                for key, value in body.items():
                    result += f"• **{key.replace('_', ' ').title()}**: {value}\n"
                return result
                
        elif isinstance(body, str):
            return body
        else:
            return str(body)
            
    except Exception as e:
        return f"Error formatting response: {str(e)}"