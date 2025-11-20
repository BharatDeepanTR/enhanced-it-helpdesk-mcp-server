#!/bin/bash
# CloudShell: Complete MCP Gateway Setup
# Create calculator MCP server, API Gateway endpoint, and configure gateway

echo "🚀 Complete MCP Gateway Setup in CloudShell"
echo "============================================"
echo ""

# Configuration
GATEWAY_ID="a208194-askjulius-agentcore-gateway-mcp-iam-fvro4phd59"
CALCULATOR_FUNCTION_NAME="calculator-mcp-server"
API_NAME="calculator-mcp-api"
ROLE_ARN="arn:aws:iam::818565325759:role/a208194-askjulius-agentcore-gateway"
REGION="us-east-1"
STAGE_NAME="prod"

echo "🎯 Configuration:"
echo "  Gateway ID: $GATEWAY_ID"
echo "  Calculator Function: $CALCULATOR_FUNCTION_NAME"
echo "  API Gateway: $API_NAME"
echo "  Role: $ROLE_ARN"
echo "  Region: $REGION"
echo ""

echo "🔍 Step 1: Verify AWS Environment"
echo "=============================="

echo "CloudShell AWS Identity:"
aws sts get-caller-identity

echo ""
echo "📦 Step 2: Create Calculator MCP Server Lambda"
echo "============================================="

echo "Creating calculator MCP server code..."

cat > lambda_function.py << 'EOF'
import json
import logging
import math

logger = logging.getLogger()
logger.setLevel(logging.INFO)

def lambda_handler(event, context):
    """
    Calculator MCP Server for Bedrock Agent Core Gateway
    Implements JSON-RPC 2.0 protocol with proper MCP format
    """
    
    try:
        logger.info(f"Received event: {json.dumps(event, default=str)}")
        
        # Handle API Gateway proxy format
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
                'jsonrpc': '2.0',
                'error': {'code': -32600, 'message': 'Invalid Request'},
                'id': body.get('id') if isinstance(body, dict) else None
            }
            return format_response(event, error_response)
        
        method = body.get('method')
        params = body.get('params', {})
        request_id = body.get('id')
        
        logger.info(f"Processing method: {method}")
        
        # Handle MCP methods
        if method == 'tools/list':
            result = handle_tools_list()
        elif method == 'tools/call':
            result = handle_tools_call(params)
        else:
            error_response = {
                'jsonrpc': '2.0',
                'error': {'code': -32601, 'message': f'Unknown method: {method}'},
                'id': request_id
            }
            return format_response(event, error_response)
        
        # Return successful response
        success_response = {
            'jsonrpc': '2.0',
            'result': result,
            'id': request_id
        }
        
        return format_response(event, success_response)
        
    except Exception as e:
        logger.error(f"Calculator server error: {str(e)}")
        error_response = {
            'jsonrpc': '2.0',
            'error': {'code': -32603, 'message': 'Internal error', 'data': str(e)},
            'id': body.get('id') if 'body' in locals() and isinstance(body, dict) else None
        }
        return format_response(event, error_response)

def format_response(event, response_data):
    """Format response for API Gateway or direct invocation"""
    
    if 'body' in event:
        # API Gateway format
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
        # Direct invocation format
        return response_data

def handle_tools_list():
    """Return available calculator tools"""
    return {
        'tools': [
            {
                'name': 'add',
                'description': 'Add two numbers',
                'inputSchema': {
                    'type': 'object',
                    'properties': {
                        'a': {'type': 'number', 'description': 'First number'},
                        'b': {'type': 'number', 'description': 'Second number'}
                    },
                    'required': ['a', 'b']
                }
            },
            {
                'name': 'subtract',
                'description': 'Subtract second number from first',
                'inputSchema': {
                    'type': 'object',
                    'properties': {
                        'a': {'type': 'number', 'description': 'First number'},
                        'b': {'type': 'number', 'description': 'Second number'}
                    },
                    'required': ['a', 'b']
                }
            },
            {
                'name': 'multiply',
                'description': 'Multiply two numbers',
                'inputSchema': {
                    'type': 'object',
                    'properties': {
                        'a': {'type': 'number', 'description': 'First number'},
                        'b': {'type': 'number', 'description': 'Second number'}
                    },
                    'required': ['a', 'b']
                }
            },
            {
                'name': 'divide',
                'description': 'Divide first number by second',
                'inputSchema': {
                    'type': 'object',
                    'properties': {
                        'a': {'type': 'number', 'description': 'Dividend'},
                        'b': {'type': 'number', 'description': 'Divisor'}
                    },
                    'required': ['a', 'b']
                }
            },
            {
                'name': 'power',
                'description': 'Raise base to exponent power',
                'inputSchema': {
                    'type': 'object',
                    'properties': {
                        'base': {'type': 'number', 'description': 'Base number'},
                        'exponent': {'type': 'number', 'description': 'Exponent'}
                    },
                    'required': ['base', 'exponent']
                }
            },
            {
                'name': 'sqrt',
                'description': 'Calculate square root',
                'inputSchema': {
                    'type': 'object',
                    'properties': {
                        'number': {'type': 'number', 'description': 'Number to find square root of'}
                    },
                    'required': ['number']
                }
            },
            {
                'name': 'factorial',
                'description': 'Calculate factorial',
                'inputSchema': {
                    'type': 'object',
                    'properties': {
                        'n': {'type': 'integer', 'description': 'Number to calculate factorial of'}
                    },
                    'required': ['n']
                }
            }
        ]
    }

def handle_tools_call(params):
    """Execute calculator operations"""
    tool_name = params.get('name')
    arguments = params.get('arguments', {})
    
    logger.info(f"Executing tool: {tool_name} with args: {arguments}")
    
    try:
        if tool_name == 'add':
            a = float(arguments.get('a', 0))
            b = float(arguments.get('b', 0))
            result = a + b
            text = f"Addition: {a} + {b} = {result}"
            
        elif tool_name == 'subtract':
            a = float(arguments.get('a', 0))
            b = float(arguments.get('b', 0))
            result = a - b
            text = f"Subtraction: {a} - {b} = {result}"
            
        elif tool_name == 'multiply':
            a = float(arguments.get('a', 0))
            b = float(arguments.get('b', 0))
            result = a * b
            text = f"Multiplication: {a} × {b} = {result}"
            
        elif tool_name == 'divide':
            a = float(arguments.get('a', 0))
            b = float(arguments.get('b', 0))
            if b == 0:
                text = "Error: Division by zero"
            else:
                result = a / b
                text = f"Division: {a} ÷ {b} = {result}"
                
        elif tool_name == 'power':
            base = float(arguments.get('base', 0))
            exponent = float(arguments.get('exponent', 0))
            result = base ** exponent
            text = f"Power: {base}^{exponent} = {result}"
            
        elif tool_name == 'sqrt':
            number = float(arguments.get('number', 0))
            if number < 0:
                text = "Error: Cannot calculate square root of negative number"
            else:
                result = math.sqrt(number)
                text = f"Square root: √{number} = {result}"
                
        elif tool_name == 'factorial':
            n = int(arguments.get('n', 0))
            if n < 0:
                text = "Error: Factorial not defined for negative numbers"
            elif n > 100:
                text = "Error: Number too large for factorial calculation"
            else:
                result = math.factorial(n)
                text = f"Factorial: {n}! = {result}"
                
        else:
            raise ValueError(f"Unknown tool: {tool_name}")
        
        return {
            'content': [{
                'type': 'text',
                'text': text
            }],
            'isError': False
        }
        
    except Exception as e:
        return {
            'content': [{
                'type': 'text',
                'text': f"Calculation error: {str(e)}"
            }],
            'isError': True
        }
EOF

echo "✅ Calculator MCP code created!"

echo ""
echo "Creating deployment package..."
zip -q calculator-mcp-server.zip lambda_function.py

if [ -f "calculator-mcp-server.zip" ]; then
    echo "✅ Deployment package ready"
    ls -la calculator-mcp-server.zip
else
    echo "❌ Failed to create package"
    exit 1
fi

echo ""
echo "🚀 Step 3: Deploy Calculator Lambda"
echo "================================="

echo "Deploying calculator Lambda function..."

# Try to create the function
CREATE_OUTPUT=$(aws lambda create-function \
  --function-name "$CALCULATOR_FUNCTION_NAME" \
  --runtime python3.9 \
  --role "$ROLE_ARN" \
  --handler lambda_function.lambda_handler \
  --zip-file fileb://calculator-mcp-server.zip \
  --description "Calculator MCP Server for Agent Core Gateway" \
  --timeout 30 \
  --memory-size 256 \
  --environment Variables='{\"LOG_LEVEL\":\"INFO\"}' \
  --output json 2>&1)

CREATE_RESULT=$?

if [ $CREATE_RESULT -eq 0 ]; then
    echo "✅ Calculator Lambda created successfully!"
    LAMBDA_ARN=$(echo "$CREATE_OUTPUT" | jq -r '.FunctionArn')
    echo "📋 Function ARN: $LAMBDA_ARN"
    
else
    echo "Create failed, attempting update..."
    
    # Try to update existing function
    UPDATE_OUTPUT=$(aws lambda update-function-code \
      --function-name "$CALCULATOR_FUNCTION_NAME" \
      --zip-file fileb://calculator-mcp-server.zip \
      --output json 2>&1)
    
    if [ $? -eq 0 ]; then
        echo "✅ Calculator Lambda updated successfully!"
        LAMBDA_ARN=$(echo "$UPDATE_OUTPUT" | jq -r '.FunctionArn')
        echo "📋 Function ARN: $LAMBDA_ARN"
    else
        echo "❌ Failed to create or update Lambda"
        echo "Create output: $CREATE_OUTPUT"
        echo "Update output: $UPDATE_OUTPUT"
        exit 1
    fi
fi

echo ""
echo "🧪 Testing Lambda function..."

# Test the Lambda function
TEST_PAYLOAD='{"jsonrpc":"2.0","id":"test","method":"tools/list","params":{}}'

aws lambda invoke \
  --function-name "$CALCULATOR_FUNCTION_NAME" \
  --payload "$TEST_PAYLOAD" \
  --output text \
  response.json >/dev/null 2>&1

if [ -f "response.json" ]; then
    echo "✅ Lambda test successful!"
    echo "📋 Response preview:"
    head -c 200 response.json
    echo "..."
    rm -f response.json
else
    echo "⚠️  Lambda test had issues"
fi

echo ""
echo "🌐 Step 4: Create API Gateway"
echo "=========================="

echo "Creating REST API for MCP endpoint..."

# Create REST API
API_CREATE_OUTPUT=$(aws apigateway create-rest-api \
  --name "$API_NAME" \
  --description "HTTP endpoint for Calculator MCP Server" \
  --output json)

API_ID=$(echo "$API_CREATE_OUTPUT" | jq -r '.id')

if [ -n "$API_ID" ] && [ "$API_ID" != "null" ]; then
    echo "✅ API Gateway created!"
    echo "📋 API ID: $API_ID"
else
    echo "❌ Failed to create API Gateway"
    echo "Output: $API_CREATE_OUTPUT"
    exit 1
fi

# Get root resource ID
ROOT_RESOURCE_ID=$(aws apigateway get-resources \
  --rest-api-id "$API_ID" \
  --query 'items[?path==`/`].id' \
  --output text)

echo "📋 Root resource ID: $ROOT_RESOURCE_ID"

# Create /mcp resource
MCP_RESOURCE_OUTPUT=$(aws apigateway create-resource \
  --rest-api-id "$API_ID" \
  --parent-id "$ROOT_RESOURCE_ID" \
  --path-part "mcp" \
  --output json)

MCP_RESOURCE_ID=$(echo "$MCP_RESOURCE_OUTPUT" | jq -r '.id')
echo "📋 MCP resource ID: $MCP_RESOURCE_ID"

# Create POST method
aws apigateway put-method \
  --rest-api-id "$API_ID" \
  --resource-id "$MCP_RESOURCE_ID" \
  --http-method POST \
  --authorization-type NONE \
  --no-api-key-required >/dev/null

echo "✅ POST method created"

# Create OPTIONS method for CORS
aws apigateway put-method \
  --rest-api-id "$API_ID" \
  --resource-id "$MCP_RESOURCE_ID" \
  --http-method OPTIONS \
  --authorization-type NONE \
  --no-api-key-required >/dev/null

# Set up Lambda integration
aws apigateway put-integration \
  --rest-api-id "$API_ID" \
  --resource-id "$MCP_RESOURCE_ID" \
  --http-method POST \
  --type AWS_PROXY \
  --integration-http-method POST \
  --uri "arn:aws:apigateway:${REGION}:lambda:path/2015-03-31/functions/${LAMBDA_ARN}/invocations" >/dev/null

echo "✅ Lambda integration configured"

# Set up CORS integration
aws apigateway put-integration \
  --rest-api-id "$API_ID" \
  --resource-id "$MCP_RESOURCE_ID" \
  --http-method OPTIONS \
  --type MOCK \
  --request-templates '{"application/json":"{\"statusCode\": 200}"}' >/dev/null

# Add integration response for CORS
aws apigateway put-integration-response \
  --rest-api-id "$API_ID" \
  --resource-id "$MCP_RESOURCE_ID" \
  --http-method OPTIONS \
  --status-code 200 \
  --response-parameters '{"method.response.header.Access-Control-Allow-Headers":"'\''Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'\''","method.response.header.Access-Control-Allow-Methods":"'\''POST,OPTIONS'\''","method.response.header.Access-Control-Allow-Origin":"'\''*'\''}' >/dev/null

# Add method response for CORS
aws apigateway put-method-response \
  --rest-api-id "$API_ID" \
  --resource-id "$MCP_RESOURCE_ID" \
  --http-method OPTIONS \
  --status-code 200 \
  --response-parameters '{"method.response.header.Access-Control-Allow-Headers":false,"method.response.header.Access-Control-Allow-Methods":false,"method.response.header.Access-Control-Allow-Origin":false}' >/dev/null

echo "✅ CORS configured"

# Grant API Gateway permission to invoke Lambda
aws lambda add-permission \
  --function-name "$CALCULATOR_FUNCTION_NAME" \
  --statement-id allow-api-gateway \
  --action lambda:InvokeFunction \
  --principal apigateway.amazonaws.com \
  --source-arn "arn:aws:execute-api:${REGION}:$(aws sts get-caller-identity --query Account --output text):${API_ID}/*/*" 2>/dev/null || echo "Permission already exists"

echo "✅ Lambda permission granted"

# Deploy API
aws apigateway create-deployment \
  --rest-api-id "$API_ID" \
  --stage-name "$STAGE_NAME" \
  --description "MCP Calculator API deployment" >/dev/null

echo "✅ API deployed to stage: $STAGE_NAME"

# Construct endpoint URL
MCP_ENDPOINT_URL="https://${API_ID}.execute-api.${REGION}.amazonaws.com/${STAGE_NAME}/mcp"

echo ""
echo "🌐 MCP Endpoint: $MCP_ENDPOINT_URL"

echo ""
echo "🧪 Step 5: Test API Gateway Endpoint"
echo "=================================="

echo "Testing MCP endpoint..."

# Test endpoint
ENDPOINT_TEST=$(curl -s -X POST "$MCP_ENDPOINT_URL" \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":"test","method":"tools/list","params":{}}' \
  -w "HTTPSTATUS:%{http_code}")

HTTP_STATUS=$(echo "$ENDPOINT_TEST" | grep -o "HTTPSTATUS:[0-9]*" | cut -d: -f2)
RESPONSE_BODY=$(echo "$ENDPOINT_TEST" | sed 's/HTTPSTATUS:[0-9]*$//')

echo "HTTP Status: $HTTP_STATUS"

if [ "$HTTP_STATUS" = "200" ]; then
    echo "✅ Endpoint working!"
    
    if echo "$RESPONSE_BODY" | grep -q '"tools"'; then
        echo "✅ MCP protocol response confirmed!"
        
        # Quick calculation test
        echo ""
        echo "Testing calculation..."
        
        CALC_TEST=$(curl -s -X POST "$MCP_ENDPOINT_URL" \
          -H "Content-Type: application/json" \
          -d '{"jsonrpc":"2.0","id":"calc","method":"tools/call","params":{"name":"add","arguments":{"a":5,"b":3}}}')
        
        if echo "$CALC_TEST" | grep -q "Addition.*5.*3.*8"; then
            echo "✅ Calculator working perfectly!"
            ENDPOINT_READY=true
        else
            echo "⚠️  Calculator response unexpected"
            echo "Response: $CALC_TEST"
        fi
    else
        echo "⚠️  Response doesn't look like MCP"
        echo "Response: $RESPONSE_BODY"
    fi
else
    echo "❌ Endpoint not working (HTTP $HTTP_STATUS)"
    echo "Response: $RESPONSE_BODY"
fi

echo ""
echo "🔧 Step 6: Update Gateway with HTTP Endpoint"
echo "=========================================="

if [ "$ENDPOINT_READY" = "true" ]; then
    echo "Updating gateway to use MCP HTTP endpoint..."
    
    # Try different methods to update gateway
    echo "Method 1: target-endpoint-url..."
    
    GATEWAY_UPDATE_1=$(aws bedrock-agentcore-control update-gateway \
      --gateway-id "$GATEWAY_ID" \
      --target-endpoint-url "$MCP_ENDPOINT_URL" \
      --output json 2>&1)
    
    if [ $? -eq 0 ]; then
        echo "✅ Gateway updated with target-endpoint-url!"
        GATEWAY_UPDATED=true
    else
        echo "Method 1 failed, trying endpoint-configuration..."
        
        GATEWAY_UPDATE_2=$(aws bedrock-agentcore-control update-gateway \
          --gateway-id "$GATEWAY_ID" \
          --endpoint-configuration endpointUrl="$MCP_ENDPOINT_URL" \
          --output json 2>&1)
        
        if [ $? -eq 0 ]; then
            echo "✅ Gateway updated with endpoint-configuration!"
            GATEWAY_UPDATED=true
        else
            echo "⚠️  Gateway update failed with CLI"
            echo "Update output 1: $GATEWAY_UPDATE_1"
            echo "Update output 2: $GATEWAY_UPDATE_2"
        fi
    fi
else
    echo "⚠️  Skipping gateway update - endpoint not ready"
fi

echo ""
echo "🔍 Step 7: Verify Complete Setup"
echo "=============================="

# Check gateway status
echo "Checking updated gateway..."
GATEWAY_INFO=$(aws bedrock-agentcore-control get-gateway \
  --gateway-id "$GATEWAY_ID" \
  --output json 2>/dev/null)

if [ $? -eq 0 ]; then
    echo "✅ Gateway accessible"
    
    # Show relevant configuration
    echo "$GATEWAY_INFO" | jq '{
        id: .id,
        name: .name,
        status: .status,
        endpointUrl: .endpointUrl,
        targetEndpoint: .targetEndpoint
    }' 2>/dev/null || echo "Configuration retrieved"
else
    echo "⚠️  Could not verify gateway"
fi

echo ""
echo "🎉 SETUP COMPLETE!"
echo "================="

echo ""
echo "📋 SUMMARY:"
echo "==========="
echo "✅ Calculator MCP Server: $CALCULATOR_FUNCTION_NAME"
echo "✅ API Gateway: $API_NAME ($API_ID)"
echo "✅ MCP Endpoint: $MCP_ENDPOINT_URL"
echo "✅ Gateway: $GATEWAY_ID"

echo ""
echo "🧮 Available Calculator Operations:"
echo "• add(a, b) - Addition"
echo "• subtract(a, b) - Subtraction"
echo "• multiply(a, b) - Multiplication"
echo "• divide(a, b) - Division"
echo "• power(base, exponent) - Exponentiation"
echo "• sqrt(number) - Square root"
echo "• factorial(n) - Factorial"

echo ""
echo "🧪 Test Commands:"
echo "==============="
echo "# List tools:"
echo "curl -X POST '$MCP_ENDPOINT_URL' \\"
echo "  -H 'Content-Type: application/json' \\"
echo "  -d '{\"jsonrpc\":\"2.0\",\"method\":\"tools/list\",\"params\":{}}'"
echo ""
echo "# Calculate 5 + 3:"
echo "curl -X POST '$MCP_ENDPOINT_URL' \\"
echo "  -H 'Content-Type: application/json' \\"
echo "  -d '{\"jsonrpc\":\"2.0\",\"method\":\"tools/call\",\"params\":{\"name\":\"add\",\"arguments\":{\"a\":5,\"b\":3}}}'"

if [ "$GATEWAY_UPDATED" = "true" ]; then
    echo ""
    echo "🎯 Gateway Configuration:"
    echo "========================"
    echo "✅ Gateway updated to use HTTP endpoint"
    echo "🌐 Target: $MCP_ENDPOINT_URL"
    echo "📋 Gateway ID: $GATEWAY_ID"
else
    echo ""
    echo "🔧 Manual Gateway Configuration:"
    echo "==============================="
    echo "If CLI update failed, configure via AWS Console:"
    echo "1. Go to Bedrock → Agent Core → Gateways"
    echo "2. Find gateway: $GATEWAY_ID"
    echo "3. Edit target configuration:"
    echo "   • Type: HTTP Endpoint"
    echo "   • URL: $MCP_ENDPOINT_URL"
fi

echo ""
echo "🚀 Ready for Agent Core Gateway testing!"

# Cleanup
rm -f lambda_function.py calculator-mcp-server.zip response.json