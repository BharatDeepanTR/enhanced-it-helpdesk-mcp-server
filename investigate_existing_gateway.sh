#!/bin/bash
# Investigate Existing API Gateway
# Let's find out if this is what the calculator Lambda is using

set -e

echo "🔍 INVESTIGATING EXISTING API GATEWAY"
echo "====================================="
echo ""

EXISTING_API_ID="35f53n4021"
REGION="us-east-1"

echo "📋 Existing API Gateway Details"
echo "-------------------------------"
echo "API ID: $EXISTING_API_ID"
echo "Name: a206255-mcp-server-truccr-rest-api-ci-use1"
echo ""

echo "🔧 Getting API Gateway Configuration..."
aws apigateway get-rest-api \
    --rest-api-id "$EXISTING_API_ID" \
    --region "$REGION"

echo ""
echo "📋 Getting API Gateway Resources..."
aws apigateway get-resources \
    --rest-api-id "$EXISTING_API_ID" \
    --region "$REGION"

echo ""
echo "📋 Getting API Gateway Stages..."
aws apigateway get-stages \
    --rest-api-id "$EXISTING_API_ID" \
    --region "$REGION"

echo ""
echo "🌐 Potential Endpoint URLs:"
echo "https://${EXISTING_API_ID}.execute-api.${REGION}.amazonaws.com/prod"
echo "https://${EXISTING_API_ID}.execute-api.${REGION}.amazonaws.com/dev"
echo "https://${EXISTING_API_ID}.execute-api.${REGION}.amazonaws.com/v1"

echo ""
echo "🧪 Testing Existing API Gateway..."
echo ""

# Test different endpoints
for stage in prod dev v1; do
    echo "🎯 Testing stage: $stage"
    endpoint="https://${EXISTING_API_ID}.execute-api.${REGION}.amazonaws.com/${stage}"
    echo "   URL: $endpoint"
    
    # Try tools/list
    echo "   Testing tools/list..."
    curl -s -X POST "$endpoint" \
        -H "Content-Type: application/json" \
        -d '{"jsonrpc": "2.0", "id": 1, "method": "tools/list"}' \
        --aws-sigv4 "aws:amz:${REGION}:execute-api" \
        --user "$AWS_ACCESS_KEY_ID:$AWS_SECRET_ACCESS_KEY" \
        -w "\n   Status: %{http_code}\n" 2>/dev/null || echo "   ❌ Failed"
    
    echo ""
done

echo ""
echo "🔍 ANALYSIS QUESTIONS:"
echo "====================="
echo ""
echo "1. Is this the gateway that calculator Lambda is actually using?"
echo "2. Should we use this existing gateway instead of creating a new Bedrock Agent Core Gateway?"
echo "3. Does this API Gateway already have the application details target configured?"
echo "4. What authentication method does this gateway use? (API Key vs IAM)"
echo ""
echo "💡 NEXT STEPS:"
echo "=============="
echo "1. If this gateway works for calculator, we should use it for app details too"
echo "2. If it doesn't work, we need to create the Bedrock Agent Core Gateway"
echo "3. We need to find the actual working endpoint from calculator setup"