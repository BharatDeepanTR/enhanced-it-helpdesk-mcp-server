#!/bin/bash
# Test Bedrock Agent Core Gateway with proper AWS SigV4 authentication
# This script handles the AWS IAM authentication for MCP protocol testing

set -e

GATEWAY_ENDPOINT="https://a208194-askjulius-agentcore-mcp-gateway-dhy8ntpcvu.gateway.bedrock-agentcore.us-east-1.amazonaws.com"
MCP_PATH="/mcp"
REGION="us-east-1"
SERVICE="bedrock-agentcore"

echo "🔧 Bedrock Agent Core Gateway MCP Testing"
echo "========================================="
echo ""
echo "Gateway Endpoint: $GATEWAY_ENDPOINT"
echo "MCP Path: $MCP_PATH"
echo "Authentication: AWS IAM (SigV4)"
echo ""

# Detect environment and setup credentials
if [[ "$AWS_EXECUTION_ENV" == "CloudShell"* ]] || [[ -n "$AWS_CLOUDSHELL_USER_ID" ]]; then
    echo "🌩️  Detected AWS CloudShell environment"
    echo "Using CloudShell temporary credentials..."
    
    # CloudShell has credentials pre-configured
    if ! aws sts get-caller-identity &>/dev/null; then
        echo "❌ CloudShell credentials not available"
        echo "Please refresh your CloudShell session"
        exit 1
    fi
else
    echo "💻 Detected local environment"
    # Check if AWS CLI is configured
    if ! aws sts get-caller-identity >/dev/null 2>&1; then
        echo "❌ AWS credentials not configured"
        echo "Please run: aws configure"
        echo "Or upload this script to AWS CloudShell for automatic credential handling"
        exit 1
    fi
fi

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo "✅ AWS Account: $ACCOUNT_ID"
echo ""

# Test 1: Basic MCP tools/list request using awscurl (if available)
echo "🧪 Test 1: Using awscurl (if available)"
echo "======================================"

if command -v awscurl >/dev/null 2>&1; then
    echo "Using awscurl for SigV4 signed request..."
    
    awscurl \
        --service "$SERVICE" \
        --region "$REGION" \
        -X POST \
        -H "Content-Type: application/json" \
        -d '{"jsonrpc":"2.0","id":1,"method":"tools/list","params":{}}' \
        "${GATEWAY_ENDPOINT}${MCP_PATH}"
    
    echo ""
else
    echo "⚠️  awscurl not available, trying alternative methods..."
fi

# Test 2: Using AWS CLI with SigV4 signing
echo ""
echo "🧪 Test 2: Using AWS CLI for signed requests"
echo "==========================================="

# Create temporary file for request body
cat > /tmp/mcp-request.json << 'EOF'
{
    "jsonrpc": "2.0",
    "id": 1,
    "method": "tools/list",
    "params": {}
}
EOF

echo "Making signed request using AWS CLI..."

# Use aws execute-api if available for API Gateway-style endpoints
if aws apigateway help >/dev/null 2>&1; then
    echo "Trying AWS API Gateway approach..."
    
    # Extract API ID from the gateway endpoint
    API_ID=$(echo "$GATEWAY_ENDPOINT" | sed 's/https:\/\/\([^.]*\).*/\1/')
    
    aws apigateway test-invoke-method \
        --rest-api-id "$API_ID" \
        --resource-id "/" \
        --http-method POST \
        --path-with-query-string "$MCP_PATH" \
        --body file:///tmp/mcp-request.json \
        --region "$REGION" 2>/dev/null || echo "API Gateway method not applicable"
fi

# Test 3: Using Python with boto3 and requests-aws4auth
echo ""
echo "🧪 Test 3: Python script with SigV4 authentication"
echo "================================================="

cat > /tmp/test_mcp_gateway.py << 'EOF'
#!/usr/bin/env python3
import boto3
import requests
import json
from requests_aws4auth import AWS4Auth

# Gateway configuration
gateway_endpoint = "https://a208194-askjulius-agentcore-mcp-gateway-dhy8ntpcvu.gateway.bedrock-agentcore.us-east-1.amazonaws.com"
mcp_path = "/mcp"
region = "us-east-1"
service = "bedrock-agentcore"

# Get AWS credentials
session = boto3.Session()
credentials = session.get_credentials()

# Create AWS4Auth object
auth = AWS4Auth(
    credentials.access_key,
    credentials.secret_key,
    region,
    service,
    session_token=credentials.token
)

# MCP request payload
mcp_request = {
    "jsonrpc": "2.0",
    "id": 1,
    "method": "tools/list",
    "params": {}
}

try:
    print(f"🔄 Making SigV4-signed request to: {gateway_endpoint}{mcp_path}")
    
    response = requests.post(
        f"{gateway_endpoint}{mcp_path}",
        json=mcp_request,
        auth=auth,
        headers={"Content-Type": "application/json"}
    )
    
    print(f"✅ Response Status: {response.status_code}")
    print(f"📄 Response Headers: {dict(response.headers)}")
    print(f"📋 Response Body: {response.text}")
    
    if response.status_code == 200:
        print("🎉 MCP Gateway connection successful!")
    else:
        print(f"⚠️  Unexpected status code: {response.status_code}")

except Exception as e:
    print(f"❌ Error: {e}")
EOF

# Try to run the Python script
if command -v python3 >/dev/null 2>&1; then
    echo "Installing required Python packages..."
    pip3 install --user requests-aws4auth boto3 requests >/dev/null 2>&1 || echo "Package installation failed, but may already be installed"
    
    echo "Running Python test..."
    python3 /tmp/test_mcp_gateway.py
else
    echo "⚠️  Python3 not available for testing"
fi

# Test 4: Manual curl with SigV4 (complex but educational)
echo ""
echo "🧪 Test 4: Manual SigV4 signing instructions"
echo "==========================================="

echo "For manual curl with SigV4, you would need to:"
echo "1. Generate AWS SigV4 signature"
echo "2. Include appropriate headers"
echo ""
echo "Example headers needed:"
echo "- Authorization: AWS4-HMAC-SHA256 Credential=..., SignedHeaders=..., Signature=..."
echo "- X-Amz-Date: <ISO8601 timestamp>"
echo "- X-Amz-Security-Token: <session token if using temporary credentials>"
echo ""

# Test 5: Alternative MCP methods
echo ""
echo "🧪 Test 5: Testing other MCP methods"
echo "=================================="

# Test tools/call method
cat > /tmp/mcp-tools-call.json << 'EOF'
{
    "jsonrpc": "2.0",
    "id": 2,
    "method": "tools/call",
    "params": {
        "name": "get_application_details",
        "arguments": {
            "asset_id": "a12345"
        }
    }
}
EOF

# Test resources/list method
cat > /tmp/mcp-resources-list.json << 'EOF'
{
    "jsonrpc": "2.0",
    "id": 3,
    "method": "resources/list",
    "params": {}
}
EOF

echo "Created additional MCP test payloads:"
echo "- tools/call: /tmp/mcp-tools-call.json"
echo "- resources/list: /tmp/mcp-resources-list.json"
echo ""

# Cleanup and summary
echo ""
echo "📋 Testing Summary"
echo "=================="
echo ""
echo "🔑 Key Points:"
echo "1. Your gateway uses AWS IAM authentication (not Bearer tokens)"
echo "2. All requests must be signed with AWS SigV4"
echo "3. The endpoint converts your Lambda function to MCP-compatible tools"
echo ""
echo "✅ Successful connection indicators:"
echo "- HTTP 200 response"
echo "- Valid JSON-RPC 2.0 response"
echo "- tools/list returns available tools"
echo ""
echo "🛠️  If authentication still fails:"
echo "1. Verify the IAM role has bedrock-agentcore permissions"
echo "2. Check if the gateway is in 'Active' status"
echo "3. Ensure your AWS credentials have access to invoke the gateway"
echo ""

# Show proper awscurl installation if needed
echo "📦 Install awscurl for easier testing:"
echo "pip3 install --user awscurl"
echo ""
echo "Then test with:"
echo "awscurl --service bedrock-agentcore --region us-east-1 \\"
echo "  -X POST -H 'Content-Type: application/json' \\"
echo "  -d '{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"tools/list\",\"params\":{}}' \\"
echo "  '${GATEWAY_ENDPOINT}${MCP_PATH}'"

# Cleanup temporary files
rm -f /tmp/mcp-request.json /tmp/mcp-tools-call.json /tmp/mcp-resources-list.json /tmp/test_mcp_gateway.py

echo ""
echo "✅ MCP Gateway testing script completed!"