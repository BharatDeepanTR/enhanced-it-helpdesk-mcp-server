#!/bin/bash
# Admin Guide: Fix PostAuthentication Lambda Execution Role
# Complete steps for admin to resolve AccessDeniedException

echo "👨‍💼 ADMIN GUIDE: Fix PostAuthentication Lambda Permissions"
echo "=========================================================="
echo ""

LAMBDA_ARN="arn:aws:lambda:us-east-1:818565325759:function:a207907-73-popularqueries-s3"
USER_POOL_ID="us-east-1_wzWpXwzR6"

echo "📋 ISSUE SUMMARY:"
echo "================"
echo "• Lambda Function: a207907-73-popularqueries-s3"
echo "• Error: AccessDeniedException in PostAuthentication trigger"
echo "• Impact: ALL users cannot authenticate to Cognito User Pool"
echo "• Result: MCP Gateway testing is blocked"
echo ""

echo "🎯 ADMIN REQUIRED PERMISSIONS:"
echo "=============================="
echo "The admin performing this fix needs:"
echo "• lambda:GetFunction"
echo "• lambda:GetFunctionConfiguration"
echo "• iam:GetRole"
echo "• iam:ListAttachedRolePolicies"
echo "• iam:AttachRolePolicy"
echo "• iam:CreatePolicy (if new policy needed)"
echo "• logs:DescribeLogGroups"
echo "• logs:DescribeLogStreams"
echo "• logs:GetLogEvents"
echo ""

echo "🔍 STEP 1: Diagnose the Lambda Function"
echo "======================================="
echo ""
echo "1.1 Get Lambda function details:"
echo ""
cat << 'EOF'
aws lambda get-function \
  --function-name a207907-73-popularqueries-s3 \
  --query 'Configuration.{Role:Role,Runtime:Runtime,Handler:Handler,Environment:Environment}'
EOF

echo ""
echo "1.2 Get the execution role name:"
echo ""
cat << 'EOF'
LAMBDA_ROLE=$(aws lambda get-function \
  --function-name a207907-73-popularqueries-s3 \
  --query 'Configuration.Role' --output text)

ROLE_NAME=$(echo $LAMBDA_ROLE | awk -F'/' '{print $NF}')
echo "Execution Role: $ROLE_NAME"
EOF

echo ""
echo "🔍 STEP 2: Check Current Role Permissions"
echo "========================================"
echo ""
echo "2.1 List attached managed policies:"
echo ""
cat << 'EOF'
aws iam list-attached-role-policies \
  --role-name $ROLE_NAME
EOF

echo ""
echo "2.2 List inline policies:"
echo ""
cat << 'EOF'
aws iam list-role-policies \
  --role-name $ROLE_NAME
EOF

echo ""
echo "2.3 Get policy details for each attached policy:"
echo ""
cat << 'EOF'
for policy_arn in $(aws iam list-attached-role-policies \
  --role-name $ROLE_NAME \
  --query 'AttachedPolicies[].PolicyArn' \
  --output text); do
  
  echo "Policy: $policy_arn"
  
  # Get policy version
  VERSION=$(aws iam get-policy --policy-arn $policy_arn \
    --query 'Policy.DefaultVersionId' --output text)
  
  # Get policy document
  aws iam get-policy-version \
    --policy-arn $policy_arn \
    --version-id $VERSION \
    --query 'PolicyVersion.Document'
done
EOF

echo ""
echo "🔍 STEP 3: Check Lambda Function Logs"
echo "====================================="
echo ""
echo "3.1 Find the log group:"
echo ""
cat << 'EOF'
LOG_GROUP="/aws/lambda/a207907-73-popularqueries-s3"
aws logs describe-log-groups \
  --log-group-name-prefix $LOG_GROUP
EOF

echo ""
echo "3.2 Get recent error logs:"
echo ""
cat << 'EOF'
# Get latest log stream
LATEST_STREAM=$(aws logs describe-log-streams \
  --log-group-name $LOG_GROUP \
  --order-by LastEventTime \
  --descending \
  --max-items 1 \
  --query 'logStreams[0].logStreamName' \
  --output text)

echo "Latest log stream: $LATEST_STREAM"

# Get recent log events
aws logs get-log-events \
  --log-group-name $LOG_GROUP \
  --log-stream-name $LATEST_STREAM \
  --start-time $(date -d '1 hour ago' +%s)000 \
  --query 'events[?contains(message, `ERROR`) || contains(message, `AccessDenied`) || contains(message, `Exception`)].message'
EOF

echo ""
echo "🛠️ STEP 4: Fix Missing Permissions"
echo "=================================="
echo ""
echo "4.1 Create comprehensive policy for PostAuthentication Lambda:"
echo ""

cat << 'EOF'
# Create policy document
cat > /tmp/postauth-lambda-policy.json << 'POLICY_EOF'
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "CloudWatchLogs",
            "Effect": "Allow",
            "Action": [
                "logs:CreateLogGroup",
                "logs:CreateLogStream",
                "logs:PutLogEvents",
                "logs:DescribeLogGroups",
                "logs:DescribeLogStreams"
            ],
            "Resource": [
                "arn:aws:logs:us-east-1:818565325759:log-group:/aws/lambda/a207907-73-popularqueries-s3",
                "arn:aws:logs:us-east-1:818565325759:log-group:/aws/lambda/a207907-73-popularqueries-s3:*"
            ]
        },
        {
            "Sid": "CognitoUserPoolAccess",
            "Effect": "Allow",
            "Action": [
                "cognito-idp:AdminGetUser",
                "cognito-idp:AdminUpdateUserAttributes",
                "cognito-idp:AdminSetUserSettings",
                "cognito-idp:AdminListGroupsForUser",
                "cognito-idp:AdminAddUserToGroup"
            ],
            "Resource": [
                "arn:aws:cognito-idp:us-east-1:818565325759:userpool/us-east-1_wzWpXwzR6"
            ]
        },
        {
            "Sid": "S3Access",
            "Effect": "Allow",
            "Action": [
                "s3:GetObject",
                "s3:PutObject",
                "s3:ListBucket",
                "s3:GetBucketLocation"
            ],
            "Resource": [
                "arn:aws:s3:::*popularqueries*",
                "arn:aws:s3:::*popularqueries*/*",
                "arn:aws:s3:::*popular-queries*",
                "arn:aws:s3:::*popular-queries*/*"
            ]
        },
        {
            "Sid": "DynamoDBAccess",
            "Effect": "Allow",
            "Action": [
                "dynamodb:GetItem",
                "dynamodb:PutItem",
                "dynamodb:UpdateItem",
                "dynamodb:Query",
                "dynamodb:Scan"
            ],
            "Resource": [
                "arn:aws:dynamodb:us-east-1:818565325759:table/*popular*",
                "arn:aws:dynamodb:us-east-1:818565325759:table/*queries*"
            ]
        }
    ]
}
POLICY_EOF
EOF

echo ""
echo "4.2 Create and attach the policy:"
echo ""
cat << 'EOF'
# Create the policy
aws iam create-policy \
  --policy-name PostAuthLambdaComprehensivePolicy \
  --policy-document file:///tmp/postauth-lambda-policy.json

# Get the policy ARN
POLICY_ARN="arn:aws:iam::818565325759:policy/PostAuthLambdaComprehensivePolicy"

# Attach to the Lambda role
aws iam attach-role-policy \
  --role-name $ROLE_NAME \
  --policy-arn $POLICY_ARN

echo "✅ Policy attached successfully"
EOF

echo ""
echo "🛠️ STEP 5: Alternative - Add Inline Policy"
echo "=========================================="
echo ""
echo "If managed policy approach doesn't work, add inline policy:"
echo ""
cat << 'EOF'
aws iam put-role-policy \
  --role-name $ROLE_NAME \
  --policy-name PostAuthInlinePolicy \
  --policy-document file:///tmp/postauth-lambda-policy.json

echo "✅ Inline policy added successfully"
EOF

echo ""
echo "🧪 STEP 6: Test the Fix"
echo "======================"
echo ""
echo "6.1 Test Lambda function directly:"
echo ""
cat << 'EOF'
# Create test event for PostAuthentication
cat > /tmp/test-event.json << 'TEST_EOF'
{
    "version": "1",
    "region": "us-east-1",
    "userPoolId": "us-east-1_wzWpXwzR6",
    "userName": "testuser",
    "callerContext": {
        "awsRequestId": "test-request-id",
        "client": "57o30hpgrhrovfbe4tmnkrtv50"
    },
    "triggerSource": "PostAuthentication_Authentication",
    "request": {
        "userAttributes": {
            "email": "test@example.com",
            "email_verified": "true"
        },
        "newDeviceUsed": false,
        "clientMetadata": {}
    },
    "response": {}
}
TEST_EOF

# Invoke the function
aws lambda invoke \
  --function-name a207907-73-popularqueries-s3 \
  --payload file:///tmp/test-event.json \
  --output json \
  /tmp/lambda-response.json

# Check the response
cat /tmp/lambda-response.json
EOF

echo ""
echo "6.2 Test Cognito authentication:"
echo ""
cat << 'EOF'
# Test with a simple user
aws cognito-idp admin-create-user \
  --user-pool-id us-east-1_wzWpXwzR6 \
  --username admintest \
  --temporary-password "TempPass123!" \
  --message-action SUPPRESS

aws cognito-idp admin-set-user-password \
  --user-pool-id us-east-1_wzWpXwzR6 \
  --username admintest \
  --password "AdminTest123!" \
  --permanent

# Test authentication (will trigger PostAuthentication)
# This should now work without AccessDeniedException
EOF

echo ""
echo "🔍 STEP 7: Monitor and Verify"
echo "============================"
echo ""
echo "7.1 Check CloudWatch logs after fix:"
echo ""
cat << 'EOF'
# Wait a few minutes after testing, then check logs
aws logs get-log-events \
  --log-group-name /aws/lambda/a207907-73-popularqueries-s3 \
  --log-stream-name $LATEST_STREAM \
  --start-time $(date -d '10 minutes ago' +%s)000 \
  --query 'events[].message'
EOF

echo ""
echo "7.2 Verify no more AccessDenied errors:"
echo ""
cat << 'EOF'
# Should return empty or no ERROR messages
aws logs filter-log-events \
  --log-group-name /aws/lambda/a207907-73-popularqueries-s3 \
  --filter-pattern "ERROR AccessDenied" \
  --start-time $(date -d '5 minutes ago' +%s)000
EOF

echo ""
echo "📋 STEP 8: Notify User"
echo "====================="
echo ""
echo "After successful fix, notify the user:"
echo ""
echo "✅ PostAuthentication Lambda permissions fixed"
echo "✅ Users can now authenticate to Cognito"
echo "✅ MCP Gateway testing can proceed"
echo ""
echo "User should test with:"
echo "./simple-auth-test.sh"
echo ""

echo "🚨 TROUBLESHOOTING"
echo "=================="
echo ""
echo "If the fix doesn't work:"
echo ""
echo "1. Check Lambda function code for other permission requirements"
echo "2. Verify the function isn't trying to access resources outside the policy"
echo "3. Check if the function has environment variables pointing to other resources"
echo "4. Review the complete error stack trace in CloudWatch logs"
echo "5. Consider temporarily disabling the trigger if fix is complex"
echo ""

echo "🔄 ROLLBACK PLAN"
echo "================"
echo ""
echo "If something goes wrong:"
echo ""
cat << 'EOF'
# Remove the new policy
aws iam detach-role-policy \
  --role-name $ROLE_NAME \
  --policy-arn $POLICY_ARN

# Or remove inline policy
aws iam delete-role-policy \
  --role-name $ROLE_NAME \
  --policy-name PostAuthInlinePolicy
EOF

echo ""
echo "📞 ESCALATION"
echo "============="
echo ""
echo "If admin needs help:"
echo "• AWS Support case with Lambda/IAM team"
echo "• Internal security team for policy review"
echo "• Lambda function owner/developer for code analysis"
echo ""

echo "✅ Admin guide completed!"
echo ""
echo "📋 SUMMARY FOR ADMIN:"
echo "• The PostAuthentication Lambda needs proper S3/Cognito permissions"
echo "• Create comprehensive policy covering all required services"
echo "• Test with Lambda invoke and Cognito authentication"
echo "• Monitor CloudWatch logs to verify fix"
echo "• This will unblock MCP Gateway testing for all users"