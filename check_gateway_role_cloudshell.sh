#!/bin/bash
# Check and Validate Gateway Service Role Bedrock Permissions for CloudShell
# Optimized for AWS CloudShell execution environment

set -e

echo "🔍 AWS CloudShell: Gateway Service Role Bedrock Permissions Validation"
echo "======================================================================="
echo ""

# Configuration
GATEWAY_SERVICE_ROLE="a208194-askjulius-agentcore-gateway"
CURRENT_LAMBDA_ROLE="a208194-julius-search-LambdaExecutionRole"
LAMBDA_FUNCTION="a208194-ai-bedrock-calculator-mcp-server"
REGION="us-east-1"

# Get account ID for CloudShell
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo "📋 CloudShell Session Configuration:"
echo "   AWS Account ID: $ACCOUNT_ID"
echo "   Region: $REGION"
echo "   Gateway Service Role: $GATEWAY_SERVICE_ROLE"
echo "   Current Lambda Role: $CURRENT_LAMBDA_ROLE"
echo "   Lambda Function: $LAMBDA_FUNCTION"
echo ""

# Verify CloudShell credentials
echo "🔐 Verifying CloudShell Credentials..."
CALLER_IDENTITY=$(aws sts get-caller-identity)
echo "   Current Identity: $(echo $CALLER_IDENTITY | jq -r '.Arn // .UserId')"
echo "   ✅ CloudShell credentials active"
echo ""

# Step 1: Check if gateway service role exists
echo "🔍 Step 1: Verifying Gateway Service Role Exists..."
echo "==================================================="

if aws iam get-role --role-name "$GATEWAY_SERVICE_ROLE" >/dev/null 2>&1; then
    echo "   ✅ Gateway service role '$GATEWAY_SERVICE_ROLE' found"
else
    echo "   ❌ Gateway service role '$GATEWAY_SERVICE_ROLE' not found"
    echo "   🚨 Cannot proceed without the gateway service role"
    exit 1
fi

# Step 2: Analyze trust policy
echo ""
echo "🔍 Step 2: Analyzing Trust Policy..."
echo "===================================="

echo "Trust Policy for $GATEWAY_SERVICE_ROLE:"
TRUST_POLICY=$(aws iam get-role --role-name "$GATEWAY_SERVICE_ROLE" --query 'Role.AssumeRolePolicyDocument')
echo "$TRUST_POLICY" | jq '.'

# Check if Lambda service can assume this role
LAMBDA_TRUST=$(echo "$TRUST_POLICY" | jq -r '.Statement[] | select(.Principal.Service? // empty | contains("lambda")) | .Effect' 2>/dev/null || echo "")
BEDROCK_TRUST=$(echo "$TRUST_POLICY" | jq -r '.Statement[] | select(.Principal.Service? // empty | contains("bedrock")) | .Effect' 2>/dev/null || echo "")

echo ""
echo "Trust Policy Analysis:"
if [ "$LAMBDA_TRUST" = "Allow" ]; then
    echo "   ✅ Lambda service can assume this role"
    LAMBDA_ASSUME_ALLOWED=true
else
    echo "   ❌ Lambda service CANNOT assume this role"
    LAMBDA_ASSUME_ALLOWED=false
fi

if [ "$BEDROCK_TRUST" = "Allow" ]; then
    echo "   ✅ Bedrock service can assume this role"
else
    echo "   ℹ️  Bedrock service trust found"
fi

# Step 3: Check attached managed policies
echo ""
echo "🔍 Step 3: Checking Managed Policies..."
echo "======================================="

echo "Attached Managed Policies:"
MANAGED_POLICIES=$(aws iam list-attached-role-policies --role-name "$GATEWAY_SERVICE_ROLE")
echo "$MANAGED_POLICIES" | jq -r '.AttachedPolicies[] | "   • \(.PolicyName) (\(.PolicyArn))"'

# Check for specific Bedrock policies
BEDROCK_FULL_ACCESS=$(echo "$MANAGED_POLICIES" | jq -r '.AttachedPolicies[] | select(.PolicyArn | contains("AmazonBedrockFullAccess")) | .PolicyName' 2>/dev/null || echo "")
BEDROCK_AGENT_CORE=$(echo "$MANAGED_POLICIES" | jq -r '.AttachedPolicies[] | select(.PolicyArn | contains("BedrockAgentCoreFullAccess")) | .PolicyName' 2>/dev/null || echo "")

echo ""
echo "Bedrock Policy Analysis:"
BEDROCK_PERMISSIONS_FOUND=false

if [ -n "$BEDROCK_FULL_ACCESS" ]; then
    echo "   ✅ AmazonBedrockFullAccess policy attached"
    BEDROCK_PERMISSIONS_FOUND=true
fi

if [ -n "$BEDROCK_AGENT_CORE" ]; then
    echo "   ✅ BedrockAgentCoreFullAccess policy attached"
    BEDROCK_PERMISSIONS_FOUND=true
fi

if [ "$BEDROCK_PERMISSIONS_FOUND" = "false" ]; then
    echo "   ⚠️  No explicit Bedrock managed policies found"
fi

# Step 4: Check inline policies
echo ""
echo "🔍 Step 4: Checking Inline Policies..."
echo "======================================"

INLINE_POLICIES=$(aws iam list-role-policies --role-name "$GATEWAY_SERVICE_ROLE" --query 'PolicyNames[]' --output text)

if [ -n "$INLINE_POLICIES" ]; then
    echo "Inline Policies found:"
    for policy in $INLINE_POLICIES; do
        echo "   • $policy"
        echo "     Content:"
        aws iam get-role-policy --role-name "$GATEWAY_SERVICE_ROLE" --policy-name "$policy" --query 'PolicyDocument' | jq '.'
        echo ""
    done
    
    # Check if inline policies contain Bedrock permissions
    for policy in $INLINE_POLICIES; do
        BEDROCK_INLINE=$(aws iam get-role-policy --role-name "$GATEWAY_SERVICE_ROLE" --policy-name "$policy" --query 'PolicyDocument' | jq -r '.Statement[]? | select(.Action[]? // .Action? // empty | contains("bedrock")) | .Effect' 2>/dev/null || echo "")
        if [ "$BEDROCK_INLINE" = "Allow" ]; then
            echo "   ✅ Bedrock permissions found in inline policy: $policy"
            BEDROCK_PERMISSIONS_FOUND=true
        fi
    done
else
    echo "   ℹ️  No inline policies found"
fi

# Step 5: Final assessment and recommendations
echo ""
echo "🎯 Step 5: Final Assessment & Recommendations"
echo "============================================="

echo ""
echo "📊 SUMMARY:"
echo "==========="

# Trust Policy Assessment
if [ "$LAMBDA_ASSUME_ALLOWED" = "true" ]; then
    echo "   ✅ Trust Policy: Lambda can assume gateway service role"
    CAN_USE_AS_LAMBDA_ROLE=true
else
    echo "   ❌ Trust Policy: Lambda CANNOT assume gateway service role"
    echo "      Solution needed: Add Lambda to trust policy"
    CAN_USE_AS_LAMBDA_ROLE=false
fi

# Bedrock Permissions Assessment
if [ "$BEDROCK_PERMISSIONS_FOUND" = "true" ]; then
    echo "   ✅ Bedrock Permissions: Found in role policies"
    HAS_BEDROCK_PERMISSIONS=true
else
    echo "   ❌ Bedrock Permissions: NOT found in role policies"
    echo "      Solution needed: Add Bedrock permissions to role"
    HAS_BEDROCK_PERMISSIONS=false
fi

echo ""
echo "🎯 RECOMMENDATION:"
echo "=================="

if [ "$CAN_USE_AS_LAMBDA_ROLE" = "true" ] && [ "$HAS_BEDROCK_PERMISSIONS" = "true" ]; then
    echo "   ✅ OPTIMAL: Use gateway service role as Lambda execution role"
    echo ""
    echo "   🔧 Next Steps:"
    echo "   1. Update Lambda function to use gateway service role as execution role"
    echo "   2. Remove dependency on current Lambda execution role"
    echo "   3. Test AI Calculator functionality"
    echo ""
    echo "   💡 Benefits:"
    echo "   • Single role management"
    echo "   • Consistent permissions across gateway and Lambda"
    echo "   • Simplified architecture"
    
    # Provide the exact AWS CLI command
    echo ""
    echo "   🚀 CloudShell Command to Update Lambda:"
    echo "   aws lambda update-function-configuration \\"
    echo "       --function-name '$LAMBDA_FUNCTION' \\"
    echo "       --role 'arn:aws:iam::${ACCOUNT_ID}:role/${GATEWAY_SERVICE_ROLE}' \\"
    echo "       --region '$REGION'"
    
elif [ "$CAN_USE_AS_LAMBDA_ROLE" = "true" ] && [ "$HAS_BEDROCK_PERMISSIONS" = "false" ]; then
    echo "   ⚠️  PARTIAL: Trust policy allows Lambda, but missing Bedrock permissions"
    echo ""
    echo "   🔧 Options:"
    echo "   A) Add Bedrock permissions to gateway service role (RECOMMENDED)"
    echo "   B) Fix current Lambda execution role Bedrock permissions"
    echo ""
    echo "   🚀 CloudShell Command to Add Bedrock Permissions:"
    echo "   aws iam attach-role-policy \\"
    echo "       --role-name '$GATEWAY_SERVICE_ROLE' \\"
    echo "       --policy-arn 'arn:aws:iam::aws:policy/service-role/AmazonBedrockFullAccess'"
    
elif [ "$CAN_USE_AS_LAMBDA_ROLE" = "false" ] && [ "$HAS_BEDROCK_PERMISSIONS" = "true" ]; then
    echo "   ⚠️  PARTIAL: Has Bedrock permissions, but trust policy doesn't allow Lambda"
    echo ""
    echo "   🔧 Options:"
    echo "   A) Add Lambda to trust policy (RECOMMENDED)"
    echo "   B) Fix current Lambda execution role Bedrock permissions"
    echo ""
    echo "   🚀 CloudShell Commands to Add Lambda Trust:"
    echo "   # First, get current trust policy"
    echo "   aws iam get-role --role-name '$GATEWAY_SERVICE_ROLE' --query 'Role.AssumeRolePolicyDocument' > trust-policy.json"
    echo "   # Edit trust-policy.json to add lambda.amazonaws.com service"
    echo "   # Then update the trust policy"
    echo "   aws iam update-assume-role-policy --role-name '$GATEWAY_SERVICE_ROLE' --policy-document file://trust-policy.json"
    
else
    echo "   ❌ SUBOPTIMAL: Missing both Lambda trust and Bedrock permissions"
    echo ""
    echo "   🔧 Recommendation: Fix current Lambda execution role instead"
    echo ""
    echo "   🚀 CloudShell Command to Fix Current Lambda Role:"
    echo "   aws iam attach-role-policy \\"
    echo "       --role-name '$CURRENT_LAMBDA_ROLE' \\"
    echo "       --policy-arn 'arn:aws:iam::aws:policy/service-role/AmazonBedrockFullAccess'"
fi

echo ""
echo "🏁 CloudShell Validation Complete!"
echo "=================================="
echo ""
echo "📋 Results Summary:"
echo "   Gateway Service Role: $GATEWAY_SERVICE_ROLE"
echo "   Lambda Assume Allowed: $CAN_USE_AS_LAMBDA_ROLE"
echo "   Bedrock Permissions Found: $HAS_BEDROCK_PERMISSIONS"
echo ""

if [ "$CAN_USE_AS_LAMBDA_ROLE" = "true" ] && [ "$HAS_BEDROCK_PERMISSIONS" = "true" ]; then
    echo "🎯 READY TO PROCEED: Use gateway service role for Lambda execution"
    exit 0
else
    echo "🔧 CONFIGURATION NEEDED: Additional setup required before role switch"
    exit 1
fi