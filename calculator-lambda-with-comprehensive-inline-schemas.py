import json
import logging
import math

logger = logging.getLogger()
logger.setLevel(logging.INFO)

def lambda_handler(event, context):
    """
    Calculator MCP Server with Comprehensive Inline Schemas
    
    Features complete inline schema definitions for all calculator operations
    with proper validation and Agent Core Gateway compatibility
    """
    
    try:
        logger.info(f"Received event: {json.dumps(event, default=str)}")
        
        # Handle both API Gateway proxy format and direct invocation
        if 'body' in event:
            if isinstance(event['body'], str):
                body = json.loads(event['body'])
            else:
                body = event['body']
        else:
            body = event
            
        # Validate JSON-RPC 2.0 format
        if not isinstance(body, dict) or body.get('jsonrpc') != '2.0':
            error_response = {
                "jsonrpc": "2.0",
                "error": {
                    "code": -32600, 
                    "message": "Invalid Request - Must be JSON-RPC 2.0 format"
                },
                "id": body.get('id') if isinstance(body, dict) else None
            }
            return format_response(event, error_response)
        
        method = body.get('method')
        params = body.get('params', {})
        request_id = body.get('id')
        
        logger.info(f"Processing MCP method: {method}")
        
        # Handle MCP protocol methods
        if method == 'tools/list':
            result = handle_tools_list_with_inline_schemas()
        elif method == 'tools/call':
            result = handle_tools_call(params)
        else:
            error_response = {
                "jsonrpc": "2.0",
                "error": {
                    "code": -32601, 
                    "message": f"Method not found: {method}",
                    "data": "Supported methods: tools/list, tools/call"
                },
                "id": request_id
            }
            return format_response(event, error_response)
        
        # Return successful response
        success_response = {
            "jsonrpc": "2.0",
            "result": result,
            "id": request_id
        }
        
        logger.info(f"Returning success response for method: {method}")
        return format_response(event, success_response)
        
    except Exception as e:
        logger.error(f"Calculator server error: {str(e)}")
        
        error_response = {
            "jsonrpc": "2.0",
            "error": {
                "code": -32603, 
                "message": "Internal error", 
                "data": str(e)
            },
            "id": body.get('id') if 'body' in locals() and isinstance(body, dict) else None
        }
        return format_response(event, error_response)

def format_response(event, response_data):
    """Format response appropriately for API Gateway or direct invocation"""
    
    if 'body' in event:
        # API Gateway proxy integration format
        return {
            "statusCode": 200,
            "headers": {
                "Content-Type": "application/json",
                "Access-Control-Allow-Origin": "*",
                "Access-Control-Allow-Methods": "POST, OPTIONS",
                "Access-Control-Allow-Headers": "Content-Type, Authorization"
            },
            "body": json.dumps(response_data)
        }
    else:
        # Direct Lambda invocation format
        return response_data

def handle_tools_list_with_inline_schemas():
    """
    Return calculator tools with comprehensive inline schemas
    
    CRITICAL: All schemas use JSON double quotes for Gateway compatibility
    Each tool includes detailed validation rules and clear descriptions
    """
    
    return {
        "tools": [
            # Basic Addition Tool
            {
                "name": "add",
                "description": "Add two numbers together with validation for reasonable numeric ranges",
                "inputSchema": {
                    "type": "object",
                    "properties": {
                        "a": {
                            "type": "number", 
                            "description": "First number to add",
                            "minimum": -999999999,
                            "maximum": 999999999,
                            "examples": [5, 10.5, -3.14]
                        },
                        "b": {
                            "type": "number", 
                            "description": "Second number to add",
                            "minimum": -999999999,
                            "maximum": 999999999,
                            "examples": [3, 7.2, -1.5]
                        }
                    },
                    "required": ["a", "b"],
                    "additionalProperties": False,
                    "examples": [
                        {"a": 5, "b": 3},
                        {"a": 10.5, "b": 7.2},
                        {"a": -3, "b": 8}
                    ]
                }
            },
            
            # Subtraction Tool
            {
                "name": "subtract",
                "description": "Subtract the second number from the first number",
                "inputSchema": {
                    "type": "object",
                    "properties": {
                        "a": {
                            "type": "number", 
                            "description": "Number to subtract from (minuend)",
                            "minimum": -999999999,
                            "maximum": 999999999
                        },
                        "b": {
                            "type": "number", 
                            "description": "Number to subtract (subtrahend)",
                            "minimum": -999999999,
                            "maximum": 999999999
                        }
                    },
                    "required": ["a", "b"],
                    "additionalProperties": False,
                    "examples": [
                        {"a": 10, "b": 3},
                        {"a": 5.5, "b": 2.1},
                        {"a": 0, "b": -5}
                    ]
                }
            },
            
            # Multiplication Tool
            {
                "name": "multiply",
                "description": "Multiply two numbers together with overflow protection",
                "inputSchema": {
                    "type": "object",
                    "properties": {
                        "a": {
                            "type": "number", 
                            "description": "First number to multiply (multiplicand)",
                            "minimum": -999999,
                            "maximum": 999999
                        },
                        "b": {
                            "type": "number", 
                            "description": "Second number to multiply (multiplier)",
                            "minimum": -999999,
                            "maximum": 999999
                        }
                    },
                    "required": ["a", "b"],
                    "additionalProperties": False,
                    "examples": [
                        {"a": 6, "b": 7},
                        {"a": 3.5, "b": 2},
                        {"a": -4, "b": 5}
                    ]
                }
            },
            
            # Division Tool with Zero Protection
            {
                "name": "divide",
                "description": "Divide the first number by the second number with zero-division protection",
                "inputSchema": {
                    "type": "object",
                    "properties": {
                        "a": {
                            "type": "number", 
                            "description": "Number to be divided (dividend)",
                            "minimum": -999999999,
                            "maximum": 999999999
                        },
                        "b": {
                            "type": "number", 
                            "description": "Number to divide by (divisor) - cannot be zero",
                            "minimum": -999999999,
                            "maximum": 999999999,
                            "not": {"const": 0}
                        }
                    },
                    "required": ["a", "b"],
                    "additionalProperties": False,
                    "examples": [
                        {"a": 15, "b": 3},
                        {"a": 22.5, "b": 4.5},
                        {"a": -10, "b": 2}
                    ]
                }
            },
            
            # Power/Exponentiation Tool
            {
                "name": "power",
                "description": "Raise base number to the power of exponent with reasonable limits",
                "inputSchema": {
                    "type": "object",
                    "properties": {
                        "base": {
                            "type": "number", 
                            "description": "Base number to be raised to a power",
                            "minimum": -1000,
                            "maximum": 1000
                        },
                        "exponent": {
                            "type": "number", 
                            "description": "Exponent (power to raise base to)",
                            "minimum": -100,
                            "maximum": 100
                        }
                    },
                    "required": ["base", "exponent"],
                    "additionalProperties": False,
                    "examples": [
                        {"base": 2, "exponent": 3},
                        {"base": 5, "exponent": 2},
                        {"base": 10, "exponent": -2}
                    ]
                }
            },
            
            # Square Root Tool
            {
                "name": "sqrt",
                "description": "Calculate the square root of a non-negative number",
                "inputSchema": {
                    "type": "object",
                    "properties": {
                        "number": {
                            "type": "number", 
                            "description": "Non-negative number to find square root of",
                            "minimum": 0,
                            "maximum": 999999999,
                            "examples": [9, 16, 25, 2.25, 100]
                        }
                    },
                    "required": ["number"],
                    "additionalProperties": False,
                    "examples": [
                        {"number": 9},
                        {"number": 16.25},
                        {"number": 100}
                    ]
                }
            },
            
            # Factorial Tool
            {
                "name": "factorial",
                "description": "Calculate factorial of a non-negative integer (n!) with performance limits",
                "inputSchema": {
                    "type": "object",
                    "properties": {
                        "n": {
                            "type": "integer", 
                            "description": "Non-negative integer to calculate factorial of (limit: 100 for performance)",
                            "minimum": 0,
                            "maximum": 100,
                            "examples": [5, 10, 0, 7]
                        }
                    },
                    "required": ["n"],
                    "additionalProperties": False,
                    "examples": [
                        {"n": 5},
                        {"n": 0},
                        {"n": 10}
                    ]
                }
            },
            
            # Advanced: Percentage Calculator
            {
                "name": "percentage",
                "description": "Calculate percentage of a number or percentage change between two numbers",
                "inputSchema": {
                    "type": "object",
                    "properties": {
                        "operation": {
                            "type": "string",
                            "enum": ["of", "change", "increase", "decrease"],
                            "description": "Type of percentage calculation",
                            "examples": ["of", "change"]
                        },
                        "value": {
                            "type": "number",
                            "description": "Primary value for calculation",
                            "minimum": -999999999,
                            "maximum": 999999999
                        },
                        "percentage": {
                            "type": "number",
                            "description": "Percentage value (for 'of' operations)",
                            "minimum": -1000,
                            "maximum": 1000
                        },
                        "original_value": {
                            "type": "number",
                            "description": "Original value (for change calculations)",
                            "minimum": -999999999,
                            "maximum": 999999999
                        },
                        "new_value": {
                            "type": "number",
                            "description": "New value (for change calculations)",
                            "minimum": -999999999,
                            "maximum": 999999999
                        }
                    },
                    "required": ["operation"],
                    "oneOf": [
                        {
                            "properties": {
                                "operation": {"const": "of"}
                            },
                            "required": ["value", "percentage"]
                        },
                        {
                            "properties": {
                                "operation": {"enum": ["change", "increase", "decrease"]}
                            },
                            "required": ["original_value", "new_value"]
                        }
                    ],
                    "additionalProperties": False,
                    "examples": [
                        {"operation": "of", "value": 200, "percentage": 15},
                        {"operation": "change", "original_value": 100, "new_value": 120}
                    ]
                }
            },
            
            # Advanced: Trigonometric Functions
            {
                "name": "trigonometry",
                "description": "Calculate trigonometric functions (sin, cos, tan) for angles in degrees or radians",
                "inputSchema": {
                    "type": "object",
                    "properties": {
                        "function": {
                            "type": "string",
                            "enum": ["sin", "cos", "tan", "asin", "acos", "atan"],
                            "description": "Trigonometric function to calculate"
                        },
                        "angle": {
                            "type": "number",
                            "description": "Angle value for calculation",
                            "minimum": -3600,
                            "maximum": 3600
                        },
                        "unit": {
                            "type": "string",
                            "enum": ["degrees", "radians"],
                            "default": "degrees",
                            "description": "Unit of angle measurement"
                        },
                        "precision": {
                            "type": "integer",
                            "minimum": 0,
                            "maximum": 10,
                            "default": 6,
                            "description": "Number of decimal places for result"
                        }
                    },
                    "required": ["function", "angle"],
                    "additionalProperties": False,
                    "examples": [
                        {"function": "sin", "angle": 30, "unit": "degrees"},
                        {"function": "cos", "angle": 1.5708, "unit": "radians"},
                        {"function": "tan", "angle": 45, "unit": "degrees", "precision": 4}
                    ]
                }
            },
            
            # Advanced: Statistical Functions
            {
                "name": "statistics",
                "description": "Calculate statistical measures for a dataset (mean, median, mode, standard deviation)",
                "inputSchema": {
                    "type": "object",
                    "properties": {
                        "operation": {
                            "type": "string",
                            "enum": ["mean", "median", "mode", "std_dev", "variance", "all"],
                            "description": "Statistical operation to perform"
                        },
                        "data": {
                            "type": "array",
                            "items": {
                                "type": "number"
                            },
                            "minItems": 1,
                            "maxItems": 1000,
                            "description": "Array of numerical data points"
                        },
                        "precision": {
                            "type": "integer",
                            "minimum": 0,
                            "maximum": 10,
                            "default": 4,
                            "description": "Number of decimal places for results"
                        }
                    },
                    "required": ["operation", "data"],
                    "additionalProperties": False,
                    "examples": [
                        {"operation": "mean", "data": [1, 2, 3, 4, 5]},
                        {"operation": "all", "data": [10, 20, 30, 40, 50], "precision": 2}
                    ]
                }
            }
        ]
    }

def handle_tools_call(params):
    """Execute calculator operations with comprehensive validation"""
    
    tool_name = params.get('name')
    arguments = params.get('arguments', {})
    
    logger.info(f"Executing calculator tool: {tool_name} with arguments: {arguments}")
    
    try:
        if tool_name == "add":
            return handle_add(arguments)
        elif tool_name == "subtract":
            return handle_subtract(arguments)
        elif tool_name == "multiply":
            return handle_multiply(arguments)
        elif tool_name == "divide":
            return handle_divide(arguments)
        elif tool_name == "power":
            return handle_power(arguments)
        elif tool_name == "sqrt":
            return handle_sqrt(arguments)
        elif tool_name == "factorial":
            return handle_factorial(arguments)
        elif tool_name == "percentage":
            return handle_percentage(arguments)
        elif tool_name == "trigonometry":
            return handle_trigonometry(arguments)
        elif tool_name == "statistics":
            return handle_statistics(arguments)
        else:
            raise ValueError(f"Unknown calculator tool: {tool_name}")
            
    except Exception as e:
        logger.error(f"Tool execution error for {tool_name}: {str(e)}")
        return create_error_result(f"Calculation error: {str(e)}")

# Individual tool handlers with detailed implementations

def handle_add(args):
    """Handle addition with validation"""
    a = float(args.get('a', 0))
    b = float(args.get('b', 0))
    result = a + b
    
    return create_success_result(f"Addition: {a} + {b} = {result}")

def handle_subtract(args):
    """Handle subtraction with validation"""
    a = float(args.get('a', 0))
    b = float(args.get('b', 0))
    result = a - b
    
    return create_success_result(f"Subtraction: {a} - {b} = {result}")

def handle_multiply(args):
    """Handle multiplication with overflow protection"""
    a = float(args.get('a', 0))
    b = float(args.get('b', 0))
    result = a * b
    
    # Check for overflow
    if abs(result) > 1e15:
        return create_error_result("Result too large - potential overflow")
    
    return create_success_result(f"Multiplication: {a} × {b} = {result}")

def handle_divide(args):
    """Handle division with zero protection"""
    a = float(args.get('a', 0))
    b = float(args.get('b', 0))
    
    if b == 0:
        return create_error_result("Error: Division by zero is undefined")
    
    result = a / b
    return create_success_result(f"Division: {a} ÷ {b} = {result}")

def handle_power(args):
    """Handle exponentiation with limits"""
    base = float(args.get('base', 0))
    exponent = float(args.get('exponent', 0))
    
    try:
        result = base ** exponent
        
        # Check for overflow
        if abs(result) > 1e15:
            return create_error_result("Result too large - potential overflow")
        
        return create_success_result(f"Power: {base}^{exponent} = {result}")
        
    except OverflowError:
        return create_error_result("Result too large - overflow error")

def handle_sqrt(args):
    """Handle square root with validation"""
    number = float(args.get('number', 0))
    
    if number < 0:
        return create_error_result("Error: Cannot calculate square root of negative number")
    
    result = math.sqrt(number)
    return create_success_result(f"Square root: √{number} = {result}")

def handle_factorial(args):
    """Handle factorial with limits"""
    n = int(args.get('n', 0))
    
    if n < 0:
        return create_error_result("Error: Factorial not defined for negative numbers")
    elif n > 100:
        return create_error_result("Error: Number too large for factorial calculation (limit: 100)")
    
    result = math.factorial(n)
    return create_success_result(f"Factorial: {n}! = {result}")

def handle_percentage(args):
    """Handle percentage calculations"""
    operation = args.get('operation')
    
    if operation == 'of':
        value = float(args.get('value'))
        percentage = float(args.get('percentage'))
        result = (percentage / 100) * value
        return create_success_result(f"{percentage}% of {value} = {result}")
    
    elif operation in ['change', 'increase', 'decrease']:
        original = float(args.get('original_value'))
        new = float(args.get('new_value'))
        
        if original == 0:
            return create_error_result("Cannot calculate percentage change from zero")
        
        change = ((new - original) / original) * 100
        return create_success_result(f"Percentage change: {original} → {new} = {change:.2f}%")
    
    return create_error_result(f"Unknown percentage operation: {operation}")

def handle_trigonometry(args):
    """Handle trigonometric functions"""
    function = args.get('function')
    angle = float(args.get('angle'))
    unit = args.get('unit', 'degrees')
    precision = args.get('precision', 6)
    
    # Convert to radians if needed
    if unit == 'degrees':
        angle_rad = math.radians(angle)
    else:
        angle_rad = angle
    
    try:
        if function == 'sin':
            result = math.sin(angle_rad)
        elif function == 'cos':
            result = math.cos(angle_rad)
        elif function == 'tan':
            result = math.tan(angle_rad)
        elif function == 'asin':
            result = math.asin(angle_rad)
        elif function == 'acos':
            result = math.acos(angle_rad)
        elif function == 'atan':
            result = math.atan(angle_rad)
        else:
            return create_error_result(f"Unknown trigonometric function: {function}")
        
        result = round(result, precision)
        return create_success_result(f"{function}({angle} {unit}) = {result}")
        
    except ValueError as e:
        return create_error_result(f"Math domain error: {str(e)}")

def handle_statistics(args):
    """Handle statistical calculations"""
    operation = args.get('operation')
    data = args.get('data', [])
    precision = args.get('precision', 4)
    
    if not data:
        return create_error_result("No data provided for statistical analysis")
    
    try:
        if operation == 'mean':
            result = sum(data) / len(data)
            return create_success_result(f"Mean of {len(data)} values: {round(result, precision)}")
        
        elif operation == 'median':
            sorted_data = sorted(data)
            n = len(sorted_data)
            if n % 2 == 0:
                result = (sorted_data[n//2 - 1] + sorted_data[n//2]) / 2
            else:
                result = sorted_data[n//2]
            return create_success_result(f"Median of {len(data)} values: {round(result, precision)}")
        
        elif operation == 'std_dev':
            mean = sum(data) / len(data)
            variance = sum((x - mean) ** 2 for x in data) / len(data)
            std_dev = math.sqrt(variance)
            return create_success_result(f"Standard deviation: {round(std_dev, precision)}")
        
        elif operation == 'all':
            mean = sum(data) / len(data)
            sorted_data = sorted(data)
            n = len(sorted_data)
            if n % 2 == 0:
                median = (sorted_data[n//2 - 1] + sorted_data[n//2]) / 2
            else:
                median = sorted_data[n//2]
            
            variance = sum((x - mean) ** 2 for x in data) / len(data)
            std_dev = math.sqrt(variance)
            
            result_text = f"Statistics for {n} values:\n"
            result_text += f"Mean: {round(mean, precision)}\n"
            result_text += f"Median: {round(median, precision)}\n"
            result_text += f"Standard Deviation: {round(std_dev, precision)}"
            
            return create_success_result(result_text)
        
        return create_error_result(f"Unknown statistical operation: {operation}")
        
    except Exception as e:
        return create_error_result(f"Statistical calculation error: {str(e)}")

def create_success_result(text):
    """Create successful tool result"""
    return {
        "content": [{
            "type": "text",
            "text": text
        }],
        "isError": False
    }

def create_error_result(text):
    """Create error tool result"""
    return {
        "content": [{
            "type": "text",
            "text": text
        }],
        "isError": True
    }