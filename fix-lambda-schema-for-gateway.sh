#!/bin/bash
# CloudShell: Fix Lambda Schema Format for Direct Gateway Targeting
# Update calculator Lambda with proper JSON schema format

echo "🔧 Fix Lambda Schema Format for Gateway Compatibility"
echo "===================================================="
echo ""

CALCULATOR_FUNCTION_NAME="a208194-calculator-mcp-server"
REGION="us-east-1"

echo "🎯 Configuration:"
echo "  Function: $CALCULATOR_FUNCTION_NAME"
echo "  Region: $REGION"
echo ""

echo "🔍 Issue Analysis:"
echo "================="
echo "❌ Error: 'Invalid JSON in inline schema'"
echo "🎯 Root Cause: Python dict format != JSON format in schemas"
echo "🔧 Solution: Fix schema format to be JSON-compliant"
echo ""

echo "📦 Step 1: Create Fixed Calculator Code"
echo "====================================="

echo "Creating calculator Lambda with JSON-compliant schemas..."

cat > lambda_function_fixed.py << 'EOF'
import json
import logging
import math

logger = logging.getLogger()
logger.setLevel(logging.INFO)

def lambda_handler(event, context):
    """
    Calculator MCP Server - Fixed for Agent Core Gateway Direct Targeting
    
    Key Fix: All schemas return proper JSON format, not Python dict format
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
            result = handle_tools_list()
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
        # Direct Lambda invocation format - MUST be JSON serializable
        return response_data

def handle_tools_list():
    """
    Return available calculator tools with JSON-compliant schemas
    
    KEY FIX: All schemas use JSON-compatible format
    """
    
    return {
        "tools": [
            {
                "name": "add",
                "description": "Add two numbers together",
                "inputSchema": {
                    "type": "object",
                    "properties": {
                        "a": {
                            "type": "number", 
                            "description": "First number to add"
                        },
                        "b": {
                            "type": "number", 
                            "description": "Second number to add"
                        }
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
                        "a": {
                            "type": "number", 
                            "description": "Number to subtract from"
                        },
                        "b": {
                            "type": "number", 
                            "description": "Number to subtract"
                        }
                    },
                    "required": ["a", "b"]
                }
            },
            {
                "name": "multiply",
                "description": "Multiply two numbers together",
                "inputSchema": {
                    "type": "object",
                    "properties": {
                        "a": {
                            "type": "number", 
                            "description": "First number to multiply"
                        },
                        "b": {
                            "type": "number", 
                            "description": "Second number to multiply"
                        }
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
                        "a": {
                            "type": "number", 
                            "description": "Dividend (number to be divided)"
                        },
                        "b": {
                            "type": "number", 
                            "description": "Divisor (number to divide by)"
                        }
                    },
                    "required": ["a", "b"]
                }
            },
            {
                "name": "power",
                "description": "Raise base number to the power of exponent",
                "inputSchema": {
                    "type": "object",
                    "properties": {
                        "base": {
                            "type": "number", 
                            "description": "Base number"
                        },
                        "exponent": {
                            "type": "number", 
                            "description": "Exponent (power to raise base to)"
                        }
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
                        "number": {
                            "type": "number", 
                            "description": "Number to find square root of (must be non-negative)"
                        }
                    },
                    "required": ["number"]
                }
            }
        ]
    }

def handle_tools_call(params):
    """Execute calculator operations"""
    
    tool_name = params.get('name')
    arguments = params.get('arguments', {})
    
    logger.info(f"Executing calculator tool: {tool_name} with arguments: {arguments}")
    
    try:
        if tool_name == "add":
            a = float(arguments.get('a', 0))
            b = float(arguments.get('b', 0))
            result_value = a + b
            result_text = f"Addition: {a} + {b} = {result_value}"
            
        elif tool_name == "subtract":
            a = float(arguments.get('a', 0))
            b = float(arguments.get('b', 0))
            result_value = a - b
            result_text = f"Subtraction: {a} - {b} = {result_value}"
            
        elif tool_name == "multiply":
            a = float(arguments.get('a', 0))
            b = float(arguments.get('b', 0))
            result_value = a * b
            result_text = f"Multiplication: {a} × {b} = {result_value}"
            
        elif tool_name == "divide":
            a = float(arguments.get('a', 0))
            b = float(arguments.get('b', 0))
            
            if b == 0:
                result_text = "Error: Division by zero is undefined"
                is_error = True
            else:
                result_value = a / b
                result_text = f"Division: {a} ÷ {b} = {result_value}"
                is_error = False
                
        elif tool_name == "power":
            base = float(arguments.get('base', 0))
            exponent = float(arguments.get('exponent', 0))
            result_value = base ** exponent
            result_text = f"Power: {base}^{exponent} = {result_value}"
            is_error = False
            
        elif tool_name == "sqrt":
            number = float(arguments.get('number', 0))
            
            if number < 0:
                result_text = "Error: Cannot calculate square root of negative number"
                is_error = True
            else:
                result_value = math.sqrt(number)
                result_text = f"Square root: √{number} = {result_value}"
                is_error = False
                
        else:
            raise ValueError(f"Unknown calculator tool: {tool_name}")
        
        return {
            "content": [{
                "type": "text",
                "text": result_text
            }],
            "isError": is_error if 'is_error' in locals() else False
        }
        
    except (ValueError, TypeError, OverflowError) as e:
        logger.warning(f"Calculation error for tool {tool_name}: {str(e)}")
        
        return {
            "content": [{
                "type": "text",
                "text": f"Calculation error: {str(e)}"
            }],
            "isError": True
        }
    
    except Exception as e:
        logger.error(f"Unexpected error in tool {tool_name}: {str(e)}")
        
        return {
            "content": [{
                "type": "text",
                "text": f"Internal calculation error: {str(e)}"
            }],
            "isError": True
        }
EOF

echo "✅ Fixed calculator code created!"

echo ""
echo "📦 Step 2: Create Updated Deployment Package"
echo "=========================================="

echo "Creating deployment package..."
rm -f calculator-mcp-server-fixed.zip
zip -q calculator-mcp-server-fixed.zip lambda_function_fixed.py

if [ -f "calculator-mcp-server-fixed.zip" ]; then
    echo "✅ Fixed deployment package ready: calculator-mcp-server-fixed.zip"
    ls -la calculator-mcp-server-fixed.zip
else
    echo "❌ Failed to create package"
    exit 1
fi

echo ""
echo "🚀 Step 3: Update Lambda Function"
echo "=============================="

echo "Updating calculator Lambda with fixed schema format..."

UPDATE_OUTPUT=$(aws lambda update-function-code \
    --function-name "$CALCULATOR_FUNCTION_NAME" \
    --zip-file fileb://calculator-mcp-server-fixed.zip \
    --output json 2>&1)

UPDATE_RESULT=$?

if [ $UPDATE_RESULT -eq 0 ]; then
    echo "✅ Lambda function updated successfully!"
    
    # Extract version info
    VERSION=$(echo "$UPDATE_OUTPUT" | jq -r '.Version' 2>/dev/null)
    LAST_MODIFIED=$(echo "$UPDATE_OUTPUT" | jq -r '.LastModified' 2>/dev/null)
    
    echo "📋 Update Details:"
    echo "   Version: $VERSION"
    echo "   Last Modified: $LAST_MODIFIED"
    
else
    echo "❌ Failed to update Lambda function"
    echo "Error: $UPDATE_OUTPUT"
    exit 1
fi

echo ""
echo "🧪 Step 4: Test Updated Lambda"
echo "=========================="

echo "Testing Lambda with fixed schema format..."

TEST_PAYLOAD='{"jsonrpc":"2.0","id":"schema-test","method":"tools/list","params":{}}'

LAMBDA_TEST_RESULT=$(aws lambda invoke \
    --function-name "$CALCULATOR_FUNCTION_NAME" \
    --payload "$TEST_PAYLOAD" \
    --output text \
    /tmp/fixed-lambda-response.json 2>&1)

if [ $? -eq 0 ] && [ -f "/tmp/fixed-lambda-response.json" ]; then
    echo "✅ Lambda test successful!"
    
    # Check response
    RESPONSE_CONTENT=$(cat /tmp/fixed-lambda-response.json)
    
    if echo "$RESPONSE_CONTENT" | grep -q '"jsonrpc":"2.0"' && echo "$RESPONSE_CONTENT" | grep -q '"tools"'; then
        echo "✅ MCP protocol confirmed!"
        
        # Check schema format
        if echo "$RESPONSE_CONTENT" | grep -q '"type":"object"' && echo "$RESPONSE_CONTENT" | grep -q '"properties"'; then
            echo "✅ JSON schema format confirmed!"
            LAMBDA_SCHEMA_FIXED=true
        else
            echo "⚠️  Schema format may still have issues"
        fi
    else
        echo "❌ MCP protocol response issue"
        echo "Response: $RESPONSE_CONTENT"
    fi
    
    rm -f /tmp/fixed-lambda-response.json
    
else
    echo "❌ Lambda test failed!"
    echo "Error: $LAMBDA_TEST_RESULT"
    exit 1
fi

echo ""
echo "🔧 Step 5: Retry Direct Lambda ARN Gateway Configuration"
echo "====================================================="

if [ "$LAMBDA_SCHEMA_FIXED" = "true" ]; then
    echo "Attempting gateway configuration with fixed Lambda..."
    
    # Get Lambda ARN
    LAMBDA_ARN=$(aws lambda get-function --function-name "$CALCULATOR_FUNCTION_NAME" --query 'Configuration.FunctionArn' --output text)
    
    GATEWAY_ID="a208194-askjulius-agentcore-gateway-mcp-iam-fvro4phd59"
    
    echo "📋 Configuration:"
    echo "   Gateway: $GATEWAY_ID"
    echo "   Lambda ARN: $LAMBDA_ARN"
    
    # Try to update gateway
    GATEWAY_UPDATE=$(aws bedrock-agentcore-control update-gateway \
        --gateway-id "$GATEWAY_ID" \
        --target-lambda-arn "$LAMBDA_ARN" \
        --output json 2>&1)
    
    GATEWAY_RESULT=$?
    
    if [ $GATEWAY_RESULT -eq 0 ]; then
        echo "🎉 SUCCESS! Gateway configured with direct Lambda ARN!"
        
        # Verify configuration
        sleep 3
        echo "Verifying gateway configuration..."
        
        UPDATED_GATEWAY=$(aws bedrock-agentcore-control get-gateway \
            --gateway-id "$GATEWAY_ID" \
            --output json 2>/dev/null)
        
        if [ $? -eq 0 ]; then
            echo "✅ Gateway verification successful!"
            echo "$UPDATED_GATEWAY" | jq '{
                id: .id,
                name: .name,
                status: .status,
                lambdaArn: .lambdaArn
            }' 2>/dev/null || echo "Configuration updated"
            
            GATEWAY_CONFIGURED=true
        fi
        
    else
        echo "❌ Gateway configuration still failed"
        echo "Error: $GATEWAY_UPDATE"
        
        # Analyze the error
        if echo "$GATEWAY_UPDATE" | grep -q "Invalid JSON in inline schema"; then
            echo ""
            echo "🔍 Still getting schema error - possible additional issues:"
            echo "• Schema might need different format for gateway validation"
            echo "• Gateway might have stricter JSON requirements"
            echo "• May need to use HTTP endpoint approach instead"
        fi
    fi
else
    echo "❌ Skipping gateway update - Lambda schema still has issues"
fi

echo ""
echo "📊 RESULTS"
echo "=========="

if [ "$GATEWAY_CONFIGURED" = "true" ]; then
    echo "🎉 SUCCESS! Direct Lambda ARN targeting works!"
    echo ""
    echo "✅ What was fixed:"
    echo "• Changed Python single quotes to JSON double quotes"
    echo "• Ensured all schema objects are JSON-serializable"
    echo "• Fixed string formatting in schemas"
    echo ""
    echo "🚀 Your gateway is now configured with:"
    echo "• Calculator Lambda: $CALCULATOR_FUNCTION_NAME"
    echo "• Direct Lambda ARN targeting (no API Gateway needed)"
    echo "• 6 calculator operations available"
    echo ""
    echo "🎯 Next Steps:"
    echo "• Test calculator via gateway"
    echo "• Apply same schema fix pattern to other Lambdas"
    echo "• Use direct Lambda ARN approach for all functions"
    
else
    echo "⚠️  Direct Lambda ARN approach still has issues"
    echo ""
    echo "🔧 Alternative Solutions:"
    echo "1. Use API Gateway approach (known to work)"
    echo "2. Further investigate schema format requirements"
    echo "3. Check if gateway has additional validation rules"
    echo ""
    echo "📋 What was attempted:"
    echo "• Fixed JSON schema format"
    echo "• Updated Lambda with proper JSON quotes"
    echo "• Tested Lambda function independently"
    echo ""
    echo "🎯 Recommendation:"
    echo "Use the API Gateway approach for reliable HTTP endpoint targeting"
fi

# Cleanup
rm -f lambda_function_fixed.py calculator-mcp-server-fixed.zip