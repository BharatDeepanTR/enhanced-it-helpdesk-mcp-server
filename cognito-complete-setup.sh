#!/bin/bash
# Complete Cognito User Setup and JWT Token Generation Guide
# Run this in AWS CloudShell to set up authentication for your MCP gateway

echo "🔐 Cognito User Setup and JWT Token Generation"
echo "=============================================="
echo ""

# Configuration
USER_POOL_ID="us-east-1_wzWpXwzR6"
CLIENT_ID="57o30hpgrhrovfbe4tmnkrtv50"
REGION="us-east-1"

echo "Configuration:"
echo "  User Pool ID: $USER_POOL_ID"
echo "  Client ID: $CLIENT_ID"
echo "  Region: $REGION"
echo ""

# Step 1: Check if client supports ADMIN_NO_SRP_AUTH
echo "🔍 Step 1: Checking Cognito Client Configuration..."
echo "=================================================="

echo "Checking client authentication flows..."
aws cognito-idp describe-user-pool-client \
  --user-pool-id $USER_POOL_ID \
  --client-id $CLIENT_ID \
  --query 'UserPoolClient.ExplicitAuthFlows' \
  --output table

echo ""
echo "If ADMIN_NO_SRP_AUTH is not listed above, you'll need to update the client."
echo ""

# Step 2: Create a test user
echo "👤 Step 2: Creating Test User..."
echo "==============================="

# You can customize these values
TEST_USERNAME="mcptest"
TEMP_PASSWORD="TempPass123!"

echo "Creating user: $TEST_USERNAME"

# Create user
aws cognito-idp admin-create-user \
  --user-pool-id $USER_POOL_ID \
  --username $TEST_USERNAME \
  --temporary-password $TEMP_PASSWORD \
  --message-action SUPPRESS \
  --user-attributes Name=email,Value=mcptest@example.com Name=email_verified,Value=true

if [ $? -eq 0 ]; then
    echo "✅ User created successfully"
else
    echo "⚠️  User creation failed (user might already exist)"
fi

echo ""

# Step 3: Set permanent password
echo "🔑 Step 3: Setting Permanent Password..."
echo "======================================="

PERMANENT_PASSWORD="McpTest123!"

echo "Setting permanent password for $TEST_USERNAME..."

aws cognito-idp admin-set-user-password \
  --user-pool-id $USER_POOL_ID \
  --username $TEST_USERNAME \
  --password $PERMANENT_PASSWORD \
  --permanent

if [ $? -eq 0 ]; then
    echo "✅ Permanent password set"
else
    echo "❌ Failed to set permanent password"
fi

echo ""

# Step 4: Try authentication
echo "🔓 Step 4: Testing Authentication..."
echo "==================================="

echo "Attempting to authenticate user: $TEST_USERNAME"

AUTH_RESPONSE=$(aws cognito-idp admin-initiate-auth \
  --user-pool-id $USER_POOL_ID \
  --client-id $CLIENT_ID \
  --auth-flow ADMIN_USER_PASSWORD_AUTH \
  --auth-parameters USERNAME=$TEST_USERNAME,PASSWORD=$PERMANENT_PASSWORD \
  --output json 2>&1)

if echo "$AUTH_RESPONSE" | grep -q "AuthenticationResult"; then
    echo "✅ Authentication successful!"
    
    # Extract tokens
    ACCESS_TOKEN=$(echo "$AUTH_RESPONSE" | jq -r '.AuthenticationResult.AccessToken')
    ID_TOKEN=$(echo "$AUTH_RESPONSE" | jq -r '.AuthenticationResult.IdToken')
    
    echo ""
    echo "🎫 Tokens Retrieved:"
    echo "==================="
    echo "Access Token: ${ACCESS_TOKEN:0:50}..."
    echo "ID Token: ${ID_TOKEN:0:50}..."
    
    # Test the gateway
    echo ""
    echo "🧪 Step 5: Testing MCP Gateway with JWT Token..."
    echo "================================================"
    
    GATEWAY_URL="https://a208194-askjulius-agentcore-mcp-gateway-dhy8ntpcvu.gateway.bedrock-agentcore.us-east-1.amazonaws.com/mcp"
    
    echo "Testing tools/list with JWT token..."
    
    GATEWAY_RESPONSE=$(curl -s -X POST \
      -H "Content-Type: application/json" \
      -H "Authorization: Bearer $ACCESS_TOKEN" \
      -d '{"jsonrpc":"2.0","id":1,"method":"tools/list","params":{}}' \
      -w "\nHTTP_STATUS:%{http_code}" \
      "$GATEWAY_URL")
    
    echo "Gateway Response:"
    echo "$GATEWAY_RESPONSE"
    
    if echo "$GATEWAY_RESPONSE" | grep -q "200"; then
        echo ""
        echo "🎉 SUCCESS! Gateway authentication working!"
    else
        echo ""
        echo "⚠️  Gateway test failed - check response above"
    fi
    
    # Save token for manual testing
    echo ""
    echo "💾 For manual testing, use:"
    echo "=========================="
    echo "export JWT_TOKEN='$ACCESS_TOKEN'"
    echo "curl -X POST \\"
    echo "  -H 'Content-Type: application/json' \\"
    echo "  -H 'Authorization: Bearer \$JWT_TOKEN' \\"
    echo "  -d '{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"tools/list\",\"params\":{}}' \\"
    echo "  '$GATEWAY_URL'"
    
else
    echo "❌ Authentication failed"
    echo ""
    echo "Error response:"
    echo "$AUTH_RESPONSE"
    echo ""
    
    if echo "$AUTH_RESPONSE" | grep -q "InvalidParameterException"; then
        echo "🔧 Possible solutions:"
        echo "1. Update the Cognito client to enable ALLOW_ADMIN_USER_PASSWORD_AUTH:"
        echo ""
        echo "aws cognito-idp update-user-pool-client \\"
        echo "  --user-pool-id $USER_POOL_ID \\"
        echo "  --client-id $CLIENT_ID \\"
        echo "  --explicit-auth-flows ALLOW_ADMIN_USER_PASSWORD_AUTH ALLOW_CUSTOM_AUTH ALLOW_REFRESH_TOKEN_AUTH ALLOW_USER_SRP_AUTH"
        echo ""
    elif echo "$AUTH_RESPONSE" | grep -q "NotAuthorizedException"; then
        echo "🔧 Check username and password"
    fi
fi

echo ""
echo "📋 Summary:"
echo "=========="
echo "  User Pool ID: $USER_POOL_ID"
echo "  Client ID: $CLIENT_ID"
echo "  Test Username: $TEST_USERNAME"
echo "  Test Password: $PERMANENT_PASSWORD"
echo "  Gateway URL: $GATEWAY_URL"
echo ""
echo "🔄 Alternative Authentication Methods:"
echo "====================================="
echo ""
echo "If ADMIN_NO_SRP_AUTH doesn't work, try:"
echo ""
echo "1. SRP Authentication (more complex but always works):"
echo "   aws cognito-idp initiate-auth \\"
echo "     --client-id $CLIENT_ID \\"
echo "     --auth-flow SRP_AUTH \\"
echo "     --auth-parameters USERNAME=$TEST_USERNAME"
echo ""
echo "2. Use AWS Console to create users and get temporary tokens"
echo ""
echo "3. Use a web application that integrates with this User Pool"