#!/bin/bash
# Gateway Reconfiguration for IAM Authentication
# Alternative approach if JWT authentication continues to have issues

echo "🔧 Gateway Authentication Reconfiguration"
echo "========================================="
echo ""

# Configuration
GATEWAY_NAME="a208194-askjulius-agentcore-mcp-gateway"
GATEWAY_ID="a208194-askjulius-agentcore-mcp-gateway-dhy8ntpcvu"
IAM_ROLE_ARN="arn:aws:iam::818565325759:role/a208194-askjulius-agentcore-gateway"
REGION="us-east-1"

echo "Current Gateway Configuration:"
echo "  Name: $GATEWAY_NAME"
echo "  ID: $GATEWAY_ID"
echo "  Role: $IAM_ROLE_ARN"
echo "  Current Auth: CUSTOM_JWT (Cognito)"
echo ""

echo "🔍 Checking if gateway can be reconfigured..."
echo "============================================="

# Check current gateway status
echo "📋 Current gateway details:"
aws bedrock-agentcore describe-gateway \
  --gateway-id $GATEWAY_ID \
  --query 'Gateway.{Name:Name,Status:Status,AuthorizerType:AuthorizerType,CreatedAt:CreatedAt}' \
  --output table

if [ $? -ne 0 ]; then
    echo "❌ Cannot access gateway with current credentials"
    echo "💡 You may need to:"
    echo "   1. Assume the gateway role"
    echo "   2. Check your permissions for bedrock-agentcore"
    echo ""
fi

echo ""
echo "🔧 Reconfiguration Options:"
echo "=========================="
echo ""

echo "Option 1: Update Current Gateway to IAM Auth"
echo "--------------------------------------------"
echo "⚠️  Note: This may not be supported for existing gateways"
echo ""
echo "Command to try:"
echo "aws bedrock-agentcore update-gateway \\"
echo "  --gateway-id $GATEWAY_ID \\"
echo "  --authorizer-type IAM \\"
echo "  --authorizer-configuration '{}'"
echo ""

read -p "Do you want to try updating the current gateway to IAM auth? (y/N): " update_gateway

if [[ $update_gateway =~ ^[Yy]$ ]]; then
    echo ""
    echo "🔄 Attempting to update gateway authorization..."
    
    aws bedrock-agentcore update-gateway \
      --gateway-id $GATEWAY_ID \
      --authorizer-type IAM \
      --authorizer-configuration '{}'
    
    if [ $? -eq 0 ]; then
        echo "✅ Gateway updated successfully!"
        echo ""
        echo "🧪 Testing updated gateway..."
        ./iam-gateway-test.sh
    else
        echo "❌ Gateway update failed"
        echo "   This operation may not be supported"
    fi
else
    echo ""
    echo "Option 2: Create New Gateway with IAM Auth"
    echo "-------------------------------------------"
    echo ""
    echo "If updating doesn't work, create a new gateway:"
    echo ""
    
    NEW_GATEWAY_NAME="${GATEWAY_NAME}-iam"
    echo "New gateway name: $NEW_GATEWAY_NAME"
    echo ""
    
    read -p "Create new gateway with IAM authentication? (y/N): " create_new
    
    if [[ $create_new =~ ^[Yy]$ ]]; then
        echo ""
        echo "🚀 Creating new gateway with IAM authentication..."
        
        # Get the Lambda function ARN from the current gateway
        echo "📋 Getting Lambda function from current gateway..."
        
        LAMBDA_ARN="arn:aws:lambda:us-east-1:818565325759:function:a208194-chatops_application_details_intent"
        
        echo "   Lambda ARN: $LAMBDA_ARN"
        echo ""
        
        # Create new gateway
        CREATE_RESULT=$(aws bedrock-agentcore create-gateway \
          --name "$NEW_GATEWAY_NAME" \
          --role-arn "$IAM_ROLE_ARN" \
          --protocol-type MCP \
          --authorizer-type IAM \
          --lambda-functions "LambdaArn=$LAMBDA_ARN" \
          --output json)
        
        if [ $? -eq 0 ]; then
            NEW_GATEWAY_ID=$(echo "$CREATE_RESULT" | jq -r '.Gateway.Id')
            NEW_GATEWAY_ENDPOINT=$(echo "$CREATE_RESULT" | jq -r '.Gateway.Endpoint')
            
            echo "✅ New gateway created successfully!"
            echo "   New Gateway ID: $NEW_GATEWAY_ID"
            echo "   New Endpoint: $NEW_GATEWAY_ENDPOINT"
            echo ""
            
            # Wait for gateway to be ready
            echo "⏳ Waiting for gateway to be active..."
            aws bedrock-agentcore wait gateway-active --gateway-id "$NEW_GATEWAY_ID"
            
            if [ $? -eq 0 ]; then
                echo "✅ Gateway is now active!"
                echo ""
                echo "🧪 Testing new IAM-authenticated gateway..."
                
                # Update the test script with new endpoint
                sed -i "s|a208194-askjulius-agentcore-mcp-gateway-dhy8ntpcvu|$NEW_GATEWAY_ID|g" iam-gateway-test.sh
                
                ./iam-gateway-test.sh
                
                echo ""
                echo "📋 New Gateway Details:"
                echo "======================"
                echo "  Name: $NEW_GATEWAY_NAME"
                echo "  ID: $NEW_GATEWAY_ID"
                echo "  Endpoint: $NEW_GATEWAY_ENDPOINT/mcp"
                echo "  Authentication: IAM"
                echo "  Status: Active"
                
            else
                echo "❌ Gateway creation timed out"
            fi
        else
            echo "❌ Failed to create new gateway"
        fi
    fi
fi

echo ""
echo "Option 3: Fix Cognito Authentication (Recommended)"
echo "==================================================="
echo ""
echo "The most straightforward solution is still to fix the Cognito issue:"
echo ""
echo "1. Remove PostAuthentication Lambda trigger temporarily:"
echo "   - AWS Console > Cognito User Pools > $USER_POOL_ID"
echo "   - User pool properties > Lambda triggers"
echo "   - Remove PostAuthentication trigger"
echo ""
echo "2. Test authentication:"
echo "   ./interactive-cognito-auth.sh"
echo ""
echo "3. Fix Lambda permissions and restore trigger"
echo ""

echo "🎯 Recommendation:"
echo "=================="
echo ""
echo "For quickest results:"
echo "1. Try Option 1 (update current gateway) first"
echo "2. If that fails, use Option 3 (fix Cognito)"
echo "3. Option 2 (new gateway) as last resort"
echo ""
echo "Your current setup is almost perfect - just the authentication method needs adjustment!"