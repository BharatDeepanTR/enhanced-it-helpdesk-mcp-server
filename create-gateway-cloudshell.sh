#!/bin/bash
# Execute Agent Core Gateway creation with CloudShell temporary credentials

echo "🔐 Setting up CloudShell temporary credentials..."
echo "================================================"

# Check if we're in CloudShell environment
if [[ -n "$AWS_EXECUTION_ENV" ]] || [[ -n "$AWS_CLOUDSHELL_USER_ID" ]]; then
    echo "✅ AWS CloudShell detected - credentials should be automatic"
else
    echo "📝 Manual temporary credentials setup required"
    echo ""
    echo "Please provide your temporary credentials from CloudShell:"
    echo ""
    read -p "AWS Access Key ID: " AWS_ACCESS_KEY_ID
    read -s -p "AWS Secret Access Key: " AWS_SECRET_ACCESS_KEY
    echo ""
    read -p "AWS Session Token: " AWS_SESSION_TOKEN
    read -p "AWS Region [us-east-1]: " AWS_REGION
    
    # Set defaults
    AWS_REGION=${AWS_REGION:-us-east-1}
    
    # Export credentials
    export AWS_ACCESS_KEY_ID="$AWS_ACCESS_KEY_ID"
    export AWS_SECRET_ACCESS_KEY="$AWS_SECRET_ACCESS_KEY"
    export AWS_SESSION_TOKEN="$AWS_SESSION_TOKEN"
    export AWS_DEFAULT_REGION="$AWS_REGION"
    
    echo "✅ Temporary credentials set"
fi

echo ""
echo "🧪 Testing AWS credentials..."
if aws sts get-caller-identity >/dev/null 2>&1; then
    ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    echo "✅ Credentials valid - Account: $ACCOUNT_ID"
else
    echo "❌ Credentials invalid - please check and try again"
    exit 1
fi

echo ""
echo "🚀 Creating Agent Core Gateway..."
echo "================================="

# Gateway parameters
GATEWAY_NAME="a208194-askjulius-agentcore-gateway"
ROLE_ARN="arn:aws:iam::818565325759:role/a208194-askjulius-agentcore-gateway"
PROTOCOL_TYPE="MCP"
AUTHORIZER_TYPE="AWS_IAM"

echo "Gateway Name: $GATEWAY_NAME"
echo "Role ARN: $ROLE_ARN"
echo "Protocol Type: $PROTOCOL_TYPE"
echo "Authorizer Type: $AUTHORIZER_TYPE"
echo ""

# Execute the gateway creation command
echo "🔄 Executing: aws bedrock-agentcore-control create-gateway..."

aws bedrock-agentcore-control create-gateway \
    --name "$GATEWAY_NAME" \
    --role-arn "$ROLE_ARN" \
    --protocol-type "$PROTOCOL_TYPE" \
    --authorizer-type "$AUTHORIZER_TYPE" \
    --region us-east-1

# Check if command was successful
if [ $? -eq 0 ]; then
    echo ""
    echo "🎉 Gateway creation command executed successfully!"
    echo ""
    echo "📋 Next steps:"
    echo "1. Check AWS Console → Bedrock → Agent Core → Gateways"
    echo "2. Verify the gateway is listed and active"
    echo "3. Configure any additional targets/endpoints as needed"
else
    echo ""
    echo "❌ Gateway creation failed"
    echo ""
    echo "💡 Troubleshooting:"
    echo "1. Verify the role ARN exists and has correct permissions"
    echo "2. Check that you have bedrock-agentcore-control permissions"
    echo "3. Ensure the CLI version supports this command"
    echo "4. Try running with --debug flag for more details"
fi

echo ""
echo "✅ Script completed"