#!/bin/bash
# Lambda Trigger Analysis - Understanding the Impact
# Better approach: Fix the trigger instead of removing it

echo "🔍 PostAuthentication Lambda Trigger Analysis"
echo "============================================="
echo ""

USER_POOL_ID="us-east-1_wzWpXwzR6"
REGION="us-east-1"

echo "🚨 Why Removing Lambda Trigger Could Be Problematic:"
echo "===================================================="
echo ""
echo "1. Business Logic Loss:"
echo "   - The trigger likely performs important post-login actions"
echo "   - Could handle user data initialization"
echo "   - Might manage permissions or group assignments"
echo "   - Could update user attributes or external systems"
echo ""
echo "2. Security Implications:"
echo "   - May enforce security policies"
echo "   - Could log authentication events"
echo "   - Might validate user status or compliance"
echo ""
echo "3. Integration Dependencies:"
echo "   - Other systems might depend on trigger actions"
echo "   - Could break downstream processes"
echo "   - Might affect user experience or functionality"
echo ""

echo "🔧 Better Approach: Fix the Lambda Trigger"
echo "=========================================="
echo ""

# Get detailed Lambda trigger information
echo "📋 Analyzing Current Lambda Trigger..."

LAMBDA_CONFIG=$(aws cognito-idp describe-user-pool \
  --user-pool-id $USER_POOL_ID \
  --query 'UserPool.LambdaConfig' \
  --output json 2>/dev/null)

if [ $? -eq 0 ] && [ "$LAMBDA_CONFIG" != "null" ]; then
    echo "Current Lambda triggers:"
    echo "$LAMBDA_CONFIG" | jq '.'
    
    # Extract PostAuthentication Lambda ARN
    POST_AUTH_LAMBDA=$(echo "$LAMBDA_CONFIG" | jq -r '.PostAuthentication // "null"')
    
    if [ "$POST_AUTH_LAMBDA" != "null" ]; then
        echo ""
        echo "🎯 PostAuthentication Lambda Details:"
        echo "   ARN: $POST_AUTH_LAMBDA"
        
        # Extract function name from ARN
        FUNCTION_NAME=$(echo "$POST_AUTH_LAMBDA" | cut -d':' -f6)
        echo "   Function Name: $FUNCTION_NAME"
        echo ""
        
        # Check Lambda function details
        echo "📊 Lambda Function Analysis:"
        echo "============================"
        
        FUNCTION_INFO=$(aws lambda get-function \
          --function-name "$FUNCTION_NAME" \
          --output json 2>/dev/null)
        
        if [ $? -eq 0 ]; then
            ROLE_ARN=$(echo "$FUNCTION_INFO" | jq -r '.Configuration.Role')
            RUNTIME=$(echo "$FUNCTION_INFO" | jq -r '.Configuration.Runtime')
            LAST_MODIFIED=$(echo "$FUNCTION_INFO" | jq -r '.Configuration.LastModified')
            
            echo "✅ Lambda function accessible:"
            echo "   Role: $ROLE_ARN"
            echo "   Runtime: $RUNTIME" 
            echo "   Last Modified: $LAST_MODIFIED"
            echo ""
            
            # Check Lambda execution role permissions
            echo "🔐 Checking Lambda Execution Role Permissions..."
            echo "==============================================="
            
            ROLE_NAME=$(echo "$ROLE_ARN" | cut -d'/' -f2)
            
            echo "Role Name: $ROLE_NAME"
            echo ""
            
            # Get attached policies
            echo "📋 Attached Policies:"
            aws iam list-attached-role-policies \
              --role-name "$ROLE_NAME" \
              --output table 2>/dev/null
            
            echo ""
            echo "📋 Inline Policies:"
            aws iam list-role-policies \
              --role-name "$ROLE_NAME" \
              --output table 2>/dev/null
            
        else
            echo "❌ Cannot access Lambda function details"
            echo "   You may not have lambda:GetFunction permissions"
        fi
        
        echo ""
        echo "🔍 Recent Lambda Errors:"
        echo "======================="
        
        # Check CloudWatch logs for recent errors
        LOG_GROUP="/aws/lambda/$FUNCTION_NAME"
        
        echo "Log Group: $LOG_GROUP"
        
        RECENT_ERRORS=$(aws logs filter-log-events \
          --log-group-name "$LOG_GROUP" \
          --start-time $(date -d '1 hour ago' +%s)000 \
          --filter-pattern 'ERROR' \
          --query 'events[?@.message != `null`].message' \
          --output text 2>/dev/null)
        
        if [ $? -eq 0 ] && [ -n "$RECENT_ERRORS" ]; then
            echo "Recent errors found:"
            echo "$RECENT_ERRORS"
        else
            echo "No recent errors found (or no access to logs)"
        fi
        
    fi
else
    echo "❌ Cannot access User Pool configuration"
fi

echo ""
echo "🛠️ Step-by-Step Lambda Fix Approach"
echo "==================================="
echo ""
echo "Instead of removing the trigger, let's fix it:"
echo ""
echo "Step 1: Check Lambda Function Code"
echo "---------------------------------"
echo "1. Go to AWS Console > Lambda"
echo "2. Find function: $FUNCTION_NAME"
echo "3. Check the code for:"
echo "   - What resources it's trying to access"
echo "   - What permissions it needs"
echo "   - What external services it calls"
echo ""

echo "Step 2: Fix Lambda Permissions"
echo "------------------------------"
echo "Common permissions needed for PostAuthentication:"
echo "• cognito-idp:AdminGetUser"
echo "• cognito-idp:AdminUpdateUserAttributes"  
echo "• cognito-idp:AdminAddUserToGroup"
echo "• logs:CreateLogGroup"
echo "• logs:CreateLogStream"
echo "• logs:PutLogEvents"
echo ""
echo "Add these to the Lambda execution role if missing."
echo ""

echo "Step 3: Test Lambda Function Directly"
echo "------------------------------------"
echo "Test the Lambda with a sample Cognito event:"
cat << 'EOF'

Sample test event for PostAuthentication trigger:
{
  "version": "1",
  "region": "us-east-1",
  "userPoolId": "us-east-1_wzWpXwzR6",
  "userName": "mcptest",
  "callerContext": {
    "awsRequestId": "test-request-id",
    "clientId": "57o30hpgrhrovfbe4tmnkrtv50"
  },
  "triggerSource": "PostAuthentication_Authentication",
  "request": {
    "userAttributes": {
      "email": "mcptest@example.com",
      "email_verified": "true"
    }
  },
  "response": {}
}
EOF

echo ""
echo "Step 4: Alternative Solutions (Without Removing Trigger)"
echo "========================================================="
echo ""
echo "Option A: Temporarily Bypass Trigger"
echo "-----------------------------------"
echo "1. Create a new test user pool without triggers"
echo "2. Test MCP gateway with the new pool"
echo "3. Fix original trigger without affecting production"
echo ""

echo "Option B: Use Different Authentication Flow"
echo "------------------------------------------"
echo "1. Try USER_SRP_AUTH instead of ADMIN_USER_PASSWORD_AUTH"
echo "2. This might bypass the PostAuthentication trigger"
echo ""

echo "Option C: Fix Gateway Authorization Instead"
echo "------------------------------------------"
echo "1. Reconfigure gateway to use IAM authentication"
echo "2. Bypass Cognito entirely for testing"
echo "3. Use AWS credentials instead of JWT tokens"
echo ""

echo "🎯 Recommended Next Steps:"
echo "========================="
echo ""
echo "1. First, try the IAM gateway test (safest approach):"
echo "   ./iam-gateway-test.sh"
echo ""
echo "2. If that fails, analyze the Lambda function:"
echo "   - Check Lambda logs for specific error details"
echo "   - Review Lambda execution role permissions"
echo "   - Test Lambda function directly"
echo ""
echo "3. Only consider removing trigger as LAST RESORT"
echo "   - And only after understanding what it does"
echo "   - And only temporarily for testing"
echo ""

echo "💡 Key Point:"
echo "============="
echo "The Lambda trigger is failing due to permissions, not because it's unnecessary."
echo "Fixing the permissions is safer than removing business logic."
echo ""
echo "Would you like me to create scripts to:"
echo "1. Test IAM authentication instead? (Recommended)"
echo "2. Analyze the Lambda function in detail?"
echo "3. Create a temporary test user pool for gateway testing?"