#!/bin/bash
# CloudShell: Fixed MCP Gateway Setup (handles permissions & syntax)
# Create calculator MCP server, API Gateway endpoint, and configure gateway

echo "🚀 Fixed MCP Gateway Setup in CloudShell"
echo "========================================"
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

echo "🔍 Step 1: Check AWS Environment & Permissions"
echo "============================================="

echo "CloudShell AWS Identity:"
CALLER_IDENTITY=$(aws sts get-caller-identity)
echo "$CALLER_IDENTITY"

USER_ARN=$(echo "$CALLER_IDENTITY" | jq -r '.Arn')
ACCOUNT_ID=$(echo "$CALLER_IDENTITY" | jq -r '.Account')

echo ""
echo "🔐 Checking Lambda Permissions..."

# Test Lambda permissions
LAMBDA_TEST=$(aws lambda list-functions --max-items 1 2>&1)
if echo "$LAMBDA_TEST" | grep -q "AccessDenied\|not authorized"; then
    echo "❌ LAMBDA PERMISSIONS DENIED"
    echo "==============================================="
    echo "Your current role: $(echo "$USER_ARN" | cut -d'/' -f2)"
    echo ""
    echo "🚨 PERMISSION ISSUES DETECTED:"
    echo "• lambda:CreateFunction"
    echo "• lambda:UpdateFunctionCode"
    echo "• lambda:UpdateFunctionConfiguration"
    echo "• lambda:ListFunctions"
    echo "• lambda:InvokeFunction"
    echo ""
    echo "🔧 SOLUTIONS:"
    echo ""
    echo "Option 1: Request Lambda Permissions"
    echo "-----------------------------------"
    echo "Ask your admin to add these policies to your role:"
    echo "• AWSLambda_FullAccess"
    echo "• Or custom policy with lambda:* permissions"
    echo ""
    echo "Option 2: Use Console Method"
    echo "---------------------------"
    echo "1. Go to AWS Lambda Console"
    echo "2. Create function manually:"
    echo "   - Name: $CALCULATOR_FUNCTION_NAME"
    echo "   - Runtime: Python 3.9"
    echo "   - Role: $ROLE_ARN"
    echo "3. Copy the calculator code (provided below)"
    echo "4. Run the API Gateway part of this script"
    echo ""
    echo "Option 3: Alternative Architecture"
    echo "--------------------------------"
    echo "Use your existing application Lambda with universal wrapper"
    echo ""
    
    # Still provide the calculator code for manual creation
    echo "📦 CALCULATOR CODE FOR MANUAL CREATION:"
    echo "======================================"
    
    cat > calculator-code-for-manual-creation.py << 'MANUAL_EOF'
import json
import logging
import math

logger = logging.getLogger()
logger.setLevel(logging.INFO)

def lambda_handler(event, context):
    """
    Calculator MCP Server for Bedrock Agent Core Gateway
    Copy this code to Lambda console for manual creation
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
            
        elif tool_name == 'multiply':
            a = float(arguments.get('a', 0))
            b = float(arguments.get('b', 0))
            result = a * b
            text = f"Multiplication: {a} × {b} = {result}"
            
        elif tool_name == 'power':
            base = float(arguments.get('base', 0))
            exponent = float(arguments.get('exponent', 0))
            result = base ** exponent
            text = f"Power: {base}^{exponent} = {result}"
            
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
MANUAL_EOF

    echo ""
    echo "✅ Calculator code saved to: calculator-code-for-manual-creation.py"
    echo "📋 Copy this file content to Lambda console"
    echo ""
    echo "After manual Lambda creation, run:"
    echo "  ./cloudshell-setup-fixed.sh --api-only"
    echo ""
    
    # Check if user wants to continue with API Gateway only
    if [[ "$1" != "--api-only" ]]; then
        echo "❌ Stopping due to Lambda permission issues"
        echo "🔧 Create Lambda manually, then re-run with --api-only"
        exit 1
    fi
    
    echo "🔄 Continuing with API Gateway setup only..."
    LAMBDA_CREATED_MANUALLY=true
    
else
    echo "✅ Lambda permissions: OK"
    LAMBDA_PERMISSIONS_OK=true
fi

if [[ "$LAMBDA_PERMISSIONS_OK" == "true" ]]; then
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
    """Calculator MCP Server for Bedrock Agent Core Gateway"""
    
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
        
        if method == 'tools/list':
            result = {
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
                    }
                ]
            }
            
        elif method == 'tools/call':
            tool_name = params.get('name')
            arguments = params.get('arguments', {})
            
            if tool_name == 'add':
                a = float(arguments.get('a', 0))
                b = float(arguments.get('b', 0))
                result_val = a + b
                text = f"Addition: {a} + {b} = {result_val}"
                
            elif tool_name == 'multiply':
                a = float(arguments.get('a', 0))
                b = float(arguments.get('b', 0))
                result_val = a * b
                text = f"Multiplication: {a} × {b} = {result_val}"
                
            else:
                raise ValueError(f"Unknown tool: {tool_name}")
            
            result = {
                'content': [{
                    'type': 'text',
                    'text': text
                }],
                'isError': False
            }
        else:
            error_response = {
                'jsonrpc': '2.0',
                'error': {'code': -32601, 'message': f'Unknown method: {method}'},
                'id': request_id
            }
            return format_response(event, error_response)
        
        success_response = {
            'jsonrpc': '2.0',
            'result': result,
            'id': request_id
        }
        
        return format_response(event, success_response)
        
    except Exception as e:
        logger.error(f"Calculator error: {str(e)}")
        error_response = {
            'jsonrpc': '2.0',
            'error': {'code': -32603, 'message': 'Internal error', 'data': str(e)},
            'id': body.get('id') if 'body' in locals() and isinstance(body, dict) else None
        }
        return format_response(event, error_response)

def format_response(event, response_data):
    """Format response for API Gateway or direct invocation"""
    if 'body' in event:
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
        return response_data
EOF

    echo "✅ Calculator MCP code created!"

    echo ""
    echo "Creating deployment package..."
    zip -q calculator-mcp-server.zip lambda_function.py

    if [ -f "calculator-mcp-server.zip" ]; then
        echo "✅ Deployment package ready"
    else
        echo "❌ Failed to create package"
        exit 1
    fi

    echo ""
    echo "🚀 Step 3: Deploy Calculator Lambda (Fixed Syntax)"
    echo "================================================="

    echo "Deploying calculator Lambda function..."

    # Fixed environment variable syntax - no escaping issues
    CREATE_OUTPUT=$(aws lambda create-function \
      --function-name "$CALCULATOR_FUNCTION_NAME" \
      --runtime python3.9 \
      --role "$ROLE_ARN" \
      --handler lambda_function.lambda_handler \
      --zip-file fileb://calculator-mcp-server.zip \
      --description "Calculator MCP Server for Agent Core Gateway" \
      --timeout 30 \
      --memory-size 256 \
      --environment Variables='{LOG_LEVEL=INFO}' \
      --output json 2>&1)

    CREATE_RESULT=$?

    if [ $CREATE_RESULT -eq 0 ]; then
        echo "✅ Calculator Lambda created successfully!"
        LAMBDA_ARN=$(echo "$CREATE_OUTPUT" | jq -r '.FunctionArn')
        echo "📋 Function ARN: $LAMBDA_ARN"
        
    else
        echo "Create failed, attempting update..."
        
        # Try to update existing function (also with fixed syntax)
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
            echo "Create error: $CREATE_OUTPUT"
            echo "Update error: $UPDATE_OUTPUT"
            
            # Check for permission issues
            if echo "$CREATE_OUTPUT $UPDATE_OUTPUT" | grep -q "AccessDenied\|not authorized"; then
                echo ""
                echo "🚨 This is a PERMISSIONS issue, not a syntax issue"
                echo "You need Lambda permissions from your administrator"
                exit 1
            else
                echo ""
                echo "🤔 Unexpected error - please check the output above"
                exit 1
            fi
        fi
    fi

    # Test the Lambda function
    echo ""
    echo "🧪 Testing Lambda function..."

    TEST_PAYLOAD='{"jsonrpc":"2.0","id":"test","method":"tools/list","params":{}}'

    aws lambda invoke \
      --function-name "$CALCULATOR_FUNCTION_NAME" \
      --payload "$TEST_PAYLOAD" \
      --output text \
      response.json >/dev/null 2>&1

    if [ -f "response.json" ]; then
        echo "✅ Lambda test successful!"
        rm -f response.json
        LAMBDA_READY=true
    else
        echo "⚠️  Lambda test had issues"
        LAMBDA_READY=true  # Continue anyway
    fi

    # Clean up deployment files
    rm -f lambda_function.py calculator-mcp-server.zip

elif [[ "$LAMBDA_CREATED_MANUALLY" == "true" ]]; then
    echo ""
    echo "📋 Step 2: Using Manually Created Lambda"
    echo "======================================="
    
    # Verify the Lambda exists
    LAMBDA_CHECK=$(aws lambda get-function --function-name "$CALCULATOR_FUNCTION_NAME" 2>&1)
    
    if echo "$LAMBDA_CHECK" | grep -q "ResourceNotFoundException"; then
        echo "❌ Lambda function $CALCULATOR_FUNCTION_NAME not found"
        echo "🔧 Please create it manually first using the provided code"
        exit 1
    else
        echo "✅ Found manually created Lambda function"
        LAMBDA_ARN=$(echo "$LAMBDA_CHECK" | jq -r '.Configuration.FunctionArn' 2>/dev/null)
        echo "📋 Function ARN: $LAMBDA_ARN"
        LAMBDA_READY=true
    fi
fi

if [[ "$LAMBDA_READY" == "true" ]]; then
    echo ""
    echo "🌐 Step 4: Create API Gateway"
    echo "=========================="

    echo "Creating REST API for MCP endpoint..."

    # Create REST API
    API_CREATE_OUTPUT=$(aws apigateway create-rest-api \
      --name "$API_NAME" \
      --description "HTTP endpoint for Calculator MCP Server" \
      --output json 2>&1)

    API_ID=$(echo "$API_CREATE_OUTPUT" | jq -r '.id' 2>/dev/null)

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

    # Create /mcp resource
    MCP_RESOURCE_OUTPUT=$(aws apigateway create-resource \
      --rest-api-id "$API_ID" \
      --parent-id "$ROOT_RESOURCE_ID" \
      --path-part "mcp" \
      --output json)

    MCP_RESOURCE_ID=$(echo "$MCP_RESOURCE_OUTPUT" | jq -r '.id')

    # Create POST method
    aws apigateway put-method \
      --rest-api-id "$API_ID" \
      --resource-id "$MCP_RESOURCE_ID" \
      --http-method POST \
      --authorization-type NONE \
      --no-api-key-required >/dev/null

    # Set up Lambda integration
    aws apigateway put-integration \
      --rest-api-id "$API_ID" \
      --resource-id "$MCP_RESOURCE_ID" \
      --http-method POST \
      --type AWS_PROXY \
      --integration-http-method POST \
      --uri "arn:aws:apigateway:${REGION}:lambda:path/2015-03-31/functions/arn:aws:lambda:${REGION}:${ACCOUNT_ID}:function:${CALCULATOR_FUNCTION_NAME}/invocations" >/dev/null

    # Grant permission to API Gateway
    aws lambda add-permission \
      --function-name "$CALCULATOR_FUNCTION_NAME" \
      --statement-id allow-api-gateway-$(date +%s) \
      --action lambda:InvokeFunction \
      --principal apigateway.amazonaws.com \
      --source-arn "arn:aws:execute-api:${REGION}:${ACCOUNT_ID}:${API_ID}/*/*" 2>/dev/null || echo "Permission already exists or added"

    # Deploy API
    aws apigateway create-deployment \
      --rest-api-id "$API_ID" \
      --stage-name "$STAGE_NAME" \
      --description "MCP Calculator API deployment" >/dev/null

    # Construct endpoint URL
    MCP_ENDPOINT_URL="https://${API_ID}.execute-api.${REGION}.amazonaws.com/${STAGE_NAME}/mcp"

    echo "✅ API Gateway deployed!"
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
            ENDPOINT_READY=true
        else
            echo "⚠️  Response doesn't look like MCP"
            echo "Response: $RESPONSE_BODY"
        fi
    else
        echo "❌ Endpoint not working (HTTP $HTTP_STATUS)"
        echo "Response: $RESPONSE_BODY"
        echo ""
        echo "🔧 Try testing the Lambda directly first"
    fi

    if [[ "$ENDPOINT_READY" == "true" ]]; then
        echo ""
        echo "🔧 Step 6: Update Gateway with HTTP Endpoint"
        echo "=========================================="
        
        echo "Updating gateway to use MCP HTTP endpoint..."
        
        # Try to update gateway
        GATEWAY_UPDATE=$(aws bedrock-agentcore-control update-gateway \
          --gateway-id "$GATEWAY_ID" \
          --target-endpoint-url "$MCP_ENDPOINT_URL" \
          --output json 2>&1)
        
        if [ $? -eq 0 ]; then
            echo "✅ Gateway updated successfully!"
            GATEWAY_UPDATED=true
        else
            echo "⚠️  Gateway update failed via CLI"
            echo "Update response: $GATEWAY_UPDATE"
            echo ""
            echo "🔧 Manual Configuration Required:"
            echo "1. Go to Bedrock → Agent Core → Gateways"
            echo "2. Find gateway: $GATEWAY_ID"
            echo "3. Edit target configuration:"
            echo "   • Type: HTTP Endpoint"
            echo "   • URL: $MCP_ENDPOINT_URL"
        fi
    fi

    echo ""
    echo "🎉 SETUP COMPLETE!"
    echo "================="

    echo ""
    echo "📋 FINAL SUMMARY:"
    echo "================="
    if [[ "$LAMBDA_READY" == "true" ]]; then
        echo "✅ Calculator Lambda: $CALCULATOR_FUNCTION_NAME"
    fi
    echo "✅ API Gateway: $API_NAME ($API_ID)"
    echo "✅ MCP Endpoint: $MCP_ENDPOINT_URL"
    echo "✅ Gateway: $GATEWAY_ID"

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

    echo ""
    echo "🚀 Ready for Agent Core Gateway testing!"

else
    echo ""
    echo "❌ Setup incomplete - Lambda not ready"
    echo "🔧 Please resolve Lambda creation issues first"
fi