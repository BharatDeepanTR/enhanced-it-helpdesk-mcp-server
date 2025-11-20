#!/bin/bash
# Fix Bedrock Model Permissions for Gateway Service Role
# Add bedrock:InvokeModel permission for Claude models

set -e

SERVICE_ROLE_NAME="a208194-askjulius-agentcore-gateway"
REGION="us-east-1"

echo "🔧 Fixing Bedrock Model Permissions for Gateway Service Role"
echo "============================================================="
echo "Role: $SERVICE_ROLE_NAME"
echo "Region: $REGION"
echo ""

# Check if role exists
echo "🔍 Verifying service role exists..."
if ! aws iam get-role --role-name "$SERVICE_ROLE_NAME" >/dev/null 2>&1; then
    echo "❌ Service role '$SERVICE_ROLE_NAME' not found"
    exit 1
fi
echo "✅ Service role found"
echo ""

# Create comprehensive Bedrock model policy
echo "📝 Creating Bedrock model invocation policy..."
cat > bedrock-model-policy.json << 'EOF'
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "BedrockModelInvoke",
            "Effect": "Allow",
            "Action": [
                "bedrock:InvokeModel",
                "bedrock:InvokeModelWithResponseStream"
            ],
            "Resource": [
                "arn:aws:bedrock:*::foundation-model/anthropic.claude-3-sonnet-20240229-v1:0",
                "arn:aws:bedrock:*::foundation-model/anthropic.claude-3-haiku-20240307-v1:0",
                "arn:aws:bedrock:*::foundation-model/anthropic.claude-3-opus-20240229-v1:0",
                "arn:aws:bedrock:*::foundation-model/anthropic.claude-v2",
                "arn:aws:bedrock:*::foundation-model/anthropic.claude-v2:1",
                "arn:aws:bedrock:*::foundation-model/anthropic.claude-instant-v1"
            ]
        },
        {
            "Sid": "BedrockModelAccess",
            "Effect": "Allow",
            "Action": [
                "bedrock:GetFoundationModel",
                "bedrock:ListFoundationModels"
            ],
            "Resource": "*"
        }
    ]
}
EOF

# Apply the policy
echo "🚀 Applying Bedrock model policy to role..."
aws iam put-role-policy \
    --role-name "$SERVICE_ROLE_NAME" \
    --policy-name "BedrockModelInvokePolicy" \
    --policy-document file://bedrock-model-policy.json

echo "✅ Bedrock model policy applied successfully"
echo ""

# Verify the policy was applied
echo "🔍 Verifying policy application..."
if aws iam get-role-policy --role-name "$SERVICE_ROLE_NAME" --policy-name "BedrockModelInvokePolicy" >/dev/null 2>&1; then
    echo "✅ Policy verification successful"
else
    echo "⚠️  Policy verification failed, but may still be working"
fi

echo ""
echo "📋 Current inline policies for role:"
aws iam list-role-policies --role-name "$SERVICE_ROLE_NAME" --output table

echo ""
echo "🎯 Summary of Added Permissions:"
echo "- bedrock:InvokeModel (for Claude model invocation)"
echo "- bedrock:InvokeModelWithResponseStream (for streaming responses)"
echo "- bedrock:GetFoundationModel (for model metadata)"
echo "- bedrock:ListFoundationModels (for model discovery)"
echo ""
echo "🎯 Supported Claude Models:"
echo "- anthropic.claude-3-sonnet-20240229-v1:0"
echo "- anthropic.claude-3-haiku-20240307-v1:0"
echo "- anthropic.claude-3-opus-20240229-v1:0"
echo "- anthropic.claude-v2"
echo "- anthropic.claude-v2:1"
echo "- anthropic.claude-instant-v1"
echo ""

# Clean up
rm -f bedrock-model-policy.json

echo "✅ Bedrock permissions fix completed!"
echo ""
echo "🎯 Next Steps:"
echo "1. Wait 30 seconds for IAM propagation"
echo "2. Test Lambda function directly"
echo "3. Test MCP gateway endpoint"
echo "4. The AI Calculator should now have Claude access"