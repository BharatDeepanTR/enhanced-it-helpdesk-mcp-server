#!/bin/bash
# Quick Cognito Client Configuration Fix
# Run this first if ADMIN_NO_SRP_AUTH is not working

echo "🔧 Cognito Client Configuration Fix"
echo "==================================="
echo ""

USER_POOL_ID="us-east-1_wzWpXwzR6"
CLIENT_ID="57o30hpgrhrovfbe4tmnkrtv50"

echo "Checking current client configuration..."

# Check current auth flows
CURRENT_FLOWS=$(aws cognito-idp describe-user-pool-client \
  --user-pool-id $USER_POOL_ID \
  --client-id $CLIENT_ID \
  --query 'UserPoolClient.ExplicitAuthFlows' \
  --output json)

echo "Current auth flows: $CURRENT_FLOWS"

if echo "$CURRENT_FLOWS" | grep -q "ALLOW_ADMIN_USER_PASSWORD_AUTH"; then
    echo "✅ ALLOW_ADMIN_USER_PASSWORD_AUTH is already enabled"
else
    echo "⚠️  ALLOW_ADMIN_USER_PASSWORD_AUTH is not enabled"
    echo ""
    echo "Enabling ADMIN_NO_SRP_AUTH..."
    
    # Update client to enable ALLOW_ADMIN_USER_PASSWORD_AUTH (new syntax)
    echo "Using new ALLOW_ syntax for auth flows..."
    aws cognito-idp update-user-pool-client \
      --user-pool-id $USER_POOL_ID \
      --client-id $CLIENT_ID \
      --explicit-auth-flows ALLOW_ADMIN_USER_PASSWORD_AUTH ALLOW_CUSTOM_AUTH ALLOW_REFRESH_TOKEN_AUTH ALLOW_USER_SRP_AUTH
    
    if [ $? -eq 0 ]; then
        echo "✅ Client updated successfully"
        echo ""
        echo "Updated auth flows:"
        aws cognito-idp describe-user-pool-client \
          --user-pool-id $USER_POOL_ID \
          --client-id $CLIENT_ID \
          --query 'UserPoolClient.ExplicitAuthFlows' \
          --output table
    else
        echo "❌ Failed to update client"
        echo "You may need additional permissions or the client might be managed by other resources"
    fi
fi

echo ""
echo "🚀 Next step: Run the complete setup script"
echo "./cognito-complete-setup.sh"