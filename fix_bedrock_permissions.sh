#!/bin/bash
# Fix Lambda Execution Role Bedrock Permissions
# Addresses: "Access denied to Bedrock model" error

set -e

echo "🔧 Fixing Lambda Execution Role Bedrock Permissions"
echo "=================================================="
echo ""

# Configuration
LAMBDA_FUNCTION="a208194-ai-bedrock-calculator-mcp-server"
LAMBDA_EXECUTION_ROLE="a208194-julius-search-LambdaExecutionRole"
REGION="us-east-1"

echo "📋 Configuration:"
echo "   Lambda Function: $LAMBDA_FUNCTION"
echo "   Execution Role: $LAMBDA_EXECUTION_ROLE"
echo "   Region: $REGION"
echo ""

# Step 1: Check current role policies
echo "🔍 Step 1: Checking current execution role policies..."
echo "===================================================="

echo "Attached managed policies:"
aws iam list-attached-role-policies --role-name "$LAMBDA_EXECUTION_ROLE" --query 'AttachedPolicies[*].{PolicyName:PolicyName,PolicyArn:PolicyArn}' --output table

echo ""
echo "Inline policies:"
aws iam list-role-policies --role-name "$LAMBDA_EXECUTION_ROLE" --query 'PolicyNames' --output table

# Step 2: Add Bedrock permissions
echo ""
echo "🛠️  Step 2: Adding Bedrock model permissions..."
echo "=============================================="

# Check if BedrockFullAccess is already attached
BEDROCK_ATTACHED=$(aws iam list-attached-role-policies --role-name "$LAMBDA_EXECUTION_ROLE" --query 'AttachedPolicies[?contains(PolicyArn, `AmazonBedrockFullAccess`)].PolicyName' --output text)

if [ -n "$BEDROCK_ATTACHED" ]; then
    echo "✅ AmazonBedrockFullAccess already attached"
else
    echo "Attaching AmazonBedrockFullAccess policy..."
    aws iam attach-role-policy \
        --role-name "$LAMBDA_EXECUTION_ROLE" \
        --policy-arn "arn:aws:iam::aws:policy/AmazonBedrockFullAccess"
    echo "✅ AmazonBedrockFullAccess policy attached"
fi

# Step 3: Create specific Bedrock invoke policy
echo ""
echo "🔧 Step 3: Creating specific Bedrock model invoke policy..."
echo "========================================================"

cat > bedrock-model-invoke-policy.json << 'EOF'
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "bedrock:InvokeModel",
                "bedrock:InvokeModelWithResponseStream"
            ],
            "Resource": [
                "arn:aws:bedrock:us-east-1::foundation-model/anthropic.claude-3-sonnet-20240229-v1:0",
                "arn:aws:bedrock:us-east-1::foundation-model/anthropic.claude-3-haiku-20240307-v1:0",
                "arn:aws:bedrock:us-east-1::foundation-model/anthropic.claude-v2:1",
                "arn:aws:bedrock:us-east-1::foundation-model/anthropic.claude-v2",
                "arn:aws:bedrock:us-east-1::foundation-model/anthropic.claude-instant-v1"
            ]
        }
    ]
}
EOF

echo "Created specific Bedrock model invoke policy"

# Apply the policy (this will overwrite existing BedrockModelInvokePolicy if it exists)
echo "Applying Bedrock model invoke policy to Lambda execution role..."
aws iam put-role-policy \
    --role-name "$LAMBDA_EXECUTION_ROLE" \
    --policy-name "BedrockModelInvokePolicy" \
    --policy-document file://bedrock-model-invoke-policy.json

echo "✅ Bedrock model invoke policy applied successfully"

# Step 4: Verify permissions
echo ""
echo "🔍 Step 4: Verifying permissions..."
echo "================================="

echo "Lambda execution role policies after update:"
echo ""
echo "Attached managed policies:"
aws iam list-attached-role-policies --role-name "$LAMBDA_EXECUTION_ROLE" --query 'AttachedPolicies[*].{PolicyName:PolicyName,PolicyArn:PolicyArn}' --output table

echo ""
echo "Inline policies:"
aws iam list-role-policies --role-name "$LAMBDA_EXECUTION_ROLE" --query 'PolicyNames' --output table

echo ""
echo "BedrockModelInvokePolicy details:"
aws iam get-role-policy \
    --role-name "$LAMBDA_EXECUTION_ROLE" \
    --policy-name "BedrockModelInvokePolicy" \
    --query 'PolicyDocument'

# Clean up temporary files
rm -f bedrock-model-invoke-policy.json

echo ""
echo "📊 Summary of Changes:"
echo "===================="
echo "✅ Verified/Added AmazonBedrockFullAccess managed policy"
echo "✅ Created BedrockModelInvokePolicy for specific model access"
echo "✅ Lambda execution role now has Bedrock model invoke permissions"
echo "✅ Supports Claude models: Sonnet, Haiku, Claude v2, Claude Instant"
echo ""
echo "🧪 Test the Lambda function:"
echo "=============================="
echo "The Lambda should now be able to invoke Bedrock models successfully."
echo ""
echo "🎯 Next Steps:"
echo "1. Wait 1-2 minutes for IAM permission propagation"
echo "2. Test the Lambda function again"
echo "3. The 'Access denied to Bedrock model' error should be resolved"
echo "4. Test with your enterprise MCP client"
echo ""
echo "🔧 Test Command:"
echo "python3 test_permission_fix.py"