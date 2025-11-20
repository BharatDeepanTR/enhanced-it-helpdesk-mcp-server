import json
import logging
import math

logger = logging.getLogger()
logger.setLevel(logging.INFO)

def lambda_handler(event, context):
    """
    Calculator MCP Server for Bedrock Agent Core Gateway
    
    This Lambda function implements the Model Context Protocol (MCP) with JSON-RPC 2.0
    for use with AWS Bedrock Agent Core Gateway.
    
    Supports:
    - tools/list: Returns available calculator operations
    - tools/call: Executes calculator operations
    
    Manual Setup Instructions:
    1. Create Lambda function with this code
    2. Set runtime: Python 3.9
    3. Set execution role: arn:aws:iam::818565325759:role/a208194-askjulius-agentcore-gateway
    4. Set timeout: 30 seconds
    5. Set memory: 256 MB
    """
    
    try:
        logger.info(f"Received event: {json.dumps(event, default=str)}")
        
        # Handle both API Gateway proxy format and direct invocation
        if 'body' in event:
            # API Gateway proxy integration
            if isinstance(event['body'], str):
                body = json.loads(event['body'])
            else:
                body = event['body']
        else:
            # Direct Lambda invocation
            body = event
            
        # Validate JSON-RPC 2.0 format
        if not isinstance(body, dict) or body.get('jsonrpc') != '2.0':
            error_response = {
                'jsonrpc': '2.0',
                'error': {
                    'code': -32600, 
                    'message': 'Invalid Request - Must be JSON-RPC 2.0 format'
                },
                'id': body.get('id') if isinstance(body, dict) else None
            }
            return format_response(event, error_response)
        
        method = body.get('method')
        params = body.get('params', {})
        request_id = body.get('id')
        
        logger.info(f"Processing MCP method: {method}")
        
        # Handle MCP protocol methods
        if method == 'tools/list':
            # Return list of available calculator tools
            result = handle_tools_list()
            
        elif method == 'tools/call':
            # Execute a specific calculator operation
            result = handle_tools_call(params)
            
        else:
            # Unknown method error
            error_response = {
                'jsonrpc': '2.0',
                'error': {
                    'code': -32601, 
                    'message': f'Method not found: {method}',
                    'data': 'Supported methods: tools/list, tools/call'
                },
                'id': request_id
            }
            return format_response(event, error_response)
        
        # Return successful response
        success_response = {
            'jsonrpc': '2.0',
            'result': result,
            'id': request_id
        }
        
        logger.info(f"Returning success response for method: {method}")
        return format_response(event, success_response)
        
    except Exception as e:
        logger.error(f"Calculator server error: {str(e)}")
        
        # Handle any unexpected errors
        error_response = {
            'jsonrpc': '2.0',
            'error': {
                'code': -32603, 
                'message': 'Internal error', 
                'data': str(e)
            },
            'id': body.get('id') if 'body' in locals() and isinstance(body, dict) else None
        }
        return format_response(event, error_response)

def format_response(event, response_data):
    """
    Format response appropriately for API Gateway or direct invocation
    
    Args:
        event: Original Lambda event (determines response format)
        response_data: JSON-RPC response data
        
    Returns:
        Properly formatted response for the invocation method
    """
    
    if 'body' in event:
        # API Gateway proxy integration format
        return {
            'statusCode': 200,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Methods': 'POST, OPTIONS',
                'Access-Control-Allow-Headers': 'Content-Type, Authorization'
            },
            'body': json.dumps(response_data)
        }
    else:
        # Direct Lambda invocation format
        return response_data

def handle_tools_list():
    """
    Return the list of available calculator tools
    
    Returns:
        MCP tools list response with all supported calculator operations
    """
    
    return {
        'tools': [
            {
                'name': 'add',
                'description': 'Add two numbers together',
                'inputSchema': {
                    'type': 'object',
                    'properties': {
                        'a': {
                            'type': 'number', 
                            'description': 'First number to add'
                        },
                        'b': {
                            'type': 'number', 
                            'description': 'Second number to add'
                        }
                    },
                    'required': ['a', 'b']
                }
            },
            {
                'name': 'subtract',
                'description': 'Subtract second number from first number',
                'inputSchema': {
                    'type': 'object',
                    'properties': {
                        'a': {
                            'type': 'number', 
                            'description': 'Number to subtract from'
                        },
                        'b': {
                            'type': 'number', 
                            'description': 'Number to subtract'
                        }
                    },
                    'required': ['a', 'b']
                }
            },
            {
                'name': 'multiply',
                'description': 'Multiply two numbers together',
                'inputSchema': {
                    'type': 'object',
                    'properties': {
                        'a': {
                            'type': 'number', 
                            'description': 'First number to multiply'
                        },
                        'b': {
                            'type': 'number', 
                            'description': 'Second number to multiply'
                        }
                    },
                    'required': ['a', 'b']
                }
            },
            {
                'name': 'divide',
                'description': 'Divide first number by second number',
                'inputSchema': {
                    'type': 'object',
                    'properties': {
                        'a': {
                            'type': 'number', 
                            'description': 'Dividend (number to be divided)'
                        },
                        'b': {
                            'type': 'number', 
                            'description': 'Divisor (number to divide by)'
                        }
                    },
                    'required': ['a', 'b']
                }
            },
            {
                'name': 'power',
                'description': 'Raise base number to the power of exponent',
                'inputSchema': {
                    'type': 'object',
                    'properties': {
                        'base': {
                            'type': 'number', 
                            'description': 'Base number'
                        },
                        'exponent': {
                            'type': 'number', 
                            'description': 'Exponent (power to raise base to)'
                        }
                    },
                    'required': ['base', 'exponent']
                }
            },
            {
                'name': 'sqrt',
                'description': 'Calculate square root of a number',
                'inputSchema': {
                    'type': 'object',
                    'properties': {
                        'number': {
                            'type': 'number', 
                            'description': 'Number to find square root of (must be non-negative)'
                        }
                    },
                    'required': ['number']
                }
            },
            {
                'name': 'factorial',
                'description': 'Calculate factorial of a non-negative integer',
                'inputSchema': {
                    'type': 'object',
                    'properties': {
                        'n': {
                            'type': 'integer', 
                            'description': 'Non-negative integer to calculate factorial of (n!)'
                        }
                    },
                    'required': ['n']
                }
            }
        ]
    }

def handle_tools_call(params):
    """
    Execute a calculator operation based on the tool name and arguments
    
    Args:
        params: MCP tools/call parameters containing 'name' and 'arguments'
        
    Returns:
        MCP tools/call response with calculation result or error
    """
    
    tool_name = params.get('name')
    arguments = params.get('arguments', {})
    
    logger.info(f"Executing calculator tool: {tool_name} with arguments: {arguments}")
    
    try:
        if tool_name == 'add':
            a = float(arguments.get('a', 0))
            b = float(arguments.get('b', 0))
            result_value = a + b
            result_text = f"Addition: {a} + {b} = {result_value}"
            
        elif tool_name == 'subtract':
            a = float(arguments.get('a', 0))
            b = float(arguments.get('b', 0))
            result_value = a - b
            result_text = f"Subtraction: {a} - {b} = {result_value}"
            
        elif tool_name == 'multiply':
            a = float(arguments.get('a', 0))
            b = float(arguments.get('b', 0))
            result_value = a * b
            result_text = f"Multiplication: {a} × {b} = {result_value}"
            
        elif tool_name == 'divide':
            a = float(arguments.get('a', 0))
            b = float(arguments.get('b', 0))
            
            if b == 0:
                result_text = "Error: Division by zero is undefined"
                is_error = True
            else:
                result_value = a / b
                result_text = f"Division: {a} ÷ {b} = {result_value}"
                is_error = False
                
        elif tool_name == 'power':
            base = float(arguments.get('base', 0))
            exponent = float(arguments.get('exponent', 0))
            result_value = base ** exponent
            result_text = f"Power: {base}^{exponent} = {result_value}"
            is_error = False
            
        elif tool_name == 'sqrt':
            number = float(arguments.get('number', 0))
            
            if number < 0:
                result_text = "Error: Cannot calculate square root of negative number"
                is_error = True
            else:
                result_value = math.sqrt(number)
                result_text = f"Square root: √{number} = {result_value}"
                is_error = False
                
        elif tool_name == 'factorial':
            n = int(arguments.get('n', 0))
            
            if n < 0:
                result_text = "Error: Factorial is not defined for negative numbers"
                is_error = True
            elif n > 100:
                result_text = "Error: Number too large for factorial calculation (limit: 100)"
                is_error = True
            else:
                result_value = math.factorial(n)
                result_text = f"Factorial: {n}! = {result_value}"
                is_error = False
                
        else:
            raise ValueError(f"Unknown calculator tool: {tool_name}")
        
        # Return successful calculation result
        return {
            'content': [{
                'type': 'text',
                'text': result_text
            }],
            'isError': is_error if 'is_error' in locals() else False
        }
        
    except (ValueError, TypeError, OverflowError) as e:
        # Handle calculation errors
        logger.warning(f"Calculation error for tool {tool_name}: {str(e)}")
        
        return {
            'content': [{
                'type': 'text',
                'text': f"Calculation error: {str(e)}"
            }],
            'isError': True
        }
    
    except Exception as e:
        # Handle unexpected errors during calculation
        logger.error(f"Unexpected error in tool {tool_name}: {str(e)}")
        
        return {
            'content': [{
                'type': 'text',
                'text': f"Internal calculation error: {str(e)}"
            }],
            'isError': True
        }