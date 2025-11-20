# CloudShell MCP Gateway Testing Instructions

## Quick Setup for AWS CloudShell

### 1. Upload the test script to CloudShell

Open AWS CloudShell in the us-east-1 region and run:

```bash
# Upload the test script
cat > test-mcp-gateway.sh << 'EOF'
[COPY THE ENTIRE CONTENT OF test-mcp-gateway.sh HERE]
EOF

# Make it executable
chmod +x test-mcp-gateway.sh
```

### 2. Run the MCP gateway test

```bash
./test-mcp-gateway.sh
```

### 3. Expected Output

The script will:
- ✅ Detect CloudShell environment automatically
- ✅ Use CloudShell's temporary credentials
- ✅ Test MCP protocol connectivity with proper AWS SigV4 authentication
- ✅ Verify the `get_application_details` tool is available
- ✅ Test actual tool invocation

### 4. Alternative: Direct CloudShell Commands

If you prefer to run commands directly in CloudShell:

```bash
# Install required Python packages
pip3 install --user requests-aws4auth

# Test MCP endpoint with awscurl (if available)
# Note: awscurl might not be pre-installed in CloudShell

# Test with Python boto3 (always available in CloudShell)
python3 << 'EOF'
import json
import requests
from requests_aws4auth import AWS4Auth
import boto3

# Get AWS credentials from boto3 session
session = boto3.Session()
credentials = session.get_credentials()
region = 'us-east-1'
service = 'bedrock-agentcore'

# Create AWS4Auth object
auth = AWS4Auth(
    credentials.access_key,
    credentials.secret_key,
    region,
    service,
    session_token=credentials.token
)

# MCP tools/list request
url = 'https://a208194-askjulius-agentcore-mcp-gateway-dhy8ntpcvu.gateway.bedrock-agentcore.us-east-1.amazonaws.com/mcp'
headers = {'Content-Type': 'application/json'}
data = {
    "jsonrpc": "2.0",
    "id": 1,
    "method": "tools/list",
    "params": {}
}

response = requests.post(url, auth=auth, headers=headers, json=data)
print(f"Status: {response.status_code}")
print(f"Response: {response.text}")
EOF
```

### 5. Troubleshooting

If you encounter issues:

1. **Credentials Error**: CloudShell credentials are temporary and auto-refresh
2. **Gateway Not Found**: Verify the gateway was created successfully
3. **Authentication Error**: The gateway requires AWS IAM authentication, not Bearer tokens
4. **Region Mismatch**: Ensure you're in us-east-1 region

### 6. Gateway Information

- **Gateway Name**: a208194-askjulius-agentcore-gateway
- **Gateway ID**: (extracted from endpoint URL)
- **Endpoint**: https://a208194-askjulius-agentcore-mcp-gateway-dhy8ntpcvu.gateway.bedrock-agentcore.us-east-1.amazonaws.com
- **Region**: us-east-1
- **Authentication**: AWS IAM with SigV4 signing
- **Protocol**: MCP (Model Context Protocol)
- **Available Tool**: get_application_details (Lambda function)