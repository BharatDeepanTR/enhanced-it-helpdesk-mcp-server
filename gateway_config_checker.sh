#!/bin/bash
# Gateway Configuration Checker and Fixer
# Helps resolve authentication issues with the MCP gateway

GATEWAY_NAME="a208194-askjulius-agentcore-mcp-gateway"
REGION="us-east-1"
LAMBDA_ARN="arn:aws:lambda:us-east-1:818565325759:function:a208194-chatops_application_details_intent"

echo "🔧 MCP Gateway Configuration Checker"
echo "===================================="
echo "Gateway: $GATEWAY_NAME"
echo "Region: $REGION"
echo ""

# Check AWS connectivity
echo "🔍 Checking AWS connectivity..."
if ! aws sts get-caller-identity > /dev/null 2>&1; then
    echo "❌ AWS credentials not configured"
    exit 1
fi

ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
echo "✅ AWS Account: $ACCOUNT"

# Check if gateway exists
echo ""
echo "🔍 Checking gateway status..."

# Try different commands to check gateway
GATEWAY_EXISTS=false

if aws bedrock-agent-runtime list-agent-core-gateways --region "$REGION" > /dev/null 2>&1; then
    echo "   📋 Checking with bedrock-agent-runtime..."
    if aws bedrock-agent-runtime list-agent-core-gateways --region "$REGION" --query "gateways[?gatewayName=='$GATEWAY_NAME']" --output text 2>/dev/null | grep -q "$GATEWAY_NAME"; then
        echo "   ✅ Gateway found via bedrock-agent-runtime"
        GATEWAY_EXISTS=true
        
        # Get gateway details
        aws bedrock-agent-runtime describe-agent-core-gateway --gateway-id "$GATEWAY_NAME" --region "$REGION" 2>/dev/null || \
        echo "   ⚠️ Could not get gateway details"
    else
        echo "   ❌ Gateway not found via bedrock-agent-runtime"
    fi
else
    echo "   ⚠️ bedrock-agent-runtime commands not available"
fi

# Try alternative commands
if [ "$GATEWAY_EXISTS" = "false" ]; then
    echo "   📋 Trying alternative commands..."
    
    if aws bedrock list-agent-core-gateways --region "$REGION" > /dev/null 2>&1; then
        echo "   📋 Checking with bedrock..."
        if aws bedrock list-agent-core-gateways --region "$REGION" --query "gateways[?gatewayName=='$GATEWAY_NAME']" --output text 2>/dev/null | grep -q "$GATEWAY_NAME"; then
            echo "   ✅ Gateway found via bedrock"
            GATEWAY_EXISTS=true
        fi
    fi
fi

# Check Lambda function
echo ""
echo "🔍 Checking target Lambda function..."
if aws lambda get-function --function-name "a208194-chatops_application_details_intent" --region "$REGION" > /dev/null 2>&1; then
    echo "✅ Target Lambda function exists and is accessible"
    
    # Get Lambda details
    LAMBDA_RUNTIME=$(aws lambda get-function --function-name "a208194-chatops_application_details_intent" --region "$REGION" --query 'Configuration.Runtime' --output text)
    LAMBDA_UPDATED=$(aws lambda get-function --function-name "a208194-chatops_application_details_intent" --region "$REGION" --query 'Configuration.LastModified' --output text)
    echo "   Runtime: $LAMBDA_RUNTIME"
    echo "   Last Modified: $LAMBDA_UPDATED"
else
    echo "❌ Target Lambda function not accessible"
fi

# Check service role
echo ""
echo "🔍 Checking service role..."
SERVICE_ROLE_NAME="a208194-askjulius-agentcore-gateway"
if aws iam get-role --role-name "$SERVICE_ROLE_NAME" > /dev/null 2>&1; then
    echo "✅ Service role exists"
    
    # Check attached policies
    echo "   📋 Attached policies:"
    aws iam list-attached-role-policies --role-name "$SERVICE_ROLE_NAME" --query 'AttachedPolicies[].PolicyName' --output text
    
    # Check inline policies
    echo "   📋 Inline policies:"
    aws iam list-role-policies --role-name "$SERVICE_ROLE_NAME" --query 'PolicyNames' --output text
else
    echo "❌ Service role does not exist"
fi

echo ""
echo "📊 Status Summary:"
echo "=================="
echo "Gateway Exists: $(if [ "$GATEWAY_EXISTS" = "true" ]; then echo "✅ Yes"; else echo "❌ No"; fi)"
echo "Lambda Accessible: $(if aws lambda get-function --function-name "a208194-chatops_application_details_intent" --region "$REGION" > /dev/null 2>&1; then echo "✅ Yes"; else echo "❌ No"; fi)"
echo "Service Role: $(if aws iam get-role --role-name "$SERVICE_ROLE_NAME" > /dev/null 2>&1; then echo "✅ Exists"; else echo "❌ Missing"; fi)"

echo ""
if [ "$GATEWAY_EXISTS" = "false" ]; then
    echo "🛠️ Gateway Recreation Required"
    echo "============================="
    echo ""
    echo "The gateway does not exist or is not accessible."
    echo "You can recreate it using:"
    echo ""
    echo "   1. Run the creation script:"
    echo "      ./create-agentcore-gateway.sh"
    echo ""
    echo "   2. Or create manually via AWS Console:"
    echo "      - Go to AWS Console → Bedrock → Agent Core → Gateways"
    echo "      - Use gateway name: $GATEWAY_NAME"
    echo "      - Configure for IAM authentication (not Bearer token)"
    echo "      - Target Lambda: $LAMBDA_ARN"
    echo ""
    echo "   3. Ensure the gateway is configured with:"
    echo "      - Inbound Auth: AWS_IAM (not Bearer token)"
    echo "      - Outbound Auth: AWS_IAM"
    echo "      - Proper MCP schema for get_application_details tool"
else
    echo "🔍 Authentication Issue Diagnosis"
    echo "================================="
    echo ""
    echo "The gateway exists but authentication is failing."
    echo "This suggests a configuration mismatch."
    echo ""
    echo "Next steps:"
    echo "1. Run authentication diagnostic:"
    echo "   ./cloudshell_auth_diagnostic.sh"
    echo ""
    echo "2. Check gateway authentication configuration in AWS Console"
    echo ""
    echo "3. Verify the gateway is configured for IAM authentication"
    echo "   (not Bearer token authentication)"
    echo ""
    echo "4. If needed, delete and recreate the gateway with proper config"
fi

echo ""
echo "💡 Troubleshooting Commands:"
echo "============================"
echo ""
echo "# Check gateway in console:"
echo "# AWS Console → Bedrock → Agent Core → Gateways"
echo ""
echo "# Test authentication:"
echo "./cloudshell_auth_diagnostic.sh"
echo ""
echo "# Recreate gateway:"
echo "./create-agentcore-gateway.sh"
echo ""
echo "# Test direct Lambda:"
echo "aws lambda invoke --function-name a208194-chatops_application_details_intent --region us-east-1 --payload '{\"asset_id\":\"a12345\"}' response.json && cat response.json"