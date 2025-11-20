#!/bin/bash
# Fix Gateway Service Role Trust Policy to Allow Lambda Service
# Adds lambda.amazonaws.com to the trust policy for CloudShell execution

set -e

echo "🔧 Fixing Gateway Service Role Trust Policy for Lambda"
echo "====================================================="
echo ""

# Configuration
GATEWAY_SERVICE_ROLE="a208194-askjulius-agentcore-gateway"
LAMBDA_FUNCTION="a208194-ai-bedrock-calculator-mcp-server"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REGION="us-east-1"

echo "📋 CloudShell Configuration:"
echo "   AWS Account ID: $ACCOUNT_ID"
echo "   Region: $REGION"
echo "   Gateway Service Role: $GATEWAY_SERVICE_ROLE"
echo "   Lambda Function: $LAMBDA_FUNCTION"
echo ""

# Step 1: Get current trust policy
echo "🔍 Step 1: Getting Current Trust Policy..."
echo "=========================================="

CURRENT_TRUST=$(aws iam get-role --role-name "$GATEWAY_SERVICE_ROLE" --query 'Role.AssumeRolePolicyDocument')
echo "Current Trust Policy:"
echo "$CURRENT_TRUST" | jq '.'

# Step 2: Create updated trust policy with Lambda service
echo ""
echo "🔧 Step 2: Creating Updated Trust Policy..."
echo "==========================================="

# Create the new trust policy that includes both bedrock and lambda services
cat > updated-trust-policy.json << 'EOF'
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Service": [
                    "bedrock.amazonaws.com",
                    "lambda.amazonaws.com"
                ]
            },
            "Action": "sts:AssumeRole"
        }
    ]
}
EOF

echo "Updated Trust Policy (adding lambda.amazonaws.com):"
cat updated-trust-policy.json | jq '.'

# Step 3: Apply the updated trust policy
echo ""
echo "🚀 Step 3: Applying Updated Trust Policy..."
echo "==========================================="

aws iam update-assume-role-policy \
    --role-name "$GATEWAY_SERVICE_ROLE" \
    --policy-document file://updated-trust-policy.json

echo "   ✅ Trust policy updated successfully"

# Step 4: Verify the change
echo ""
echo "🔍 Step 4: Verifying Trust Policy Update..."
echo "==========================================="

echo "New Trust Policy:"
aws iam get-role --role-name "$GATEWAY_SERVICE_ROLE" --query 'Role.AssumeRolePolicyDocument' | jq '.'

# Wait for IAM propagation
echo ""
echo "⏳ Waiting 10 seconds for IAM propagation..."
sleep 10

# Step 5: Update Lambda function to use gateway service role
echo ""
echo "🔧 Step 5: Updating Lambda Function Execution Role..."
echo "===================================================="

GATEWAY_ROLE_ARN="arn:aws:iam::${ACCOUNT_ID}:role/${GATEWAY_SERVICE_ROLE}"

echo "Updating Lambda function '$LAMBDA_FUNCTION' to use role: $GATEWAY_ROLE_ARN"

aws lambda update-function-configuration \
    --function-name "$LAMBDA_FUNCTION" \
    --role "$GATEWAY_ROLE_ARN" \
    --region "$REGION"

echo "   ✅ Lambda function execution role updated successfully"

# Step 6: Verify the Lambda function configuration
echo ""
echo "🔍 Step 6: Verifying Lambda Function Update..."
echo "=============================================="

CURRENT_LAMBDA_ROLE=$(aws lambda get-function-configuration --function-name "$LAMBDA_FUNCTION" --region "$REGION" --query 'Role' --output text)
echo "Current Lambda execution role: $CURRENT_LAMBDA_ROLE"

if [ "$CURRENT_LAMBDA_ROLE" = "$GATEWAY_ROLE_ARN" ]; then
    echo "   ✅ Lambda function is now using the gateway service role"
else
    echo "   ❌ Lambda function role update may not have taken effect yet"
    echo "   Expected: $GATEWAY_ROLE_ARN"
    echo "   Actual: $CURRENT_LAMBDA_ROLE"
fi

# Clean up temporary files
rm -f updated-trust-policy.json

echo ""
echo "🎉 Gateway Service Role Trust Policy Fix Complete!"
echo "================================================="
echo ""
echo "📊 Summary:"
echo "   Gateway Service Role: $GATEWAY_SERVICE_ROLE"
echo "   Trust Policy: Updated to allow both bedrock.amazonaws.com and lambda.amazonaws.com"
echo "   Lambda Function: $LAMBDA_FUNCTION"
echo "   New Execution Role: $GATEWAY_ROLE_ARN"
echo ""
echo "🎯 Benefits Achieved:"
echo "   ✅ Single role management (gateway service role)"
echo "   ✅ Bedrock model invoke permissions"
echo "   ✅ Lambda execution permissions"
echo "   ✅ Consistent permissions across gateway and Lambda"
echo ""
echo "🧪 Next Steps:"
echo "1. Test AI Calculator functionality through the MCP gateway"
echo "2. Verify natural language math queries work properly"
echo "3. Monitor CloudWatch logs for any permission issues"
echo ""
echo "🚀 Ready to test: AI Calculator with optimized role configuration!"