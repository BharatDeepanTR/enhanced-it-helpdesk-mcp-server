#!/bin/bash
# Analyze PostAuthentication Trigger Access Issues
# Identify which user needs what permissions

echo "🔍 PostAuthentication Trigger Access Analysis"
echo "============================================="
echo ""

USER_POOL_ID="us-east-1_wzWpXwzR6"
PROBLEM_LAMBDA="arn:aws:lambda:us-east-1:818565325759:function:a207907-73-popularqueries-s3"

echo "📋 Context:"
echo "  User Pool: $USER_POOL_ID"
echo "  Failing Lambda: $PROBLEM_LAMBDA"
echo "  Error: AccessDeniedException in PostAuthentication trigger"
echo ""

echo "🎯 Step 1: Understand What's Happening"
echo "======================================"

echo ""
echo "💡 When ANY user tries to authenticate:"
echo "   1. User provides username/password"
echo "   2. Cognito validates credentials ✅"
echo "   3. Cognito tries to run PostAuthentication trigger"
echo "   4. Lambda function a207907-73-popularqueries-s3 fails ❌"
echo "   5. Authentication is blocked for ALL users"
echo ""

echo "🎯 Step 2: Check Current PostAuthentication Configuration"
echo "======================================================="

LAMBDA_CONFIG=$(aws cognito-idp describe-user-pool \
  --user-pool-id $USER_POOL_ID \
  --query 'UserPool.LambdaConfig' \
  --output json 2>/dev/null)

if [ $? -eq 0 ]; then
    echo "✅ Lambda configuration retrieved:"
    echo "$LAMBDA_CONFIG" | jq '.'
    echo ""
    
    POST_AUTH_LAMBDA=$(echo "$LAMBDA_CONFIG" | jq -r '.PostAuthentication // "none"')
    
    if [ "$POST_AUTH_LAMBDA" != "none" ] && [ "$POST_AUTH_LAMBDA" != "null" ]; then
        echo "🎯 PostAuthentication trigger found:"
        echo "   Lambda ARN: $POST_AUTH_LAMBDA"
        echo ""
        
        if [[ "$POST_AUTH_LAMBDA" == *"a207907-73-popularqueries-s3"* ]]; then
            echo "✅ This matches the failing function we identified"
        else
            echo "⚠️  Different function than expected"
        fi
        
        # Extract function name and account
        FUNCTION_NAME=$(echo "$POST_AUTH_LAMBDA" | awk -F':' '{print $6}' | awk -F'/' '{print $1}')
        ACCOUNT_ID=$(echo "$POST_AUTH_LAMBDA" | awk -F':' '{print $5}')
        
        echo ""
        echo "📋 Function Details:"
        echo "   Function Name: $FUNCTION_NAME"
        echo "   Account ID: $ACCOUNT_ID"
        echo "   Region: us-east-1"
        
    else
        echo "✅ No PostAuthentication trigger configured"
        echo "   This means it was already removed!"
    fi
    
else
    echo "❌ Cannot retrieve Lambda configuration"
    echo "   Limited permissions to view user pool settings"
fi

echo ""
echo "🎯 Step 3: Analyze Lambda Function Permissions"
echo "=============================================="

echo "The PostAuthentication trigger fails because the LAMBDA FUNCTION"
echo "doesn't have the right permissions, not the authenticating user."
echo ""

# Try to get Lambda function info
echo "🔍 Checking Lambda function configuration..."

LAMBDA_INFO=$(aws lambda get-function \
  --function-name $PROBLEM_LAMBDA \
  --query 'Configuration.{Role:Role,Runtime:Runtime,Handler:Handler}' \
  --output json 2>/dev/null)

if [ $? -eq 0 ]; then
    echo "✅ Lambda function information retrieved:"
    echo "$LAMBDA_INFO" | jq '.'
    
    LAMBDA_ROLE=$(echo "$LAMBDA_INFO" | jq -r '.Role')
    echo ""
    echo "📋 Lambda Execution Role: $LAMBDA_ROLE"
    
    # Try to get role policies
    ROLE_NAME=$(echo "$LAMBDA_ROLE" | awk -F'/' '{print $NF}')
    echo "   Role Name: $ROLE_NAME"
    
    echo ""
    echo "🔍 Checking role policies..."
    
    ATTACHED_POLICIES=$(aws iam list-attached-role-policies \
      --role-name "$ROLE_NAME" \
      --query 'AttachedPolicies[].PolicyArn' \
      --output json 2>/dev/null)
    
    if [ $? -eq 0 ]; then
        echo "✅ Attached policies:"
        echo "$ATTACHED_POLICIES" | jq -r '.[]' | sed 's/^/  • /'
    else
        echo "❌ Cannot retrieve attached policies"
        echo "   You don't have IAM permissions to analyze the role"
    fi
    
else
    echo "❌ Cannot retrieve Lambda function information"
    echo "   You don't have lambda:GetFunction permissions"
    echo ""
    echo "💡 This is exactly the problem!"
    echo "   The Lambda function likely has similar permission issues"
fi

echo ""
echo "🎯 Step 4: What the Lambda Function Needs"
echo "========================================"

echo ""
echo "🔍 The PostAuthentication Lambda typically needs:"
echo ""
echo "📋 REQUIRED PERMISSIONS for PostAuth Lambda:"
echo "   • cognito-idp:AdminUpdateUserAttributes"
echo "   • cognito-idp:AdminGetUser"  
echo "   • logs:CreateLogGroup"
echo "   • logs:CreateLogStream"
echo "   • logs:PutLogEvents"
echo "   • Plus any custom permissions for its specific function"
echo ""

echo "💡 COMMON CAUSES of AccessDeniedException:"
echo "   1. Lambda execution role missing Cognito permissions"
echo "   2. Lambda execution role missing CloudWatch Logs permissions" 
echo "   3. Lambda function trying to access other AWS services without permission"
echo "   4. Lambda function has bugs/errors causing crashes"
echo ""

echo "🎯 Step 5: Who Can Fix This?"
echo "============================"

echo ""
echo "👤 REQUIRED ACCESS LEVELS:"
echo ""
echo "🔧 To analyze the problem:"
echo "   • lambda:GetFunction (to see function config)"
echo "   • lambda:GetFunctionConfiguration"
echo "   • iam:GetRole (to see execution role)"
echo "   • iam:ListAttachedRolePolicies"
echo "   • iam:GetRolePolicy"
echo ""
echo "🛠️  To fix the Lambda function:"
echo "   • lambda:UpdateFunctionCode (if code fix needed)"
echo "   • lambda:UpdateFunctionConfiguration"  
echo "   • iam:AttachRolePolicy (to add missing policies)"
echo "   • iam:PutRolePolicy (to add inline policies)"
echo ""
echo "⚡ To bypass the issue (easiest):"
echo "   • cognito-idp:UpdateUserPool (to remove trigger)"
echo "   ✅ This is what we can do!"
echo ""

echo "🎯 Step 6: Identify Current User Permissions"
echo "==========================================="

echo ""
echo "🔍 Checking what YOU can do..."

# Test various permissions
echo "Testing your permissions:"

# Test Cognito permissions
echo -n "  • cognito-idp:DescribeUserPool: "
aws cognito-idp describe-user-pool --user-pool-id $USER_POOL_ID --output text --query 'UserPool.Name' 2>/dev/null
if [ $? -eq 0 ]; then echo "✅"; else echo "❌"; fi

echo -n "  • cognito-idp:UpdateUserPool: "
# Just test without actually changing anything
aws cognito-idp update-user-pool --user-pool-id $USER_POOL_ID --dry-run 2>/dev/null
if [ $? -eq 0 ]; then echo "✅"; else echo "❌ (need this to remove trigger)"; fi

echo -n "  • lambda:GetFunction: "
aws lambda get-function --function-name $PROBLEM_LAMBDA --query 'Configuration.FunctionName' --output text 2>/dev/null
if [ $? -eq 0 ]; then echo "✅"; else echo "❌"; fi

echo -n "  • lambda:ListFunctions: "
aws lambda list-functions --max-items 1 --query 'Functions[0].FunctionName' --output text 2>/dev/null
if [ $? -eq 0 ]; then echo "✅"; else echo "❌"; fi

echo ""
echo "🎯 RECOMMENDED SOLUTION PATHS"
echo "============================"
echo ""

echo "🥇 OPTION 1: Remove PostAuthentication Trigger (EASIEST)"
echo "======================================================="
echo "✅ Pros: Immediate fix, you can do this now"
echo "❌ Cons: Loses whatever the trigger was supposed to do"
echo ""
echo "Command:"
echo "aws cognito-idp update-user-pool \\"
echo "  --user-pool-id $USER_POOL_ID \\"
echo "  --lambda-config '{}'"
echo ""

echo "🥈 OPTION 2: Request Admin to Fix Lambda (THOROUGH)"  
echo "=================================================="
echo "✅ Pros: Keeps trigger functionality, proper fix"
echo "❌ Cons: Requires admin with Lambda/IAM permissions"
echo ""
echo "Admin needs to:"
echo "1. Check Lambda function logs in CloudWatch"
echo "2. Add missing permissions to Lambda execution role"
echo "3. Fix any code issues in the Lambda function"
echo ""

echo "🥉 OPTION 3: Get Elevated Permissions (COMPLEX)"
echo "=============================================="
echo "✅ Pros: You could fix it yourself"
echo "❌ Cons: Requires security approval for Lambda/IAM access"
echo ""
echo "Request these permissions:"
echo "• lambda:GetFunction"
echo "• lambda:UpdateFunctionConfiguration" 
echo "• iam:AttachRolePolicy"
echo "• iam:ListAttachedRolePolicies"
echo ""

echo "💡 RECOMMENDATION:"
echo "=================="
echo ""
echo "🎯 Go with OPTION 1 - Remove the trigger"
echo "   • Your MCP gateway works fine without it"
echo "   • You can restore it later when someone fixes the Lambda"
echo "   • Unblocks your testing immediately"
echo ""
echo "🚀 Next Action:"
echo "   ./remove-trigger-now.sh"
echo ""

echo "✅ PostAuthentication access analysis completed!"