#!/bin/bash
# CloudShell Agent Core Gateway Creator
# Upload this script to AWS CloudShell and execute

echo "☁️  AWS CloudShell: Agent Core Gateway Creator"
echo "=============================================="
echo ""

# Verify we're in CloudShell environment
echo "🔍 Environment Check..."
if [[ -n "$AWS_EXECUTION_ENV" ]] || [[ -n "$AWS_CLOUDSHELL_USER_ID" ]] || [[ -n "$CLOUDSHELL_ENVIRONMENT" ]]; then
    echo "✅ AWS CloudShell environment detected"
else
    echo "⚠️  Not in CloudShell - setting up manual credentials..."
fi

# Test AWS credentials
echo ""
echo "🧪 Testing AWS Access..."
if ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null); then
    echo "✅ AWS credentials active"
    echo "   Account ID: $ACCOUNT_ID"
    echo "   Region: $(aws configure get region 2>/dev/null || echo 'us-east-1')"
else
    echo "❌ AWS credentials not working"
    echo ""
    echo "🔧 CloudShell Credential Setup:"
    echo "1. Make sure you're logged into AWS Console"
    echo "2. Open CloudShell from the console"
    echo "3. Credentials should be automatic in CloudShell"
    echo ""
    exit 1
fi

# Check AWS CLI version and bedrock-agentcore-control availability
echo ""
echo "🔧 AWS CLI Version Check..."
AWS_CLI_VERSION=$(aws --version 2>&1)
echo "Current version: $AWS_CLI_VERSION"

echo ""
echo "🔍 Checking bedrock-agentcore-control command availability..."
if aws bedrock-agentcore-control help >/dev/null 2>&1; then
    echo "✅ bedrock-agentcore-control command available"
    COMMAND_AVAILABLE=true
else
    echo "❌ bedrock-agentcore-control command not available"
    echo ""
    echo "🔄 Attempting to update AWS CLI in CloudShell..."
    
    # Try to update CLI in CloudShell
    if command -v pip3 >/dev/null 2>&1; then
        echo "   Updating AWS CLI via pip3..."
        pip3 install --user --upgrade awscli
        
        # Add to PATH if needed
        export PATH="$HOME/.local/bin:$PATH"
        
        # Test again
        if aws bedrock-agentcore-control help >/dev/null 2>&1; then
            echo "✅ bedrock-agentcore-control now available after update"
            COMMAND_AVAILABLE=true
        else
            echo "❌ bedrock-agentcore-control still not available"
            COMMAND_AVAILABLE=false
        fi
    else
        echo "   Cannot update CLI - pip3 not available"
        COMMAND_AVAILABLE=false
    fi
fi

# Gateway configuration
GATEWAY_NAME="a208194-askjulius-agentcore-gateway"
ROLE_ARN="arn:aws:iam::818565325759:role/a208194-askjulius-agentcore-gateway"
PROTOCOL_TYPE="MCP"
AUTHORIZER_TYPE="AWS_IAM"
REGION="us-east-1"

echo ""
echo "🎯 Gateway Configuration:"
echo "========================"
echo "Name: $GATEWAY_NAME"
echo "Role ARN: $ROLE_ARN"
echo "Protocol: $PROTOCOL_TYPE"
echo "Authorizer: $AUTHORIZER_TYPE"
echo "Region: $REGION"
echo ""

if [ "$COMMAND_AVAILABLE" = "true" ]; then
    echo "🚀 Creating Agent Core Gateway via CLI..."
    echo "========================================"
    
    # Execute the gateway creation with inbound auth configuration
    echo "Running command with IAM auth configuration:"
    echo "aws bedrock-agentcore-control create-gateway \\"
    echo "  --name $GATEWAY_NAME \\"
    echo "  --role-arn $ROLE_ARN \\"
    echo "  --protocol-type $PROTOCOL_TYPE \\"
    echo "  --authorizer-type $AUTHORIZER_TYPE \\"
    echo "  --inbound-auth-config '{\"type\": \"AWS_IAM\", \"iamConfig\": {\"roleArn\": \"$ROLE_ARN\"}}' \\"
    echo "  --region $REGION"
    echo ""
    
    # Try with inbound auth configuration first
    aws bedrock-agentcore-control create-gateway \
        --name "$GATEWAY_NAME" \
        --role-arn "$ROLE_ARN" \
        --protocol-type "$PROTOCOL_TYPE" \
        --authorizer-type "$AUTHORIZER_TYPE" \
        --inbound-auth-config "{\"type\": \"AWS_IAM\", \"iamConfig\": {\"roleArn\": \"$ROLE_ARN\"}}" \
        --region "$REGION" 2>/dev/null
    
    # If that fails, try without inbound auth config
    if [ $? -ne 0 ]; then
        echo "⚠️  Inbound auth config failed, trying basic creation..."
        aws bedrock-agentcore-control create-gateway \
            --name "$GATEWAY_NAME" \
            --role-arn "$ROLE_ARN" \
            --protocol-type "$PROTOCOL_TYPE" \
            --authorizer-type "$AUTHORIZER_TYPE" \
            --region "$REGION"
    fi
    
    if [ $? -eq 0 ]; then
        echo ""
        echo "🎉 Gateway created successfully!"
        echo ""
        echo "📋 Next Steps:"
        echo "1. Check AWS Console → Bedrock → Agent Core → Gateways"
        echo "2. Verify gateway status is Active"
        echo "3. Configure targets/endpoints as needed"
    else
        echo ""
        echo "❌ Gateway creation failed"
        echo ""
        echo "💡 Common issues:"
        echo "1. Role doesn't exist or lacks permissions"
        echo "2. Gateway name already exists"
        echo "3. Insufficient bedrock permissions"
        echo ""
        echo "🔧 Try with debug flag:"
        echo "aws bedrock-agentcore-control create-gateway --name $GATEWAY_NAME --role-arn $ROLE_ARN --protocol-type $PROTOCOL_TYPE --authorizer-type $AUTHORIZER_TYPE --region $REGION --debug"
    fi
else
    echo "⚠️  CLI Command Not Available - Manual Creation Required"
    echo "======================================================"
    echo ""
    echo "🌐 Manual Creation via AWS Console:"
    echo "1. Go to: https://console.aws.amazon.com/bedrock/"
    echo "2. Navigate: Agent Core → Gateways"
    echo "3. Click: Create Gateway"
    echo ""
    echo "📝 Use these exact values:"
    echo "   Gateway Name: $GATEWAY_NAME"
    echo "   Role ARN: $ROLE_ARN"
    echo "   Protocol Type: $PROTOCOL_TYPE"
    echo "   Authorizer Type: $AUTHORIZER_TYPE"
    echo "   Region: $REGION"
    echo ""
    echo "🔑 Alternative CLI Commands to Try:"
    echo "# Try different service names:"
    echo "aws bedrock create-agent-core-gateway --help"
    echo "aws bedrock-agent create-gateway --help"  
    echo "aws bedrock-runtime create-gateway --help"
    echo ""
fi

echo ""
echo "📊 Validation Commands:"
echo "======================"
echo "# List existing gateways:"
echo "aws bedrock-agentcore-control list-gateways --region $REGION"
echo ""
echo "# Get gateway details:"
echo "aws bedrock-agentcore-control get-gateway --gateway-id <gateway-id> --region $REGION"
echo ""

echo "✅ CloudShell execution completed!"
echo ""
echo "💡 If this script helped, the gateway should now be created."
echo "   Check the AWS Console to verify."