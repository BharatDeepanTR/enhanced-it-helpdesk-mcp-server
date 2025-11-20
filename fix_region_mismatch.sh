#!/bin/bash
# Fix Region Mismatch - Add us-west-2 permissions and ensure Lambda uses us-east-1

set -e

ROLE_NAME="a208194-askjulius-agentcore-gateway"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

echo "🔧 Fixing Region Mismatch Issue"
echo "==============================="
echo "Role: $ROLE_NAME"
echo "Account: $ACCOUNT_ID"
echo ""
echo "Issue: Lambda trying us-west-2 but permissions only for us-east-1"
echo ""

# Create updated policy with both regions
cat > multi-region-policy.json << 'EOF'
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
                "arn:aws:bedrock:us-west-2::foundation-model/anthropic.claude-3-5-sonnet-20241022-v2:0",
                "arn:aws:bedrock:us-west-2::foundation-model/*",
                "arn:aws:bedrock:us-west-2:818565325759:inference-profile/us.anthropic.claude-3-5-sonnet-20241022-v2:0",
                "arn:aws:bedrock:*::foundation-model/*",
                "arn:aws:bedrock:*::inference-profile/*",
                "arn:aws:bedrock:*:*:inference-profile/*"
            ]
        }
    ]
}
EOF

echo "📋 Created multi-region policy:"
cat multi-region-policy.json
echo ""

echo "🔄 Updating BedrockModelInvokePolicy with multi-region support..."
aws iam put-role-policy \
    --role-name "$ROLE_NAME" \
    --policy-name "BedrockModelInvokePolicy" \
    --policy-document file://multi-region-policy.json

echo ""
echo "✅ Policy updated successfully!"
echo ""
echo "🧪 PERMISSIONS ADDED:"
echo "   ✅ us-east-1 foundation models and inference profiles"
echo "   ✅ us-west-2 foundation models and inference profiles" 
echo "   ✅ All regions wildcard access"
echo ""

# Also update Lambda environment to ensure it uses us-east-1
echo "🔄 Setting Lambda environment variable for region..."
aws lambda update-function-configuration \
    --function-name "a208194-ai-bedrock-calculator-mcp-server" \
    --environment Variables="{AWS_REGION=us-east-1,BEDROCK_REGION=us-east-1}" \
    --region us-east-1

echo ""
echo "✅ Lambda environment updated!"
echo ""
echo "🎯 NEXT STEPS:"
echo "1. Test Lambda function from AWS Console again"
echo "2. Should now work with either us-east-1 or us-west-2"
echo "3. Test via MCP gateway if Lambda test succeeds"

# Cleanup
rm -f multi-region-policy.json

echo ""
echo "🎉 Ready for Lambda testing!"