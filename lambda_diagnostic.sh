#!/bin/bash
# Lambda Function Diagnostic Script
# Download and analyze the chatops_applications_details_intent Lambda function

set -e

LAMBDA_FUNCTION_NAME="a208194-chatops_application_details_intent"
REGION="us-east-1"

echo "🔍 Lambda Function Diagnostic"
echo "=============================="
echo "Function: $LAMBDA_FUNCTION_NAME"
echo "Region: $REGION"
echo ""

# Get Lambda function configuration
echo "📋 Getting Lambda function configuration..."
aws lambda get-function-configuration \
    --function-name "$LAMBDA_FUNCTION_NAME" \
    --region "$REGION" > lambda_config.json

echo "✅ Configuration saved to lambda_config.json"

# Extract key information
echo ""
echo "📊 Function Details:"
echo "   Runtime: $(jq -r '.Runtime' lambda_config.json)"
echo "   Handler: $(jq -r '.Handler' lambda_config.json)" 
echo "   Code Size: $(jq -r '.CodeSize' lambda_config.json) bytes"
echo "   Last Modified: $(jq -r '.LastModified' lambda_config.json)"

# Download the Lambda function code
echo ""
echo "📥 Downloading Lambda function code..."
aws lambda get-function \
    --function-name "$LAMBDA_FUNCTION_NAME" \
    --region "$REGION" > lambda_full_info.json

# Extract the download URL
DOWNLOAD_URL=$(jq -r '.Code.Location' lambda_full_info.json)

echo "   Download URL obtained"
echo "   Downloading ZIP file..."

# Download the ZIP file
curl -s "$DOWNLOAD_URL" -o lambda_code.zip

echo "   ✅ Code downloaded as lambda_code.zip"

# Extract the ZIP file
echo ""
echo "📂 Extracting Lambda code..."
mkdir -p lambda_code_extracted
cd lambda_code_extracted
unzip -q ../lambda_code.zip
cd ..

echo "   ✅ Code extracted to lambda_code_extracted/"

# List the extracted files
echo ""
echo "📁 Extracted files:"
find lambda_code_extracted -type f -name "*.py" | head -10

# Look for the specific file with the error
echo ""
echo "🔍 Looking for chatops_applications_details_intent.py..."
if [ -f "lambda_code_extracted/chatops_applications_details_intent.py" ]; then
    echo "   ✅ Found chatops_applications_details_intent.py"
    
    echo ""
    echo "🐛 Analyzing error at line 46..."
    echo "   Lines 40-50:"
    sed -n '40,50p' lambda_code_extracted/chatops_applications_details_intent.py | nl -v40
    
    echo ""
    echo "🔍 Looking for 'except E:' pattern..."
    grep -n "except E" lambda_code_extracted/chatops_applications_details_intent.py || echo "   Pattern 'except E' not found"
    
    echo ""
    echo "🔍 Looking for all exception handling..."
    grep -n "except" lambda_code_extracted/chatops_applications_details_intent.py || echo "   No except statements found"
    
else
    echo "   ❌ chatops_applications_details_intent.py not found"
    echo "   📁 Available Python files:"
    find lambda_code_extracted -name "*.py"
fi

echo ""
echo "🔧 Next Steps:"
echo "1. Examine the chatops_applications_details_intent.py file"
echo "2. Fix the 'except E:' syntax error"
echo "3. Create corrected version"
echo "4. Deploy the fix"

echo ""
echo "📝 Files created:"
echo "   - lambda_config.json (function configuration)"
echo "   - lambda_full_info.json (full function info)"
echo "   - lambda_code.zip (source code archive)"
echo "   - lambda_code_extracted/ (extracted source code)"