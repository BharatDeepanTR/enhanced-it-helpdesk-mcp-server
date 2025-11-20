#!/bin/bash
# CloudShell: Create Calculator MCP Server Lambda
# Simple calculator that properly implements MCP protocol for testing

echo "🧮 Creating Calculator MCP Server Lambda"
echo "======================================="
echo ""

CALCULATOR_FUNCTION_NAME="calculator-mcp-server"
ROLE_ARN="arn:aws:iam::818565325759:role/a208194-askjulius-agentcore-gateway"
REGION="us-east-1"

echo "🎯 Configuration:"
echo "  Function Name: $CALCULATOR_FUNCTION_NAME"
echo "  Role ARN: $ROLE_ARN"
echo "  Region: $REGION"
echo ""

echo "📦 Step 1: Create Calculator MCP Server Code"
echo "=========================================="

mkdir -p /tmp/calculator-mcp-server
cd /tmp/calculator-mcp-server

# Create the calculator MCP server code
cat > lambda_function.py << 'EOF'
import json
import logging
import math

# Set up logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

def lambda_handler(event, context):
    """
    Calculator MCP Server
    Implements proper MCP protocol (JSON-RPC 2.0) for mathematical operations
    """
    
    logger.info(f"Calculator MCP Server received event: {json.dumps(event)}")
    
    try:
        # Handle different event formats (API Gateway vs Direct)
        if 'body' in event:
            # API Gateway format
            if isinstance(event['body'], str):
                request_body = json.loads(event['body'])
            else:
                request_body = event['body']
        else:
            # Direct invocation
            request_body = event
        
        # Extract MCP request components
        jsonrpc = request_body.get('jsonrpc', '2.0')
        method = request_body.get('method', '')
        params = request_body.get('params', {})
        request_id = request_body.get('id', 'unknown')
        
        logger.info(f"MCP Method: {method}, Params: {params}")
        
        # Validate JSON-RPC version
        if jsonrpc != '2.0':
            return create_error_response(request_id, -32600, "Invalid Request", "JSON-RPC version must be 2.0")
        
        # Handle MCP methods
        if method == 'tools/list':
            response = handle_tools_list(request_id)
        elif method == 'tools/call':
            response = handle_tools_call(request_id, params)
        else:
            response = create_error_response(request_id, -32601, f"Method not found: {method}")
        
        logger.info(f"Calculator response: {json.dumps(response)}")
        
        # Return response in appropriate format
        if 'body' in event:
            # API Gateway format
            return {
                'statusCode': 200,
                'headers': {
                    'Content-Type': 'application/json',
                    'Access-Control-Allow-Origin': '*'
                },
                'body': json.dumps(response)
            }
        else:
            # Direct invocation
            return response
            
    except json.JSONDecodeError as e:
        error_response = create_error_response('unknown', -32700, "Parse error", f"Invalid JSON: {str(e)}")
        return format_response(event, error_response)
    except Exception as e:
        logger.error(f"Calculator server error: {str(e)}")
        error_response = create_error_response(
            request_body.get('id', 'unknown') if 'request_body' in locals() else 'unknown',
            -32603, 
            "Internal error", 
            str(e)
        )
        return format_response(event, error_response)

def handle_tools_list(request_id):
    """Handle tools/list MCP request - return available calculator tools"""
    
    tools = [
        {
            "name": "add",
            "description": "Add two numbers",
            "inputSchema": {
                "type": "object",
                "properties": {
                    "a": {"type": "number", "description": "First number"},
                    "b": {"type": "number", "description": "Second number"}
                },
                "required": ["a", "b"]
            }
        },
        {
            "name": "subtract",
            "description": "Subtract second number from first number",
            "inputSchema": {
                "type": "object",
                "properties": {
                    "a": {"type": "number", "description": "First number"},
                    "b": {"type": "number", "description": "Second number"}
                },
                "required": ["a", "b"]
            }
        },
        {
            "name": "multiply",
            "description": "Multiply two numbers",
            "inputSchema": {
                "type": "object",
                "properties": {
                    "a": {"type": "number", "description": "First number"},
                    "b": {"type": "number", "description": "Second number"}
                },
                "required": ["a", "b"]
            }
        },
        {
            "name": "divide",
            "description": "Divide first number by second number",
            "inputSchema": {
                "type": "object",
                "properties": {
                    "a": {"type": "number", "description": "Dividend"},
                    "b": {"type": "number", "description": "Divisor (cannot be zero)"}
                },
                "required": ["a", "b"]
            }
        },
        {
            "name": "power",
            "description": "Raise first number to the power of second number",
            "inputSchema": {
                "type": "object",
                "properties": {
                    "base": {"type": "number", "description": "Base number"},
                    "exponent": {"type": "number", "description": "Exponent"}
                },
                "required": ["base", "exponent"]
            }
        },
        {
            "name": "sqrt",
            "description": "Calculate square root of a number",
            "inputSchema": {
                "type": "object",
                "properties": {
                    "number": {"type": "number", "description": "Number to calculate square root", "minimum": 0}
                },
                "required": ["number"]
            }
        },
        {
            "name": "factorial",
            "description": "Calculate factorial of a non-negative integer",
            "inputSchema": {
                "type": "object",
                "properties": {
                    "n": {"type": "integer", "description": "Non-negative integer", "minimum": 0, "maximum": 170}
                },
                "required": ["n"]
            }
        }
    ]
    
    return {
        "jsonrpc": "2.0",
        "id": request_id,
        "result": {
            "tools": tools
        }
    }

def handle_tools_call(request_id, params):
    """Handle tools/call MCP request - execute calculator operations"""
    
    tool_name = params.get('name', '')
    arguments = params.get('arguments', {})
    
    logger.info(f"Executing tool: {tool_name} with arguments: {arguments}")
    
    try:
        # Execute the calculator operation
        if tool_name == 'add':
            result = calculate_add(arguments)
        elif tool_name == 'subtract':
            result = calculate_subtract(arguments)
        elif tool_name == 'multiply':
            result = calculate_multiply(arguments)
        elif tool_name == 'divide':
            result = calculate_divide(arguments)
        elif tool_name == 'power':
            result = calculate_power(arguments)
        elif tool_name == 'sqrt':
            result = calculate_sqrt(arguments)
        elif tool_name == 'factorial':
            result = calculate_factorial(arguments)
        else:
            return create_error_response(request_id, -32601, f"Unknown tool: {tool_name}")
        
        # Return successful result
        return {
            "jsonrpc": "2.0",
            "id": request_id,
            "result": {
                "content": [
                    {
                        "type": "text",
                        "text": f"Result: {result}"
                    }
                ]
            }
        }
        
    except ValueError as e:
        return create_error_response(request_id, -32602, "Invalid params", str(e))
    except Exception as e:
        return create_error_response(request_id, -32603, "Internal error", str(e))

# Calculator operation functions
def calculate_add(args):
    """Add two numbers"""
    a = args.get('a')
    b = args.get('b')
    
    if a is None or b is None:
        raise ValueError("Both 'a' and 'b' parameters are required")
    
    if not isinstance(a, (int, float)) or not isinstance(b, (int, float)):
        raise ValueError("Parameters 'a' and 'b' must be numbers")
    
    return a + b

def calculate_subtract(args):
    """Subtract second number from first"""
    a = args.get('a')
    b = args.get('b')
    
    if a is None or b is None:
        raise ValueError("Both 'a' and 'b' parameters are required")
    
    if not isinstance(a, (int, float)) or not isinstance(b, (int, float)):
        raise ValueError("Parameters 'a' and 'b' must be numbers")
    
    return a - b

def calculate_multiply(args):
    """Multiply two numbers"""
    a = args.get('a')
    b = args.get('b')
    
    if a is None or b is None:
        raise ValueError("Both 'a' and 'b' parameters are required")
    
    if not isinstance(a, (int, float)) or not isinstance(b, (int, float)):
        raise ValueError("Parameters 'a' and 'b' must be numbers")
    
    return a * b

def calculate_divide(args):
    """Divide first number by second"""
    a = args.get('a')
    b = args.get('b')
    
    if a is None or b is None:
        raise ValueError("Both 'a' and 'b' parameters are required")
    
    if not isinstance(a, (int, float)) or not isinstance(b, (int, float)):
        raise ValueError("Parameters 'a' and 'b' must be numbers")
    
    if b == 0:
        raise ValueError("Division by zero is not allowed")
    
    return a / b

def calculate_power(args):
    """Raise base to the power of exponent"""
    base = args.get('base')
    exponent = args.get('exponent')
    
    if base is None or exponent is None:
        raise ValueError("Both 'base' and 'exponent' parameters are required")
    
    if not isinstance(base, (int, float)) or not isinstance(exponent, (int, float)):
        raise ValueError("Parameters 'base' and 'exponent' must be numbers")
    
    return math.pow(base, exponent)

def calculate_sqrt(args):
    """Calculate square root"""
    number = args.get('number')
    
    if number is None:
        raise ValueError("Parameter 'number' is required")
    
    if not isinstance(number, (int, float)):
        raise ValueError("Parameter 'number' must be a number")
    
    if number < 0:
        raise ValueError("Cannot calculate square root of negative number")
    
    return math.sqrt(number)

def calculate_factorial(args):
    """Calculate factorial"""
    n = args.get('n')
    
    if n is None:
        raise ValueError("Parameter 'n' is required")
    
    if not isinstance(n, int):
        raise ValueError("Parameter 'n' must be an integer")
    
    if n < 0:
        raise ValueError("Factorial is not defined for negative numbers")
    
    if n > 170:
        raise ValueError("Factorial too large (maximum n=170)")
    
    return math.factorial(n)

def create_error_response(request_id, code, message, data=None):
    """Create standardized MCP error response"""
    error_response = {
        "jsonrpc": "2.0",
        "id": request_id,
        "error": {
            "code": code,
            "message": message
        }
    }
    
    if data:
        error_response["error"]["data"] = data
    
    return error_response

def format_response(event, response):
    """Format response based on invocation type"""
    if 'body' in event:
        return {
            'statusCode': 400 if 'error' in response else 200,
            'headers': {'Content-Type': 'application/json'},
            'body': json.dumps(response)
        }
    else:
        return response
EOF

echo "✅ Calculator MCP server code created!"

echo ""
echo "📦 Step 2: Create Deployment Package"
echo "==================================="

# Create deployment package
zip -r calculator-mcp-server.zip lambda_function.py

if [ -f "calculator-mcp-server.zip" ]; then
    echo "✅ Deployment package created: $(ls -lh calculator-mcp-server.zip)"
else
    echo "❌ Failed to create deployment package"
    exit 1
fi

echo ""
echo "🚀 Step 3: Deploy Calculator Lambda Function"
echo "=========================================="

echo "Deploying Lambda function..."

aws lambda create-function \
  --function-name "$CALCULATOR_FUNCTION_NAME" \
  --runtime python3.9 \
  --role "$ROLE_ARN" \
  --handler lambda_function.lambda_handler \
  --zip-file fileb://calculator-mcp-server.zip \
  --description "Calculator MCP Server - demonstrates proper MCP protocol implementation" \
  --timeout 30 \
  --memory-size 256 \
  --environment 'Variables={"LOG_LEVEL":"INFO"}' \
  --output json

DEPLOY_RESULT=$?

if [ $DEPLOY_RESULT -eq 0 ]; then
    echo "✅ Calculator Lambda function deployed successfully!"
    
    # Get function ARN
    CALCULATOR_ARN=$(aws lambda get-function --function-name "$CALCULATOR_FUNCTION_NAME" --query 'Configuration.FunctionArn' --output text)
    echo "📋 Function ARN: $CALCULATOR_ARN"
    
else
    echo "❌ Failed to deploy Lambda function"
    
    # Try to update if function already exists
    echo "Attempting to update existing function..."
    
    aws lambda update-function-code \
      --function-name "$CALCULATOR_FUNCTION_NAME" \
      --zip-file fileb://calculator-mcp-server.zip \
      --output json
    
    UPDATE_RESULT=$?
    
    if [ $UPDATE_RESULT -eq 0 ]; then
        echo "✅ Calculator function updated successfully!"
        CALCULATOR_ARN=$(aws lambda get-function --function-name "$CALCULATOR_FUNCTION_NAME" --query 'Configuration.FunctionArn' --output text)
        echo "📋 Function ARN: $CALCULATOR_ARN"
        DEPLOY_RESULT=0
    else
        echo "❌ Failed to deploy or update function"
        exit 1
    fi
fi

cd - > /dev/null

echo ""
echo "🧪 Step 4: Test Calculator MCP Server"
echo "=================================="

if [ $DEPLOY_RESULT -eq 0 ]; then
    echo "Testing calculator MCP server functionality..."
    
    # Test 1: tools/list
    echo ""
    echo "Test 1: MCP tools/list"
    echo "======================"
    
    aws lambda invoke \
      --function-name "$CALCULATOR_FUNCTION_NAME" \
      --payload '{"jsonrpc":"2.0","id":"test-1","method":"tools/list","params":{}}' \
      /tmp/calculator-tools-list.json \
      --output table
    
    echo "Response:"
    cat /tmp/calculator-tools-list.json | jq . 2>/dev/null || cat /tmp/calculator-tools-list.json
    
    # Test 2: Addition
    echo ""
    echo "Test 2: Addition (5 + 3)"
    echo "========================"
    
    aws lambda invoke \
      --function-name "$CALCULATOR_FUNCTION_NAME" \
      --payload '{"jsonrpc":"2.0","id":"test-2","method":"tools/call","params":{"name":"add","arguments":{"a":5,"b":3}}}' \
      /tmp/calculator-add-test.json \
      --output table
    
    echo "Response:"
    cat /tmp/calculator-add-test.json | jq . 2>/dev/null || cat /tmp/calculator-add-test.json
    
    # Test 3: Division
    echo ""
    echo "Test 3: Division (10 / 2)"
    echo "========================="
    
    aws lambda invoke \
      --function-name "$CALCULATOR_FUNCTION_NAME" \
      --payload '{"jsonrpc":"2.0","id":"test-3","method":"tools/call","params":{"name":"divide","arguments":{"a":10,"b":2}}}' \
      /tmp/calculator-divide-test.json \
      --output table
    
    echo "Response:"
    cat /tmp/calculator-divide-test.json | jq . 2>/dev/null || cat /tmp/calculator-divide-test.json
    
    # Test 4: Square root
    echo ""
    echo "Test 4: Square Root (sqrt(16))"
    echo "=============================="
    
    aws lambda invoke \
      --function-name "$CALCULATOR_FUNCTION_NAME" \
      --payload '{"jsonrpc":"2.0","id":"test-4","method":"tools/call","params":{"name":"sqrt","arguments":{"number":16}}}' \
      /tmp/calculator-sqrt-test.json \
      --output table
    
    echo "Response:"
    cat /tmp/calculator-sqrt-test.json | jq . 2>/dev/null || cat /tmp/calculator-sqrt-test.json
    
    # Test 5: Error handling (division by zero)
    echo ""
    echo "Test 5: Error Handling (divide by zero)"
    echo "======================================="
    
    aws lambda invoke \
      --function-name "$CALCULATOR_FUNCTION_NAME" \
      --payload '{"jsonrpc":"2.0","id":"test-5","method":"tools/call","params":{"name":"divide","arguments":{"a":10,"b":0}}}' \
      /tmp/calculator-error-test.json \
      --output table
    
    echo "Response:"
    cat /tmp/calculator-error-test.json | jq . 2>/dev/null || cat /tmp/calculator-error-test.json
    
    # Clean up test files
    rm -f /tmp/calculator-*.json
    
    echo ""
    echo "✅ Calculator testing completed!"
fi

echo ""
echo "🔗 Step 5: Gateway Integration Instructions"
echo "=========================================="

if [ -n "$CALCULATOR_ARN" ]; then
    echo "To add this calculator as a target to your existing gateway:"
    echo ""
    echo "Gateway ID: a208194-askjulius-agentcore-gateway-mcp-iam-fvro4phd59"
    echo "Calculator ARN: $CALCULATOR_ARN"
    echo ""
    echo "🔧 Method 1: Update gateway via CLI"
    echo "=================================="
    echo ""
    echo "aws bedrock-agentcore-control update-gateway \\"
    echo "  --gateway-id \"a208194-askjulius-agentcore-gateway-mcp-iam-fvro4phd59\" \\"
    echo "  --target-lambda-arn \"$CALCULATOR_ARN\" \\"
    echo "  --output json"
    echo ""
    echo "Alternative parameter names to try:"
    echo "  --lambda-arn"
    echo "  --backend-configuration"
    echo ""
    echo "🔧 Method 2: Use AWS Console"
    echo "=========================="
    echo "1. Go to AWS Bedrock Console → Agent Core → Gateways"
    echo "2. Find gateway: a208194-askjulius-agentcore-gateway-mcp-iam-fvro4phd59"
    echo "3. Click 'Edit' or 'Configure'"
    echo "4. Set Lambda ARN: $CALCULATOR_ARN"
    echo "5. Save configuration"
    echo ""
    echo "🧪 Method 3: Test Gateway with Calculator"
    echo "========================================"
    echo "Once configured, test the gateway:"
    echo ""
    echo "Gateway URL: https://a208194-askjulius-agentcore-gateway-mcp-iam-fvro4phd59.gateway.bedrock-agentcore.us-east-1.amazonaws.com/mcp"
    echo ""
    echo "Test payload:"
    echo '{"jsonrpc":"2.0","id":"gateway-test","method":"tools/list","params":{}}'
    echo ""
    echo "Expected response: List of calculator tools (add, subtract, multiply, etc.)"
fi

echo ""
echo "📋 CALCULATOR MCP SERVER SUMMARY"
echo "================================"

echo ""
echo "✅ What's been created:"
echo "   📦 Lambda Function: $CALCULATOR_FUNCTION_NAME"
echo "   🔧 MCP Tools: add, subtract, multiply, divide, power, sqrt, factorial"
echo "   📋 Function ARN: $CALCULATOR_ARN"
echo ""
echo "🎯 MCP Protocol Features:"
echo "   ✅ Proper JSON-RPC 2.0 implementation"
echo "   ✅ tools/list method (tool discovery)"
echo "   ✅ tools/call method (tool execution)"
echo "   ✅ Error handling with standard MCP error codes"
echo "   ✅ Input validation and schema definitions"
echo ""
echo "🧮 Available Calculator Operations:"
echo "   • add(a, b) - Addition"
echo "   • subtract(a, b) - Subtraction" 
echo "   • multiply(a, b) - Multiplication"
echo "   • divide(a, b) - Division"
echo "   • power(base, exponent) - Exponentiation"
echo "   • sqrt(number) - Square root"
echo "   • factorial(n) - Factorial"
echo ""
echo "🚀 Next Steps:"
echo "   1. Update your gateway to target this calculator ARN"
echo "   2. Test the gateway with calculator operations"
echo "   3. Use this as a template for other MCP servers"

echo ""
echo "✅ Calculator MCP Server deployment completed!"
echo "🧮 Ready to add as gateway target!"