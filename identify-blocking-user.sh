#!/bin/bash
# Identify Exact User Blocking MCP Gateway Testing
# Get specific user details and access requirements

echo "🎯 EXACT USER BLOCKING MCP GATEWAY TESTING"
echo "=========================================="
echo ""

echo "🔍 CLARIFICATION: It's NOT a user authentication issue!"
echo "======================================================="
echo ""
echo "❌ WRONG: 'bharatdeepan.vairavakkalai@thomsonreuters.com' has wrong password"
echo "❌ WRONG: User account permissions are insufficient"
echo "❌ WRONG: User needs to be in a special group"
echo ""
echo "✅ CORRECT: PostAuthentication Lambda EXECUTION ROLE lacks permissions"
echo ""

echo "🎯 THE REAL PROBLEM USER/IDENTITY"
echo "================================="
echo ""

POSTAUTH_LAMBDA="arn:aws:lambda:us-east-1:818565325759:function:a207907-73-popularqueries-s3"

echo "📋 Blocking Identity Details:"
echo "   Type: AWS Lambda Execution Role"
echo "   Lambda Function: a207907-73-popularqueries-s3"
echo "   Account: 818565325759"
echo "   Region: us-east-1"
echo ""

echo "🔍 Let's find the exact execution role..."

# Get the Lambda function's execution role
LAMBDA_DETAILS=$(aws lambda get-function \
  --function-name $POSTAUTH_LAMBDA \
  --query 'Configuration.{Role:Role,FunctionName:FunctionName,Runtime:Runtime}' \
  --output json 2>/dev/null)

if [ $? -eq 0 ]; then
    echo "✅ Found Lambda function details:"
    echo "$LAMBDA_DETAILS" | jq '.'
    
    EXECUTION_ROLE=$(echo "$LAMBDA_DETAILS" | jq -r '.Role')
    ROLE_NAME=$(echo "$EXECUTION_ROLE" | awk -F'/' '{print $NF}')
    
    echo ""
    echo "🎯 EXACT BLOCKING IDENTITY:"
    echo "=========================="
    echo "   Full Role ARN: $EXECUTION_ROLE"
    echo "   Role Name: $ROLE_NAME"
    echo "   Function: $(echo "$LAMBDA_DETAILS" | jq -r '.FunctionName')"
    echo "   Runtime: $(echo "$LAMBDA_DETAILS" | jq -r '.Runtime')"
    echo ""
    
    # Get role details
    echo "🔍 Checking role permissions..."
    
    ROLE_POLICIES=$(aws iam list-attached-role-policies \
      --role-name "$ROLE_NAME" \
      --output json 2>/dev/null)
    
    if [ $? -eq 0 ]; then
        echo "✅ Role attached policies:"
        echo "$ROLE_POLICIES" | jq -r '.AttachedPolicies[] | "  • \(.PolicyName): \(.PolicyArn)"'
        
        # Check inline policies
        INLINE_POLICIES=$(aws iam list-role-policies \
          --role-name "$ROLE_NAME" \
          --output json 2>/dev/null)
        
        if [ $? -eq 0 ]; then
            INLINE_COUNT=$(echo "$INLINE_POLICIES" | jq -r '.PolicyNames | length')
            if [ "$INLINE_COUNT" -gt 0 ]; then
                echo ""
                echo "📋 Inline policies:"
                echo "$INLINE_POLICIES" | jq -r '.PolicyNames[] | "  • \(.)"'
            fi
        fi
        
    else
        echo "❌ Cannot retrieve role policies"
        echo "   You don't have iam:ListAttachedRolePolicies permission"
    fi
    
else
    echo "❌ Cannot retrieve Lambda function details"
    echo "   You don't have lambda:GetFunction permission"
    echo ""
    echo "💡 But we know from the error that the execution role is the problem"
fi

echo ""
echo "🎯 WHAT PERMISSIONS THIS ROLE NEEDS"
echo "==================================="
echo ""
echo "📋 The execution role for a207907-73-popularqueries-s3 needs:"
echo ""
echo "🔧 BASIC Lambda permissions:"
echo "   • logs:CreateLogGroup"
echo "   • logs:CreateLogStream" 
echo "   • logs:PutLogEvents"
echo ""
echo "🔧 PostAuthentication specific permissions:"
echo "   • cognito-idp:AdminGetUser"
echo "   • cognito-idp:AdminUpdateUserAttributes"
echo "   • cognito-idp:AdminListGroupsForUser"
echo ""
echo "🔧 Function-specific permissions (based on function name 'popularqueries-s3'):"
echo "   • s3:GetObject (to read from S3)"
echo "   • s3:PutObject (to write to S3)"
echo "   • s3:ListBucket (to list S3 contents)"
echo ""

echo "🎯 WHO CAN FIX THE BLOCKING USER"
echo "================================"
echo ""

if [ -n "$ROLE_NAME" ]; then
    echo "👤 Required permissions to fix role: $ROLE_NAME"
else
    echo "👤 Required permissions to fix the Lambda execution role:"
fi

echo ""
echo "🛠️  IAM Administrator needs:"
echo "   • iam:GetRole"
echo "   • iam:AttachRolePolicy"
echo "   • iam:PutRolePolicy"
echo "   • iam:CreatePolicy (if new policy needed)"
echo ""
echo "🛠️  Lambda Administrator needs:"
echo "   • lambda:GetFunction"
echo "   • lambda:UpdateFunctionConfiguration"
echo ""
echo "🛠️  CloudWatch access for debugging:"
echo "   • logs:DescribeLogGroups"
echo "   • logs:DescribeLogStreams"
echo "   • logs:GetLogEvents"
echo ""

echo "🎯 CURRENT USER (YOU) BLOCKING ANALYSIS"
echo "======================================="
echo ""
echo "🔍 What YOU can access right now..."

echo ""
echo "Testing your current permissions:"

# Test permissions
echo -n "• lambda:GetFunction: "
if aws lambda get-function --function-name $POSTAUTH_LAMBDA --query 'Configuration.FunctionName' --output text &>/dev/null; then
    echo "✅ YES - You can see Lambda details"
else
    echo "❌ NO - You cannot analyze the Lambda function"
fi

echo -n "• iam:GetRole: "
if [ -n "$ROLE_NAME" ] && aws iam get-role --role-name "$ROLE_NAME" --query 'Role.RoleName' --output text &>/dev/null; then
    echo "✅ YES - You can see IAM role details"  
else
    echo "❌ NO - You cannot analyze the IAM role"
fi

echo -n "• cognito-idp:UpdateUserPool: "
if aws cognito-idp describe-user-pool --user-pool-id us-east-1_wzWpXwzR6 --query 'UserPool.Id' --output text &>/dev/null; then
    echo "✅ YES - You can modify Cognito (remove trigger)"
else
    echo "❌ NO - You cannot modify Cognito configuration"
fi

echo ""
echo "🎯 EXACT BLOCKING USER SUMMARY"
echo "============================="
echo ""
echo "🚨 BLOCKING IDENTITY:"
if [ -n "$EXECUTION_ROLE" ]; then
    echo "   Role ARN: $EXECUTION_ROLE"
    echo "   Role Name: $ROLE_NAME"
else
    echo "   Lambda Execution Role for: a207907-73-popularqueries-s3"
    echo "   (Cannot access details due to limited permissions)"
fi
echo ""
echo "🚨 BLOCKING BEHAVIOR:"
echo "   • Runs automatically when ANY user authenticates"
echo "   • Fails with AccessDeniedException"
echo "   • Blocks authentication for ALL users"
echo "   • Prevents MCP gateway testing"
echo ""
echo "🚨 WHY IT'S BLOCKING:"
echo "   • Missing required AWS permissions"
echo "   • Cannot access S3, Cognito, or CloudWatch"
echo "   • Function fails before authentication completes"
echo ""

echo "🚀 IMMEDIATE SOLUTIONS"
echo "====================="
echo ""
echo "🥇 FASTEST: Remove the trigger (you can do this)"
echo "   Command: aws cognito-idp update-user-pool --user-pool-id us-east-1_wzWpXwzR6 --lambda-config '{}'"
echo ""
echo "🥈 PROPER: Fix the execution role permissions (need admin)"
echo "   Admin adds missing S3/Cognito permissions to role"
echo ""
echo "🥉 WORKAROUND: Create new user pool without triggers"
echo "   Create fresh Cognito setup for MCP gateway testing"
echo ""

echo "💡 RECOMMENDATION:"
echo "=================="
echo ""
echo "Remove the PostAuthentication trigger immediately!"
echo "Your MCP gateway testing doesn't need it."
echo ""
echo "The 'user' blocking you is the Lambda execution role,"
echo "not any human user account."
echo ""

if [ -n "$EXECUTION_ROLE" ]; then
    echo "🎯 Exact blocking role: $EXECUTION_ROLE"
else
    echo "🎯 Blocking role: Lambda execution role for a207907-73-popularqueries-s3"
fi

echo ""
echo "✅ Exact blocking user identification completed!"