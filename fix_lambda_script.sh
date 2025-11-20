#!/bin/bash
# Fix the Lambda function syntax error
# This script should be run in CloudShell where the extracted files are located

set -e

LAMBDA_FUNCTION_NAME="a208194-chatops_application_details_intent"
EXTRACTED_DIR="lambda_code_extracted"
FIXED_DIR="lambda_code_fixed"

echo "🔧 Fixing Lambda Function Syntax Error"
echo "====================================="
echo "Function: $LAMBDA_FUNCTION_NAME"
echo ""

# Check if extracted files exist
if [ ! -d "$EXTRACTED_DIR" ]; then
    echo "❌ Extracted directory '$EXTRACTED_DIR' not found"
    echo "💡 Please run ./lambda_diagnostic.sh first to extract the Lambda code"
    exit 1
fi

# Create fixed directory
mkdir -p "$FIXED_DIR"

echo "📋 Current files in $EXTRACTED_DIR:"
ls -la "$EXTRACTED_DIR/"
echo ""

# Copy files to fixed directory
echo "📁 Copying files to $FIXED_DIR..."
cp -r "$EXTRACTED_DIR"/* "$FIXED_DIR/"

# Show the problematic code around line 46
echo "🐛 Current problematic code (lines 40-50):"
echo "-------------------------------------------"
sed -n '40,50p' "$EXTRACTED_DIR/chatops_applications_details_intent.py"
echo ""

# Fix the syntax error
echo "🔧 Fixing syntax error in line 46..."
echo "   ❌ Changing: except E:"
echo "   ✅ To:       except Exception:"

# Use sed to replace 'except E:' with 'except Exception:'
sed -i 's/except E:/except Exception:/g' "$FIXED_DIR/chatops_applications_details_intent.py"

# Verify the fix
echo ""
echo "✅ Fixed code (lines 40-50):"
echo "----------------------------"
sed -n '40,50p' "$FIXED_DIR/chatops_applications_details_intent.py"
echo ""

# Create deployment package
echo "📦 Creating deployment package..."
cd "$FIXED_DIR"
zip -r "../lambda_code_fixed.zip" .
cd ..

echo "✅ Fixed Lambda package created: lambda_code_fixed.zip"
echo ""

# Deploy the fixed Lambda function
echo "🚀 Deploying fixed Lambda function..."
aws lambda update-function-code \
    --function-name "$LAMBDA_FUNCTION_NAME" \
    --zip-file fileb://lambda_code_fixed.zip \
    --region us-east-1

echo ""
echo "⏳ Waiting for function update to complete..."
aws lambda wait function-updated --function-name "$LAMBDA_FUNCTION_NAME" --region us-east-1

echo "✅ Lambda function updated successfully!"
echo ""

# Test the fixed Lambda function
echo "🧪 Testing fixed Lambda function..."
echo ""

# Test with asset ID a208194
echo "🎯 Testing with asset ID 'a208194'..."
aws lambda invoke \
    --function-name "$LAMBDA_FUNCTION_NAME" \
    --payload "$(echo '{"asset_id": "a208194"}' | base64 -w 0)" \
    /tmp/lambda_test_fixed_response.json \
    --region us-east-1

echo ""
echo "📋 Lambda Response:"
cat /tmp/lambda_test_fixed_response.json
echo ""

# Test with asset ID a12345
echo "🎯 Testing with asset ID 'a12345'..."
aws lambda invoke \
    --function-name "$LAMBDA_FUNCTION_NAME" \
    --payload "$(echo '{"asset_id": "a12345"}' | base64 -w 0)" \
    /tmp/lambda_test_fixed_response2.json \
    --region us-east-1

echo ""
echo "📋 Lambda Response:"
cat /tmp/lambda_test_fixed_response2.json
echo ""

echo "🎉 Lambda function fix completed!"
echo ""
echo "📝 Summary:"
echo "  ✅ Syntax error fixed: 'except E:' → 'except Exception:'"
echo "  ✅ Function deployed successfully"
echo "  ✅ Function tested with sample inputs"
echo ""
echo "🔧 Next Step: Test the MCP client with the fixed Lambda function"