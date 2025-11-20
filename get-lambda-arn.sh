#!/bin/bash
# Script to get the Lambda function ARN for Agent Core Gateway

echo "🔍 Finding DNS Lookup Lambda Function ARN..."
echo ""

# Get account ID
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null)
if [ $? -eq 0 ]; then
    echo "Account ID: $ACCOUNT_ID"
else
    echo "❌ Could not get Account ID. Make sure AWS credentials are configured."
    exit 1
fi

# Get region
REGION=${AWS_DEFAULT_REGION:-$(aws configure get region 2>/dev/null)}
if [ -z "$REGION" ]; then
    REGION="us-east-1"
fi
echo "Region: $REGION"
echo ""

# Look for possible Lambda function names
FUNCTION_NAMES=("dns-lookup-service" "chatops-dns-lookup" "dns-lookup" "lambda-dns-lookup")

echo "🔍 Searching for Lambda functions..."
for FUNC_NAME in "${FUNCTION_NAMES[@]}"; do
    ARN=$(aws lambda get-function --function-name "$FUNC_NAME" --query 'Configuration.FunctionArn' --output text 2>/dev/null)
    if [ $? -eq 0 ] && [ "$ARN" != "None" ]; then
        echo "✅ Found Lambda function: $FUNC_NAME"
        echo "   ARN: $ARN"
        echo ""
        echo "📋 Use this ARN in your Agent Core Gateway:"
        echo "   $ARN"
        exit 0
    fi
done

echo "❌ No matching Lambda function found."
echo ""
echo "💡 Try listing all Lambda functions:"
echo "   aws lambda list-functions --query 'Functions[].FunctionName' --output table"
echo ""
echo "🔍 Or search for functions containing 'dns':"
aws lambda list-functions --query 'Functions[?contains(FunctionName, `dns`)].{Name:FunctionName, ARN:FunctionArn}' --output table 2>/dev/null || echo "   Run: aws lambda list-functions"