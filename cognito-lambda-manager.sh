#!/bin/bash
# Cognito Lambda Trigger Management
# Temporarily disable PostAuthentication trigger for testing

echo "🔧 Cognito Lambda Trigger Management"
echo "===================================="
echo ""

USER_POOL_ID="us-east-1_wzWpXwzR6"
REGION="us-east-1"

echo "Configuration:"
echo "  User Pool ID: $USER_POOL_ID"
echo "  Region: $REGION"
echo ""

# Check current Lambda triggers
echo "🔍 Step 1: Checking Current Lambda Triggers..."
echo "=============================================="

LAMBDA_CONFIG=$(aws cognito-idp describe-user-pool \
  --user-pool-id $USER_POOL_ID \
  --query 'UserPool.LambdaConfig' \
  --output json)

echo "Current Lambda triggers:"
echo "$LAMBDA_CONFIG" | jq -r '. | to_entries[] | "\(.key): \(.value)"'

echo ""

# Check if PostAuthentication trigger exists
POST_AUTH_LAMBDA=$(echo "$LAMBDA_CONFIG" | jq -r '.PostAuthentication // "null"')

if [ "$POST_AUTH_LAMBDA" != "null" ]; then
    echo "❌ PostAuthentication trigger found: $POST_AUTH_LAMBDA"
    echo ""
    echo "🔧 Step 2: Options to resolve..."
    echo "==============================="
    echo ""
    echo "Option A: Temporarily Remove Lambda Trigger (CLI)"
    echo "--------------------------------------------------"
    echo "This will remove ALL Lambda triggers temporarily for testing."
    echo ""
    read -p "Do you want to remove all Lambda triggers temporarily? (y/N): " remove_triggers
    
    if [[ $remove_triggers =~ ^[Yy]$ ]]; then
        echo ""
        echo "🗑️  Removing Lambda triggers..."
        
        # Update user pool to remove all Lambda triggers
        aws cognito-idp update-user-pool \
          --user-pool-id $USER_POOL_ID \
          --lambda-config '{}'
        
        if [ $? -eq 0 ]; then
            echo "✅ Lambda triggers removed successfully!"
            echo ""
            echo "🧪 Now test authentication again:"
            echo "./interactive-cognito-auth.sh"
            echo ""
            echo "📝 To restore triggers later, save this command:"
            echo "aws cognito-idp update-user-pool \\"
            echo "  --user-pool-id $USER_POOL_ID \\"
            echo "  --lambda-config '$LAMBDA_CONFIG'"
        else
            echo "❌ Failed to remove Lambda triggers via CLI"
            echo "You may need additional permissions or need to use the Console method"
        fi
    else
        echo ""
        echo "Option B: Manual Console Method (Recommended)"
        echo "--------------------------------------------"
        echo ""
        echo "📋 Step-by-step Console instructions:"
        echo ""
        echo "1. Open AWS Console: https://console.aws.amazon.com/cognito/"
        echo "2. Click 'User pools'"
        echo "3. Click on User Pool: $USER_POOL_ID"
        echo "4. In the left sidebar, click 'User pool properties'"
        echo "5. Click on 'Lambda triggers' tab"
        echo "6. Find 'PostAuthentication' trigger"
        echo "7. Click 'Edit' or the pencil icon"
        echo "8. Remove or clear the PostAuthentication Lambda function"
        echo "9. Click 'Save changes'"
        echo "10. Re-run: ./interactive-cognito-auth.sh"
        echo ""
        echo "🔄 After testing, you can restore the trigger the same way"
    fi
else
    echo "✅ No PostAuthentication trigger found (this shouldn't happen based on the error)"
fi

echo ""
echo "Option C: Fix Lambda Permissions (Alternative)"
echo "---------------------------------------------"
echo ""
echo "If you prefer to fix the Lambda function instead of removing it:"
echo ""
echo "1. Find the PostAuthentication Lambda function:"
echo "   Function ARN: $POST_AUTH_LAMBDA"
echo ""
echo "2. Check CloudWatch logs for the Lambda function:"
echo "   aws logs describe-log-groups --log-group-name-prefix '/aws/lambda/'"
echo ""
echo "3. Common permission issues and fixes:"
echo "   - Lambda execution role needs 'cognito-idp:*' permissions"
echo "   - Lambda needs CloudWatch logs permissions"
echo "   - Check if Lambda is trying to access other AWS services"
echo ""
echo "4. Check Lambda execution role:"
LAMBDA_NAME=$(echo "$POST_AUTH_LAMBDA" | cut -d':' -f6)
if [ ! -z "$LAMBDA_NAME" ]; then
    echo "   aws lambda get-function --function-name $LAMBDA_NAME --query 'Configuration.Role'"
fi

echo ""
echo "🚀 Recommended Next Steps:"
echo "========================="
echo ""
echo "For quickest testing:"
echo "1. Use Console method to temporarily remove PostAuthentication trigger"
echo "2. Run: ./interactive-cognito-auth.sh"
echo "3. Test your MCP gateway successfully"
echo "4. Fix Lambda permissions (if needed)"
echo "5. Restore PostAuthentication trigger"
echo ""
echo "Your authentication setup is perfect - just this Lambda trigger needs attention!"