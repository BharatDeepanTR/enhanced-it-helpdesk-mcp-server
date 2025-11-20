#!/bin/bash
# Simple Calculator Lambda Creation with Permission Check

echo "🔍 Checking AWS Permissions and Creating Calculator Lambda"
echo "========================================================="

FUNCTION_NAME="calculator-mcp-server"
ROLE_ARN="arn:aws:iam::818565325759:role/a208194-askjulius-agentcore-gateway"

echo "🎯 Configuration:"
echo "  Function: $FUNCTION_NAME"
echo "  Role: $ROLE_ARN"
echo ""

echo "🔍 Step 1: Check AWS Identity and Permissions"
echo "==========================================="

echo "Current AWS identity:"
aws sts get-caller-identity 2>/dev/null || {
    echo "❌ AWS credentials not configured"
    echo "🔧 Please run: aws configure"
    exit 1
}

echo ""
echo "Testing Lambda permissions..."

# Test Lambda list permissions
LAMBDA_LIST=$(aws lambda list-functions --max-items 1 2>/dev/null)
if [ $? -eq 0 ]; then
    echo "✅ Lambda list permission: OK"
else
    echo "❌ Lambda list permission: DENIED"
    echo ""
    echo "🚨 PERMISSION ISSUE DETECTED"
    echo "=========================="
    echo "Your role: a208194-PowerUser2"
    echo "Missing permissions:"
    echo "• lambda:CreateFunction"
    echo "• lambda:UpdateFunctionCode" 
    echo "• lambda:UpdateFunctionConfiguration"
    echo "• lambda:ListFunctions"
    echo ""
    echo "🔧 SOLUTION: Request Lambda permissions from your admin"
    echo "   OR use a different approach with existing resources"
    exit 1
fi

echo ""
echo "📦 Step 2: Create Lambda Function Code"
echo "===================================="

# Create minimal calculator code
cat > lambda_function.py << 'CALCEOF'
import json
import logging
import math

logger = logging.getLogger()
logger.setLevel(logging.INFO)

def lambda_handler(event, context):
    """
    Simple Calculator MCP Server
    Implements JSON-RPC 2.0 protocol for Bedrock Agent Core
    """
    
    try:
        logger.info(f"Received event: {json.dumps(event)}")
        
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
            return {
                'statusCode': 400,
                'headers': {'Content-Type': 'application/json'},
                'body': json.dumps({
                    'jsonrpc': '2.0',
                    'error': {'code': -32600, 'message': 'Invalid Request'},
                    'id': body.get('id') if isinstance(body, dict) else None
                })
            }
        
        method = body.get('method')
        params = body.get('params', {})
        request_id = body.get('id')
        
        # Handle different MCP methods
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
                calc_result = a + b
                result = {
                    'content': [{
                        'type': 'text',
                        'text': f'Addition: {a} + {b} = {calc_result}'
                    }],
                    'isError': False
                }
                
            elif tool_name == 'multiply':
                a = float(arguments.get('a', 0))
                b = float(arguments.get('b', 0))
                calc_result = a * b
                result = {
                    'content': [{
                        'type': 'text', 
                        'text': f'Multiplication: {a} × {b} = {calc_result}'
                    }],
                    'isError': False
                }
                
            else:
                return {
                    'statusCode': 400,
                    'headers': {'Content-Type': 'application/json'},
                    'body': json.dumps({
                        'jsonrpc': '2.0',
                        'error': {'code': -32601, 'message': f'Unknown tool: {tool_name}'},
                        'id': request_id
                    })
                }
        else:
            return {
                'statusCode': 400,
                'headers': {'Content-Type': 'application/json'},
                'body': json.dumps({
                    'jsonrpc': '2.0',
                    'error': {'code': -32601, 'message': f'Unknown method: {method}'},
                    'id': request_id
                })
            }
        
        # Return successful response
        response = {
            'statusCode': 200,
            'headers': {'Content-Type': 'application/json'},
            'body': json.dumps({
                'jsonrpc': '2.0',
                'result': result,
                'id': request_id
            })
        }
        
        logger.info(f"Returning response: {json.dumps(response)}")
        return response
        
    except Exception as e:
        logger.error(f"Lambda error: {str(e)}")
        return {
            'statusCode': 500,
            'headers': {'Content-Type': 'application/json'},
            'body': json.dumps({
                'jsonrpc': '2.0',
                'error': {'code': -32603, 'message': 'Internal error', 'data': str(e)},
                'id': body.get('id') if 'body' in locals() and isinstance(body, dict) else None
            })
        }
CALCEOF

echo "✅ Simple calculator code created"

echo ""
echo "📦 Step 3: Create Deployment Package"
echo "=================================="

rm -f calculator-simple.zip
zip -q calculator-simple.zip lambda_function.py

if [ -f "calculator-simple.zip" ]; then
    echo "✅ Package created: calculator-simple.zip"
    ls -la calculator-simple.zip
else
    echo "❌ Failed to create package"
    exit 1
fi

echo ""
echo "🚀 Step 4: Deploy Lambda Function"
echo "=============================="

echo "Attempting to create Lambda function..."

DEPLOY_OUTPUT=$(aws lambda create-function \
  --function-name "$FUNCTION_NAME" \
  --runtime python3.9 \
  --role "$ROLE_ARN" \
  --handler lambda_function.lambda_handler \
  --zip-file fileb://calculator-simple.zip \
  --description "Simple Calculator MCP Server" \
  --timeout 30 \
  --memory-size 256 \
  --output json 2>&1)

DEPLOY_RESULT=$?

if [ $DEPLOY_RESULT -eq 0 ]; then
    echo "🎉 SUCCESS! Lambda function created!"
    
    # Extract function ARN
    FUNCTION_ARN=$(echo "$DEPLOY_OUTPUT" | jq -r '.FunctionArn' 2>/dev/null)
    echo "📋 Function ARN: $FUNCTION_ARN"
    
    echo ""
    echo "🧪 Testing Lambda function..."
    
    # Test the function
    TEST_PAYLOAD='{"jsonrpc":"2.0","id":"test","method":"tools/list","params":{}}'
    
    TEST_OUTPUT=$(aws lambda invoke \
      --function-name "$FUNCTION_NAME" \
      --payload "$TEST_PAYLOAD" \
      --output text \
      response.json 2>&1)
    
    if [ $? -eq 0 ] && [ -f "response.json" ]; then
        echo "✅ Lambda function test successful!"
        echo "📋 Response:"
        cat response.json | jq '.' 2>/dev/null || cat response.json
        rm -f response.json
        
        FUNCTION_READY=true
    else
        echo "⚠️  Lambda created but test failed"
        echo "Output: $TEST_OUTPUT"
    fi
    
else
    echo "❌ Failed to create Lambda function"
    echo "Error output:"
    echo "$DEPLOY_OUTPUT"
    
    # Check if function already exists
    if echo "$DEPLOY_OUTPUT" | grep -q "ResourceConflictException\|already exists"; then
        echo ""
        echo "🔄 Function already exists, attempting update..."
        
        UPDATE_OUTPUT=$(aws lambda update-function-code \
          --function-name "$FUNCTION_NAME" \
          --zip-file fileb://calculator-simple.zip \
          --output json 2>&1)
        
        if [ $? -eq 0 ]; then
            echo "✅ Function updated successfully!"
            FUNCTION_READY=true
        else
            echo "❌ Update failed: $UPDATE_OUTPUT"
            
            # Check if it's a permissions issue
            if echo "$UPDATE_OUTPUT" | grep -q "AccessDenied\|not authorized"; then
                echo ""
                echo "🚨 PERMISSION DENIED"
                echo "=================="
                echo "You need Lambda update permissions."
                echo ""
                echo "🔧 Request these permissions:"
                echo "• lambda:UpdateFunctionCode"
                echo "• lambda:UpdateFunctionConfiguration"
                echo ""
                echo "🎯 Alternative: Use existing Lambda or manual console creation"
                exit 1
            fi
        fi
    fi
fi

echo ""
echo "📋 DEPLOYMENT SUMMARY"
echo "==================="

if [ "$FUNCTION_READY" = "true" ]; then
    echo "✅ Calculator Lambda: Ready"
    echo "📋 Function: $FUNCTION_NAME"
    echo "🎯 Ready for API Gateway creation"
    echo ""
    echo "🔗 Next step: ./create-calculator-api-endpoint.sh"
else
    echo "❌ Calculator Lambda: Failed"
    echo ""
    echo "🔧 Options:"
    echo "1. Request Lambda permissions from admin"
    echo "2. Create function via AWS Console manually"
    echo "3. Use existing Lambda function"
fi

# Cleanup
rm -f lambda_function.py calculator-simple.zip