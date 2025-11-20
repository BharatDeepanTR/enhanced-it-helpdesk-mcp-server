#!/bin/bash
# Quick CloudShell Test for Application Details Gateway
# Simple, focused test for a208194-chatops_application_details_intent

ASSET_ID="${1:-a12345}"
GATEWAY_ID="a208194-askjulius-agentcore-gateway-mcp-iam"
REGION="us-east-1"

echo "🔍 Quick Application Details Test"
echo "================================"
echo "Asset ID: $ASSET_ID"
echo "Gateway: $GATEWAY_ID"
echo ""

# Check AWS connectivity
echo "🔧 Checking AWS access..."
if ! aws sts get-caller-identity > /dev/null 2>&1; then
    echo "❌ AWS credentials not configured"
    echo "💡 Run: aws configure"
    exit 1
fi

ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
echo "✅ AWS Account: $ACCOUNT"
echo ""

# Create test payload
echo "📤 Creating test payload..."
cat > quick_test_payload.json << EOF
{
    "gatewayId": "$GATEWAY_ID",
    "agentAliasId": "TSTALIASID",
    "sessionId": "quick-test-$(date +%s)",
    "inputText": "Get application details for asset $ASSET_ID",
    "endSession": false
}
EOF

echo "Payload created:"
cat quick_test_payload.json | jq . 2>/dev/null || cat quick_test_payload.json
echo ""

# Test gateway
echo "🚀 Testing gateway invocation..."
if aws bedrock-agent-runtime invoke-agent-core-gateway \
    --cli-input-json file://quick_test_payload.json \
    --region "$REGION" \
    --output json > quick_test_response.json 2>&1; then
    
    echo "✅ Gateway invocation successful!"
    echo ""
    echo "📥 Response:"
    echo "----------"
    cat quick_test_response.json | jq . 2>/dev/null || cat quick_test_response.json
    echo ""
    
    # Extract completion if available
    if command -v jq > /dev/null 2>&1; then
        COMPLETION=$(cat quick_test_response.json | jq -r '.completion // empty' 2>/dev/null)
        if [ ! -z "$COMPLETION" ] && [ "$COMPLETION" != "null" ]; then
            echo "💬 Application Details:"
            echo "$COMPLETION"
        fi
    fi
    
else
    echo "❌ Gateway invocation failed"
    echo ""
    echo "📥 Error details:"
    cat quick_test_response.json
    echo ""
    
    # Try direct Lambda as fallback
    echo "🔄 Trying direct Lambda invocation as fallback..."
    
    cat > lambda_payload.json << EOF
{
    "asset_id": "$ASSET_ID"
}
EOF
    
    if aws lambda invoke \
        --function-name a208194-chatops_application_details_intent \
        --region "$REGION" \
        --payload file://lambda_payload.json \
        lambda_response.json > /dev/null 2>&1; then
        
        echo "✅ Direct Lambda worked!"
        echo "📥 Lambda Response:"
        cat lambda_response.json | jq . 2>/dev/null || cat lambda_response.json
        
        rm -f lambda_payload.json lambda_response.json
    else
        echo "❌ Direct Lambda also failed"
    fi
fi

# Cleanup
rm -f quick_test_payload.json quick_test_response.json

echo ""
echo "🏁 Quick test completed"
echo ""
echo "💡 For more comprehensive testing:"
echo "   ./cloudshell_comprehensive_test.sh comprehensive"