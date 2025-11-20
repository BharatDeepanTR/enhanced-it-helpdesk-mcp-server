#!/bin/bash
# Cloud Shell Optimized: Create Bedrock Agent Core Gateway
# Works with AWS CloudShell, Google Cloud Shell, or any temporary environment

set -e

GATEWAY_NAME="a208194-askjulius-agentcore-gateway"
SERVICE_ROLE_NAME="a208194-askjulius-agentcore-gateway"
LAMBDA_ARN="arn:aws:lambda:us-east-1:818565325759:function:a208194-chatops_application_details_intent"
TARGET_NAME="a208194-application-details-tool-target"
TARGET_DESCRIPTION="Details of the application based on the asset insight"
REGION="us-east-1"

echo "☁️  Cloud Shell: Bedrock Agent Core Gateway Creator"
echo "=================================================="
echo ""

# Detect environment
if [[ "$CLOUD_SHELL" == "true" ]]; then
    echo "🌐 Detected: Google Cloud Shell"
    SHELL_TYPE="gcp"
elif [[ -n "$AWS_EXECUTION_ENV" ]] || [[ -n "$AWS_CLOUDSHELL_USER_ID" ]]; then
    echo "☁️  Detected: AWS CloudShell"
    SHELL_TYPE="aws"
elif [[ -n "$CODESPACES" ]]; then
    echo "💻 Detected: GitHub Codespaces"
    SHELL_TYPE="codespaces"
else
    echo "🖥️  Detected: Local/Other Environment"
    SHELL_TYPE="local"
fi

echo "   Environment: $SHELL_TYPE"
echo ""

# Step 1: AWS CLI Installation/Check
echo "📋 Step 1: AWS CLI Setup"
echo "========================"

if ! command -v aws >/dev/null 2>&1; then
    echo "🔧 Installing AWS CLI..."
    case $SHELL_TYPE in
        "gcp"|"codespaces"|"local")
            curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
            unzip -q awscliv2.zip
            sudo ./aws/install
            rm -rf aws awscliv2.zip
            ;;
        "aws")
            echo "✅ AWS CLI should be pre-installed in AWS CloudShell"
            ;;
    esac
else
    echo "✅ AWS CLI found: $(aws --version | head -1)"
fi

# Step 2: Credential Setup Based on Environment
echo ""
echo "🔐 Step 2: AWS Credentials Setup"
echo "================================"

case $SHELL_TYPE in
    "aws")
        echo "☁️  AWS CloudShell: Credentials should be automatic"
        if aws sts get-caller-identity >/dev/null 2>&1; then
            echo "✅ AWS credentials active"
        else
            echo "❌ AWS credentials issue in CloudShell"
            exit 1
        fi
        ;;
    "gcp")
        echo "🌐 Google Cloud Shell: Manual AWS credential setup required"
        echo ""
        echo "Choose credential method:"
        echo "1. AWS SSO Login"
        echo "2. Temporary Access Keys"
        echo "3. AWS CLI Configure"
        echo ""
        read -p "Enter choice (1-3): " cred_choice
        
        case $cred_choice in
            1)
                echo "Setting up AWS SSO..."
                aws configure sso
                aws sso login
                ;;
            2)
                echo "Enter temporary AWS credentials:"
                read -p "Access Key ID: " aws_access_key
                read -s -p "Secret Access Key: " aws_secret_key
                echo ""
                read -p "Session Token (optional): " aws_session_token
                
                export AWS_ACCESS_KEY_ID="$aws_access_key"
                export AWS_SECRET_ACCESS_KEY="$aws_secret_key"
                if [[ -n "$aws_session_token" ]]; then
                    export AWS_SESSION_TOKEN="$aws_session_token"
                fi
                export AWS_DEFAULT_REGION="$REGION"
                
                echo "✅ Credentials set via environment variables"
                ;;
            3)
                aws configure
                ;;
        esac
        ;;
    *)
        echo "🔧 Standard credential setup"
        if ! aws sts get-caller-identity >/dev/null 2>&1; then
            echo "Setting up AWS credentials..."
            aws configure
        fi
        ;;
esac

# Verify credentials
echo ""
echo "🧪 Testing AWS Access..."
if ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null); then
    echo "✅ AWS Access Verified"
    echo "   Account: $ACCOUNT_ID"
    echo "   Region: $REGION"
else
    echo "❌ AWS Access Failed"
    echo "Please check your credentials and try again"
    exit 1
fi

SERVICE_ROLE_ARN="arn:aws:iam::${ACCOUNT_ID}:role/${SERVICE_ROLE_NAME}"

# Step 3: Service Role Management
echo ""
echo "🛠️  Step 3: Service Role Setup"
echo "============================="

echo "Checking service role: $SERVICE_ROLE_NAME"
if aws iam get-role --role-name "$SERVICE_ROLE_NAME" >/dev/null 2>&1; then
    echo "✅ Service role exists: $SERVICE_ROLE_ARN"
else
    echo "🔧 Creating service role..."
    
    # Trust policy
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

    # Lambda invoke policy
    cat > /tmp/lambda-policy.json << EOF
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
                "logs:PutLogEvents",
                "bedrock:*"
            ],
            "Resource": "*"
        }
    ]
}
EOF

    # Create role
    aws iam create-role \
        --role-name "$SERVICE_ROLE_NAME" \
        --assume-role-policy-document file:///tmp/trust-policy.json \
        --description "Agent Core Gateway service role"

    # Attach policies
    aws iam attach-role-policy \
        --role-name "$SERVICE_ROLE_NAME" \
        --policy-arn "arn:aws:iam::aws:policy/service-role/AmazonBedrockFullAccess"

    aws iam put-role-policy \
        --role-name "$SERVICE_ROLE_NAME" \
        --policy-name "AgentCoreGatewayInlinePolicy" \
        --policy-document file:///tmp/lambda-policy.json

    echo "✅ Service role created: $SERVICE_ROLE_ARN"
    echo "⏳ Waiting for role propagation..."
    sleep 10

    # Cleanup
    rm -f /tmp/trust-policy.json /tmp/lambda-policy.json
fi

# Step 4: Gateway Creation Attempts
echo ""
echo "🚀 Step 4: Agent Core Gateway Creation"
echo "====================================="

GATEWAY_CREATED=false

# Try various CLI methods
echo "🔄 Attempting automated gateway creation..."

# Method 1: Direct bedrock command
if command -v aws >/dev/null 2>&1; then
    echo "   Trying: aws bedrock create-agent-core-gateway..."
    if aws bedrock create-agent-core-gateway \
        --gateway-name "$GATEWAY_NAME" \
        --service-role-arn "$SERVICE_ROLE_ARN" \
        --region "$REGION" 2>/dev/null; then
        echo "✅ Gateway created via bedrock service!"
        GATEWAY_CREATED=true
    fi
fi

# Method 2: bedrock-agent-runtime
if [ "$GATEWAY_CREATED" != "true" ]; then
    echo "   Trying: aws bedrock-agent-runtime..."
    if aws bedrock-agent-runtime create-agent-core-gateway \
        --gateway-name "$GATEWAY_NAME" \
        --service-role-arn "$SERVICE_ROLE_ARN" \
        --region "$REGION" 2>/dev/null; then
        echo "✅ Gateway created via bedrock-agent-runtime!"
        GATEWAY_CREATED=true
    fi
fi

# Step 5: Manual Creation Guide
if [ "$GATEWAY_CREATED" != "true" ]; then
    echo ""
    echo "📋 Step 5: Manual Creation Required"
    echo "=================================="
    echo ""
    echo "⚠️  Automated creation not available. Manual steps:"
    echo ""
    echo "🌐 Open AWS Console:"
    echo "   https://console.aws.amazon.com/bedrock/"
    echo ""
    echo "🎯 Navigate to:"
    echo "   Bedrock → Agent Core → Gateways → Create Gateway"
    echo ""
    echo "📝 Configuration Values:"
    echo "   ┌─────────────────────────────────────────────────────────────────┐"
    echo "   │ Gateway Name: $GATEWAY_NAME"
    echo "   │ Service Role: $SERVICE_ROLE_ARN"
    echo "   │ Semantic Search: ✅ Enabled"
    echo "   │ Region: $REGION"
    echo "   └─────────────────────────────────────────────────────────────────┘"
    echo ""
    echo "🎯 Target Configuration:"
    echo "   ┌─────────────────────────────────────────────────────────────────┐"
    echo "   │ Target Name: $TARGET_NAME"
    echo "   │ Description: $TARGET_DESCRIPTION"
    echo "   │ Type: Lambda ARN"
    echo "   │ Lambda ARN: $LAMBDA_ARN"
    echo "   │ Outbound Auth: IAM Role"
    echo "   └─────────────────────────────────────────────────────────────────┘"
    echo ""
    echo "📄 Schema Configuration:"
    echo "   Schema Type: Define an inline schema"
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
fi

# Final Summary
echo ""
echo "📊 Creation Summary"
echo "=================="
echo "   Environment: $SHELL_TYPE"
echo "   Account ID: $ACCOUNT_ID"
echo "   Region: $REGION"
echo "   Service Role: ✅ Ready"
echo "   Gateway: $([ "$GATEWAY_CREATED" = "true" ] && echo "✅ Created" || echo "📋 Manual Creation Required")"
echo ""

if [ "$GATEWAY_CREATED" = "true" ]; then
    echo "🎉 Success! Gateway created automatically"
    echo "💡 You can now test with: {\"asset_id\": \"a12345\"}"
else
    echo "📌 Next: Follow manual creation steps above"
    echo "💡 Service role is ready and verified"
fi

echo ""
echo "🔄 Session Information:"
case $SHELL_TYPE in
    "aws")
        echo "   AWS CloudShell: Credentials persist during session"
        ;;
    "gcp")
        echo "   Google Cloud Shell: AWS credentials are temporary"
        echo "   Re-run this script if session expires"
        ;;
    *)
        echo "   Local environment: Check credential persistence"
        ;;
esac

echo ""
echo "✅ Setup Complete!"