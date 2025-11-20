#!/bin/bash
# Fix AI Calculator Lambda Function - Update with corrected Bedrock API code
# This fixes the "Invalid request to Bedrock model" issue

set -e

LAMBDA_FUNCTION_NAME="a208194-ai-bedrock-calculator-mcp-server"
REGION="us-east-1"

echo "🔧 Fixing AI Calculator Lambda Function"
echo "========================================"
echo "Function: $LAMBDA_FUNCTION_NAME"
echo "Region: $REGION"
echo ""

# Create a temporary directory for the Lambda package
TEMP_DIR=$(mktemp -d)
echo "📁 Working directory: $TEMP_DIR"

# Copy the fixed Lambda function (v2 with inference profile)
cp lambda_function_fixed_v2.py "$TEMP_DIR/lambda_function.py"

# Change to temp directory and create deployment package
cd "$TEMP_DIR"

echo "📦 Creating deployment package..."
zip -r lambda-deployment-package.zip lambda_function.py

echo "🚀 Updating Lambda function code..."
aws lambda update-function-code \
    --function-name "$LAMBDA_FUNCTION_NAME" \
    --zip-file fileb://lambda-deployment-package.zip \
    --region "$REGION"

echo ""
echo "⏳ Waiting for function update to complete..."
aws lambda wait function-updated \
    --function-name "$LAMBDA_FUNCTION_NAME" \
    --region "$REGION"

echo ""
echo "✅ Lambda function updated successfully!"
echo ""
echo "🧪 KEY FIXES APPLIED (V2):"
echo "   ✅ FIXED: Claude 3.5 Sonnet inference profile format"
echo "   ✅ Model ID: us.anthropic.claude-3-5-sonnet-20241022-v2:0"
echo "   ✅ Correct anthropic_version: 'bedrock-2023-05-31'"
echo "   ✅ Correct messages format (not prompt)"
echo "   ✅ Enhanced error handling"
echo "   ✅ Fixed response parsing"
echo ""
echo "🎯 NEXT STEPS:"
echo "1. Test Lambda function from AWS Console again"
echo "2. Test via MCP gateway if Lambda test succeeds" 
echo "3. Verify Claude responses are working properly"

# Cleanup
cd - >/dev/null
rm -rf "$TEMP_DIR"

echo ""
echo "🎉 Ready for testing!"