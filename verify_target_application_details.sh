#!/bin/bash

# Quick verification of target-chatops-application-details
# Checks if the target exists and is properly configured

echo "🔍 Quick Target Verification: target-chatops-application-details"
echo "================================================================"

# Configuration
GATEWAY_ID="a208194-askjulius-agentcore-gateway-mcp-iam-fvro4phd59"
TARGET_NAME="target-chatops-application-details"
LAMBDA_ARN="arn:aws:lambda:us-east-1:818565325759:function:a208194-chatops_application_details_intent"
REGION="us-east-1"

echo "📋 Verification Details:"
echo "   Gateway ID: $GATEWAY_ID"
echo "   Target Name: $TARGET_NAME"
echo "   Lambda ARN: $LAMBDA_ARN"
echo "   Region: $REGION"
echo ""

# Step 1: Check if Lambda exists
echo "🔧 Step 1: Verifying Lambda function exists..."
if aws lambda get-function --function-name "$LAMBDA_ARN" --region "$REGION" >/dev/null 2>&1; then
    echo "   ✅ Lambda function exists and is accessible"
    
    # Get Lambda details
    echo "   📋 Lambda details:"
    aws lambda get-function --function-name "$LAMBDA_ARN" --region "$REGION" --query 'Configuration.[FunctionName,Runtime,Handler,LastModified]' --output table
else
    echo "   ❌ Lambda function not found or not accessible"
    echo "   💡 Check if the Lambda ARN is correct or if you have permissions"
fi

echo ""

# Step 2: Check if gateway exists
echo "🌐 Step 2: Verifying gateway exists..."
if aws bedrock-agent list-agent-core-gateways --region "$REGION" >/dev/null 2>&1; then
    echo "   ✅ Can access gateway list API"
    
    # Check if our specific gateway exists
    GATEWAY_CHECK=$(aws bedrock-agent list-agent-core-gateways --region "$REGION" 2>/dev/null | grep -i "$GATEWAY_ID" || echo "")
    
    if [ -n "$GATEWAY_CHECK" ]; then
        echo "   ✅ Gateway found in list"
    else
        echo "   ⚠️  Gateway not found in list (may still exist)"
    fi
else
    echo "   ⚠️  Cannot access gateway list API (check permissions)"
fi

echo ""

# Step 3: Check target within gateway (if gateway detail API works)
echo "🎯 Step 3: Checking target configuration..."

# Try to get gateway details
if aws bedrock-agent get-agent-core-gateway --gateway-id "$GATEWAY_ID" --region "$REGION" >/dev/null 2>&1; then
    echo "   ✅ Can access gateway details"
    
    # Look for targets
    TARGETS=$(aws bedrock-agent get-agent-core-gateway --gateway-id "$GATEWAY_ID" --region "$REGION" --query 'gatewayDetails.targets[].targetName' --output text 2>/dev/null || echo "")
    
    if [ -n "$TARGETS" ]; then
        echo "   📋 Targets found in gateway:"
        echo "$TARGETS" | while read target; do
            echo "      • $target"
            if [ "$target" = "$TARGET_NAME" ]; then
                echo "        🎯 MATCH: Our target is configured!"
            fi
        done
    else
        echo "   ⚠️  No targets found or unable to read target configuration"
    fi
else
    echo "   ⚠️  Cannot access gateway details (check permissions or gateway ID)"
fi

echo ""

# Step 4: Test basic connectivity
echo "🌐 Step 4: Testing basic gateway connectivity..."

GATEWAY_URL="https://a208194-askjulius-agentcore-gateway-mcp-iam-fvro4phd59.gateway.bedrock-agentcore.us-east-1.amazonaws.com"

# Test basic connectivity
echo "   Testing: $GATEWAY_URL"
if curl -s -o /dev/null -w "%{http_code}" --max-time 10 "$GATEWAY_URL" | grep -E "^(200|401|403)"; then
    echo "   ✅ Gateway endpoint is accessible"
else
    echo "   ❌ Gateway endpoint is not accessible"
fi

# Test MCP endpoint
MCP_URL="$GATEWAY_URL/mcp"
echo "   Testing: $MCP_URL"
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "$MCP_URL")
case $HTTP_CODE in
    200) echo "   ✅ MCP endpoint accessible (no auth required)" ;;
    401) echo "   🔐 MCP endpoint accessible (authentication required)" ;;
    403) echo "   🚫 MCP endpoint accessible (authorization required)" ;;
    404) echo "   ❌ MCP endpoint not found" ;;
    *) echo "   ⚠️  MCP endpoint status: $HTTP_CODE" ;;
esac

echo ""

# Step 5: Summary and next steps
echo "📊 Verification Summary:"
echo "========================"

echo ""
echo "✅ Verified components:"
echo "   • Lambda function existence"
echo "   • Gateway API access"
echo "   • Basic connectivity"
echo ""
echo "🎯 Ready for testing:"
echo "   ./cloudshell_test_target_application_details.sh"
echo ""
echo "💡 If verification shows issues:"
echo "   • Check AWS credentials and permissions"
echo "   • Verify gateway ID is correct"
echo "   • Confirm target is properly configured in gateway"