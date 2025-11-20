#!/bin/bash
# Create Bedrock Agent Core Gateway using AWS Temporary Credentials
# This script guides you through setting up temporary credentials and creating the gateway

set -e

GATEWAY_NAME="a208194-askjulius-agentcore-gateway"
SERVICE_ROLE_NAME="a208194-askjulius-agentcore-gateway"
LAMBDA_ARN="arn:aws:lambda:us-east-1:818565325759:function:a208194-chatops_application_details_intent"
TARGET_NAME="a208194-application-details-tool-target"
TARGET_DESCRIPTION="Details of the application based on the asset insight"
REGION="us-east-1"

echo "🔐 AWS Temporary Credentials Setup for Agent Core Gateway Creation"
echo "=================================================================="
echo ""

# Check if AWS CLI is installed
if ! command -v aws >/dev/null 2>&1; then
    echo "❌ AWS CLI not found. Please install AWS CLI first:"
    echo "   curl 'https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip' -o 'awscliv2.zip'"
    echo "   unzip awscliv2.zip"
    echo "   sudo ./aws/install"
    exit 1
fi

echo "📋 Step 1: Set up AWS Temporary Credentials"
echo "============================================"
echo ""
echo "Option A: Use AWS SSO (Recommended)"
echo "-----------------------------------"
echo "1. Run: aws configure sso"
echo "2. Follow the prompts to set up SSO"
echo "3. Use your organization's SSO start URL"
echo ""
echo "Option B: Use AWS STS Assume Role"
echo "--------------------------------"
echo "If you have access to assume a role with proper permissions:"
echo ""

read -p "Do you want to configure temporary credentials now? (y/N): " configure_creds

if [[ $configure_creds =~ ^[Yy]$ ]]; then
    echo ""
    echo "🔧 Configuring AWS Temporary Credentials..."
    echo ""
    
    echo "Choose your method:"
    echo "1. AWS SSO Login"
    echo "2. Manual STS Token Entry"
    echo "3. Assume Role"
    echo "4. Skip (credentials already configured)"
    echo ""
    read -p "Enter choice (1-4): " cred_method
    
    case $cred_method in
        1)
            echo "🔐 Setting up AWS SSO..."
            echo "Follow the prompts to configure SSO:"
            aws configure sso
            echo ""
            echo "Now logging in via SSO..."
            aws sso login
            ;;
        2)
            echo "📝 Manual temporary credentials entry"
            echo "You'll need to provide:"
            echo "- AWS Access Key ID"
            echo "- AWS Secret Access Key"
            echo "- Session Token"
            echo ""
            read -p "AWS Access Key ID: " access_key
            read -p "AWS Secret Access Key: " secret_key
            read -p "Session Token: " session_token
            
            export AWS_ACCESS_KEY_ID="$access_key"
            export AWS_SECRET_ACCESS_KEY="$secret_key"
            export AWS_SESSION_TOKEN="$session_token"
            export AWS_DEFAULT_REGION="$REGION"
            
            echo "✅ Temporary credentials set via environment variables"
            ;;
        3)
            echo "🔄 Assume Role setup"
            read -p "Enter Role ARN to assume: " role_arn
            read -p "Enter Role Session Name: " session_name
            
            echo "Assuming role..."
            creds=$(aws sts assume-role \
                --role-arn "$role_arn" \
                --role-session-name "$session_name" \
                --output json)
            
            export AWS_ACCESS_KEY_ID=$(echo $creds | jq -r '.Credentials.AccessKeyId')
            export AWS_SECRET_ACCESS_KEY=$(echo $creds | jq -r '.Credentials.SecretAccessKey')
            export AWS_SESSION_TOKEN=$(echo $creds | jq -r '.Credentials.SessionToken')
            export AWS_DEFAULT_REGION="$REGION"
            
            echo "✅ Role assumed successfully"
            ;;
        4)
            echo "⏭️  Skipping credential configuration"
            ;;
        *)
            echo "❌ Invalid choice"
            exit 1
            ;;
    esac
fi

echo ""
echo "🧪 Step 2: Test AWS Credentials"
echo "==============================="

# Test AWS credentials
echo "Testing AWS credentials..."
if ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null); then
    echo "✅ AWS credentials working"
    echo "   Account ID: $ACCOUNT_ID"
    echo "   Region: $REGION"
else
    echo "❌ AWS credentials not working"
    echo ""
    echo "💡 Troubleshooting:"
    echo "1. Check if your temporary credentials are valid"
    echo "2. Verify you have permissions for STS operations"
    echo "3. Try running: aws sts get-caller-identity"
    echo ""
    exit 1
fi

SERVICE_ROLE_ARN="arn:aws:iam::${ACCOUNT_ID}:role/${SERVICE_ROLE_NAME}"

echo ""
echo "🏗️  Step 3: Create/Verify Service Role"
echo "======================================"

# Check if the service role exists
echo "Checking if service role exists..."
if aws iam get-role --role-name "$SERVICE_ROLE_NAME" >/dev/null 2>&1; then
    echo "✅ Service role '$SERVICE_ROLE_NAME' already exists"
else
    echo "🔧 Creating service role..."
    
    # Create trust policy for Agent Core Gateway
    cat > trust-policy-temp.json << EOF
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

    # Create the service role
    aws iam create-role \
        --role-name "$SERVICE_ROLE_NAME" \
        --assume-role-policy-document file://trust-policy-temp.json \
        --description "Service role for Agent Core Gateway $GATEWAY_NAME"
    
    # Attach necessary policies
    aws iam attach-role-policy \
        --role-name "$SERVICE_ROLE_NAME" \
        --policy-arn "arn:aws:iam::aws:policy/service-role/AmazonBedrockFullAccess"
    
    # Create inline policy for Lambda invocation
    cat > lambda-policy-temp.json << EOF
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
                "logs:CreateLogGroup",
                "logs:CreateLogStream",
                "logs:PutLogEvents"
            ],
            "Resource": "*"
        }
    ]
}
EOF

    aws iam put-role-policy \
        --role-name "$SERVICE_ROLE_NAME" \
        --policy-name "AgentCoreGatewayPolicy" \
        --policy-document file://lambda-policy-temp.json
    
    echo "✅ Service role created successfully"
    echo "⏳ Waiting 15 seconds for role propagation..."
    sleep 15
    
    # Clean up temporary files
    rm -f trust-policy-temp.json lambda-policy-temp.json
fi

echo ""
echo "🚀 Step 4: Create Agent Core Gateway"
echo "===================================="

# Try to create the gateway using different CLI methods
CREATION_SUCCESS=false

# Method 1: bedrock-agent-runtime
echo "🔄 Attempting gateway creation via bedrock-agent-runtime..."
if aws bedrock-agent-runtime help 2>/dev/null | grep -q "create-agent-core-gateway"; then
    if aws bedrock-agent-runtime create-agent-core-gateway \
        --gateway-name "$GATEWAY_NAME" \
        --service-role-arn "$SERVICE_ROLE_ARN" \
        --region "$REGION" 2>/dev/null; then
        echo "✅ Gateway created successfully via bedrock-agent-runtime!"
        CREATION_SUCCESS=true
    fi
fi

# Method 2: bedrock service
if [ "$CREATION_SUCCESS" != "true" ]; then
    echo "🔄 Attempting gateway creation via bedrock service..."
    if aws bedrock help 2>/dev/null | grep -q "create-agent-core-gateway"; then
        if aws bedrock create-agent-core-gateway \
            --gateway-name "$GATEWAY_NAME" \
            --service-role-arn "$SERVICE_ROLE_ARN" \
            --region "$REGION" 2>/dev/null; then
            echo "✅ Gateway created successfully via bedrock!"
            CREATION_SUCCESS=true
        fi
    fi
fi

# Method 3: CloudFormation as fallback
if [ "$CREATION_SUCCESS" != "true" ]; then
    echo "🔄 Attempting gateway creation via CloudFormation..."
    
    cat > agentcore-gateway-stack.yaml << EOF
AWSTemplateFormatVersion: '2010-09-09'
Description: 'Bedrock Agent Core Gateway with all configurations'

Resources:
  # Note: Agent Core Gateway CloudFormation support may be limited
  # This creates supporting resources, manual gateway creation may be required
  
  DummyResource:
    Type: AWS::CloudFormation::WaitConditionHandle

Outputs:
  GatewayName:
    Value: '$GATEWAY_NAME'
  ServiceRoleArn:
    Value: '$SERVICE_ROLE_ARN'
  LambdaArn:
    Value: '$LAMBDA_ARN'
  ManualCreationRequired:
    Value: 'Use AWS Console: Bedrock -> Agent Core -> Gateways'
EOF

    if aws cloudformation create-stack \
        --stack-name "agentcore-gateway-support-${GATEWAY_NAME}" \
        --template-body file://agentcore-gateway-stack.yaml \
        --region "$REGION" 2>/dev/null; then
        echo "✅ Support stack created, but manual gateway creation required"
    fi
    
    rm -f agentcore-gateway-stack.yaml
fi

echo ""
echo "📋 Step 5: Manual Creation Instructions (if needed)"
echo "=================================================="

if [ "$CREATION_SUCCESS" != "true" ]; then
    echo "⚠️  Automated creation not available. Use manual creation:"
    echo ""
    echo "🌐 AWS Console Steps:"
    echo "1. Go to: https://console.aws.amazon.com/bedrock/"
    echo "2. Navigate to: Agent Core → Gateways"
    echo "3. Click: Create Gateway"
    echo ""
    echo "📝 Use these exact values:"
    echo "   Gateway Name: $GATEWAY_NAME"
    echo "   Service Role ARN: $SERVICE_ROLE_ARN"
    echo "   Semantic Search: ✅ Enabled"
    echo "   Region: $REGION"
    echo ""
    echo "🎯 Target Configuration:"
    echo "   Target Name: $TARGET_NAME"
    echo "   Description: $TARGET_DESCRIPTION"
    echo "   Type: Lambda ARN"
    echo "   Lambda ARN: $LAMBDA_ARN"
    echo "   Outbound Auth: IAM Role"
    echo ""
    echo "🔑 Schema (copy-paste):"
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
fi

echo ""
echo "✅ Setup Complete!"
echo ""
echo "📊 Summary:"
echo "   Account ID: $ACCOUNT_ID"
echo "   Region: $REGION"
echo "   Gateway Name: $GATEWAY_NAME"
echo "   Service Role: $SERVICE_ROLE_ARN"
echo "   Lambda ARN: $LAMBDA_ARN"
echo ""

if [ "$CREATION_SUCCESS" = "true" ]; then
    echo "🎉 Gateway created successfully via AWS CLI!"
else
    echo "📌 Service role is ready - proceed with manual gateway creation"
    echo "💡 The temporary credentials are active for this session"
fi

echo ""
echo "🔄 Credential Management:"
echo "   - Current session credentials are temporary"
echo "   - They will expire based on your credential source"
echo "   - For future operations, re-run this script or configure permanent access"