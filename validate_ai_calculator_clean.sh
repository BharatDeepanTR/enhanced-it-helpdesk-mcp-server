#!/bin/bash
# Clean AI Calculator MCP Target Validation Script
# Focuses on validating Bedrock Claude permissions for the gateway service role

set -e

echo "🔍 AI Calculator MCP Target Validation"
echo "======================================"

# Configuration
GATEWAY_URL="https://a208194-askjulius-agentcore-gateway-mcp-iam-fvro4phd59.gateway.bedrock-agentcore.us-east-1.amazonaws.com/mcp"
TARGET_NAME="target-lambda-direct-ai-calculator-mcp"
LAMBDA_ARN="arn:aws:lambda:us-east-1:818565325759:function:a208194-ai-bedrock-calculator-mcp-server"
SERVICE_ROLE_NAME="a208194-askjulius-agentcore-gateway"
REGION="us-east-1"
ACCOUNT_ID="818565325759"

echo "🎯 Target Configuration:"
echo "   Gateway: $GATEWAY_URL"
echo "   Target: $TARGET_NAME"
echo "   Lambda: $LAMBDA_ARN"
echo "   Service Role: $SERVICE_ROLE_NAME"
echo ""

# Step 1: Check if Lambda function exists and is accessible
echo "1️⃣ Validating Lambda Function..."
if aws lambda get-function --function-name "$LAMBDA_ARN" --region "$REGION" >/dev/null 2>&1; then
    echo "   ✅ Lambda function accessible"
    
    # Get Lambda execution role
    LAMBDA_ROLE=$(aws lambda get-function --function-name "$LAMBDA_ARN" --region "$REGION" --query 'Configuration.Role' --output text 2>/dev/null)
    echo "   📋 Lambda execution role: $LAMBDA_ROLE"
else
    echo "   ❌ Cannot access Lambda function"
    exit 1
fi

# Step 2: Check gateway service role permissions
echo ""
echo "2️⃣ Checking Gateway Service Role Permissions..."

SERVICE_ROLE_ARN="arn:aws:iam::${ACCOUNT_ID}:role/${SERVICE_ROLE_NAME}"
echo "   🔍 Role ARN: $SERVICE_ROLE_ARN"

# Get role policies
echo "   📋 Attached managed policies:"
aws iam list-attached-role-policies --role-name "$SERVICE_ROLE_NAME" --query 'AttachedPolicies[*].[PolicyName,PolicyArn]' --output table 2>/dev/null || echo "   ⚠️  Could not retrieve attached policies"

echo ""
echo "   📋 Inline policies:"
aws iam list-role-policies --role-name "$SERVICE_ROLE_NAME" --query 'PolicyNames' --output table 2>/dev/null || echo "   ⚠️  Could not retrieve inline policies"

# Step 3: Check specific Bedrock model permissions
echo ""
echo "3️⃣ Checking Bedrock Claude Model Access..."

# Check if role has Bedrock permissions
echo "   🔍 Checking Bedrock permissions in attached policies..."

# Get specific policy details for Bedrock
BEDROCK_POLICIES=$(aws iam list-attached-role-policies --role-name "$SERVICE_ROLE_NAME" --query 'AttachedPolicies[?contains(PolicyName, `Bedrock`) || contains(PolicyArn, `Bedrock`)].PolicyArn' --output text 2>/dev/null)

if [ ! -z "$BEDROCK_POLICIES" ]; then
    echo "   ✅ Found Bedrock-related policies:"
    for policy in $BEDROCK_POLICIES; do
        echo "      - $policy"
        
        # Get policy version and document
        POLICY_VERSION=$(aws iam get-policy --policy-arn "$policy" --query 'Policy.DefaultVersionId' --output text 2>/dev/null)
        echo "      Version: $POLICY_VERSION"
        
        # Check if policy allows bedrock:InvokeModel
        INVOKE_MODEL_ALLOWED=$(aws iam get-policy-version --policy-arn "$policy" --version-id "$POLICY_VERSION" --query 'PolicyVersion.Document' --output json 2>/dev/null | grep -i "bedrock.*InvokeModel\|InvokeModel.*bedrock" || echo "")
        
        if [ ! -z "$INVOKE_MODEL_ALLOWED" ]; then
            echo "      ✅ Contains bedrock:InvokeModel permissions"
        else
            echo "      ⚠️  No explicit bedrock:InvokeModel found"
        fi
    done
else
    echo "   ❌ No Bedrock policies found"
    echo ""
    echo "   🚨 ISSUE IDENTIFIED: Gateway service role lacks Bedrock permissions!"
    echo ""
    echo "   🛠️  SOLUTION: Add Bedrock model access permissions"
    echo "   The role needs permission to invoke Bedrock Claude models"
    echo ""
    
    # Create the missing policy
    echo "   📝 Creating Bedrock Claude permissions policy..."
    
    cat > bedrock-claude-policy.json << 'EOF'
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
                "arn:aws:bedrock:us-east-1::foundation-model/anthropic.claude-3-opus-20240229-v1:0",
                "arn:aws:bedrock:*::foundation-model/anthropic.claude*"
            ]
        }
    ]
}
EOF

    echo "   📄 Policy created: bedrock-claude-policy.json"
    echo ""
    echo "   🔧 To fix this, run:"
    echo "   aws iam put-role-policy --role-name '$SERVICE_ROLE_NAME' --policy-name 'BedrockClaudeAccess' --policy-document file://bedrock-claude-policy.json"
    echo ""
    
    # Offer to apply the fix
    echo "   🤔 Apply this fix now? [y/N]"
    read -r response
    if [[ "$response" =~ ^[Yy]$ ]]; then
        echo "   🔧 Applying Bedrock Claude permissions..."
        
        if aws iam put-role-policy --role-name "$SERVICE_ROLE_NAME" --policy-name "BedrockClaudeAccess" --policy-document file://bedrock-claude-policy.json; then
            echo "   ✅ Bedrock Claude permissions added successfully!"
            echo "   ⏳ Waiting 10 seconds for permissions to propagate..."
            sleep 10
        else
            echo "   ❌ Failed to add permissions"
        fi
        
        # Clean up
        rm -f bedrock-claude-policy.json
    else
        echo "   ⏭️  Skipping fix - you can apply it manually later"
    fi
fi

# Step 4: Test Lambda function directly (if accessible)
echo ""
echo "4️⃣ Testing Lambda Function Directly..."

# Create test payload for AI Calculator
cat > lambda-test-payload.json << 'EOF'
{
    "jsonrpc": "2.0",
    "id": "direct-test",
    "method": "tools/call",
    "params": {
        "name": "ai_calculate",
        "arguments": {
            "query": "What is 25 + 17?"
        }
    }
}
EOF

echo "   📤 Testing Lambda with simple calculation..."
LAMBDA_RESULT=$(aws lambda invoke --function-name "$LAMBDA_ARN" --payload file://lambda-test-payload.json --region "$REGION" lambda-response.json 2>&1)

if [ $? -eq 0 ]; then
    echo "   ✅ Lambda invocation successful"
    echo "   📥 Response:"
    cat lambda-response.json | jq . 2>/dev/null || cat lambda-response.json
    echo ""
    
    # Check for Bedrock access errors in the response
    if grep -q "AccessDenied\|UnauthorizedOperation\|Access denied to Bedrock" lambda-response.json; then
        echo "   🚨 BEDROCK ACCESS DENIED in Lambda response!"
        echo "   The Lambda function cannot access Bedrock Claude models"
    else
        echo "   ✅ No obvious Bedrock access errors detected"
    fi
else
    echo "   ❌ Lambda invocation failed:"
    echo "   $LAMBDA_RESULT"
fi

# Clean up test files
rm -f lambda-test-payload.json lambda-response.json

# Step 5: Summary and recommendations
echo ""
echo "5️⃣ Summary & Recommendations"
echo "=========================="

echo "📊 Configuration Validation Results:"
echo "   Lambda Function: ✅ Accessible"
echo "   Gateway Service Role: ❓ Checking permissions..."

# Check if we found Bedrock permissions
if [ ! -z "$BEDROCK_POLICIES" ]; then
    echo "   Bedrock Permissions: ✅ Found"
    echo ""
    echo "🎯 If you're still getting UnknownOperationException:"
    echo "   1. Check target configuration in AWS Console"
    echo "   2. Verify target name matches exactly: $TARGET_NAME"
    echo "   3. Check CloudWatch logs for detailed errors"
    echo "   4. Ensure MCP tools schema is correctly configured"
else
    echo "   Bedrock Permissions: ❌ Missing"
    echo ""
    echo "🚨 ROOT CAUSE IDENTIFIED:"
    echo "   Gateway service role '$SERVICE_ROLE_NAME' lacks Bedrock Claude model permissions"
    echo ""
    echo "🛠️  NEXT STEPS:"
    echo "   1. Add Bedrock Claude access permissions to the gateway service role"
    echo "   2. Test again after permissions propagate (5-10 minutes)"
    echo "   3. If issue persists, check target configuration in console"
fi

echo ""
echo "🔗 Gateway URL for reference:"
echo "   $GATEWAY_URL"
echo "   Target: $TARGET_NAME"