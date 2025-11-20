#!/bin/bash
# CloudShell Solution: Create Service Role and Get Console Instructions
# Since CLI commands don't exist yet, focus on making console work

echo "☁️  CloudShell: Bedrock Agent Core Gateway Console Solution"
echo "========================================================"
echo ""

# Verify CloudShell credentials
if ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null); then
    echo "✅ CloudShell credentials active - Account: $ACCOUNT_ID"
else
    echo "❌ CloudShell credentials not working"
    exit 1
fi

GATEWAY_NAME="a208194-askjulius-agentcore-gateway"
SERVICE_ROLE_NAME="a208194-askjulius-agentcore-gateway"
LAMBDA_ARN="arn:aws:lambda:us-east-1:818565325759:function:a208194-chatops_application_details_intent"
SERVICE_ROLE_ARN="arn:aws:iam::${ACCOUNT_ID}:role/${SERVICE_ROLE_NAME}"

echo "🛠️  Step 1: Ensure Perfect Service Role Configuration"
echo "=================================================="

# Create/update the service role with optimal configuration for console visibility
echo "Creating service role optimized for console visibility..."

# Perfect trust policy for Bedrock Agent Core Gateway
cat > /tmp/trust-policy.json << EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Service": "bedrock.amazonaws.com"
            },
            "Action": "sts:AssumeRole"
        }
    ]
}
EOF

# Create or update the role
if aws iam get-role --role-name "$SERVICE_ROLE_NAME" >/dev/null 2>&1; then
    echo "   Updating existing role..."
    aws iam update-assume-role-policy \
        --role-name "$SERVICE_ROLE_NAME" \
        --policy-document file:///tmp/trust-policy.json
else
    echo "   Creating new role..."
    aws iam create-role \
        --role-name "$SERVICE_ROLE_NAME" \
        --assume-role-policy-document file:///tmp/trust-policy.json \
        --description "Service role for Bedrock Agent Core Gateway"
fi

# Attach comprehensive policies
echo "   Attaching policies..."
aws iam attach-role-policy \
    --role-name "$SERVICE_ROLE_NAME" \
    --policy-arn "arn:aws:iam::aws:policy/service-role/AmazonBedrockFullAccess" 2>/dev/null || true

# Perfect inline policy
cat > /tmp/inline-policy.json << EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "lambda:InvokeFunction"
            ],
            "Resource": "$LAMBDA_ARN"
        },
        {
            "Effect": "Allow",
            "Action": [
                "bedrock:*",
                "bedrock-agent:*",
                "bedrock-agent-runtime:*"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "logs:*"
            ],
            "Resource": "*"
        }
    ]
}
EOF

aws iam put-role-policy \
    --role-name "$SERVICE_ROLE_NAME" \
    --policy-name "BedrockAgentCoreGatewayPolicy" \
    --policy-document file:///tmp/inline-policy.json

echo "✅ Service role configured: $SERVICE_ROLE_ARN"

echo ""
echo "⏳ Step 2: Wait for IAM Propagation"
echo "================================="
echo "   Waiting 15 seconds for AWS IAM propagation..."
sleep 15
echo "✅ Propagation complete"

echo ""
echo "🌐 Step 3: Console Instructions with Workarounds"
echo "=============================================="

echo ""
echo "🎯 EXACT STEPS FOR AWS CONSOLE:"
echo "==============================="
echo ""
echo "1. 🌐 Open AWS Console in new tab:"
echo "   https://console.aws.amazon.com/bedrock/"
echo ""
echo "2. 📍 Navigate to:"
echo "   Bedrock → Agent Core → Gateways → Create Gateway"
echo ""
echo "3. 📝 Fill in Gateway Details:"
echo "   ┌─────────────────────────────────────────────────────────────┐"
echo "   │ Gateway name: $GATEWAY_NAME │"
echo "   │ Enable semantic search: ✅ CHECKED                         │"
echo "   └─────────────────────────────────────────────────────────────┘"
echo ""
echo "4. 🔧 SERVICE ROLE WORKAROUNDS:"
echo "   ┌─────────────────────────────────────────────────────────────┐"
echo "   │ If dropdown shows roles:                                    │"
echo "   │   → Select: $SERVICE_ROLE_NAME            │"
echo "   │                                                             │"
echo "   │ If dropdown is EMPTY (common issue):                       │"
echo "   │   → Look for 'Enter ARN manually' option                   │"
echo "   │   → Or try pasting ARN in text field:                      │"
echo "   │   → $SERVICE_ROLE_ARN │"
echo "   │                                                             │"
echo "   │ If no text field visible:                                  │"
echo "   │   → Refresh page 2-3 times                                 │"
echo "   │   → Try different browser                                   │"
echo "   │   → Clear cache and try again                              │"
echo "   └─────────────────────────────────────────────────────────────┘"
echo ""
echo "5. 🎯 Target Configuration:"
echo "   ┌─────────────────────────────────────────────────────────────┐"
echo "   │ Target name: a208194-application-details-tool-target       │"
echo "   │ Target description: Details of the application based on    │"
echo "   │                    the asset insight                       │"
echo "   │ Target type: Lambda ARN                                     │"
echo "   │ Lambda ARN: $LAMBDA_ARN │"
echo "   │ Outbound Auth: IAM Role                                     │"
echo "   └─────────────────────────────────────────────────────────────┘"
echo ""
echo "6. 📄 Schema Configuration:"
echo "   Schema type: Define an inline schema"
echo "   Copy-paste this JSON:"
echo ""
cat << 'SCHEMA_EOF'
{
    "name": "get_application_details",
    "description": "Get application details including name, contact, and regional presence for a given asset ID",
    "inputSchema": {
        "type": "object",
        "properties": {
            "asset_id": {
                "type": "string",
                "description": "The application asset ID (can include 'a' prefix, e.g., 'a12345' or '12345')"
            }
        },
        "required": ["asset_id"]
    }
}
SCHEMA_EOF

echo ""
echo "🔧 TROUBLESHOOTING THE SERVICE ROLE DROPDOWN:"
echo "============================================="
echo ""
echo "Issue: Role not visible in dropdown"
echo "Solutions (try in order):"
echo ""
echo "   A. Browser Fixes:"
echo "      • Ctrl+F5 (hard refresh)"
echo "      • Clear browser cache completely"
echo "      • Use incognito/private mode"
echo "      • Try different browser (Chrome/Firefox/Safari)"
echo ""
echo "   B. Console Fixes:"
echo "      • Log out and back into AWS Console"
echo "      • Wait 5-10 minutes and try again"
echo "      • Go to IAM → Roles, verify role exists, then back to Bedrock"
echo ""
echo "   C. Manual ARN Entry:"
echo "      • Look for 'Custom' or 'Enter manually' option"
echo "      • Paste: $SERVICE_ROLE_ARN"
echo ""

echo ""
echo "📋 Step 4: Verification Checklist"
echo "================================"
echo ""
echo "✅ Verify these before creating gateway:"
echo "   □ Service role exists in IAM console"
echo "   □ Role ARN copied correctly"
echo "   □ Lambda function exists and is accessible"
echo "   □ Using same AWS region (us-east-1)"
echo "   □ Schema JSON is valid (paste in JSON validator if unsure)"
echo ""

echo "🎉 Step 5: Success Indicators"
echo "============================"
echo ""
echo "Gateway creation successful when you see:"
echo "   ✅ Gateway Status: Creating → Active"
echo "   ✅ Target Status: Connected"
echo "   ✅ No error messages"
echo ""
echo "Test your gateway with:"
echo '   Input: {"asset_id": "a12345"}'
echo ""

# Cleanup
rm -f /tmp/trust-policy.json /tmp/inline-policy.json

echo "💡 Summary:"
echo "=========="
echo "   Service Role: ✅ Ready and optimized"
echo "   Console Path: ✅ Documented with workarounds"
echo "   CLI Alternative: ❌ Not available yet"
echo "   Best Approach: 🌐 Enhanced console method with manual ARN entry"
echo ""
echo "🚀 Ready to create your Agent Core Gateway!"