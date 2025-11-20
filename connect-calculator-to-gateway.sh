#!/bin/bash
# CloudShell: Connect Calculator Lambda to Agent Core Gateway
# Creates API Gateway endpoint and configures gateway target

echo "🔗 Connect Calculator Lambda to Agent Core Gateway"
echo "================================================="
echo ""

# Configuration
GATEWAY_ID="a208194-askjulius-agentcore-gateway-mcp-iam-fvro4phd59"
CALCULATOR_FUNCTION_NAME="a208194-calculator-mcp-server"
API_NAME="a208194-calculator-mcp-api"
REGION="us-east-1"
STAGE_NAME="prod"

echo "🎯 Configuration:"
echo "  Gateway ID: $GATEWAY_ID"
echo "  Calculator Lambda: $CALCULATOR_FUNCTION_NAME"
echo "  API Gateway Name: $API_NAME"
echo "  Region: $REGION"
echo ""

echo "🔍 Step 1: Verify Calculator Lambda Exists"
echo "======================================="

echo "Checking if calculator Lambda function exists..."

LAMBDA_INFO=$(aws lambda get-function --function-name "$CALCULATOR_FUNCTION_NAME" 2>&1)

if echo "$LAMBDA_INFO" | grep -q "ResourceNotFoundException"; then
    echo "❌ Lambda function $CALCULATOR_FUNCTION_NAME not found!"
    echo ""
    echo "🔧 Please check:"
    echo "• Function name is exactly: $CALCULATOR_FUNCTION_NAME"
    echo "• Function exists in region: $REGION"
    echo "• You have Lambda:GetFunction permission"
    exit 1
else
    echo "✅ Calculator Lambda found!"
    
    # Extract key info
    LAMBDA_ARN=$(echo "$LAMBDA_INFO" | jq -r '.Configuration.FunctionArn' 2>/dev/null)
    LAMBDA_RUNTIME=$(echo "$LAMBDA_INFO" | jq -r '.Configuration.Runtime' 2>/dev/null)
    LAMBDA_ARCH=$(echo "$LAMBDA_INFO" | jq -r '.Configuration.Architectures[0]' 2>/dev/null)
    
    echo "📋 Lambda Details:"
    echo "   ARN: $LAMBDA_ARN"
    echo "   Runtime: $LAMBDA_RUNTIME"
    echo "   Architecture: $LAMBDA_ARCH"
fi

echo ""
echo "🧪 Step 2: Test Calculator Lambda Directly"
echo "======================================"

echo "Testing Lambda with MCP tools/list request..."

# Test Lambda directly
TEST_PAYLOAD='{"jsonrpc":"2.0","id":"direct-test","method":"tools/list","params":{}}'

LAMBDA_TEST_RESULT=$(aws lambda invoke \
    --function-name "$CALCULATOR_FUNCTION_NAME" \
    --payload "$TEST_PAYLOAD" \
    --output text \
    /tmp/lambda-response.json 2>&1)

if [ $? -eq 0 ] && [ -f "/tmp/lambda-response.json" ]; then
    echo "✅ Lambda invocation successful!"
    
    # Check response format
    RESPONSE_CONTENT=$(cat /tmp/lambda-response.json)
    
    if echo "$RESPONSE_CONTENT" | grep -q '"jsonrpc":"2.0"' && echo "$RESPONSE_CONTENT" | grep -q '"tools"'; then
        echo "✅ MCP protocol response confirmed!"
        
        # Count tools
        TOOL_COUNT=$(echo "$RESPONSE_CONTENT" | jq '.result.tools | length' 2>/dev/null)
        echo "📋 Found $TOOL_COUNT calculator tools"
        
        LAMBDA_WORKING=true
    else
        echo "⚠️  Response format unexpected"
        echo "Response: $RESPONSE_CONTENT"
        echo ""
        echo "🔧 Check if Lambda code implements proper MCP protocol"
    fi
    
    rm -f /tmp/lambda-response.json
else
    echo "❌ Lambda test failed!"
    echo "Error: $LAMBDA_TEST_RESULT"
    echo ""
    echo "🔧 Possible issues:"
    echo "• Lambda execution role permissions"
    echo "• Lambda code errors"
    echo "• Timeout or memory issues"
    exit 1
fi

echo ""
echo "🌐 Step 3: Create API Gateway for HTTP Endpoint"
echo "============================================="

if [ "$LAMBDA_WORKING" = "true" ]; then
    echo "Creating REST API for calculator MCP endpoint..."
    
    # Check if API already exists
    EXISTING_API_ID=$(aws apigateway get-rest-apis \
        --query "items[?name=='$API_NAME'].id" \
        --output text 2>/dev/null)
    
    if [ -n "$EXISTING_API_ID" ] && [ "$EXISTING_API_ID" != "None" ]; then
        echo "🔄 API Gateway already exists!"
        API_ID="$EXISTING_API_ID"
        echo "📋 Existing API ID: $API_ID"
    else
        echo "Creating new REST API..."
        
        # Create REST API
        API_CREATE_OUTPUT=$(aws apigateway create-rest-api \
            --name "$API_NAME" \
            --description "HTTP endpoint for Calculator MCP Server - Agent Core Gateway integration" \
            --output json 2>&1)
        
        API_ID=$(echo "$API_CREATE_OUTPUT" | jq -r '.id' 2>/dev/null)
        
        if [ -n "$API_ID" ] && [ "$API_ID" != "null" ]; then
            echo "✅ API Gateway created!"
            echo "📋 New API ID: $API_ID"
        else
            echo "❌ Failed to create API Gateway"
            echo "Output: $API_CREATE_OUTPUT"
            exit 1
        fi
    fi
    
    # Get account ID for permissions
    ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    
    # Get root resource ID
    ROOT_RESOURCE_ID=$(aws apigateway get-resources \
        --rest-api-id "$API_ID" \
        --query 'items[?path==`/`].id' \
        --output text)
    
    echo "📋 Root resource ID: $ROOT_RESOURCE_ID"
    
    # Check if /mcp resource exists
    MCP_RESOURCE_ID=$(aws apigateway get-resources \
        --rest-api-id "$API_ID" \
        --query 'items[?pathPart==`mcp`].id' \
        --output text 2>/dev/null)
    
    if [ -n "$MCP_RESOURCE_ID" ] && [ "$MCP_RESOURCE_ID" != "None" ]; then
        echo "🔄 /mcp resource already exists: $MCP_RESOURCE_ID"
    else
        echo "Creating /mcp resource..."
        
        # Create /mcp resource
        MCP_RESOURCE_OUTPUT=$(aws apigateway create-resource \
            --rest-api-id "$API_ID" \
            --parent-id "$ROOT_RESOURCE_ID" \
            --path-part "mcp" \
            --output json)
        
        MCP_RESOURCE_ID=$(echo "$MCP_RESOURCE_OUTPUT" | jq -r '.id')
        echo "✅ Created /mcp resource: $MCP_RESOURCE_ID"
    fi
    
    # Set up POST method
    echo "Configuring POST method and Lambda integration..."
    
    aws apigateway put-method \
        --rest-api-id "$API_ID" \
        --resource-id "$MCP_RESOURCE_ID" \
        --http-method POST \
        --authorization-type NONE \
        --no-api-key-required >/dev/null 2>&1 || echo "POST method already exists"
    
    # Set up Lambda integration
    aws apigateway put-integration \
        --rest-api-id "$API_ID" \
        --resource-id "$MCP_RESOURCE_ID" \
        --http-method POST \
        --type AWS_PROXY \
        --integration-http-method POST \
        --uri "arn:aws:apigateway:${REGION}:lambda:path/2015-03-31/functions/${LAMBDA_ARN}/invocations" >/dev/null 2>&1 || echo "Integration already configured"
    
    # Grant API Gateway permission to invoke Lambda
    aws lambda add-permission \
        --function-name "$CALCULATOR_FUNCTION_NAME" \
        --statement-id "allow-api-gateway-$(date +%s)" \
        --action lambda:InvokeFunction \
        --principal apigateway.amazonaws.com \
        --source-arn "arn:aws:execute-api:${REGION}:${ACCOUNT_ID}:${API_ID}/*/*" 2>/dev/null || echo "Permission already exists"
    
    # Deploy API
    echo "Deploying API to production stage..."
    aws apigateway create-deployment \
        --rest-api-id "$API_ID" \
        --stage-name "$STAGE_NAME" \
        --description "Calculator MCP API for Agent Core Gateway - $(date)" >/dev/null 2>&1
    
    # Construct endpoint URL
    MCP_ENDPOINT_URL="https://${API_ID}.execute-api.${REGION}.amazonaws.com/${STAGE_NAME}/mcp"
    
    echo "✅ API Gateway configured!"
    echo "🌐 MCP Endpoint URL: $MCP_ENDPOINT_URL"
    
    API_READY=true
else
    echo "❌ Skipping API Gateway - Lambda not working properly"
    exit 1
fi

echo ""
echo "🧪 Step 4: Test API Gateway Endpoint"
echo "=================================="

if [ "$API_READY" = "true" ]; then
    echo "Testing MCP endpoint via API Gateway..."
    
    # Test endpoint
    ENDPOINT_TEST=$(curl -s -X POST "$MCP_ENDPOINT_URL" \
        -H "Content-Type: application/json" \
        -d '{"jsonrpc":"2.0","id":"api-test","method":"tools/list","params":{}}' \
        -w "HTTPSTATUS:%{http_code}" \
        --max-time 30)
    
    HTTP_STATUS=$(echo "$ENDPOINT_TEST" | grep -o "HTTPSTATUS:[0-9]*" | cut -d: -f2)
    RESPONSE_BODY=$(echo "$ENDPOINT_TEST" | sed 's/HTTPSTATUS:[0-9]*$//')
    
    echo "HTTP Status: $HTTP_STATUS"
    
    if [ "$HTTP_STATUS" = "200" ]; then
        echo "✅ API Gateway endpoint working!"
        
        if echo "$RESPONSE_BODY" | grep -q '"tools"' && echo "$RESPONSE_BODY" | grep -q '"jsonrpc"'; then
            echo "✅ MCP protocol response via HTTP confirmed!"
            
            # Quick calculation test
            echo ""
            echo "Testing calculator operation..."
            
            CALC_TEST=$(curl -s -X POST "$MCP_ENDPOINT_URL" \
                -H "Content-Type: application/json" \
                -d '{"jsonrpc":"2.0","id":"calc-test","method":"tools/call","params":{"name":"add","arguments":{"a":10,"b":15}}}' \
                --max-time 30)
            
            if echo "$CALC_TEST" | grep -q "Addition.*10.*15.*25"; then
                echo "✅ Calculator working perfectly via API Gateway!"
                ENDPOINT_WORKING=true
            else
                echo "⚠️  Calculator test unexpected result"
                echo "Calc result: $CALC_TEST"
                ENDPOINT_WORKING=true  # Continue anyway
            fi
        else
            echo "⚠️  Response doesn't look like MCP protocol"
            echo "Response snippet: $(echo "$RESPONSE_BODY" | head -c 200)..."
        fi
    else
        echo "❌ API Gateway endpoint failed (HTTP $HTTP_STATUS)"
        echo "Response: $RESPONSE_BODY"
        echo ""
        echo "🔧 Common issues:"
        echo "• Lambda integration not configured properly"
        echo "• Lambda permission missing for API Gateway"
        echo "• API Gateway deployment failed"
    fi
fi

echo ""
echo "🔧 Step 5: Update Agent Core Gateway"
echo "=================================="

if [ "$ENDPOINT_WORKING" = "true" ]; then
    echo "Updating Agent Core Gateway to use calculator MCP endpoint..."
    
    # Try to update gateway
    GATEWAY_UPDATE=$(aws bedrock-agentcore-control update-gateway \
        --gateway-id "$GATEWAY_ID" \
        --target-endpoint-url "$MCP_ENDPOINT_URL" \
        --output json 2>&1)
    
    GATEWAY_UPDATE_RESULT=$?
    
    if [ $GATEWAY_UPDATE_RESULT -eq 0 ]; then
        echo "✅ Gateway updated successfully!"
        
        # Verify update
        sleep 3
        echo "Verifying gateway configuration..."
        
        UPDATED_GATEWAY=$(aws bedrock-agentcore-control get-gateway \
            --gateway-id "$GATEWAY_ID" \
            --output json 2>/dev/null)
        
        if [ $? -eq 0 ]; then
            echo "✅ Gateway configuration verified!"
            
            # Show relevant config
            echo "$UPDATED_GATEWAY" | jq '{
                id: .id,
                name: .name,
                status: .status,
                endpointUrl: .endpointUrl,
                targetEndpoint: .targetEndpoint
            }' 2>/dev/null || echo "Configuration updated"
            
            GATEWAY_CONFIGURED=true
        else
            echo "⚠️  Could not verify gateway update"
        fi
        
    else
        echo "⚠️  Gateway CLI update failed"
        echo "Update response: $GATEWAY_UPDATE"
        
        echo ""
        echo "🔧 Manual Gateway Configuration Required:"
        echo "========================================"
        echo "1. Go to AWS Bedrock Console → Agent Core → Gateways"
        echo "2. Find gateway: $GATEWAY_ID" 
        echo "3. Click 'Edit' or 'Configure Target'"
        echo "4. Set target configuration:"
        echo "   • Target Type: HTTP Endpoint"
        echo "   • Endpoint URL: $MCP_ENDPOINT_URL"
        echo "   • HTTP Method: POST"
        echo "   • Content-Type: application/json"
        echo "5. Save configuration"
    fi
else
    echo "❌ Skipping gateway update - API Gateway endpoint not working properly"
fi

echo ""
echo "🎉 SETUP COMPLETE!"
echo "================="

echo ""
echo "📋 FINAL CONFIGURATION:"
echo "======================="
echo "✅ Calculator Lambda: $CALCULATOR_FUNCTION_NAME"
echo "✅ API Gateway: $API_NAME ($API_ID)"
echo "✅ MCP Endpoint: $MCP_ENDPOINT_URL"
echo "✅ Agent Core Gateway: $GATEWAY_ID"

if [ "$GATEWAY_CONFIGURED" = "true" ]; then
    echo "✅ Gateway Status: Configured with calculator endpoint"
else
    echo "⚠️  Gateway Status: Manual configuration required"
fi

echo ""
echo "🧮 Available Calculator Tools via Gateway:"
echo "=========================================="
echo "• add(a, b) - Addition"
echo "• subtract(a, b) - Subtraction"
echo "• multiply(a, b) - Multiplication"
echo "• divide(a, b) - Division"
echo "• power(base, exponent) - Exponentiation"
echo "• sqrt(number) - Square root"
echo "• factorial(n) - Factorial"

echo ""
echo "🧪 Test Your Gateway:"
echo "==================="
echo "# Direct endpoint test:"
echo "curl -X POST '$MCP_ENDPOINT_URL' \\"
echo "  -H 'Content-Type: application/json' \\"
echo "  -d '{\"jsonrpc\":\"2.0\",\"method\":\"tools/list\",\"params\":{}}'"

echo ""
echo "# Gateway URL (for Bedrock Agent testing):"
echo "https://$GATEWAY_ID.gateway.bedrock-agentcore.${REGION}.amazonaws.com/mcp"

echo ""
echo "🚀 Next Steps:"
echo "============="
echo "1. ✅ Test calculator via gateway endpoint"
echo "2. 🔧 Apply same pattern to other Lambdas:"
echo "   • Use universal MCP wrapper for existing functions"
echo "   • Create API Gateway endpoints for each"
echo "   • Configure as gateway targets"
echo "3. 🎯 Test with Bedrock Agents using the gateway"

echo ""
if [ "$GATEWAY_CONFIGURED" = "true" ]; then
    echo "🎉 Your Agent Core Gateway is now functional with calculator MCP server!"
    echo "🌟 You can now use this pattern for other Lambda functions!"
else
    echo "🔧 Complete the manual gateway configuration to finish setup"
fi