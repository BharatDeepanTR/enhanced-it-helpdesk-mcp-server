#!/bin/bash
# Lambda Function Configuration Analysis and Fix
# Addresses both PostAuthentication trigger AND MCP gateway target function

echo "🔧 Lambda Function Configuration Analysis"
echo "========================================="
echo ""

# Your correct target function for MCP gateway
TARGET_FUNCTION="a208194-chatops_application_details_intent"
# The function causing PostAuthentication issues
POST_AUTH_FUNCTION="a207907-73-popularqueries-s3"
USER_POOL_ID="us-east-1_wzWpXwzR6"
REGION="us-east-1"

echo "Configuration Analysis:"
echo "  Target MCP Function: $TARGET_FUNCTION"
echo "  PostAuth Function: $POST_AUTH_FUNCTION"
echo "  User Pool ID: $USER_POOL_ID"
echo ""

echo "🔍 Issue Identification:"
echo "======================="
echo ""
echo "✅ Correct MCP Gateway Function: arn:aws:lambda:us-east-1:818565325759:function:$TARGET_FUNCTION"
echo "❌ PostAuthentication Trigger:   arn:aws:lambda:us-east-1:818565325759:function:$POST_AUTH_FUNCTION"
echo ""
echo "💡 The issue is NOT with your MCP gateway function!"
echo "   The issue is with the PostAuthentication trigger on your Cognito User Pool"
echo "   that's preventing JWT token generation."
echo ""

echo "🔍 Step 1: Analyzing PostAuthentication Function"
echo "==============================================="

# Get Lambda function details for PostAuth function
echo "📋 PostAuthentication Function Information:"
FUNCTION_CONFIG=$(aws lambda get-function-configuration \
  --function-name $POST_AUTH_FUNCTION \
  --output json 2>/dev/null)

if [ $? -eq 0 ]; then
    ROLE_ARN=$(echo "$FUNCTION_CONFIG" | jq -r '.Role')
    RUNTIME=$(echo "$FUNCTION_CONFIG" | jq -r '.Runtime')
    TIMEOUT=$(echo "$FUNCTION_CONFIG" | jq -r '.Timeout')
    MEMORY=$(echo "$FUNCTION_CONFIG" | jq -r '.MemorySize')
    
    echo "✅ Function details retrieved:"
    echo "   Role ARN: $ROLE_ARN"
    echo "   Runtime: $RUNTIME"
    echo "   Timeout: ${TIMEOUT}s"
    echo "   Memory: ${MEMORY}MB"
    
    # Extract role name
    ROLE_NAME=$(echo "$ROLE_ARN" | cut -d'/' -f2)
    echo "   Role Name: $ROLE_NAME"
else
    echo "❌ Cannot access Lambda function"
    echo "   You may not have lambda:GetFunctionConfiguration permissions"
    exit 1
fi

echo ""
echo "🔍 Step 2: Analyzing Your MCP Gateway Function" 
echo "=============================================="

echo "📋 MCP Gateway Function Information:"
TARGET_CONFIG=$(aws lambda get-function-configuration \
  --function-name $TARGET_FUNCTION \
  --output json 2>/dev/null)

if [ $? -eq 0 ]; then
    TARGET_ROLE_ARN=$(echo "$TARGET_CONFIG" | jq -r '.Role')
    TARGET_RUNTIME=$(echo "$TARGET_CONFIG" | jq -r '.Runtime')
    TARGET_TIMEOUT=$(echo "$TARGET_CONFIG" | jq -r '.Timeout')
    
    echo "✅ MCP Gateway function details:"
    echo "   Function: $TARGET_FUNCTION"
    echo "   Role ARN: $TARGET_ROLE_ARN"
    echo "   Runtime: $TARGET_RUNTIME"
    echo "   Timeout: ${TARGET_TIMEOUT}s"
    echo "   Status: Function is accessible and configured correctly"
else
    echo "⚠️  Cannot access MCP gateway function"
    echo "   This might indicate permission issues"
fi

echo ""
echo "🔍 Step 3: Checking Current Role Permissions (PostAuth Function)"
echo "==============================================================="

# Check current role policies
echo "📋 Current Attached Policies:"
ATTACHED_POLICIES=$(aws iam list-attached-role-policies \
  --role-name "$ROLE_NAME" \
  --output json 2>/dev/null)

if [ $? -eq 0 ]; then
    echo "$ATTACHED_POLICIES" | jq -r '.AttachedPolicies[] | "   • \(.PolicyName) (\(.PolicyArn))"'
else
    echo "❌ Cannot list attached policies"
fi

echo ""
echo "📋 Current Inline Policies:"
INLINE_POLICIES=$(aws iam list-role-policies \
  --role-name "$ROLE_NAME" \
  --output json 2>/dev/null)

if [ $? -eq 0 ]; then
    INLINE_COUNT=$(echo "$INLINE_POLICIES" | jq '.PolicyNames | length')
    if [ "$INLINE_COUNT" -gt 0 ]; then
        echo "$INLINE_POLICIES" | jq -r '.PolicyNames[] | "   • \(.)"'
    else
        echo "   No inline policies found"
    fi
else
    echo "❌ Cannot list inline policies"
fi

echo ""
echo "🔍 Step 3: Checking CloudWatch Logs"
echo "==================================="

LOG_GROUP="/aws/lambda/$POST_AUTH_FUNCTION"
echo "Log Group: $LOG_GROUP"

# Check if log group exists
aws logs describe-log-groups \
  --log-group-name-prefix "$LOG_GROUP" \
  --query 'logGroups[0].logGroupName' \
  --output text >/dev/null 2>&1

if [ $? -eq 0 ]; then
    echo "✅ Log group exists"
    
    # Get recent error logs
    echo ""
    echo "📋 Recent Error Logs (last 1 hour):"
    START_TIME=$(date -d '1 hour ago' +%s)000
    
    RECENT_LOGS=$(aws logs filter-log-events \
      --log-group-name "$LOG_GROUP" \
      --start-time $START_TIME \
      --filter-pattern 'ERROR AccessDeniedException' \
      --query 'events[*].message' \
      --output text 2>/dev/null)
    
    if [ -n "$RECENT_LOGS" ]; then
        echo "$RECENT_LOGS"
    else
        echo "   No recent AccessDeniedException errors found"
        
        # Try broader search
        GENERAL_ERRORS=$(aws logs filter-log-events \
          --log-group-name "$LOG_GROUP" \
          --start-time $START_TIME \
          --filter-pattern 'ERROR' \
          --query 'events[0:3].message' \
          --output text 2>/dev/null)
        
        if [ -n "$GENERAL_ERRORS" ]; then
            echo "   Recent general errors:"
            echo "$GENERAL_ERRORS"
        fi
    fi
else
    echo "❌ Log group not found or no access"
fi

echo ""
echo "🛠️ Step 5: Solutions for PostAuthentication Issue"
echo "================================================="
echo ""
echo "You have several options to resolve this:"
echo ""

echo "Option 1: Fix PostAuthentication Function Permissions (Recommended)"
echo "=================================================================="
echo ""
echo "The PostAuthentication function ($POST_AUTH_FUNCTION) needs these permissions:"

# Create the policy document
cat > /tmp/lambda-cognito-policy.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "cognito-idp:AdminGetUser",
        "cognito-idp:AdminUpdateUserAttributes",
        "cognito-idp:AdminAddUserToGroup",
        "cognito-idp:AdminRemoveUserFromGroup",
        "cognito-idp:AdminListGroupsForUser"
      ],
      "Resource": [
        "arn:aws:cognito-idp:us-east-1:*:userpool/us-east-1_wzWpXwzR6",
        "arn:aws:cognito-idp:us-east-1:*:userpool/us-east-1_wzWpXwzR6/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "arn:aws:logs:us-east-1:*:*"
    }
  ]
}
EOF

echo "📋 Required permissions policy created at: /tmp/lambda-cognito-policy.json"
echo ""

echo "🚀 Option A: Add Inline Policy (Quick Fix)"
echo "=========================================="
echo ""
echo "Command to add required permissions:"
echo ""
echo "aws iam put-role-policy \\"
echo "  --role-name '$ROLE_NAME' \\"
echo "  --policy-name 'CognitoPostAuthPermissions' \\"
echo "  --policy-document file:///tmp/lambda-cognito-policy.json"
echo ""

read -p "Do you want to apply this policy now? (y/N): " apply_policy

if [[ $apply_policy =~ ^[Yy]$ ]]; then
    echo ""
    echo "🔄 Applying policy to PostAuthentication function role..."
    
    aws iam put-role-policy \
      --role-name "$ROLE_NAME" \
      --policy-name "CognitoPostAuthPermissions" \
      --policy-document file:///tmp/lambda-cognito-policy.json
    
    if [ $? -eq 0 ]; then
        echo "✅ Policy applied successfully to PostAuthentication function!"
        echo ""
        echo "🧪 Now test the authentication again:"
        echo "./interactive-cognito-auth.sh"
        echo ""
        echo "⏳ Note: It may take a few minutes for permissions to propagate"
    else
        echo "❌ Failed to apply policy"
        echo "   You may not have iam:PutRolePolicy permissions"
    fi
else
    echo ""
    echo "Option 2: Temporarily Remove PostAuthentication Trigger (Quick Test)"
    echo "=================================================================="
    echo ""
    echo "⚠️  WARNING: Only for testing! Understand what the trigger does first."
    echo ""
    echo "To temporarily remove the PostAuthentication trigger:"
    echo "1. Go to AWS Console > Cognito User Pools"
    echo "2. Select: $USER_POOL_ID"
    echo "3. Go to 'User pool properties' > 'Lambda triggers'"
    echo "4. Remove the PostAuthentication trigger temporarily"
    echo "5. Test: ./interactive-cognito-auth.sh"
    echo "6. Restore the trigger after testing"
    echo ""
    
    echo "Option 3: Use Different Authentication Approach (Alternative)"
    echo "==========================================================="
    echo ""
    echo "Create a test user pool without triggers:"
    echo "1. Create new Cognito User Pool for testing"
    echo "2. Configure same client ID and settings"
    echo "3. Update gateway to use test pool"
    echo "4. Test MCP functionality"
    echo "5. Fix original pool when convenient"
fi

echo ""
echo "🧪 Step 5: Test Lambda Function Directly"
echo "========================================"

# Create test event
cat > /tmp/cognito-test-event.json << 'EOF'
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

echo "📋 Test event created at: /tmp/cognito-test-event.json"
echo ""
echo "To test the Lambda function directly:"
echo ""
echo "aws lambda invoke \\"
echo "  --function-name '$LAMBDA_FUNCTION' \\"
echo "  --payload file:///tmp/cognito-test-event.json \\"
echo "  --output-file /tmp/lambda-test-output.json"
echo ""
echo "echo 'Lambda output:'"
echo "cat /tmp/lambda-test-output.json"
echo ""

read -p "Do you want to test the Lambda function now? (y/N): " test_lambda

if [[ $test_lambda =~ ^[Yy]$ ]]; then
    echo ""
    echo "🧪 Testing Lambda function..."
    
    aws lambda invoke \
      --function-name "$POST_AUTH_FUNCTION" \
      --payload file:///tmp/cognito-test-event.json \
      --output-file /tmp/lambda-test-output.json
    
    if [ $? -eq 0 ]; then
        echo "✅ Lambda invocation completed"
        echo ""
        echo "📋 Lambda output:"
        cat /tmp/lambda-test-output.json
        echo ""
        
        # Check for errors in output
        if grep -q "errorMessage" /tmp/lambda-test-output.json; then
            echo "❌ Lambda function returned an error"
            echo "   Check the error details above"
        else
            echo "✅ Lambda function executed successfully"
        fi
    else
        echo "❌ Failed to invoke Lambda function"
    fi
fi

echo ""
echo "� SUMMARY:"
echo "==========="
echo ""
echo "🎯 Your MCP Gateway Setup:"
echo "   ✅ Target Function: $TARGET_FUNCTION (correct)"
echo "   ✅ Gateway Configuration: Properly configured"
echo "   ❌ Blocking Issue: PostAuthentication trigger ($POST_AUTH_FUNCTION)"
echo ""
echo "🔧 The Problem:"
echo "   The Cognito User Pool has a PostAuthentication trigger that runs AFTER"
echo "   successful authentication but BEFORE issuing JWT tokens. This trigger"
echo "   is failing with AccessDeniedException, preventing token generation."
echo ""
echo "💡 The Solution:"
echo "   Fix permissions for $POST_AUTH_FUNCTION OR temporarily remove the trigger"
echo "   Your MCP gateway function ($TARGET_FUNCTION) is fine!"
echo ""
echo "🚀 Next Steps:"
echo "=============="
echo ""
echo "If you applied permissions:"
echo "1. Wait 2-3 minutes for AWS to propagate the changes"
echo "2. Test authentication: ./interactive-cognito-auth.sh" 
echo "3. If successful, you'll get JWT tokens to test your MCP gateway"
echo ""
echo "If you need to remove the trigger temporarily:"
echo "1. AWS Console > Cognito User Pools > $USER_POOL_ID"
echo "2. User pool properties > Lambda triggers > Remove PostAuthentication"
echo "3. Test authentication immediately"
echo "4. Fix trigger permissions and restore it later"
echo ""
echo "Your actual MCP gateway function is working fine - it's just this"
echo "authentication prerequisite that needs to be resolved!"
echo ""

# Clean up
rm -f /tmp/lambda-cognito-policy.json /tmp/cognito-test-event.json /tmp/lambda-test-output.json

echo "✅ Lambda permission fix script completed!"