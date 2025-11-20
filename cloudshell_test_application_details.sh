#!/bin/bash
# CloudShell Application Details Test
# Simple script to test a208194-chatops_application_details_intent via Agent Core Gateway

set -e

ASSET_ID="${1:-a12345}"
GATEWAY_ID="a208194-askjulius-agentcore-gateway-mcp-iam"
REGION="us-east-1"
SESSION_ID="app-details-$(date +%s)"

echo "🔍 Application Details Test"
echo "=" * 40
echo "Asset ID: $ASSET_ID"
echo "Gateway: $GATEWAY_ID"
echo "Region: $REGION"
echo "Session: $SESSION_ID"
echo ""

# Create payload file
cat > app_details_payload.json << EOF
{
    "gatewayId": "$GATEWAY_ID",
    "agentAliasId": "TSTALIASID",
    "sessionId": "$SESSION_ID",
    "inputText": "Get application details for asset $ASSET_ID",
    "endSession": false
}
EOF

echo "📤 Request Payload:"
echo "-" * 20
cat app_details_payload.json
echo ""
echo "-" * 20

echo ""
echo "🚀 Invoking Agent Core Gateway..."
echo ""

# Invoke the gateway
if aws bedrock-agent-runtime invoke-agent-core-gateway \
    --cli-input-json file://app_details_payload.json \
    --region "$REGION" \
    --output table; then
    
    echo ""
    echo "✅ Gateway invocation completed"
    
    # Also try JSON output for easier parsing
    echo ""
    echo "📋 JSON Response:"
    echo "-" * 20
    aws bedrock-agent-runtime invoke-agent-core-gateway \
        --cli-input-json file://app_details_payload.json \
        --region "$REGION" \
        --output json
else
    echo ""
    echo "❌ Gateway invocation failed"
    echo ""
    echo "🔍 Troubleshooting:"
    echo "1. Check AWS credentials: aws sts get-caller-identity"
    echo "2. Verify gateway exists: aws bedrock list-agent-core-gateways --region $REGION 2>/dev/null || echo 'Command not available'"
    echo "3. Check target Lambda: aws lambda get-function --function-name a208194-chatops_application_details_intent --region $REGION"
    echo "4. Verify IAM permissions for gateway service role"
fi

# Clean up
rm -f app_details_payload.json

echo ""
echo "📝 Usage Examples:"
echo "  $0                    # Test with default asset ID 'a12345'"
echo "  $0 a208194           # Test with specific asset ID"
echo "  $0 12345             # Test with numeric asset ID"