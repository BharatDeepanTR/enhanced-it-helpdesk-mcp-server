#!/bin/bash
# Test Bedrock Agent Core Gateway with proper AWS authentication
# Use this in CloudShell where AWS credentials are available

echo "🔗 Testing Bedrock Agent Core Gateway Connection"
echo "==============================================="
echo ""

# Gateway configuration
GATEWAY_ENDPOINT="https://a208194-askjulius-agentcore-mcp-gateway-dhy8ntpcvu.gateway.bedrock-agentcore.us-east-1.amazonaws.com"
MCP_PATH="/mcp"
REGION="us-east-1"
SERVICE="bedrock-agentcore"

# Test AWS credentials
if ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null); then
    echo "✅ AWS credentials active - Account: $ACCOUNT_ID"
else
    echo "❌ AWS credentials not working - please configure first"
    exit 1
fi

echo ""
echo "🎯 Gateway Configuration:"
echo "========================"
echo "Endpoint: $GATEWAY_ENDPOINT"
echo "MCP Path: $MCP_PATH"
echo "Region: $REGION"
echo "Service: $SERVICE"
echo ""

# Method 1: Using AWS CLI with presigned URL
echo "🔄 Method 1: AWS CLI with Presigned URL"
echo "======================================"

# Create a temporary file with the JSON payload
cat > /tmp/mcp-request.json << 'EOF'
{
    "jsonrpc": "2.0",
    "id": 1,
    "method": "tools/list",
    "params": {}
}
EOF

echo "Testing tools/list method..."

# Try using aws s3api to generate presigned request (if supported)
# Note: This may need adjustment based on actual AWS CLI support for agentcore

# Method 2: Using curl with AWS SigV4 authentication
echo ""
echo "🔄 Method 2: Curl with AWS SigV4 Authentication"
echo "============================================="

# Get AWS credentials for SigV4
AWS_ACCESS_KEY_ID=$(aws configure get aws_access_key_id)
AWS_SECRET_ACCESS_KEY=$(aws configure get aws_secret_access_key)
AWS_SESSION_TOKEN=$(aws configure get aws_session_token)

# Create SigV4 signature (simplified approach)
REQUEST_DATE=$(date -u +"%Y%m%dT%H%M%SZ")
REQUEST_DATE_SHORT=$(date -u +"%Y%m%d")

echo "Using SigV4 authentication..."
echo "Request timestamp: $REQUEST_DATE"

# Method 3: Using awscurl (if available)
echo ""
echo "🔄 Method 3: Using awscurl Tool"
echo "============================="

# Check if awscurl is available
if command -v awscurl >/dev/null 2>&1; then
    echo "awscurl found, testing connection..."
    
    awscurl \
        --service bedrock-agentcore \
        --region "$REGION" \
        -X POST \
        -H "Content-Type: application/json" \
        -d @/tmp/mcp-request.json \
        "${GATEWAY_ENDPOINT}${MCP_PATH}"
else
    echo "awscurl not available, installing..."
    
    # Try to install awscurl
    if command -v pip3 >/dev/null 2>&1; then
        pip3 install --user awscurl
        export PATH="$HOME/.local/bin:$PATH"
        
        if command -v awscurl >/dev/null 2>&1; then
            echo "awscurl installed, testing connection..."
            
            awscurl \
                --service bedrock-agentcore \
                --region "$REGION" \
                -X POST \
                -H "Content-Type: application/json" \
                -d @/tmp/mcp-request.json \
                "${GATEWAY_ENDPOINT}${MCP_PATH}"
        else
            echo "Failed to install awscurl"
        fi
    else
        echo "pip3 not available, cannot install awscurl"
    fi
fi

# Method 4: Using AWS SDK (Python boto3)
echo ""
echo "🔄 Method 4: Python boto3 Test Script"
echo "==================================="

cat > /tmp/test_gateway.py << 'EOF'
#!/usr/bin/env python3
import boto3
import requests
import json
from botocore.auth import SigV4Auth
from botocore.awsrequest import AWSRequest
import urllib3
urllib3.disable_warnings()

def test_agentcore_gateway():
    # Gateway configuration
    gateway_url = "https://a208194-askjulius-agentcore-mcp-gateway-dhy8ntpcvu.gateway.bedrock-agentcore.us-east-1.amazonaws.com/mcp"
    region = "us-east-1"
    service = "bedrock-agentcore"
    
    # MCP request payload
    payload = {
        "jsonrpc": "2.0",
        "id": 1,
        "method": "tools/list",
        "params": {}
    }
    
    try:
        # Get AWS credentials
        session = boto3.Session()
        credentials = session.get_credentials()
        
        if not credentials:
            print("❌ No AWS credentials found")
            return
            
        print(f"✅ Using AWS credentials: {credentials.access_key[:8]}...")
        
        # Create AWS request
        request = AWSRequest(
            method='POST',
            url=gateway_url,
            data=json.dumps(payload),
            headers={
                'Content-Type': 'application/json'
            }
        )
        
        # Sign request with SigV4
        SigV4Auth(credentials, service, region).add_auth(request)
        
        print(f"🔄 Making request to: {gateway_url}")
        print(f"   Method: POST")
        print(f"   Payload: {json.dumps(payload)}")
        
        # Make the request
        response = requests.post(
            gateway_url,
            data=request.body,
            headers=dict(request.headers)
        )
        
        print(f"\n📊 Response:")
        print(f"   Status Code: {response.status_code}")
        print(f"   Headers: {dict(response.headers)}")
        print(f"   Content: {response.text}")
        
        if response.status_code == 200:
            print("✅ Gateway connection successful!")
        else:
            print(f"❌ Gateway connection failed: {response.status_code}")
            
    except Exception as e:
        print(f"❌ Error testing gateway: {e}")

if __name__ == "__main__":
    test_agentcore_gateway()
EOF

echo "Running Python test script..."
if command -v python3 >/dev/null 2>&1; then
    python3 /tmp/test_gateway.py
else
    echo "Python3 not available"
fi

# Method 5: Direct AWS CLI approach (if supported)
echo ""
echo "🔄 Method 5: Direct AWS CLI Invoke"
echo "================================="

# Try if there's a direct CLI command for invoking gateways
echo "Checking for direct AWS CLI gateway invoke command..."

# Get gateway ID
GATEWAY_ID=$(aws bedrock-agentcore-control list-gateways \
    --region "$REGION" \
    --query "gateways[?name=='a208194-askjulius-agentcore-gateway'].gatewayId" \
    --output text 2>/dev/null)

if [[ -n "$GATEWAY_ID" && "$GATEWAY_ID" != "None" ]]; then
    echo "Gateway ID: $GATEWAY_ID"
    
    # Try invoke command
    aws bedrock-agentcore-control invoke-gateway \
        --gateway-id "$GATEWAY_ID" \
        --payload file:///tmp/mcp-request.json \
        --region "$REGION" 2>/dev/null || echo "invoke-gateway command not available"
        
    # Alternative invoke patterns
    aws bedrock-agentcore invoke \
        --gateway-id "$GATEWAY_ID" \
        --body file:///tmp/mcp-request.json \
        --region "$REGION" 2>/dev/null || echo "bedrock-agentcore invoke not available"
else
    echo "Could not retrieve gateway ID"
fi

# Cleanup
rm -f /tmp/mcp-request.json /tmp/test_gateway.py

echo ""
echo "📋 Summary and Troubleshooting"
echo "=============================="
echo ""
echo "🔍 Common Issues:"
echo "1. Bearer Token Error: Use AWS SigV4, not Bearer tokens"
echo "2. Invalid Credentials: Ensure AWS credentials are valid"
echo "3. Permission Issues: Role needs bedrock-agentcore permissions"
echo "4. Gateway Not Ready: Check gateway status in console"
echo ""
echo "🛠️  Manual Testing Options:"
echo "1. Use AWS Console → Bedrock → Agent Core → Test"
echo "2. Use Postman with AWS IAM authentication"
echo "3. Use AWS SDK in your preferred language"
echo ""
echo "🔑 Required Permissions for Role:"
echo "- bedrock-agentcore:InvokeGateway"
echo "- bedrock-agentcore:GetGateway"
echo "- bedrock:InvokeModel (if applicable)"
echo ""
echo "✅ Testing completed!"