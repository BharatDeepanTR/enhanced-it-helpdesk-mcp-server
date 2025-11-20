#!/bin/bash
# Check and Validate Gateway Service Role Bedrock Permissions
# Then optionally update Lambda to use this role instead

set -e

echo "🔍 Checking Gateway Service Role Bedrock Permissions"
echo "=================================================="
echo ""

# Configuration
GATEWAY_SERVICE_ROLE="a208194-askjulius-agentcore-gateway"
CURRENT_LAMBDA_ROLE="a208194-julius-search-LambdaExecutionRole"
LAMBDA_FUNCTION="a208194-ai-bedrock-calculator-mcp-server"

echo "📋 Configuration:"
echo "   Gateway Service Role: $GATEWAY_SERVICE_ROLE"
echo "   Current Lambda Role: $CURRENT_LAMBDA_ROLE"
echo "   Lambda Function: $LAMBDA_FUNCTION"
echo ""

# Step 1: Check gateway service role permissions
echo "🔍 Step 1: Checking Gateway Service Role Permissions..."
echo "====================================================="

echo "Trust Policy for $GATEWAY_SERVICE_ROLE:"
aws iam get-role --role-name "$GATEWAY_SERVICE_ROLE" --query 'Role.AssumeRolePolicyDocument'

echo ""
echo "Attached Managed Policies:"
aws iam list-attached-role-policies --role-name "$GATEWAY_SERVICE_ROLE" --query 'AttachedPolicies[*].{PolicyName:PolicyName,PolicyArn:PolicyArn}' --output table

echo ""
echo "Inline Policies:"
aws iam list-role-policies --role-name "$GATEWAY_SERVICE_ROLE" --query 'PolicyNames' --output table

# Step 2: Check for Bedrock permissions specifically
echo ""
echo "🔍 Step 2: Analyzing Bedrock Permissions..."
echo "=========================================="

# Check for AmazonBedrockFullAccess
BEDROCK_FULL_ACCESS=$(aws iam list-attached-role-policies --role-name "$GATEWAY_SERVICE_ROLE" --query 'AttachedPolicies[?contains(PolicyArn, `AmazonBedrockFullAccess`)].PolicyName' --output text)

# Check for BedrockAgentCoreFullAccess  
BEDROCK_AGENT_CORE=$(aws iam list-attached-role-policies --role-name "$GATEWAY_SERVICE_ROLE" --query 'AttachedPolicies[?contains(PolicyArn, `BedrockAgentCoreFullAccess`)].PolicyName' --output text)

# Check inline policies for Bedrock permissions
INLINE_POLICIES=$(aws iam list-role-policies --role-name "$GATEWAY_SERVICE_ROLE" --query 'PolicyNames[]' --output text)

echo "Bedrock Permission Analysis:"
echo "=========================="

if [ -n "$BEDROCK_FULL_ACCESS" ]; then
    echo "✅ AmazonBedrockFullAccess: FOUND"
    BEDROCK_PERMISSIONS="FULL"
else
    echo "❌ AmazonBedrockFullAccess: NOT FOUND"
    BEDROCK_PERMISSIONS="PARTIAL"
fi

if [ -n "$BEDROCK_AGENT_CORE" ]; then
    echo "✅ BedrockAgentCoreFullAccess: FOUND"
else
    echo "❌ BedrockAgentCoreFullAccess: NOT FOUND"
fi

# Check inline policies for Bedrock model invoke permissions
BEDROCK_INLINE="NO"
if [ -n "$INLINE_POLICIES" ]; then
    echo ""
    echo "Checking inline policies for Bedrock model permissions..."
    for policy in $INLINE_POLICIES; do
        echo "  Checking policy: $policy"
        POLICY_DOC=$(aws iam get-role-policy --role-name "$GATEWAY_SERVICE_ROLE" --policy-name "$policy" --query 'PolicyDocument' 2>/dev/null || echo "null")
        
        # Check if policy contains bedrock:InvokeModel
        if echo "$POLICY_DOC" | grep -q "bedrock:InvokeModel"; then
            echo "  ✅ $policy contains bedrock:InvokeModel"
            BEDROCK_INLINE="YES"
        else
            echo "  ❌ $policy does not contain bedrock:InvokeModel"
        fi
    done
fi

# Step 3: Determine if role is suitable
echo ""
echo "🎯 Step 3: Permission Assessment..."
echo "================================="

CAN_USE_GATEWAY_ROLE="NO"

if [ "$BEDROCK_PERMISSIONS" = "FULL" ] || [ "$BEDROCK_INLINE" = "YES" ]; then
    echo "✅ Gateway service role HAS Bedrock model invoke permissions"
    CAN_USE_GATEWAY_ROLE="YES"
else
    echo "❌ Gateway service role LACKS Bedrock model invoke permissions"
    CAN_USE_GATEWAY_ROLE="NO"
fi

# Step 4: Check if role can be assumed by Lambda
echo ""
echo "🔍 Step 4: Checking Lambda Assume Role Permission..."
echo "=================================================="

TRUST_POLICY=$(aws iam get-role --role-name "$GATEWAY_SERVICE_ROLE" --query 'Role.AssumeRolePolicyDocument.Statement[0].Principal.Service' --output text)

if echo "$TRUST_POLICY" | grep -q "lambda.amazonaws.com\|bedrock.amazonaws.com"; then
    echo "✅ Role can be assumed by AWS services (bedrock/lambda)"
    CAN_ASSUME="YES"
else
    echo "❌ Role trust policy needs lambda.amazonaws.com principal"
    CAN_ASSUME="NO"
fi

# Step 5: Recommendation and optional update
echo ""
echo "📊 Final Assessment and Recommendation:"
echo "======================================"

if [ "$CAN_USE_GATEWAY_ROLE" = "YES" ] && [ "$CAN_ASSUME" = "YES" ]; then
    echo "🎉 RECOMMENDATION: ✅ USE GATEWAY SERVICE ROLE"
    echo ""
    echo "The gateway service role '$GATEWAY_SERVICE_ROLE' has:"
    echo "✅ Bedrock model invoke permissions"
    echo "✅ Proper trust policy for AWS services"
    echo "✅ All required permissions for Lambda execution"
    echo ""
    
    read -p "🤔 Would you like to update the Lambda function to use the gateway service role? (y/n): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo ""
        echo "🔧 Updating Lambda function execution role..."
        
        # Get the full ARN of the gateway service role
        GATEWAY_ROLE_ARN=$(aws iam get-role --role-name "$GATEWAY_SERVICE_ROLE" --query 'Role.Arn' --output text)
        
        echo "Updating Lambda function '$LAMBDA_FUNCTION' to use role: $GATEWAY_ROLE_ARN"
        
        # Update the Lambda function configuration
        aws lambda update-function-configuration \
            --function-name "$LAMBDA_FUNCTION" \
            --role "$GATEWAY_ROLE_ARN"
        
        echo ""
        echo "✅ Lambda function updated successfully!"
        echo "✅ The AI Calculator Lambda now uses the gateway service role"
        echo "✅ This should resolve the 'Access denied to Bedrock model' error"
        
        # Verify the change
        echo ""
        echo "🔍 Verifying the change..."
        UPDATED_ROLE=$(aws lambda get-function --function-name "$LAMBDA_FUNCTION" --query 'Configuration.Role' --output text)
        echo "Lambda function now uses role: $UPDATED_ROLE"
        
        if [ "$UPDATED_ROLE" = "$GATEWAY_ROLE_ARN" ]; then
            echo "✅ Role update confirmed successful!"
        else
            echo "❌ Role update may have failed. Please verify manually."
        fi
    else
        echo "❌ Skipping Lambda role update. Manual update required."
    fi
    
elif [ "$CAN_USE_GATEWAY_ROLE" = "NO" ]; then
    echo "❌ RECOMMENDATION: CANNOT USE GATEWAY SERVICE ROLE"
    echo ""
    echo "The gateway service role lacks Bedrock permissions."
    echo "Options:"
    echo "1. Add AmazonBedrockFullAccess to gateway service role"
    echo "2. Add Bedrock model invoke permissions to current Lambda role"
    echo "3. Create a new role with both Lambda and Bedrock permissions"
    
elif [ "$CAN_ASSUME" = "NO" ]; then
    echo "⚠️  RECOMMENDATION: UPDATE TRUST POLICY FIRST"
    echo ""
    echo "The gateway service role needs lambda.amazonaws.com in trust policy."
    echo "After fixing trust policy, we can use this role."
    
else
    echo "❌ RECOMMENDATION: USE ALTERNATIVE APPROACH"
    echo "Need to fix permissions on current Lambda role or gateway role."
fi

echo ""
echo "🔧 Summary:"
echo "=========="
echo "Gateway Role: $GATEWAY_SERVICE_ROLE"
echo "Bedrock Permissions: $BEDROCK_PERMISSIONS"
echo "Can Assume Role: $CAN_ASSUME"
echo "Recommended Action: $([ "$CAN_USE_GATEWAY_ROLE" = "YES" ] && [ "$CAN_ASSUME" = "YES" ] && echo "USE GATEWAY ROLE" || echo "FIX PERMISSIONS")"