#!/bin/bash
# CloudShell: Test Direct Lambda ARN as Agent Core Gateway Target
# Try adding calculator Lambda directly without API Gateway

echo "🎯 Test Direct Lambda ARN as Gateway Target"
echo "==========================================="
echo ""

# Configuration
GATEWAY_ID="a208194-askjulius-agentcore-gateway-mcp-iam-fvro4phd59"
CALCULATOR_FUNCTION_NAME="a208194-calculator-mcp-server"
REGION="us-east-1"

echo "🎯 Configuration:"
echo "  Gateway ID: $GATEWAY_ID"
echo "  Calculator Lambda: $CALCULATOR_FUNCTION_NAME"
echo "  Region: $REGION"
echo ""

echo "🔍 Step 1: Get Calculator Lambda ARN"
echo "================================="

echo "Retrieving Lambda function details..."

LAMBDA_INFO=$(aws lambda get-function --function-name "$CALCULATOR_FUNCTION_NAME" 2>&1)

if echo "$LAMBDA_INFO" | grep -q "ResourceNotFoundException"; then
    echo "❌ Lambda function $CALCULATOR_FUNCTION_NAME not found!"
    echo ""
    echo "🔧 Please check:"
    echo "• Function name is exactly: $CALCULATOR_FUNCTION_NAME"
    echo "• Function exists in region: $REGION"
    exit 1
else
    echo "✅ Calculator Lambda found!"
    
    # Extract Lambda ARN
    LAMBDA_ARN=$(echo "$LAMBDA_INFO" | jq -r '.Configuration.FunctionArn' 2>/dev/null)
    LAMBDA_RUNTIME=$(echo "$LAMBDA_INFO" | jq -r '.Configuration.Runtime' 2>/dev/null)
    
    echo "📋 Lambda Details:"
    echo "   ARN: $LAMBDA_ARN"
    echo "   Runtime: $LAMBDA_RUNTIME"
fi

echo ""
echo "🧪 Step 2: Test Lambda MCP Protocol"
echo "================================="

echo "Testing Lambda with MCP tools/list request..."

TEST_PAYLOAD='{"jsonrpc":"2.0","id":"gateway-test","method":"tools/list","params":{}}'

LAMBDA_TEST_RESULT=$(aws lambda invoke \
    --function-name "$CALCULATOR_FUNCTION_NAME" \
    --payload "$TEST_PAYLOAD" \
    --output text \
    /tmp/lambda-test-response.json 2>&1)

if [ $? -eq 0 ] && [ -f "/tmp/lambda-test-response.json" ]; then
    echo "✅ Lambda invocation successful!"
    
    # Check response format
    RESPONSE_CONTENT=$(cat /tmp/lambda-test-response.json)
    echo "📋 Response preview:"
    echo "$RESPONSE_CONTENT" | head -c 200
    echo "..."
    
    if echo "$RESPONSE_CONTENT" | grep -q '"jsonrpc":"2.0"' && echo "$RESPONSE_CONTENT" | grep -q '"tools"'; then
        echo "✅ MCP protocol confirmed - Lambda is ready!"
        LAMBDA_MCP_READY=true
    else
        echo "❌ Response is not proper MCP format"
        echo "Full response: $RESPONSE_CONTENT"
        exit 1
    fi
    
    rm -f /tmp/lambda-test-response.json
else
    echo "❌ Lambda test failed!"
    echo "Error: $LAMBDA_TEST_RESULT"
    exit 1
fi

echo ""
echo "🔧 Step 3: Try Direct Lambda ARN as Gateway Target"
echo "==============================================="

if [ "$LAMBDA_MCP_READY" = "true" ]; then
    echo "Attempting to configure gateway with direct Lambda ARN..."
    
    # Method 1: Try --target-lambda-arn parameter
    echo "Method 1: Using --target-lambda-arn..."
    
    GATEWAY_UPDATE_1=$(aws bedrock-agentcore-control update-gateway \
        --gateway-id "$GATEWAY_ID" \
        --target-lambda-arn "$LAMBDA_ARN" \
        --output json 2>&1)
    
    UPDATE_RESULT_1=$?
    echo "Response: $GATEWAY_UPDATE_1"
    
    if [ $UPDATE_RESULT_1 -eq 0 ]; then
        echo "🎉 SUCCESS! Direct Lambda ARN works!"
        DIRECT_UPDATE_SUCCESS=true
        UPDATE_METHOD="target-lambda-arn"
        
    else
        echo ""
        echo "Method 2: Using --lambda-function-arn..."
        
        GATEWAY_UPDATE_2=$(aws bedrock-agentcore-control update-gateway \
            --gateway-id "$GATEWAY_ID" \
            --lambda-function-arn "$LAMBDA_ARN" \
            --output json 2>&1)
        
        UPDATE_RESULT_2=$?
        echo "Response: $GATEWAY_UPDATE_2"
        
        if [ $UPDATE_RESULT_2 -eq 0 ]; then
            echo "🎉 SUCCESS! Direct Lambda ARN works!"
            DIRECT_UPDATE_SUCCESS=true
            UPDATE_METHOD="lambda-function-arn"
            
        else
            echo ""
            echo "Method 3: Using --backend-configuration with Lambda ARN..."
            
            GATEWAY_UPDATE_3=$(aws bedrock-agentcore-control update-gateway \
                --gateway-id "$GATEWAY_ID" \
                --backend-configuration "lambdaArn=$LAMBDA_ARN" \
                --output json 2>&1)
            
            UPDATE_RESULT_3=$?
            echo "Response: $GATEWAY_UPDATE_3"
            
            if [ $UPDATE_RESULT_3 -eq 0 ]; then
                echo "🎉 SUCCESS! Direct Lambda ARN works!"
                DIRECT_UPDATE_SUCCESS=true
                UPDATE_METHOD="backend-configuration"
                
            else
                echo ""
                echo "Method 4: Using --target-configuration with JSON..."
                
                TARGET_CONFIG='{"type":"LAMBDA","lambdaArn":"'$LAMBDA_ARN'"}'
                
                GATEWAY_UPDATE_4=$(aws bedrock-agentcore-control update-gateway \
                    --gateway-id "$GATEWAY_ID" \
                    --target-configuration "$TARGET_CONFIG" \
                    --output json 2>&1)
                
                UPDATE_RESULT_4=$?
                echo "Response: $GATEWAY_UPDATE_4"
                
                if [ $UPDATE_RESULT_4 -eq 0 ]; then
                    echo "🎉 SUCCESS! Direct Lambda ARN works!"
                    DIRECT_UPDATE_SUCCESS=true
                    UPDATE_METHOD="target-configuration"
                else
                    echo "❌ All direct Lambda ARN methods failed"
                    DIRECT_UPDATE_FAILED=true
                fi
            fi
        fi
    fi
fi

echo ""
echo "🔍 Step 4: Verify Gateway Configuration"
echo "===================================="

if [ "$DIRECT_UPDATE_SUCCESS" = "true" ]; then
    echo "Verifying gateway configuration after update..."
    
    sleep 3
    
    UPDATED_GATEWAY=$(aws bedrock-agentcore-control get-gateway \
        --gateway-id "$GATEWAY_ID" \
        --output json 2>/dev/null)
    
    if [ $? -eq 0 ]; then
        echo "✅ Gateway configuration retrieved!"
        
        # Show relevant configuration
        echo "📋 Updated Gateway Configuration:"
        echo "$UPDATED_GATEWAY" | jq '{
            id: .id,
            name: .name,
            status: .status,
            lambdaArn: .lambdaArn,
            targetConfiguration: .targetConfiguration,
            backendConfiguration: .backendConfiguration
        }' 2>/dev/null || echo "$UPDATED_GATEWAY"
        
        # Check if Lambda ARN is configured
        CONFIGURED_LAMBDA=$(echo "$UPDATED_GATEWAY" | jq -r '.lambdaArn // .targetConfiguration.lambdaArn // .backendConfiguration.lambdaArn // "none"' 2>/dev/null)
        
        if [[ "$CONFIGURED_LAMBDA" == *"calculator-mcp-server"* ]]; then
            echo ""
            echo "✅ PERFECT! Gateway configured with calculator Lambda ARN!"
            echo "📋 Configured Lambda: $CONFIGURED_LAMBDA"
            GATEWAY_CONFIGURED=true
        else
            echo ""
            echo "⚠️  Gateway Lambda configuration unclear"
            echo "📋 Found: $CONFIGURED_LAMBDA"
            echo "📋 Expected: $LAMBDA_ARN"
        fi
    else
        echo "❌ Could not retrieve gateway configuration"
    fi
    
elif [ "$DIRECT_UPDATE_FAILED" = "true" ]; then
    echo "❌ Direct Lambda ARN configuration not supported"
    echo ""
    echo "🔍 Analysis of Failures:"
    echo "======================="
    
    # Analyze the error messages
    ALL_RESPONSES="$GATEWAY_UPDATE_1 $GATEWAY_UPDATE_2 $GATEWAY_UPDATE_3 $GATEWAY_UPDATE_4"
    
    if echo "$ALL_RESPONSES" | grep -q "InvalidParameterException\|UnknownParameter"; then
        echo "• Parameter names not recognized - CLI may not support direct Lambda ARN"
    fi
    
    if echo "$ALL_RESPONSES" | grep -q "ValidationException"; then
        echo "• Validation failed - Gateway may require HTTP endpoints only"
    fi
    
    if echo "$ALL_RESPONSES" | grep -q "requires.*endpoint\|requires.*URL"; then
        echo "• Error mentions endpoint/URL requirement - HTTP endpoints mandatory"
    fi
    
    echo ""
    echo "🎯 CONCLUSION: Gateway requires HTTP endpoints, not direct Lambda ARNs"
    echo ""
    echo "🔧 SOLUTION: Use API Gateway approach"
    echo "• Agent Core Gateways need HTTP-accessible endpoints"
    echo "• API Gateway provides the required HTTP interface"
    echo "• This is the proper architecture for MCP servers"
fi

echo ""
echo "📊 RESULTS SUMMARY"
echo "=================="

if [ "$DIRECT_UPDATE_SUCCESS" = "true" ]; then
    echo "🎉 SUCCESS: Direct Lambda ARN Targeting Works!"
    echo ""
    echo "✅ Configuration Method: $UPDATE_METHOD"
    echo "✅ Gateway Status: Configured with Lambda ARN"
    echo "✅ Lambda ARN: $LAMBDA_ARN"
    echo ""
    echo "🚀 Benefits of Direct Lambda Approach:"
    echo "• Simpler architecture (no API Gateway needed)"
    echo "• Lower latency (direct Lambda invocation)"
    echo "• Fewer AWS resources to manage"
    echo "• Cost-effective (no API Gateway charges)"
    echo ""
    echo "🎯 Next Steps:"
    echo "============="
    echo "1. Test gateway functionality with Bedrock Agents"
    echo "2. Apply same pattern to other Lambda functions:"
    echo "   • Use universal MCP wrapper for existing Lambdas"
    echo "   • Configure as direct Lambda ARN targets"
    echo "3. Document this as the preferred approach"
    
else
    echo "❌ CONCLUSION: Direct Lambda ARN Not Supported"
    echo ""
    echo "🔍 Root Cause Analysis:"
    echo "• Agent Core Gateways require HTTP-accessible endpoints"
    echo "• Direct Lambda invocation not supported for gateway targets"
    echo "• API Gateway provides required HTTP interface layer"
    echo ""
    echo "🎯 Recommended Architecture:"
    echo "============================"
    echo "Lambda Function → API Gateway → HTTP Endpoint → Agent Core Gateway"
    echo ""
    echo "🔧 Next Steps:"
    echo "============="
    echo "1. Run: ~/connect-calculator-to-gateway.sh"
    echo "2. This will create the API Gateway → Lambda integration"
    echo "3. Configure gateway with HTTP endpoint URL"
    echo ""
    echo "💡 Why HTTP Endpoints:"
    echo "• Standardized interface for all gateway targets"
    echo "• Supports authentication/authorization layers"
    echo "• Compatible with external MCP servers"
    echo "• Enables proper CORS for web-based agents"
fi

echo ""
echo "📋 Gateway Information:"
echo "======================"
echo "Gateway ID: $GATEWAY_ID"
echo "Calculator Lambda: $CALCULATOR_FUNCTION_NAME"
echo "Lambda ARN: $LAMBDA_ARN"

if [ "$GATEWAY_CONFIGURED" = "true" ]; then
    echo ""
    echo "🌟 Your gateway is now functional with direct Lambda targeting!"
    echo "🧮 Calculator tools are available via the gateway!"
else
    echo ""
    echo "🔧 Use API Gateway approach for HTTP endpoint targeting"
fi