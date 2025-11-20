## 🔧 Manual MCP Wrapper Deployment Guide
## AWS Lambda Console - Step by Step

### 📋 **Pre-Deployment Setup**
Your Python code is ready at: `/tmp/mcp-wrapper-code.py` in CloudShell

---

## 🚀 **Step 1: Access AWS Lambda Console**

1. **Open AWS Console**: https://console.aws.amazon.com/lambda/
2. **Select Region**: us-east-1 (important!)
3. **Click**: "Create function"

---

## ⚙️ **Step 2: Basic Function Configuration**

### Function Settings:
- **Function name**: `mcp-wrapper-lambda`
- **Runtime**: `Python 3.9` or `Python 3.11`
- **Architecture**: `x86_64` (default)

### Execution Role:
- **Select**: "Use an existing role"
- **Existing role**: `a208194-askjulius-agentcore-gateway`
  - ⚠️ **Important**: This role already has the necessary permissions
  - 💡 **Why**: Avoids IAM PassRole permission issues

### Advanced Settings (Optional):
- **Timeout**: 60 seconds
- **Memory**: 256 MB

**Click**: "Create function"

---

## 📝 **Step 3: Deploy the Code**

### Get the Code:
In CloudShell, display the code:
```bash
cat /tmp/mcp-wrapper-code.py
```

### Copy & Paste:
1. **In Lambda Console**: Go to "Code" tab
2. **Delete** existing code in `lambda_function.py`
3. **Paste** the entire code from `/tmp/mcp-wrapper-code.py`
4. **Click**: "Deploy"

---

## 🧪 **Step 4: Test the Function**

### Create Test Event:
1. **Click**: "Test" button
2. **Create new event**:
   - **Event name**: `mcp-tools-list-test`
   - **Template**: Custom event
   - **Event JSON**:
```json
{
  "jsonrpc": "2.0",
  "id": "test-1",
  "method": "tools/list",
  "params": {}
}
```

3. **Click**: "Save" then "Test"

### Expected Response:
```json
{
  "jsonrpc": "2.0",
  "id": "test-1",
  "result": {
    "tools": [
      {
        "name": "get_application_details",
        "description": "Get application details for a given asset ID",
        "inputSchema": {
          "type": "object",
          "properties": {
            "asset_id": {
              "type": "string",
              "description": "Application asset ID"
            }
          },
          "required": ["asset_id"]
        }
      }
    ]
  }
}
```

---

## 🔍 **Step 5: Get Function ARN**

After successful deployment:

1. **In Lambda Console**: Go to function overview
2. **Copy ARN**: Should look like:
   ```
   arn:aws:lambda:us-east-1:818565325759:function:mcp-wrapper-lambda
   ```
3. **Save this ARN** - you'll need it for gateway configuration

---

## 🌐 **Step 6: Update Gateway Configuration**

### Option A: CloudShell Commands
```bash
# In CloudShell, use your wrapper function ARN:
WRAPPER_ARN="arn:aws:lambda:us-east-1:818565325759:function:mcp-wrapper-lambda"
GATEWAY_ID="a208194-askjulius-agentcore-gateway-mcp-iam-fvro4phd59"

# Try method 1:
aws bedrock-agentcore-control update-gateway \
  --gateway-id "$GATEWAY_ID" \
  --target-lambda-arn "$WRAPPER_ARN" \
  --output json

# If that fails, try method 2:
aws bedrock-agentcore-control update-gateway \
  --gateway-id "$GATEWAY_ID" \
  --lambda-arn "$WRAPPER_ARN" \
  --output json
```

### Option B: Bedrock Console
1. **Go to**: AWS Bedrock Console → Agent Core → Gateways
2. **Find**: `a208194-askjulius-agentcore-gateway-mcp-iam-fvro4phd59`
3. **Click**: "Edit" or "Configure"
4. **Update Lambda ARN**: Paste your wrapper function ARN
5. **Save**: Configuration

---

## 🧪 **Step 7: Test End-to-End**

### CloudShell Test:
```bash
# Create test script
cat > test_final_gateway.py << 'EOF'
import boto3
import requests
from botocore.auth import SigV4Auth
from botocore.awsrequest import AWSRequest
import json
from urllib.parse import urlparse

gateway_url = "https://a208194-askjulius-agentcore-gateway-mcp-iam-fvro4phd59.gateway.bedrock-agentcore.us-east-1.amazonaws.com/mcp"

session = boto3.Session()
credentials = session.get_credentials()

payload = {
    "jsonrpc": "2.0",
    "id": "final-test",
    "method": "tools/list",
    "params": {}
}

body = json.dumps(payload)
parsed_url = urlparse(gateway_url)

request = AWSRequest(
    method='POST',
    url=gateway_url,
    data=body,
    headers={
        'Content-Type': 'application/json',
        'Host': parsed_url.netloc
    }
)

SigV4Auth(credentials, 'bedrock-agentcore', 'us-east-1').add_auth(request)
headers = dict(request.headers)

response = requests.post(gateway_url, headers=headers, data=body, timeout=30)

print(f"Status: {response.status_code}")
if response.status_code == 200:
    result = response.json()
    if 'result' in result and 'tools' in result['result']:
        print("🎉 SUCCESS! Gateway → MCP Wrapper working!")
        print(f"Tools: {len(result['result']['tools'])}")
    else:
        print("Response:", result)
else:
    print("Error:", response.text)
EOF

python3 test_final_gateway.py
```

---

## 🎯 **Success Indicators**

### ✅ **Function Deployed Successfully When:**
- Lambda test returns proper MCP JSON response
- No errors in CloudWatch logs
- Function ARN is available

### ✅ **Gateway Updated Successfully When:**
- Update commands return success (no errors)
- Get-gateway shows your wrapper function ARN
- End-to-end test returns tools list

### ✅ **Complete Success When:**
- Gateway test returns: "🎉 SUCCESS! Gateway → MCP Wrapper working!"
- Tools list includes "get_application_details"
- Can call tools/call method successfully

---

## 🔧 **Troubleshooting**

### If Lambda Creation Fails:
- **Issue**: Role not found
- **Solution**: Use IAM console to verify `a208194-askjulius-agentcore-gateway` role exists

### If Gateway Update Fails:
- **Issue**: Parameter not recognized
- **Solution**: Try different parameter names or use Bedrock console

### If Test Fails:
- **Issue**: 401/403 errors
- **Solution**: Check IAM permissions and gateway configuration

---

## 📋 **Quick Summary**

1. ✅ **Create Lambda**: Use console with existing role
2. ✅ **Deploy Code**: Copy from `/tmp/mcp-wrapper-code.py`
3. ✅ **Test Function**: Use MCP JSON payload
4. ✅ **Get ARN**: Copy from Lambda console
5. ✅ **Update Gateway**: Use CloudShell commands
6. ✅ **Test Gateway**: Run end-to-end test

**Expected Result**: Full MCP protocol support through your gateway!