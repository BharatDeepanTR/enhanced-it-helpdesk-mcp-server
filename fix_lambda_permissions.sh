#!/bin/bash
# Fix Lambda Permissions for Agent Core Gateway
# Addresses: Access denied while invoking Lambda function error

set -e

echo "🔧 Fixing Lambda Permissions for Agent Core Gateway"
echo "=================================================="
echo ""

# Configuration
SERVICE_ROLE_NAME="a208194-askjulius-agentcore-gateway"
CALCULATOR_LAMBDA_ARN="arn:aws:lambda:us-east-1:818565325759:function:a208194-calculator-mcp-server"
AI_CALCULATOR_LAMBDA_ARN="arn:aws:lambda:us-east-1:818565325759:function:a208194-ai-bedrock-calculator-mcp-server"
APP_DETAILS_LAMBDA_ARN="arn:aws:lambda:us-east-1:818565325759:function:a208194-mcp-application-details-server"
REGION="us-east-1"

echo "📋 Configuration:"
echo "   Service Role: $SERVICE_ROLE_NAME"
echo "   Calculator Lambda: $CALCULATOR_LAMBDA_ARN"
echo "   AI Calculator Lambda: $AI_CALCULATOR_LAMBDA_ARN"
echo "   App Details Lambda: $APP_DETAILS_LAMBDA_ARN"
echo ""

# Step 1: Check current role policies
echo "🔍 Step 1: Checking current role policies..."
echo "============================================"

echo "Attached managed policies:"
aws iam list-attached-role-policies --role-name "$SERVICE_ROLE_NAME" --query 'AttachedPolicies[*].{PolicyName:PolicyName,PolicyArn:PolicyArn}' --output table

echo ""
echo "Inline policies:"
aws iam list-role-policies --role-name "$SERVICE_ROLE_NAME" --query 'PolicyNames' --output table

# Step 2: Update Lambda invoke policy
echo ""
echo "🛠️  Step 2: Updating Lambda invoke permissions..."
echo "=============================================="

# Create comprehensive Lambda invoke policy
cat > lambda-invoke-policy-fixed.json << EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "lambda:InvokeFunction"
            ],
            "Resource": [
                "$CALCULATOR_LAMBDA_ARN",
                "$AI_CALCULATOR_LAMBDA_ARN", 
                "$APP_DETAILS_LAMBDA_ARN"
            ]
        },
        {
            "Effect": "Allow",
            "Action": [
                "lambda:InvokeFunction"
            ],
            "Resource": [
                "arn:aws:lambda:us-east-1:818565325759:function:a208194-*"
            ]
        }
    ]
}
EOF

echo "Created comprehensive Lambda invoke policy"

# Apply the policy (this will overwrite existing LambdaInvokePolicy)
echo "Applying Lambda invoke policy to service role..."
aws iam put-role-policy \
    --role-name "$SERVICE_ROLE_NAME" \
    --policy-name "LambdaInvokePolicy" \
    --policy-document file://lambda-invoke-policy-fixed.json

echo "✅ Lambda invoke policy updated successfully"

# Step 3: Add resource-based permissions to Lambda functions
echo ""
echo "🔐 Step 3: Adding resource-based permissions to Lambda functions..."
echo "=================================================================="

# Function to add Lambda resource-based policy
add_lambda_permission() {
    local function_name=$1
    local statement_id=$2
    
    echo "Adding permission for function: $function_name"
    
    # Remove existing permission if it exists (ignore errors)
    aws lambda remove-permission \
        --function-name "$function_name" \
        --statement-id "$statement_id" 2>/dev/null || true
    
    # Add new permission
    aws lambda add-permission \
        --function-name "$function_name" \
        --statement-id "$statement_id" \
        --action lambda:InvokeFunction \
        --principal bedrock.amazonaws.com \
        --source-arn "arn:aws:bedrock-agentcore:$REGION:818565325759:gateway/*"
    
    echo "✅ Permission added for $function_name"
}

# Add permissions for all Lambda functions
add_lambda_permission "a208194-calculator-mcp-server" "AgentCoreGatewayInvoke"
add_lambda_permission "a208194-ai-bedrock-calculator-mcp-server" "AgentCoreGatewayInvoke" 
add_lambda_permission "a208194-mcp-application-details-server" "AgentCoreGatewayInvoke"

# Step 4: Verify permissions
echo ""
echo "🔍 Step 4: Verifying permissions..."
echo "================================="

echo "Service role policies after update:"
aws iam get-role-policy \
    --role-name "$SERVICE_ROLE_NAME" \
    --policy-name "LambdaInvokePolicy" \
    --query 'PolicyDocument'

echo ""
echo "Lambda resource-based policies:"
for function_name in "a208194-calculator-mcp-server" "a208194-ai-bedrock-calculator-mcp-server" "a208194-mcp-application-details-server"; do
    echo "Function: $function_name"
    aws lambda get-policy --function-name "$function_name" --query 'Policy' --output text 2>/dev/null | jq '.' 2>/dev/null || echo "No policy found or invalid JSON"
    echo ""
done

# Clean up temporary files
rm -f lambda-invoke-policy-fixed.json

echo ""
echo "📊 Summary of Changes:"
echo "===================="
echo "✅ Updated service role Lambda invoke permissions"
echo "✅ Added resource-based permissions to all Lambda functions"
echo "✅ Permissions now allow bedrock.amazonaws.com to invoke functions"
echo "✅ Source ARN restricted to your gateway ARN pattern"
echo ""
echo "🎯 Next Steps:"
echo "1. Wait 1-2 minutes for IAM permission propagation"
echo "2. Test the target again with your enterprise MCP client"
echo "3. The 'Access denied' error should now be resolved"
echo ""
echo "🚨 If the error persists:"
echo "1. Check CloudWatch logs for more detailed error messages"
echo "2. Verify the gateway service role ARN in the console"
echo "3. Ensure the Lambda functions are in the same region (us-east-1)"