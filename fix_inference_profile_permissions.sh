#!/bin/bash
# Fix Claude Inference Profile Permissions
# Add bedrock:InvokeModel permission for Claude inference profile

set -e

ROLE_NAME="a208194-askjulius-agentcore-gateway"
REGION="us-east-1"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

echo "🔧 Fixing Claude Inference Profile Permissions"
echo "=============================================="
echo "Role: $ROLE_NAME"
echo "Account: $ACCOUNT_ID"
echo "Region: $REGION"
echo ""

# Create updated policy for inference profile access
cat > inference-profile-policy.json << 'EOF'
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
                "arn:aws:bedrock:us-east-1::foundation-model/anthropic.claude-3-5-sonnet-20241022-v2:0",
                "arn:aws:bedrock:us-east-1::foundation-model/*",
                "arn:aws:bedrock:us-east-1:818565325759:inference-profile/us.anthropic.claude-3-5-sonnet-20241022-v2:0",
                "arn:aws:bedrock:*::inference-profile/*"
            ]
        }
    ]
}
EOF

echo "📋 Created inference profile policy:"
cat inference-profile-policy.json
echo ""

echo "🔄 Updating BedrockModelInvokePolicy..."
aws iam put-role-policy \
    --role-name "$ROLE_NAME" \
    --policy-name "BedrockModelInvokePolicy" \
    --policy-document file://inference-profile-policy.json \
    --region "$REGION"

echo ""
echo "✅ Policy updated successfully!"
echo ""
echo "🧪 PERMISSIONS ADDED:"
echo "   ✅ Claude 3.5 Sonnet foundation model access"
echo "   ✅ Claude 3.5 Sonnet inference profile access"
echo "   ✅ All inference profiles wildcard access"
echo "   ✅ All foundation models wildcard access"
echo ""
echo "🎯 NEXT STEPS:"
echo "1. Test Lambda function from AWS Console again"
echo "2. Should now get actual Claude response instead of AccessDenied"
echo "3. Test via MCP gateway if Lambda test succeeds"

# Cleanup
rm -f inference-profile-policy.json

echo ""
echo "🎉 Ready for Lambda testing!"