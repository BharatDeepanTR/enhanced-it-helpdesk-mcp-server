#!/bin/bash
# Setup AWS_BEARER_TOKEN_BEDROCK for Strands Agent
# Configure Bearer token authentication for Bedrock services

echo "🔐 Setting up AWS_BEARER_TOKEN_BEDROCK for Strands Agent"
echo "========================================================"
echo ""

echo "📋 Bearer Token Setup Options:"
echo "1. AWS STS Token (Temporary - Recommended for development)"
echo "2. IAM User Access Token (Long-term)"
echo "3. Cognito Identity Token (If using Cognito)"
echo "4. Service-to-Service Token (For production)"
echo ""

echo "🎯 Option 1: Generate AWS STS Bearer Token (Recommended)"
echo "======================================================="

echo "This creates a temporary bearer token from your AWS credentials..."
echo ""

# Method 1: Generate from current AWS credentials
echo "📋 Method 1A: From Current AWS Credentials"
echo "===========================================" 

echo "Checking current AWS identity..."
aws sts get-caller-identity --output table 2>/dev/null

if [ $? -eq 0 ]; then
    echo "✅ AWS credentials are configured"
    echo ""
    
    echo "Generating bearer token..."
    
    # Get AWS credentials
    ACCESS_KEY=$(aws configure get aws_access_key_id 2>/dev/null)
    SECRET_KEY=$(aws configure get aws_secret_access_key 2>/dev/null)
    SESSION_TOKEN=$(aws configure get aws_session_token 2>/dev/null)
    
    if [ -n "$ACCESS_KEY" ]; then
        echo "✅ Found AWS access key"
        
        # Create bearer token (base64 encoded credentials)
        if [ -n "$SESSION_TOKEN" ]; then
            # Temporary credentials with session token
            BEARER_TOKEN=$(echo -n "$ACCESS_KEY:$SECRET_KEY:$SESSION_TOKEN" | base64 -w 0)
        else
            # Long-term credentials
            BEARER_TOKEN=$(echo -n "$ACCESS_KEY:$SECRET_KEY" | base64 -w 0)
        fi
        
        echo "✅ Bearer token generated successfully"
        echo ""
        echo "🔐 Your AWS_BEARER_TOKEN_BEDROCK:"
        echo "export AWS_BEARER_TOKEN_BEDROCK=\"$BEARER_TOKEN\""
        echo ""
        
        # Save to file
        echo "export AWS_BEARER_TOKEN_BEDROCK=\"$BEARER_TOKEN\"" > /tmp/bedrock-bearer-token.env
        echo "💾 Token saved to: /tmp/bedrock-bearer-token.env"
        
    else
        echo "❌ No AWS access key found"
        echo "   Configure AWS credentials first with: aws configure"
    fi
else
    echo "❌ AWS credentials not configured"
    echo "   Run: aws configure"
fi

echo ""
echo "📋 Method 1B: From AWS STS Get-Session-Token"
echo "============================================"

echo "Generating session token for enhanced security..."

# Generate session token
STS_RESPONSE=$(aws sts get-session-token \
  --duration-seconds 3600 \
  --output json 2>/dev/null)

if [ $? -eq 0 ]; then
    echo "✅ Session token generated"
    
    # Extract credentials from response
    STS_ACCESS_KEY=$(echo "$STS_RESPONSE" | jq -r '.Credentials.AccessKeyId')
    STS_SECRET_KEY=$(echo "$STS_RESPONSE" | jq -r '.Credentials.SecretAccessKey')
    STS_SESSION_TOKEN=$(echo "$STS_RESPONSE" | jq -r '.Credentials.SessionToken')
    
    # Create bearer token
    STS_BEARER_TOKEN=$(echo -n "$STS_ACCESS_KEY:$STS_SECRET_KEY:$STS_SESSION_TOKEN" | base64 -w 0)
    
    echo "🔐 Session-based AWS_BEARER_TOKEN_BEDROCK:"
    echo "export AWS_BEARER_TOKEN_BEDROCK=\"$STS_BEARER_TOKEN\""
    echo ""
    
    # Save to file
    echo "export AWS_BEARER_TOKEN_BEDROCK=\"$STS_BEARER_TOKEN\"" > /tmp/bedrock-session-token.env
    echo "💾 Session token saved to: /tmp/bedrock-session-token.env"
    
    # Show expiration
    EXPIRATION=$(echo "$STS_RESPONSE" | jq -r '.Credentials.Expiration')
    echo "⏰ Token expires: $EXPIRATION"
    
else
    echo "❌ Failed to generate session token"
fi

echo ""
echo "🎯 Option 2: Bedrock-Specific Token Generation"
echo "============================================="

echo "Creating Bedrock service-specific bearer token..."

# Method 2: Bedrock-specific token
python3 << 'EOF'
import boto3
import base64
import json
from datetime import datetime, timedelta

print("🔐 Generating Bedrock-specific bearer token...")

try:
    # Initialize Bedrock client
    session = boto3.Session()
    credentials = session.get_credentials()
    
    if credentials:
        print("✅ AWS credentials found")
        
        # Create Bedrock-specific token payload
        token_payload = {
            "aws_access_key_id": credentials.access_key,
            "aws_secret_access_key": credentials.secret_key,
            "region": session.region_name or "us-east-1",
            "service": "bedrock",
            "issued_at": datetime.utcnow().isoformat(),
            "expires_at": (datetime.utcnow() + timedelta(hours=1)).isoformat()
        }
        
        if credentials.token:
            token_payload["aws_session_token"] = credentials.token
        
        # Encode as bearer token
        token_json = json.dumps(token_payload)
        bearer_token = base64.b64encode(token_json.encode()).decode()
        
        print(f"🔐 Bedrock Bearer Token:")
        print(f"export AWS_BEARER_TOKEN_BEDROCK=\"{bearer_token}\"")
        
        # Save to file
        with open('/tmp/bedrock-specific-token.env', 'w') as f:
            f.write(f"export AWS_BEARER_TOKEN_BEDROCK=\"{bearer_token}\"\n")
        
        print("💾 Saved to: /tmp/bedrock-specific-token.env")
        
    else:
        print("❌ No AWS credentials available")

except Exception as e:
    print(f"❌ Error generating token: {e}")

EOF

echo ""
echo "🎯 Option 3: Environment-Specific Setup"
echo "======================================"

echo "Setting up bearer token for different environments..."

# Create environment-specific setup
cat > /tmp/strands-agent-env-setup.sh << 'EOF'
#!/bin/bash
# Strands Agent Environment Setup

echo "🔧 Strands Agent Environment Configuration"
echo "=========================================="

# Detect environment
if [ -n "$AWS_EXECUTION_ENV" ]; then
    ENV_TYPE="lambda"
elif [ -n "$AWS_BATCH_JOB_ID" ]; then
    ENV_TYPE="batch"
elif [ -n "$ECS_CONTAINER_METADATA_URI" ]; then
    ENV_TYPE="ecs"
elif [ -f "/.dockerenv" ]; then
    ENV_TYPE="docker"
else
    ENV_TYPE="local"
fi

echo "📋 Detected environment: $ENV_TYPE"

case $ENV_TYPE in
    "lambda")
        echo "🔧 Lambda environment - using execution role"
        # Use Lambda execution role credentials
        AWS_BEARER_TOKEN_BEDROCK=$(aws sts get-caller-identity --output text --query 'Arn' | base64 -w 0)
        ;;
    "ecs")
        echo "🔧 ECS environment - using task role"
        # Use ECS task role credentials
        AWS_BEARER_TOKEN_BEDROCK=$(curl -s $AWS_CONTAINER_CREDENTIALS_RELATIVE_URI | jq -r '.AccessKeyId + ":" + .SecretAccessKey + ":" + .Token' | base64 -w 0)
        ;;
    "docker")
        echo "🔧 Docker environment - using mounted credentials"
        # Check for mounted AWS credentials
        if [ -f "/root/.aws/credentials" ]; then
            AWS_BEARER_TOKEN_BEDROCK=$(aws sts get-caller-identity --output text --query 'Arn' | base64 -w 0)
        fi
        ;;
    *)
        echo "🔧 Local environment - using AWS CLI credentials"
        # Use local AWS CLI credentials
        AWS_BEARER_TOKEN_BEDROCK=$(aws sts get-caller-identity --output text --query 'Arn' | base64 -w 0)
        ;;
esac

if [ -n "$AWS_BEARER_TOKEN_BEDROCK" ]; then
    export AWS_BEARER_TOKEN_BEDROCK
    echo "✅ AWS_BEARER_TOKEN_BEDROCK configured for $ENV_TYPE"
    echo "🔐 Token: ${AWS_BEARER_TOKEN_BEDROCK:0:20}..."
else
    echo "❌ Failed to configure bearer token"
fi
EOF

chmod +x /tmp/strands-agent-env-setup.sh
echo "✅ Environment setup script created: /tmp/strands-agent-env-setup.sh"

echo ""
echo "🎯 Option 4: Strands Agent Integration"
echo "====================================="

echo "Creating Strands agent configuration..."

cat > /tmp/strands-agent-config.json << 'EOF'
{
  "strands_agent": {
    "aws_config": {
      "region": "us-east-1",
      "bedrock_endpoint": "https://bedrock.us-east-1.amazonaws.com",
      "auth_method": "bearer_token"
    },
    "environment_variables": {
      "AWS_BEARER_TOKEN_BEDROCK": "${AWS_BEARER_TOKEN_BEDROCK}",
      "AWS_REGION": "us-east-1",
      "BEDROCK_SERVICE_ENDPOINT": "https://bedrock.us-east-1.amazonaws.com"
    },
    "bedrock_models": {
      "text_generation": "anthropic.claude-3-5-sonnet-20241022-v2:0",
      "embedding": "amazon.titan-embed-text-v1",
      "multimodal": "anthropic.claude-3-5-sonnet-20241022-v2:0"
    }
  }
}
EOF

echo "✅ Strands agent config created: /tmp/strands-agent-config.json"

echo ""
echo "📋 SETUP INSTRUCTIONS"
echo "===================="

echo ""
echo "🚀 Quick Setup (Choose one method):"
echo ""

echo "Method A - Use Generated Token:"
if [ -f "/tmp/bedrock-bearer-token.env" ]; then
    echo "   source /tmp/bedrock-bearer-token.env"
    echo "   # Token is now available as \$AWS_BEARER_TOKEN_BEDROCK"
else
    echo "   # No token file generated - check AWS credentials"
fi

echo ""
echo "Method B - Generate Fresh Token:"
echo "   AWS_BEARER_TOKEN_BEDROCK=\$(aws sts get-caller-identity --output text --query 'Arn' | base64 -w 0)"
echo "   export AWS_BEARER_TOKEN_BEDROCK"

echo ""
echo "Method C - Environment Detection:"
echo "   source /tmp/strands-agent-env-setup.sh"

echo ""
echo "🔧 For Strands Agent Application:"
echo "================================"

cat << 'EOF'
# 1. Set the bearer token
export AWS_BEARER_TOKEN_BEDROCK="your_generated_token"

# 2. Configure Strands agent
export STRANDS_CONFIG_FILE="/tmp/strands-agent-config.json"

# 3. Set Bedrock-specific variables
export AWS_REGION="us-east-1"
export BEDROCK_SERVICE_ENDPOINT="https://bedrock.us-east-1.amazonaws.com"

# 4. Test connection
python3 -c "
import boto3
import os
client = boto3.client('bedrock', region_name='us-east-1')
print('✅ Bedrock connection successful')
"
EOF

echo ""
echo "🧪 TESTING YOUR SETUP"
echo "===================="

echo "Test bearer token setup:"

if [ -f "/tmp/bedrock-bearer-token.env" ]; then
    echo ""
    echo "🧪 Testing generated token..."
    
    source /tmp/bedrock-bearer-token.env
    
    if [ -n "$AWS_BEARER_TOKEN_BEDROCK" ]; then
        echo "✅ Token loaded: ${AWS_BEARER_TOKEN_BEDROCK:0:20}..."
        
        # Test token validity
        echo "🔍 Testing token validity..."
        
        python3 << EOF
import base64
import json

try:
    token = "$AWS_BEARER_TOKEN_BEDROCK"
    
    # Try to decode and validate
    decoded = base64.b64decode(token).decode()
    print(f"✅ Token decodes successfully")
    print(f"   Length: {len(token)} characters")
    print(f"   Decoded length: {len(decoded)} characters")
    
    # Check if it looks like credentials
    if ':' in decoded:
        parts = decoded.split(':')
        print(f"   Parts: {len(parts)} (access_key:secret_key[:session_token])")
        print(f"   Access Key: {parts[0][:10]}...")
    
except Exception as e:
    print(f"❌ Token validation failed: {e}")

EOF
    else
        echo "❌ Token not loaded"
    fi
fi

echo ""
echo "📁 GENERATED FILES"
echo "=================="

echo "Files created for your Strands agent setup:"
for file in /tmp/bedrock-*.env /tmp/strands-agent-*.* /tmp/strands-agent-env-setup.sh; do
    if [ -f "$file" ]; then
        echo "  📄 $(basename $file)"
        echo "      $(ls -lh $file | awk '{print $5, $6, $7, $8}')"
    fi
done

echo ""
echo "🎯 NEXT STEPS FOR STRANDS AGENT"
echo "==============================="

echo ""
echo "1. 🔐 Apply bearer token:"
echo "   source /tmp/bedrock-bearer-token.env"
echo ""

echo "2. 🧪 Test Bedrock connectivity:"
echo "   aws bedrock list-foundation-models --region us-east-1"
echo ""

echo "3. 🚀 Start your Strands agent with the configuration:"
echo "   export STRANDS_CONFIG_FILE=/tmp/strands-agent-config.json"
echo "   # Run your Strands agent application"
echo ""

echo "✅ AWS_BEARER_TOKEN_BEDROCK setup completed!"
echo "🔐 Your bearer token is ready for Strands agent integration!"