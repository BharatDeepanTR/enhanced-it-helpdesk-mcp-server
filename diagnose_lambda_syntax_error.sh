#!/bin/bash
# Lambda Syntax Error Fix Script

set -e

echo "🔧 Lambda Syntax Error Fix"
echo "============================"
echo ""
echo "📋 Issue Identified:"
echo "   Lambda: a208194-chatops_application_details_intent"
echo "   File: /var/task/chatops_applications_details_intent.py"
echo "   Line 46: except E:  # ❌ 'E' is not defined"
echo "   Error: NameError: name 'E' is not defined"
echo ""

# Get Lambda function information
LAMBDA_ARN="arn:aws:lambda:us-east-1:818565325759:function:a208194-chatops_application_details_intent"
FUNCTION_NAME="a208194-chatops_application_details_intent"

echo "🔍 Checking Lambda function configuration..."
aws lambda get-function --function-name "$FUNCTION_NAME" --query 'Configuration.[FunctionName,Runtime,CodeSize,LastModified]' --output table

echo ""
echo "📥 Downloading Lambda function code for inspection..."

# Download function code
aws lambda get-function --function-name "$FUNCTION_NAME" --query 'Code.Location' --output text > /tmp/lambda_code_url.txt

DOWNLOAD_URL=$(cat /tmp/lambda_code_url.txt)
echo "   Download URL: $DOWNLOAD_URL"

# Download and extract the code
curl -s "$DOWNLOAD_URL" -o /tmp/lambda_code.zip
cd /tmp
unzip -q lambda_code.zip -d lambda_extracted
cd lambda_extracted

echo ""
echo "📁 Lambda function files:"
ls -la

echo ""
echo "🔍 Looking for the problematic line..."
if [ -f "chatops_applications_details_intent.py" ]; then
    echo "   Found: chatops_applications_details_intent.py"
    echo ""
    echo "📄 Content around line 46:"
    sed -n '40,50p' chatops_applications_details_intent.py | nl -v40
    echo ""
    echo "🔎 Searching for 'except E:' pattern:"
    grep -n "except E:" chatops_applications_details_intent.py || echo "   Pattern not found with exact match"
    grep -n "except.*E" chatops_applications_details_intent.py || echo "   No 'except E' variations found"
else
    echo "   File chatops_applications_details_intent.py not found"
    echo "   Available Python files:"
    find . -name "*.py" -type f
fi

echo ""
echo "💡 Fix Instructions:"
echo "==================="
echo ""
echo "1. The error is on line 46: except E:"
echo "2. Replace with one of these correct patterns:"
echo ""
echo "   ✅ For general exceptions:"
echo "      except Exception as e:"
echo ""
echo "   ✅ For specific HTTP errors:"
echo "      except requests.exceptions.RequestException as e:"
echo ""
echo "   ✅ For multiple exception types:"
echo "      except (requests.exceptions.RequestException, ValueError) as e:"
echo ""
echo "3. Update the Lambda function with corrected code"
echo "4. Deploy and test"
echo ""

# Check if we can get recent logs to see more context
echo "🔍 Recent Lambda logs (last 5 minutes):"
echo "======================================="
aws logs filter-log-events \
    --log-group-name "/aws/lambda/$FUNCTION_NAME" \
    --start-time $(date -d '5 minutes ago' +%s)000 \
    --query 'events[0:3].[timestamp,message]' \
    --output table 2>/dev/null || echo "   Unable to retrieve recent logs"

echo ""
echo "🛠️  Next Steps:"
echo "1. Fix the Lambda function code (line 46: except E: → except Exception as e:)"
echo "2. Test the fix with: aws lambda invoke --function-name $FUNCTION_NAME ..."
echo "3. Verify MCP gateway integration works after fix"

# Cleanup
rm -rf /tmp/lambda_extracted /tmp/lambda_code.zip /tmp/lambda_code_url.txt