import json
import boto3
import os
from typing import Dict, Any, List

# FORCE us-east-1 region for all AWS operations
os.environ['AWS_DEFAULT_REGION'] = 'us-east-1'
os.environ['AWS_REGION'] = 'us-east-1'

def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """
    AI Calculator MCP Server Lambda Function
    Fixed with explicit us-east-1 region enforcement
    """
    
    # Initialize Bedrock client with explicit region configuration
    bedrock_client = boto3.client(
        'bedrock-runtime',
        region_name='us-east-1'  # Explicitly set region
    )
    
    # Use inference profile format for Claude 3.5 Sonnet
    model_id = "us.anthropic.claude-3-5-sonnet-20241022-v2:0"  # Inference profile format
    
    # Log region information for debugging
    print(f"AWS_DEFAULT_REGION: {os.environ.get('AWS_DEFAULT_REGION', 'NOT_SET')}")
    print(f"AWS_REGION: {os.environ.get('AWS_REGION', 'NOT_SET')}")
    print(f"Bedrock client region: {bedrock_client._client_config.region_name}")
    print(f"Using model ID: {model_id}")
    
    try:
        # Parse the MCP JSON-RPC request
        if not isinstance(event, dict) or 'method' not in event:
            return create_error_response(event.get('id', 'unknown'), -32600, "Invalid Request")
        
        method = event.get('method')
        params = event.get('params', {})
        request_id = event.get('id', 'unknown')
        
        # Handle different MCP methods
        if method == "initialize":
            return {
                "jsonrpc": "2.0",
                "id": request_id,
                "result": {
                    "protocolVersion": "2024-11-05",
                    "capabilities": {
                        "tools": {}
                    },
                    "serverInfo": {
                        "name": "ai-calculator-mcp",
                        "version": "1.0.0"
                    }
                }
            }
        
        elif method == "tools/list":
            return {
                "jsonrpc": "2.0",
                "id": request_id,
                "result": {
                    "tools": [
                        {
                            "name": "ai_calculate",
                            "description": "AI-powered calculator that can handle natural language math queries, complex calculations, and provide step-by-step explanations",
                            "inputSchema": {
                                "type": "object",
                                "properties": {
                                    "query": {
                                        "type": "string",
                                        "description": "Natural language math query (e.g., 'What is 15% of $50,000?', 'Calculate compound interest for 5 years at 4.5%')"
                                    }
                                },
                                "required": ["query"]
                            }
                        },
                        {
                            "name": "explain_calculation",
                            "description": "Explain mathematical concepts and provide step-by-step solutions for given calculations",
                            "inputSchema": {
                                "type": "object",
                                "properties": {
                                    "calculation": {
                                        "type": "string",
                                        "description": "Mathematical expression or problem to explain (e.g., '25 + 4', 'quadratic formula')"
                                    }
                                },
                                "required": ["calculation"]
                            }
                        },
                        {
                            "name": "solve_word_problem",
                            "description": "Solve mathematical word problems with detailed explanations",
                            "inputSchema": {
                                "type": "object",
                                "properties": {
                                    "problem": {
                                        "type": "string",
                                        "description": "Mathematical word problem to solve"
                                    }
                                },
                                "required": ["problem"]
                            }
                        }
                    ]
                }
            }
        
        elif method == "tools/call":
            tool_name = params.get('name')
            arguments = params.get('arguments', {})
            
            if tool_name == "ai_calculate":
                query = arguments.get('query', '')
                result = call_bedrock_claude(bedrock_client, model_id, f"Please solve this mathematical problem and provide a clear answer: {query}")
                return create_success_response(request_id, result)
            
            elif tool_name == "explain_calculation":
                calculation = arguments.get('calculation', '')
                result = call_bedrock_claude(bedrock_client, model_id, f"Please explain this mathematical calculation step by step: {calculation}")
                return create_success_response(request_id, result)
            
            elif tool_name == "solve_word_problem":
                problem = arguments.get('problem', '')
                result = call_bedrock_claude(bedrock_client, model_id, f"Please solve this word problem step by step: {problem}")
                return create_success_response(request_id, result)
            
            else:
                return create_error_response(request_id, -32601, f"Unknown tool: {tool_name}")
        
        else:
            return create_error_response(request_id, -32601, f"Unknown method: {method}")
    
    except Exception as e:
        print(f"Error: {str(e)}")
        return create_error_response(event.get('id', 'unknown'), -32603, f"Internal error: {str(e)}")


def call_bedrock_claude(client, model_id: str, prompt: str) -> str:
    """
    Call Bedrock Claude model with proper API format and inference profile
    """
    try:
        # Correct Claude 3.5 Sonnet API format
        request_body = {
            "anthropic_version": "bedrock-2023-05-31",
            "max_tokens": 2000,
            "messages": [
                {
                    "role": "user",
                    "content": prompt
                }
            ],
            "temperature": 0.1,
            "top_p": 0.9
        }
        
        # Convert to JSON
        body = json.dumps(request_body)
        
        print(f"Making Bedrock API call to model: {model_id} in region: {client._client_config.region_name}")
        
        # Make the Bedrock API call with inference profile
        response = client.invoke_model(
            modelId=model_id,  # Using inference profile format
            body=body,
            contentType="application/json",
            accept="application/json"
        )
        
        # Parse the response
        response_body = json.loads(response['body'].read())
        
        # Extract the text content from Claude's response
        if 'content' in response_body and response_body['content']:
            return response_body['content'][0]['text']
        else:
            return "No response from Claude model."
    
    except Exception as e:
        print(f"Bedrock API Error: {str(e)}")
        print(f"Model ID used: {model_id}")
        print(f"Client region: {client._client_config.region_name}")
        return f"Error calling Bedrock model: {str(e)}"


def create_success_response(request_id: str, result: str) -> Dict[str, Any]:
    """Create a successful MCP response"""
    return {
        "jsonrpc": "2.0",
        "id": request_id,
        "result": {
            "content": [
                {
                    "type": "text",
                    "text": result
                }
            ],
            "isError": False
        }
    }


def create_error_response(request_id: str, error_code: int, error_message: str) -> Dict[str, Any]:
    """Create an MCP error response"""
    return {
        "jsonrpc": "2.0",
        "id": request_id,
        "error": {
            "code": error_code,
            "message": error_message
        }
    }