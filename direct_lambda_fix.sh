#!/bin/bash
# Simple Direct Lambda Fix - Download, Fix, and Deploy
# This is a streamlined approach to fix the syntax error

set -e

LAMBDA_FUNCTION_NAME="a208194-chatops_application_details_intent"
REGION="us-east-1"

echo "🔧 DIRECT LAMBDA FIX"
echo "===================="
echo "Function: $LAMBDA_FUNCTION_NAME"
echo ""

# Step 1: Download current Lambda code
echo "📥 Downloading current Lambda function..."
aws lambda get-function \
    --function-name "$LAMBDA_FUNCTION_NAME" \
    --region "$REGION" \
    --query 'Code.Location' \
    --output text > /tmp/download_url.txt

DOWNLOAD_URL=$(cat /tmp/download_url.txt)
echo "   Download URL obtained"

# Download the ZIP file
curl -s "$DOWNLOAD_URL" -o /tmp/lambda_current.zip
echo "   ✅ Lambda code downloaded"

# Step 2: Extract and examine
echo ""
echo "📂 Extracting Lambda code..."
rm -rf /tmp/lambda_fix_work
mkdir -p /tmp/lambda_fix_work
cd /tmp/lambda_fix_work
unzip -q /tmp/lambda_current.zip

echo "   📁 Extracted files:"
ls -la

# Step 3: Show the problematic line
echo ""
echo "🔍 Current problematic code:"
if [ -f "chatops_applications_details_intent.py" ]; then
    echo "   Line 46 (problematic):"
    sed -n '46p' chatops_applications_details_intent.py
    echo ""
    
    # Step 4: Fix the syntax error
    echo "🔧 Fixing syntax error..."
    sed -i 's/except E:/except Exception:/g' chatops_applications_details_intent.py
    
    echo "   ✅ Fixed line 46:"
    sed -n '46p' chatops_applications_details_intent.py
    echo ""
    
    # Step 5: Create new deployment package
    echo "📦 Creating fixed deployment package..."
    zip -r /tmp/lambda_fixed.zip .
    echo "   ✅ Package created: /tmp/lambda_fixed.zip"
    
    # Step 6: Deploy the fix
    echo ""
    echo "🚀 Deploying fixed Lambda function..."
    aws lambda update-function-code \
        --function-name "$LAMBDA_FUNCTION_NAME" \
        --zip-file fileb:///tmp/lambda_fixed.zip \
        --region "$REGION"
    
    echo ""
    echo "⏳ Waiting for function update to complete..."
    aws lambda wait function-updated \
        --function-name "$LAMBDA_FUNCTION_NAME" \
        --region "$REGION"
    
    echo "✅ Lambda function updated successfully!"
    
    # Step 7: Test the fixed function
    echo ""
    echo "🧪 Testing fixed Lambda function..."
    
    # Test 1: Valid asset ID
    echo "   Test 1: Asset ID 'a208194'"
    aws lambda invoke \
        --function-name "$LAMBDA_FUNCTION_NAME" \
        --payload "$(echo '{"asset_id": "a208194"}' | base64 -w 0)" \
        /tmp/test_response.json \
        --region "$REGION"
    
    echo "   Response:"
    cat /tmp/test_response.json
    echo ""
    
    # Clean up
    cd /
    rm -rf /tmp/lambda_fix_work
    rm -f /tmp/lambda_current.zip /tmp/lambda_fixed.zip /tmp/download_url.txt
    
    echo ""
    echo "🎉 LAMBDA FIX COMPLETED!"
    echo "======================="
    echo ""
    echo "📋 What was fixed:"
    echo "   ❌ Before: except E:"
    echo "   ✅ After:  except Exception:"
    echo ""
    echo "🧪 Next step: Test the MCP client:"
    echo "   python3 final_mcp_client.py get a208194"
    echo ""
    
else
    echo "❌ ERROR: chatops_applications_details_intent.py not found in Lambda package"
    echo "   Available files:"
    ls -la
fi