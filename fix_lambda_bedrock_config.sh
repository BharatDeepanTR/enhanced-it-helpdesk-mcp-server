#!/bin/bash
# Fix Lambda Configuration for Bedrock Access
# Addresses timeout, memory, and environment variable issues

set -e

LAMBDA_FUNCTION_NAME="a208194-ai-bedrock-calculator-mcp-server"
REGION="us-east-1"

echo "🔧 Fixing Lambda Configuration for Bedrock Access"
echo "=================================================="
echo "Function: $LAMBDA_FUNCTION_NAME"
echo "Region: $REGION"
echo ""

# 1. Update Lambda timeout to 30 seconds (Bedrock calls need time)
echo "⏱️  Updating Lambda timeout to 30 seconds..."
aws lambda update-function-configuration \
    --function-name "$LAMBDA_FUNCTION_NAME" \
    --timeout 30 \
    --region "$REGION"

echo "   ✅ Timeout updated to 30 seconds"

# 2. Update Lambda memory to 512 MB (better performance for Bedrock calls)
echo "🧠 Updating Lambda memory to 512 MB..."
aws lambda update-function-configuration \
    --function-name "$LAMBDA_FUNCTION_NAME" \
    --memory-size 512 \
    --region "$REGION"

echo "   ✅ Memory updated to 512 MB"

# 3. Add environment variables for Bedrock configuration
echo "🌍 Setting environment variables for Bedrock..."
aws lambda update-function-configuration \
    --function-name "$LAMBDA_FUNCTION_NAME" \
    --environment "Variables={AWS_DEFAULT_REGION=$REGION,BEDROCK_MODEL_ID=anthropic.claude-3-5-sonnet-20241022-v2:0,BEDROCK_REGION=$REGION}" \
    --region "$REGION"

echo "   ✅ Environment variables set"

# 4. Wait for configuration updates to propagate
echo "⏳ Waiting for configuration updates to propagate..."
sleep 10

# 5. Test the updated Lambda function
echo "🧪 Testing updated Lambda function..."
cat > test_payload.json << 'EOF'
{
    "jsonrpc": "2.0",
    "method": "tools/call",
    "id": "config-test",
    "params": {
        "name": "ai_calculate",
        "arguments": {
            "query": "What is 25% of $100?"
        }
    }
}
EOF

echo "📤 Testing with updated configuration..."
aws lambda invoke \
    --function-name "$LAMBDA_FUNCTION_NAME" \
    --payload file://test_payload.json \
    --region "$REGION" \
    response.json

echo ""
echo "📥 Response from updated Lambda:"
cat response.json | jq '.'

# 6. Show final configuration
echo ""
echo "📋 Final Lambda Configuration:"
aws lambda get-function-configuration \
    --function-name "$LAMBDA_FUNCTION_NAME" \
    --region "$REGION" \
    --query '{
        Timeout: Timeout,
        MemorySize: MemorySize,
        Environment: Environment.Variables,
        Role: Role,
        Runtime: Runtime
    }' \
    --output table

# Clean up
rm -f test_payload.json response.json

echo ""
echo "🎯 Configuration Updates Summary:"
echo "   ✅ Timeout: 3 seconds → 30 seconds"
echo "   ✅ Memory: 128 MB → 512 MB"
echo "   ✅ Environment variables: AWS_DEFAULT_REGION, BEDROCK_MODEL_ID, BEDROCK_REGION"
echo ""
echo "💡 These changes should resolve the 'Invalid request to Bedrock model' error"
echo "   - Longer timeout allows Bedrock calls to complete"
echo "   - More memory improves performance"
echo "   - Environment variables help Lambda find the correct model"
echo ""
echo "🧪 Next step: Test the AI Calculator through the gateway again"