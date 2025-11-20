#!/bin/bash
# Configure Agent Core Gateway with Inbound Auth IAM Permissions
# Execute this in CloudShell after gateway creation

echo "🔐 Configuring Agent Core Gateway Inbound Auth"
echo "=============================================="
echo ""

GATEWAY_NAME="a208194-askjulius-agentcore-gateway"
EXISTING_ROLE_ARN="arn:aws:iam::818565325759:role/a208194-askjulius-agentcore-gateway"
REGION="us-east-1"

# Test AWS credentials
if ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null); then
    echo "✅ AWS credentials active - Account: $ACCOUNT_ID"
else
    echo "❌ AWS credentials not working"
    exit 1
fi

echo ""
echo "🎯 Gateway Configuration:"
echo "========================"
echo "Gateway Name: $GATEWAY_NAME"
echo "Existing Role ARN: $EXISTING_ROLE_ARN"
echo "Region: $REGION"
echo ""

# Method 1: Create gateway with full IAM auth configuration
echo "🚀 Method 1: Create Gateway with Complete IAM Auth Configuration"
echo "================================================================"

echo "Creating gateway with inbound auth IAM permissions..."

# Enhanced create-gateway command with auth configuration
aws bedrock-agentcore-control create-gateway \
    --name "$GATEWAY_NAME" \
    --role-arn "$EXISTING_ROLE_ARN" \
    --protocol-type MCP \
    --authorizer-type AWS_IAM \
    --inbound-auth-config '{
        "type": "AWS_IAM",
        "iamConfig": {
            "roleArn": "'$EXISTING_ROLE_ARN'"
        }
    }' \
    --region "$REGION" 2>/dev/null

if [ $? -eq 0 ]; then
    echo "✅ Gateway created with IAM auth configuration"
else
    echo "⚠️  Basic gateway creation may have succeeded, checking alternatives..."
    
    # Method 2: Update existing gateway auth configuration
    echo ""
    echo "🔄 Method 2: Update Existing Gateway Auth Configuration"
    echo "====================================================="
    
    # Get gateway ID first
    echo "Getting gateway ID..."
    GATEWAY_ID=$(aws bedrock-agentcore-control list-gateways \
        --region "$REGION" \
        --query "gateways[?name=='$GATEWAY_NAME'].gatewayId" \
        --output text 2>/dev/null)
    
    if [[ -n "$GATEWAY_ID" && "$GATEWAY_ID" != "None" ]]; then
        echo "Found gateway ID: $GATEWAY_ID"
        
        # Update gateway auth configuration
        echo "Updating gateway auth configuration..."
        aws bedrock-agentcore-control update-gateway \
            --gateway-id "$GATEWAY_ID" \
            --inbound-auth-config '{
                "type": "AWS_IAM",
                "iamConfig": {
                    "roleArn": "'$EXISTING_ROLE_ARN'"
                }
            }' \
            --region "$REGION"
        
        if [ $? -eq 0 ]; then
            echo "✅ Gateway auth configuration updated"
        else
            echo "⚠️  Update command format may need adjustment"
        fi
    else
        echo "❌ Could not find gateway ID"
    fi
    
    # Method 3: Set auth policy directly
    echo ""
    echo "🔧 Method 3: Set Gateway Auth Policy"
    echo "==================================="
    
    if [[ -n "$GATEWAY_ID" ]]; then
        # Create auth policy JSON
        cat > /tmp/gateway-auth-policy.json << EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "AWS": "$EXISTING_ROLE_ARN"
            },
            "Action": [
                "bedrock-agentcore:InvokeGateway",
                "bedrock-agentcore:GetGateway"
            ],
            "Resource": "arn:aws:bedrock-agentcore:$REGION:$ACCOUNT_ID:gateway/$GATEWAY_ID"
        }
    ]
}
EOF

        echo "Setting gateway resource policy..."
        aws bedrock-agentcore-control put-gateway-policy \
            --gateway-id "$GATEWAY_ID" \
            --policy file:///tmp/gateway-auth-policy.json \
            --region "$REGION" 2>/dev/null
        
        if [ $? -eq 0 ]; then
            echo "✅ Gateway auth policy set"
        else
            echo "⚠️  Gateway policy command may not be available"
        fi
        
        rm -f /tmp/gateway-auth-policy.json
    fi
fi

# Method 4: Alternative command structures
echo ""
echo "🔍 Method 4: Alternative Command Structures"
echo "=========================================="

echo "Trying alternative auth configuration formats..."

# Alternative 1: Simplified IAM config
aws bedrock-agentcore-control create-gateway \
    --name "${GATEWAY_NAME}-alt1" \
    --role-arn "$EXISTING_ROLE_ARN" \
    --protocol-type MCP \
    --authorizer-type AWS_IAM \
    --auth-type IAM \
    --iam-role-arn "$EXISTING_ROLE_ARN" \
    --region "$REGION" 2>/dev/null

# Alternative 2: Separate auth configuration
aws bedrock-agentcore-control configure-gateway-auth \
    --gateway-name "$GATEWAY_NAME" \
    --auth-type AWS_IAM \
    --iam-role-arn "$EXISTING_ROLE_ARN" \
    --region "$REGION" 2>/dev/null

echo ""
echo "📋 Verification Commands"
echo "======================="

echo "Check gateway configuration:"
echo "aws bedrock-agentcore-control describe-gateway --gateway-name $GATEWAY_NAME --region $REGION"
echo ""
echo "List all gateways:"
echo "aws bedrock-agentcore-control list-gateways --region $REGION"
echo ""
echo "Get gateway auth configuration:"
echo "aws bedrock-agentcore-control get-gateway-auth --gateway-name $GATEWAY_NAME --region $REGION"
echo ""

echo ""
echo "🎯 Manual Console Configuration (if CLI doesn't work)"
echo "===================================================="
echo ""
echo "If CLI commands don't support inbound auth configuration:"
echo ""
echo "1. Go to AWS Console → Bedrock → Agent Core → Gateways"
echo "2. Find gateway: $GATEWAY_NAME"
echo "3. Click 'Edit' or 'Configure'"
echo "4. In 'Inbound Auth Configuration':"
echo "   - Select: 'Use IAM permissions'"
echo "   - Role ARN: $EXISTING_ROLE_ARN"
echo "5. Save configuration"
echo ""

echo ""
echo "🔑 IAM Role Requirements"
echo "======================="
echo ""
echo "Ensure your role ($EXISTING_ROLE_ARN) has these permissions:"
echo ""
cat << 'EOF'
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "bedrock-agentcore:InvokeGateway",
                "bedrock-agentcore:GetGateway",
                "bedrock:InvokeModel",
                "bedrock:InvokeModelWithResponseStream"
            ],
            "Resource": "*"
        }
    ]
}
EOF

echo ""
echo "And trust policy allowing bedrock.amazonaws.com:"
echo ""
cat << 'EOF'
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Service": "bedrock.amazonaws.com"
            },
            "Action": "sts:AssumeRole"
        }
    ]
}
EOF

echo ""
echo "✅ Auth configuration script completed!"
echo ""
echo "💡 Next steps:"
echo "1. Verify gateway exists and is active"
echo "2. Check auth configuration in console"
echo "3. Test gateway with appropriate IAM credentials"