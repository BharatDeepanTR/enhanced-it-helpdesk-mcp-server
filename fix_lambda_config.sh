#!/bin/bash
# Fix AI Calculator Lambda Configuration for Bedrock Access
# Addresses timeout, memory, and environment variable issues

set -e

LAMBDA_FUNCTION_NAME="a208194-ai-bedrock-calculator-mcp-server"
REGION="us-east-1"

echo "🔧 Fixing AI Calculator Lambda Configuration"
echo "============================================="
echo "Lambda Function: $LAMBDA_FUNCTION_NAME"
echo "Region: $REGION"
echo ""

echo "📋 Current Issues to Fix:"
echo "   ❌ Timeout: 3 seconds (too short for Bedrock calls)"
echo "   ❌ Memory: 128 MB (insufficient for Bedrock SDK)"
echo "   ⚠️  Missing environment variables for Bedrock model"
echo ""

echo "🎯 NEW VALUES TO APPLY:"
echo "   ✅ Timeout: 30 seconds (adequate for Bedrock API calls)"
echo "   ✅ Memory: 512 MB (sufficient for boto3 and Bedrock operations)"
echo "   ✅ Environment Variables:"
echo "      - AWS_REGION=us-east-1"
echo "      - BEDROCK_MODEL_ID=anthropic.claude-3-5-sonnet-20241022-v2:0"
echo "      - BEDROCK_REGION=us-east-1"
echo ""

echo "1️⃣ Updating Lambda timeout to 30 seconds..."
aws lambda update-function-configuration \
    --function-name "$LAMBDA_FUNCTION_NAME" \
    --timeout 30 \
    --region "$REGION"

echo "   ✅ Timeout updated successfully"

echo ""
echo "2️⃣ Updating Lambda memory to 512 MB..."
aws lambda update-function-configuration \
    --function-name "$LAMBDA_FUNCTION_NAME" \
    --memory-size 512 \
    --region "$REGION"

echo "   ✅ Memory updated successfully"

echo ""
echo "3️⃣ Adding environment variables for Bedrock access..."
aws lambda update-function-configuration \
    --function-name "$LAMBDA_FUNCTION_NAME" \
    --environment Variables='{
        "AWS_REGION": "us-east-1",
        "BEDROCK_MODEL_ID": "anthropic.claude-3-5-sonnet-20241022-v2:0",
        "BEDROCK_REGION": "us-east-1"
    }' \
    --region "$REGION"

echo "   ✅ Environment variables updated successfully"

echo ""
echo "4️⃣ Verifying updated configuration..."
aws lambda get-function-configuration \
    --function-name "$LAMBDA_FUNCTION_NAME" \
    --region "$REGION" \
    --query '{
        Timeout: Timeout,
        MemorySize: MemorySize,
        Environment: Environment.Variables,
        Role: Role
    }'

echo ""
echo "✅ LAMBDA CONFIGURATION FIXED!"
echo ""
echo "📋 Summary of Changes Applied:"
echo "   🕐 Timeout: 3s → 30s (10x increase for Bedrock calls)"
echo "   💾 Memory: 128MB → 512MB (4x increase for Bedrock SDK)" 
echo "   🌍 Environment Variables Added:"
echo "      - AWS_REGION=us-east-1"
echo "      - BEDROCK_MODEL_ID=anthropic.claude-3-5-sonnet-20241022-v2:0"
echo "      - BEDROCK_REGION=us-east-1"
echo ""
echo "🎯 Next Steps:"
echo "1. Wait 10-15 seconds for Lambda configuration to propagate"
echo "2. Test the Lambda function again with the test script"
echo "3. The 'Invalid request to Bedrock model' error should be resolved"
echo ""
echo "💡 Why These Changes Matter:"
echo "   ⏱️  Bedrock API calls need 10-30 seconds (was timing out at 3s)"
echo "   🧠 boto3 + Bedrock SDK requires more memory than 128MB"
echo "   🔧 Environment variables help Lambda code find correct model/region"